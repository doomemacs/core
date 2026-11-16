<#
.SYNOPSIS
    Install a per-user Doom Emacs bundle and its base dependencies.

.DESCRIPTION
    This is the install engine, and it is deliberately the ONLY place install logic
    lives. Two callers share it:

      * the NSIS installer, which unpacks the payload beside this script and calls
        it with -SourceMode Staging
      * a person running it directly, on a machine with nothing installed

    Both paths therefore get identical behaviour, an identical footprint, and an
    identical uninstaller. Because it is shared, this is the highest-blast-radius
    file in the installer: lifecycle checks must exercise this script as well as
    the compiled .exe.

    Needs no administrator rights. Everything lands under %LOCALAPPDATA% and HKCU,
    which is also why no UAC prompt ever appears.

    Writes install-manifest.json recording exactly what it created versus what it
    found already present. uninstall-doom.ps1 reads that file; nothing outside it
    is ever removed.

.PARAMETER SourceMode
    Staging  - payload already unpacked at -SourcePath (what NSIS uses)
    Cache    - verified archives at -SourcePath, unpack them here
    Download - fetch per payloads.lock.json, then unpack. Convenient standalone,
               and requires network access when archives are missing.

.EXAMPLE
    # Standalone, from nothing:
    .\install-doom.ps1 -SourceMode Download

    # What NSIS runs:
    .\install-doom.ps1 -SourceMode Staging -SourcePath .\payload -Silent
#>
[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'Programs\DoomEmacs'),
    [ValidateSet('Staging', 'Cache', 'Download', 'InPlace')]
    [string]$SourceMode = 'Staging',
    [string]$SourcePath,
    [string]$DoomDir = (Join-Path $env:USERPROFILE '.config\doom'),
    [switch]$Silent,
    [switch]$NoPathUpdate,
    [switch]$NoShortcut,
    [switch]$NoDesktopShortcut,
    [switch]$NoStartMenuShortcut,
    [switch]$NoSync,
    # Native optimization is optional; byte compilation remains mandatory.
    [switch]$AOT,
    [switch]$NoAOT,
    [switch]$RebuildPackages,
    [switch]$OwnInstallRoot,
    [string]$WslDistro,
    [string]$RegistryKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\DoomEmacs',
    [switch]$Force
)

$ErrorActionPreference = 'Stop'
$sw = [System.Diagnostics.Stopwatch]::StartNew()
$explicitDoomDir = $PSBoundParameters.ContainsKey('DoomDir')

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

# Raw HKCU\Environment\Path helpers; defined in one place so installer and
# uninstaller cannot drift on how PATH is read or written.
. (Join-Path $scriptDir 'env-path.ps1')
. (Join-Path $scriptDir 'wsl-integration.ps1')
. (Join-Path $scriptDir 'package-sync.ps1')

# Normalise separators up front. These paths get written into the manifest and
# later compared with -eq by the uninstaller, so a caller passing forward slashes
# (easy to do from a shell) would produce entries that never match and quietly
# fail to be cleaned up.
$InstallRoot = [System.IO.Path]::GetFullPath($InstallRoot)
$DoomDir     = [System.IO.Path]::GetFullPath($DoomDir)

$PRODUCT  = 'Doom Emacs'
$REGKEY   = $RegistryKey
$MANIFEST_FILE = 'install-manifest.json'

function Write-Stage([string]$m) { if (-not $Silent) { Write-Host ''; Write-Host "==> $m" -ForegroundColor Cyan } }
function Write-Ok([string]$m)    { if (-not $Silent) { Write-Host "    OK    $m" -ForegroundColor Green } }
function Write-Info([string]$m)  { if (-not $Silent) { Write-Host "          $m" -ForegroundColor DarkGray } }
function Write-Warn([string]$m)  { Write-Host "    WARN  $m" -ForegroundColor Yellow }
function Write-Bad([string]$m)   { Write-Host "    FAIL  $m" -ForegroundColor Red }

function Format-Size([long]$b) {
    if ($b -ge 1GB) { return ('{0:N2} GB' -f ($b / 1GB)) }
    if ($b -ge 1MB) { return ('{0:N1} MB' -f ($b / 1MB)) }
    return ('{0:N1} KB' -f ($b / 1KB))
}

# Every path this script creates is recorded here, tagged with whether we made it
# or merely found it. The uninstaller trusts this and nothing else.
$script:manifestEntries = New-Object System.Collections.Generic.List[object]
function Add-Entry {
    param([string]$Kind, [string]$Path, [string]$State, [string]$Note = '')
    $script:manifestEntries.Add([pscustomobject]@{
        kind = $Kind; path = $Path; state = $State; note = $Note
    })
}

# ------------------------------------------------------------------ preflight

Write-Stage "$PRODUCT installer"
Write-Info "install root : $InstallRoot"
Write-Info "user config  : $DoomDir"
Write-Info "source mode  : $SourceMode"

# The .exe checks these too, but the standalone path must stand on its own --
# nothing guarantees a user reached this script through the installer.

# ARM64 first. Is64BitOperatingSystem is TRUE on ARM64 Windows, so it cannot tell
# these apart on its own, and every bundled binary here is x86_64.
$arch = $env:PROCESSOR_ARCHITECTURE
$archW = $env:PROCESSOR_ARCHITEW6432
if ($arch -eq 'ARM64' -or $archW -eq 'ARM64') {
    throw 'ARM64 Windows is not supported. Every bundled binary in this payload is x86_64; an ARM64 build would need a separately compiled Emacs and toolchain.'
}
if (-not [Environment]::Is64BitOperatingSystem) {
    throw 'This installer is 64-bit only.'
}
if ([Environment]::OSVersion.Version.Major -lt 10) {
    throw "Windows 10 or newer is required (found $([Environment]::OSVersion.VersionString))."
}

# MAX_PATH headroom. A minimal install already reaches ~200 characters deep, against
# a 259 limit that applies unless LongPathsEnabled is set -- off by default on both
# Windows 10 and 11. A long root eats that headroom and the failures surface deep
# inside a package build, far from the cause.
if ($InstallRoot.Length -gt 90) {
    Write-Warn "install path is $($InstallRoot.Length) characters long"
    Write-Info 'Doom nests files deeply and Windows limits paths to 260 characters.'
    Write-Info 'Package builds may fail here. Something shorter, like C:\DoomEmacs, is safer.'
    $lp = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name LongPathsEnabled -ErrorAction SilentlyContinue).LongPathsEnabled
    if ($lp -eq 1) { Write-Info 'LongPathsEnabled is set on this machine, which mitigates it.' }
}

$existingManifestPath = Join-Path $InstallRoot $MANIFEST_FILE
$existing = Test-Path $existingManifestPath
$previousManifest = if ($existing) { Get-Content $existingManifestPath -Raw | ConvertFrom-Json } else { $null }
if (-not $explicitDoomDir -and $previousManifest.doomDir) {
    $DoomDir = [IO.Path]::GetFullPath([string]$previousManifest.doomDir)
}
if ($existing -and -not $Force) {
    throw "An existing install was found at $InstallRoot. Uninstall it first, or pass -Force to overwrite."
}
# Refuse to pour the payload into a folder that already holds something that is
# not ours. Without this the manifest would tag a user's folder 'preexisting'
# while robocopy merged 1.4GB into it, and an uninstall that keeps a preexisting
# root would leave the merge behind forever.
if ((Test-Path $InstallRoot) -and -not $existing -and $SourceMode -ne 'InPlace') {
    if (@(Get-ChildItem $InstallRoot -Force -ErrorAction SilentlyContinue).Count -gt 0) {
        throw "Install folder $InstallRoot already exists, is not empty, and contains no Doom Emacs install. Choose a new or empty folder, so uninstall can never touch what it did not create."
    }
}

# ------------------------------------------------------------------- acquire

Write-Stage 'Preparing payload'

$payloadDir = $null
$tempStaging = $null

switch ($SourceMode) {
    'InPlace' {
        # NSIS has already extracted the payload straight into $InstallRoot. Copying
        # it anywhere would mean moving 1.4GB a second time for no reason, so this
        # mode skips acquisition entirely and only does the configuration steps.
        if (-not (Test-Path (Join-Path $InstallRoot 'emacs\bin\emacs.exe'))) {
            throw "-SourceMode InPlace expects the payload to already be at $InstallRoot, but emacs\bin\emacs.exe is missing."
        }
        $payloadDir = $InstallRoot
        Write-Ok "payload already in place at $InstallRoot"
    }
    'Staging' {
        if (-not $SourcePath) { $SourcePath = Join-Path $scriptDir 'payload' }
        if (-not (Test-Path $SourcePath)) { throw "Staging payload not found at $SourcePath" }
        $payloadDir = (Resolve-Path $SourcePath).Path
        Write-Ok "using prepared payload at $payloadDir"
    }
    default {
        # Cache and Download both end in stage-payloads.ps1; Download just fetches first.
        $fetch = Join-Path $scriptDir 'build\fetch-payloads.ps1'
        $stage = Join-Path $scriptDir 'build\stage-payloads.ps1'
        foreach ($s in @($fetch, $stage)) {
            if (-not (Test-Path $s)) { throw "Required build script missing: $s (needed for -SourceMode $SourceMode)" }
        }

        $cacheArgs = @{}
        if ($SourceMode -eq 'Cache' -and $SourcePath) { $cacheArgs['CacheDir'] = $SourcePath }
        if ($SourceMode -eq 'Download') {
            Write-Info 'Downloading payloads (this is not a hermetic install path)'
            & $fetch
            if ($LASTEXITCODE -ne 0) { throw 'payload download failed' }
        } else {
            Write-Info 'verifying cached payloads'
            & $fetch @cacheArgs
            if ($LASTEXITCODE -ne 0) { throw 'payload verification failed' }
        }

        $tempStaging = Join-Path ([System.IO.Path]::GetTempPath()) ("doom-install-" + [guid]::NewGuid().ToString('N'))
        Write-Info "unpacking to $tempStaging"
        & $stage -StagingDir $tempStaging @cacheArgs
        if ($LASTEXITCODE -ne 0) { throw 'payload staging failed' }
        $payloadDir = $tempStaging
    }
}

$payloadSize = (Get-ChildItem $payloadDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
Write-Info "payload size : $(Format-Size $payloadSize)"

$drive = Get-PSDrive -Name (Split-Path -Qualifier $InstallRoot).TrimEnd(':') -ErrorAction SilentlyContinue
if ($drive -and $drive.Free -lt ($payloadSize * 1.1)) {
    throw "Not enough free space on $($drive.Name): need about $(Format-Size ($payloadSize * 1.1)), have $(Format-Size $drive.Free)."
}

# ------------------------------------------------------------------ lay files

Write-Stage 'Installing files'

# Ownership decides what the uninstaller may delete. Reinstalls inherit root
# ownership from the previous manifest. InPlace cannot
# infer whether NSIS created an empty root before invoking us, so NSIS passes
# that fact explicitly.
$rootExisted = Test-Path $InstallRoot
if (-not $rootExisted) { New-Item -ItemType Directory -Force -Path $InstallRoot | Out-Null }
$previousRootEntry = @(if ($previousManifest) {
    @($previousManifest.entries | Where-Object {
        $_.kind -eq 'dir' -and [string]::Equals($_.path, $InstallRoot, [System.StringComparison]::OrdinalIgnoreCase)
    } | Select-Object -First 1)
})
$rootState = if ($previousRootEntry.Count) {
    $previousRootEntry[0].state
} elseif ((-not $rootExisted) -or $OwnInstallRoot) {
    'created'
} else {
    'preexisting'
}
$rootOwned = ($rootState -eq 'created')
Add-Entry -Kind 'dir' -Path $InstallRoot -State $rootState -Note 'install root'

if ($SourceMode -eq 'InPlace') {
    Write-Info 'files already in place, nothing to copy'
} else {
    $rc = Start-Process -FilePath 'robocopy.exe' -ArgumentList @(
        "`"$payloadDir`"", "`"$InstallRoot`"", '/E', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/R:1', '/W:1'
    ) -NoNewWindow -Wait -PassThru
    if ($rc.ExitCode -ge 8) { throw "copying files failed (robocopy exit $($rc.ExitCode))" }

    # stage-payloads.ps1 intentionally stages only the payload. Standalone
    # Staging/Cache/Download installs still need their engine, uninstaller, and
    # shared PATH helper beside the payload, just like the compiled installer.
    foreach ($name in @('install-doom.ps1', 'uninstall-doom.ps1', 'env-path.ps1', 'repair-doom.ps1', 'native-process.ps1', 'wsl-integration.ps1', 'package-sync.ps1')) {
        Copy-Item (Join-Path $scriptDir $name) (Join-Path $InstallRoot $name) -Force
    }
    $bridgeSource = Join-Path $scriptDir 'files\bridge'
    if (Test-Path -LiteralPath $bridgeSource) {
        $bridgeDestination = Join-Path $InstallRoot 'bridge'
        New-Item -ItemType Directory -Path $bridgeDestination -Force | Out-Null
        Copy-Item -Path (Join-Path $bridgeSource '*') -Destination $bridgeDestination -Force
    }
}

foreach ($d in (Get-ChildItem $InstallRoot -Directory -ErrorAction SilentlyContinue)) {
    if ($d.Name -ne 'bridge' -and $previousManifest -and -not $rootOwned -and -not @($previousManifest.entries | Where-Object {
        $_.kind -eq 'dir' -and $_.path -eq $d.FullName -and $_.state -eq 'created'
    }).Count) { continue }
    Add-Entry -Kind 'dir' -Path $d.FullName -State 'created'
}
# Root-level files are recorded even for an owned root so uninstall can detect
# locks before it removes the manifest and Add/Remove entry.
foreach ($f in (Get-ChildItem $InstallRoot -File -ErrorAction SilentlyContinue)) {
    if ($previousManifest -and -not $rootOwned -and -not @($previousManifest.entries | Where-Object {
        $_.kind -eq 'file' -and $_.path -eq $f.FullName -and $_.state -eq 'created'
    }).Count -and $f.Name -notin @('install-doom.ps1', 'uninstall-doom.ps1', 'env-path.ps1', 'repair-doom.ps1', 'native-process.ps1', 'wsl-integration.ps1', 'package-sync.ps1')) { continue }
    Add-Entry -Kind 'file' -Path $f.FullName -State 'created'
}
$fileCount = (Get-ChildItem $InstallRoot -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
Write-Ok "$fileCount files installed"

# --------------------------------------------------------------- user config

Write-Stage 'User configuration'

# This is the one directory that is genuinely the user's. If it already exists we
# leave it strictly alone and record that we found it, so a later full uninstall
# can warn that it is deleting something we did not create.
$doomDirExisted = Test-Path $DoomDir
if ($doomDirExisted) {
    Write-Warn "existing config found at $DoomDir - leaving it untouched"
    Add-Entry -Kind 'dir' -Path $DoomDir -State 'preexisting' -Note 'user config, predates this install'
} else {
    New-Item -ItemType Directory -Force -Path $DoomDir | Out-Null
    # Templates live directly in doom/static/, NOT in a templates/ subdirectory.
    # Getting this wrong leaves the config directory empty, and Doom then starts
    # with no init.el and therefore no modules at all -- a broken install that
    # still reports success.
    $tpl = Join-Path $InstallRoot 'doom\static'
    $seeded = $false
    foreach ($f in @('init.example.el', 'config.example.el', 'packages.example.el')) {
        $src = Join-Path $tpl $f
        if (Test-Path $src) {
            Copy-Item $src (Join-Path $DoomDir ($f -replace '\.example', '')) -Force
            $seeded = $true
        }
    }
    Add-Entry -Kind 'dir' -Path $DoomDir -State 'created' -Note 'user config, created by this install'
    if ($seeded) { Write-Ok "seeded $DoomDir from templates" }
    else { Write-Ok "created $DoomDir (no templates found to seed from)" }
}

# ---------------------------------------------------------------------- PATH

$binDir = Join-Path $InstallRoot 'bin'
if (-not $NoPathUpdate) {
    Write-Stage 'PATH'
    # Read/write raw: [Environment]::Get/SetEnvironmentVariable expands
    # REG_EXPAND_SZ and rewrites it as REG_SZ, destroying %refs% in the user's
    # Path. The helper preserves the original RegistryValueKind.
    $pathNote = 'single entry; shim seals the rest per-process'
    if (Add-DoomUserPathEntry -Entry $binDir) {
        Add-Entry -Kind 'env' -Path "Path:$binDir" -State 'created' -Note $pathNote
        Write-Ok "added $binDir"
    } else {
        $previouslyCreated = $previousManifest -and @($previousManifest.entries | Where-Object {
            $_.kind -eq 'env' -and $_.path -eq "Path:$binDir" -and $_.state -eq 'created'
        }).Count -gt 0
        Add-Entry -Kind 'env' -Path "Path:$binDir" -State $(if ($previouslyCreated) { 'created' } else { 'preexisting' })
        Write-Info 'already on PATH'
    }
    if (@((Get-DoomUserPath).Value -split ';') -notcontains $binDir) {
        throw "PATH update could not be verified for $binDir"
    }
    # A directly invoked installer can update its own process; a child process
    # cannot change the PATH of an already-running terminal or Windows Terminal.
    if (@($env:Path -split ';') -notcontains $binDir) { $env:Path += ";$binDir" }
} else {
    $previousPathEntry = @(if ($previousManifest) {
        @($previousManifest.entries | Where-Object {
            $_.kind -eq 'env' -and $_.path -eq "Path:$binDir"
        } | Select-Object -First 1)
    })
    if ($previousPathEntry.Count) {
        Add-Entry -Kind 'env' -Path "Path:$binDir" -State $previousPathEntry[0].state -Note $previousPathEntry[0].note
    }
    Write-Info 'skipping PATH update (-NoPathUpdate)'
}

# ------------------------------------------------------------------ shortcut

if (-not $NoShortcut -and -not ($NoStartMenuShortcut -and $NoDesktopShortcut)) {
    Write-Stage 'Shortcuts'

    # Prefer the bundled Doom icon; fall back to the Emacs executable's own icon
    # if the payload was built without it.
    $icoFile = Join-Path $InstallRoot 'doom.ico'
    if (-not (Test-Path $icoFile)) { $icoFile = Join-Path $InstallRoot 'emacs\bin\emacs.exe' }

    $targets = @()
    if (-not $NoStartMenuShortcut) {
        $targets += @{ dir = [Environment]::GetFolderPath('Programs'); what = 'Start Menu' }
    }
    if (-not $NoDesktopShortcut) {
        $targets += @{ dir = [Environment]::GetFolderPath('Desktop'); what = 'Desktop' }
    }

    foreach ($t in $targets) {
        if (-not $t.dir) { continue }
        $lnk = Join-Path $t.dir 'Doom Emacs.lnk'
        try {
            $shell = New-Object -ComObject WScript.Shell
            $s = $shell.CreateShortcut($lnk)
            $s.TargetPath = Join-Path $InstallRoot 'bin\doom-emacs.cmd'
            $s.WorkingDirectory = $env:USERPROFILE
            $s.IconLocation = "$icoFile,0"
            $s.Description = 'Doom Emacs'
            # Minimized because launching a GUI app via .cmd briefly flashes a console.
            $s.WindowStyle = 7
            $s.Save()
            Add-Entry -Kind 'shortcut' -Path $lnk -State 'created' -Note $t.what
            Write-Ok "$($t.what): $lnk"
        } catch {
            Write-Warn "could not create $($t.what) shortcut: $($_.Exception.Message)"
        }
    }
}

# ------------------------------------------------------- Add/Remove Programs

Write-Stage 'Registering with Add/Remove Programs'
# Doom's version lives in the .doom file at the repo root, not in a defconst.
# Upstream replaced the doom-version variable with a function (see the
# "refactor!: replace doom-version var with function" commit); that function
# reads the first 96 bytes of .doom and `read`s the string out of it.
$version = '0.0.0'
$verFile = Join-Path $InstallRoot 'doom\.doom'
if (Test-Path $verFile) {
    $head = Get-Content $verFile -TotalCount 4 -ErrorAction SilentlyContinue
    foreach ($line in $head) {
        if ($line -match '"([0-9]+\.[0-9]+[^"]*)"') { $version = $Matches[1]; break }
    }
}
if ($version -eq '0.0.0') { Write-Warn "could not read Doom version from $verFile" }

try {
    $keyExisted = Test-Path $REGKEY
    if (-not $keyExisted) { New-Item -Path $REGKEY -Force | Out-Null }
    $uninstCmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$InstallRoot\uninstall-doom.ps1`" -InstallRoot `"$InstallRoot`" -Yes"
    $installSizeKb = [int]($payloadSize / 1KB)
    New-ItemProperty -Path $REGKEY -Name 'DisplayName'     -Value $PRODUCT -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $REGKEY -Name 'DisplayVersion'  -Value $version -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $REGKEY -Name 'Publisher'       -Value 'Doom Emacs community build' -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $REGKEY -Name 'InstallLocation' -Value $InstallRoot -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $REGKEY -Name 'UninstallString' -Value $uninstCmd -PropertyType String -Force | Out-Null
    $arpIcon = Join-Path $InstallRoot 'doom.ico'
    if (-not (Test-Path $arpIcon)) { $arpIcon = Join-Path $InstallRoot 'emacs\bin\emacs.exe' }
    New-ItemProperty -Path $REGKEY -Name 'DisplayIcon'     -Value $arpIcon -PropertyType String -Force | Out-Null
    New-ItemProperty -Path $REGKEY -Name 'EstimatedSize'   -Value $installSizeKb -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $REGKEY -Name 'NoModify'        -Value 1 -PropertyType DWord -Force | Out-Null
    New-ItemProperty -Path $REGKEY -Name 'NoRepair'        -Value 1 -PropertyType DWord -Force | Out-Null
    Add-Entry -Kind 'regkey' -Path $REGKEY -State $(if ($keyExisted) { 'preexisting' } else { 'created' })
    Write-Ok "$PRODUCT $version"
} catch {
    Write-Warn "could not register uninstall entry: $($_.Exception.Message)"
}

# ------------------------------------------------------------------ manifest

Write-Stage 'Writing manifest'

# NOTE the .ToArray() on entries. Writing @($script:manifestEntries) instead
# throws "Argument types do not match" under PowerShell 5.1 -- wrapping a
# List[object] in @() specifically is what breaks it. Passing the list bare,
# comma-wrapped, or as .ToArray() all work; only the @() form fails. Losing an
# install at the final step, after 1.4GB is already copied, is a miserable way
# to discover that.
$manifest = New-Object System.Collections.Specialized.OrderedDictionary
$manifest['schema']       = 1
$manifest['product']      = [string]$PRODUCT
$manifest['version']      = [string]$version
$manifest['installedUtc'] = (Get-Date).ToUniversalTime().ToString('o')
$manifest['installRoot']  = [string]$InstallRoot
$manifest['doomDir']      = [string]$DoomDir
$manifest['sourceMode']   = [string]$SourceMode
$manifest['fileCount']    = [int]$(if ($fileCount)    { $fileCount }   else { 0 })
$manifest['sizeBytes']    = [long]$(if ($payloadSize) { $payloadSize } else { 0 })
$manifestPath = Join-Path $InstallRoot $MANIFEST_FILE
Add-Entry -Kind 'file' -Path $manifestPath -State 'created' -Note 'install ownership manifest'
$manifest['entries']      = $script:manifestEntries.ToArray()
if ($previousManifest.wsl) { $manifest['wsl'] = @($previousManifest.wsl) }
if ($previousManifest.packageSync) { $manifest['packageSync'] = $previousManifest.packageSync }
if ($manifest['wsl']) {
    Save-DoomWslRegistryState -Root $InstallRoot -Key $REGKEY -Settings ([pscustomobject]@{ integrations = @($manifest['wsl']) })
}
try {
    $json = ConvertTo-Json -InputObject $manifest -Depth 8
    Set-Content -Path $manifestPath -Value $json -Encoding utf8
} catch {
    Write-Bad "manifest write failed: $($_.Exception.Message)"
    Write-Info "at: $($_.InvocationInfo.PositionMessage)"
    Write-Info "stack: $($_.ScriptStackTrace)"
    throw
}
Write-Ok "$manifestPath ($($script:manifestEntries.Count) entries)"

# The manifest exists before changing Linux profiles, so failures remain
# recoverable. Existing distro integrations survive a normal reinstall.
if ($WslDistro) {
    Write-Stage "WSL integration: $WslDistro"
    Add-Entry -Kind 'file' -Path (Join-Path $InstallRoot 'wsl-bridge.json') -State 'created' -Note 'WSL integration ownership'
    Add-Entry -Kind 'dir' -Path (Join-Path $InstallRoot 'bridge-state') -State 'created' -Note 'Windows-local Emacs server state'
    try {
        $integration = Add-DoomWslIntegration -InstallRoot $InstallRoot -DoomDir $DoomDir -Distribution $WslDistro
        $settings = Get-Content -LiteralPath (Join-Path $InstallRoot 'wsl-bridge.json') -Raw -Encoding UTF8 | ConvertFrom-Json
        Save-DoomWslRegistryState -Root $InstallRoot -Key $REGKEY -Settings $settings -Selected $integration
        Write-Ok "Windows doom and GUI client commands configured for $($integration.user) in $WslDistro"
    } finally {
        $settingsPath = Join-Path $InstallRoot 'wsl-bridge.json'
        if (Test-Path -LiteralPath $settingsPath) {
            $manifest['wsl'] = @((Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json).integrations)
        }
        $manifest['entries'] = $script:manifestEntries.ToArray()
        $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    }
}

# --------------------------------------------------------------- first sync

if (-not $NoSync) {
    Write-Stage 'Checking package builds'

    # Not optional in any meaningful sense. Doom without a sync is not a lighter
    # Doom, it is a broken one: doom-modules never gets defined and the first
    # launch dies with "(void-variable doom-modules)". An installer that leaves
    # the program unable to start has not finished its job.
    $doomCmd = Join-Path $InstallRoot 'bin\doom.cmd'
    if (Test-Path $doomCmd) {
        $runtime = Get-DoomRuntimeSignature -Root $InstallRoot
        $hasPackages = @(Get-ChildItem -LiteralPath (Join-Path $InstallRoot 'doom\.local\straight') -Filter 'build-*' -Directory -ErrorAction SilentlyContinue).Count -gt 0
        $plan = Get-DoomPackageSyncPlan -Runtime $runtime -Previous $previousManifest.packageSync -HasPackages $hasPackages -AheadOfTime ($AOT -and -not $NoAOT) -Rebuild ([bool]$RebuildPackages)
        Write-Info $plan.Reason
        if ($AOT -and -not $NoAOT) { Write-Info 'Waiting for native optimization of packages that need building (optional).' }
        else { Write-Info 'Native optimization is deferred until use; existing compatible native code is kept.' }
        # Invalidate the success record BEFORE invoking builds. An interrupted or
        # failed rebuild must not leave an old success record for a partial tree.
        $manifest['packageSync'] = @{ schema = 1; success = $false; runtime = $runtime }
        $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
        $syncExit = Invoke-DoomPackageSync -Root $InstallRoot -Config $DoomDir -Arguments $plan.Arguments

        # Trust the tree, not just the exit code: confirm packages actually landed.
        $built = @(Get-ChildItem (Join-Path $InstallRoot 'doom\.local\straight') -Filter 'build-*' -Directory -ErrorAction SilentlyContinue)
        $pkgCount = 0
        if ($built.Count -gt 0) {
            $pkgCount = @(Get-ChildItem $built[0].FullName -Directory -ErrorAction SilentlyContinue).Count
        }

        if ($syncExit -eq 0 -and $pkgCount -gt 0) {
            $manifest['packageSync'] = @{ schema = 1; success = $true; runtime = $runtime; completedUtc = (Get-Date).ToUniversalTime().ToString('o') }
            $manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
            Write-Ok "sync complete ($pkgCount packages)"
        } else {
            Write-Warn "doom sync failed (exit $syncExit, $pkgCount packages built)"
            Write-Info "The files are installed but Doom will not start correctly yet."
            Write-Info "Open a new terminal and run:  doom sync"
            $script:syncFailed = $true
        }
    } else {
        Write-Warn "shim not found at $doomCmd - skipping sync"
        $script:syncFailed = $true
    }
} else {
    Write-Warn 'skipping package sync (-NoSync): Doom will not start until you run "doom sync"'
}

# ------------------------------------------------------------------- cleanup

if ($tempStaging -and (Test-Path $tempStaging)) {
    Remove-Item $tempStaging -Recurse -Force -ErrorAction SilentlyContinue
}

$sw.Stop()
Write-Stage 'Done'
Write-Info "elapsed: $([math]::Round($sw.Elapsed.TotalMinutes,1)) min"
if (-not $Silent) {
    Write-Host ''
    if ($NoSync) {
        Write-Host "  $PRODUCT files are installed. Package sync was skipped." -ForegroundColor Yellow
        Write-Host "  Run the installed bin\doom.cmd sync before launching the editor." -ForegroundColor Gray
    } elseif ($script:syncFailed) {
        Write-Host "  $PRODUCT is installed, but its packages are not." -ForegroundColor Yellow
        Write-Host "  Open a NEW terminal and run:  doom sync" -ForegroundColor Gray
    } else {
        Write-Host "  $PRODUCT is installed and ready." -ForegroundColor Green
        Write-Host "  Launch it from the Desktop or Start Menu shortcut." -ForegroundColor Gray
        Write-Host "  For the command line, open a NEW terminal and run: doom doctor" -ForegroundColor Gray
        Write-Host "  (a new terminal is needed to pick up the PATH change)" -ForegroundColor DarkGray
    }
    Write-Host ''
}

# Keep the manifest and uninstall entry for recovery, but never report readiness
# after an unsuccessful sync (a partially built tree is not proof of success).
if ($script:syncFailed) { exit 1 }
exit 0
