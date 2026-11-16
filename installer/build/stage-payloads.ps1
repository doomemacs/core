<#
.SYNOPSIS
    Extract verified payloads into the final install layout.

.DESCRIPTION
    Unpacks everything in installer/cache/ into installer/staging/, arranged exactly
    as it will appear under the install root. NSIS then packs staging/ verbatim, so
    what you can inspect here is what ships.

    Archive roots are auto-detected rather than trusted from the lockfile: if every
    entry in a zip shares one top-level directory, that directory is stripped. The
    lockfile's stripRoot field is treated as advisory and a disagreement is reported,
    because hand-maintained flags drift (the Emacs entry was wrong on first writing).

    Idempotent: a payload whose hash already appears in staging/.staged.json is
    skipped, so re-running after a change re-extracts only what moved.

.PARAMETER Force
    Re-extract everything, ignoring .staged.json.

.PARAMETER Only
    Stage just these payload ids.
#>
[CmdletBinding()]
param(
    [switch]$Force,
    [string[]]$Only,
    [string]$LockFile,
    [string]$CacheDir,
    [string]$StagingDir
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $LockFile)   { $LockFile   = Join-Path $scriptDir 'payloads.lock.json' }
if (-not $CacheDir)   { $CacheDir   = Join-Path $scriptDir '..\cache' }

# Staging deliberately lives OUTSIDE the repo. Staged inside it, `doom version`
# reported our own dev branch: git discovery walked up out of staging/doom and
# found the parent checkout, so the staged tree inherited a repo it will not ship
# with. That is precisely the "passes because of contamination" failure the test
# harness exists to prevent, so the default keeps 1.4GB of payload out of the
# working tree entirely.
if (-not $StagingDir) { $StagingDir = Join-Path $env:LOCALAPPDATA 'doom-installer-build\staging' }

function Write-Stage([string]$m) { Write-Host ''; Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok([string]$m)    { Write-Host "    OK    $m" -ForegroundColor Green }
function Write-Info([string]$m)  { Write-Host "          $m" -ForegroundColor DarkGray }
function Write-Warn([string]$m)  { Write-Host "    WARN  $m" -ForegroundColor Yellow }
function Write-Bad([string]$m)   { Write-Host "    FAIL  $m" -ForegroundColor Red }

function Format-Size([long]$b) {
    if ($b -ge 1GB) { return ('{0:N1} GB' -f ($b / 1GB)) }
    if ($b -ge 1MB) { return ('{0:N1} MB' -f ($b / 1MB)) }
    return ('{0:N1} KB' -f ($b / 1KB))
}

function Get-ZipCommonRoot {
    param([System.IO.Compression.ZipArchive]$Zip)
    $roots = @{}
    foreach ($e in $Zip.Entries) {
        $first = ($e.FullName -split '/')[0]
        if ($first) { $roots[$first] = $true }
    }
    if ($roots.Count -eq 1) { return @($roots.Keys)[0] }
    return $null
}

function Expand-ZipPayload {
    param([string]$Archive, [string]$Dest, [bool]$LockSaysStrip)

    $zip = [System.IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        $root = Get-ZipCommonRoot -Zip $zip
        $strip = [bool]$root
        if ($strip -ne $LockSaysStrip) {
            Write-Warn "lockfile stripRoot=$LockSaysStrip but archive says $strip (root='$root') - trusting the archive"
        }
        if ($strip) { Write-Info "stripping common root '$root/'" }

        $n = 0
        foreach ($e in $zip.Entries) {
            $rel = $e.FullName
            if ($strip) {
                $rel = $rel.Substring($root.Length)
                $rel = $rel.TrimStart('/')
            }
            if (-not $rel) { continue }
            $out = Join-Path $Dest ($rel -replace '/', '\')

            if ($e.Length -eq 0 -and $e.FullName.EndsWith('/')) {
                if (-not (Test-Path $out)) { New-Item -ItemType Directory -Force -Path $out | Out-Null }
                continue
            }
            $dir = Split-Path -Parent $out
            if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($e, $out, $true)
            $n++
        }
        return $n
    } finally {
        $zip.Dispose()
    }
}

function Expand-Msys2Payload {
    param([string]$Archive, [string]$Dest, [string]$Zstd)

    # MSYS2 packages carry .BUILDINFO/.MTREE/.PKGINFO metadata beside the real
    # ucrt64/ tree. Extract only ucrt64/ and strip it.
    #
    # Decompress to a plain .tar first rather than using tar's --use-compress-program.
    # That flag resolves through whichever tar is first on PATH, and MSYS's GNU tar
    # mangles the Windows path to zstd.exe into "C\:Users..." before exec'ing it.
    # Two steps with an explicitly-resolved native bsdtar sidesteps the whole mess.
    if (-not (Test-Path $Dest)) { New-Item -ItemType Directory -Force -Path $Dest | Out-Null }
    $before = (Get-ChildItem $Dest -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count

    $sysTar = Join-Path $env:SystemRoot 'System32\tar.exe'
    if (-not (Test-Path $sysTar)) { throw "native bsdtar not found at $sysTar" }

    $tmpTar = Join-Path ([System.IO.Path]::GetTempPath()) ("doomstage-" + [guid]::NewGuid().ToString('N') + '.tar')
    try {
        & $Zstd -d -q -f -o $tmpTar $Archive
        if ($LASTEXITCODE -ne 0) { throw "zstd failed with exit code $LASTEXITCODE" }

        & $sysTar -xf $tmpTar -C $Dest --strip-components=1 ucrt64
        if ($LASTEXITCODE -ne 0) { throw "bsdtar failed with exit code $LASTEXITCODE" }
    } finally {
        if (Test-Path $tmpTar) { Remove-Item $tmpTar -Force -ErrorAction SilentlyContinue }
    }

    $after = (Get-ChildItem $Dest -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
    return ($after - $before)
}

# ---------------------------------------------------------------------- main

Write-Stage 'Doom Emacs installer - stage payloads'

if (-not (Test-Path $LockFile)) { throw "Lockfile not found: $LockFile" }
$lock = Get-Content $LockFile -Raw | ConvertFrom-Json
$CacheDir = (Resolve-Path $CacheDir).Path

$zstd = Join-Path $scriptDir 'tools\zstd.exe'
$needZstd = @($lock.payloads | Where-Object { $_.filename -like '*.zst' }).Count -gt 0
if ($needZstd -and -not (Test-Path $zstd)) {
    throw "zstd.exe not found at $zstd. Run fetch-payloads.ps1 first - MSYS2 payloads cannot be extracted without it."
}

if (-not (Test-Path $StagingDir)) { New-Item -ItemType Directory -Force -Path $StagingDir | Out-Null }
$StagingDir = (Resolve-Path $StagingDir).Path
Write-Info "cache   : $CacheDir"
Write-Info "staging : $StagingDir"

$markerFile = Join-Path $StagingDir '.staged.json'
$staged = @{}
if ((Test-Path $markerFile) -and -not $Force) {
    $m = Get-Content $markerFile -Raw | ConvertFrom-Json
    foreach ($p in $m.PSObject.Properties) { $staged[$p.Name] = $p.Value }
}

$failed = @()
foreach ($p in $lock.payloads) {
    if ($Only -and $Only -notcontains $p.id) { continue }

    $dest = Join-Path $StagingDir ($p.installSubdir -replace '/', '\')
    Write-Stage "$($p.id) -> $($p.installSubdir)"

    if (-not $Force -and $staged[$p.id] -eq $p.sha256 -and (Test-Path $dest)) {
        Write-Ok 'already staged at this hash'
        continue
    }

    $archive = Join-Path $CacheDir $p.filename
    if (-not (Test-Path $archive)) {
        Write-Bad "payload missing from cache: $($p.filename) - run fetch-payloads.ps1"
        $failed += $p.id
        continue
    }

    try {
        if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Force -Path $dest | Out-Null }

        if ($p.filename -like '*.zip') {
            $n = Expand-ZipPayload -Archive $archive -Dest $dest -LockSaysStrip ([bool]$p.stripRoot)
        } elseif ($p.filename -like '*.pkg.tar.zst') {
            $n = Expand-Msys2Payload -Archive $archive -Dest $dest -Zstd $zstd
        } else {
            throw "don't know how to extract $($p.filename)"
        }

        $staged[$p.id] = $p.sha256
        Write-Ok "$n files"
    } catch {
        Write-Bad "$($p.id): $($_.Exception.Message)"
        $failed += $p.id
    }
}

$staged | ConvertTo-Json -Depth 4 | Set-Content -Path $markerFile -Encoding utf8

# ------------------------------------------------- Doom itself, and the shims

Write-Stage 'doom -> doom (working tree)'
$repoRoot = (Resolve-Path (Join-Path $scriptDir '..\..')).Path
$doomDest = Join-Path $StagingDir 'doom'

$moduleRevision = & git -C (Join-Path $repoRoot 'sources\doom+') rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $moduleRevision -ne $lock.doom.submodule.sha) {
    throw 'The Doom module checkout does not match payloads.lock.json. Initialize the pinned submodule before building.'
}

# robocopy rather than git archive: git archive skips submodules, and
# sources/doom+ IS the module tree. Exclude .git (the installed copy is not a
# checkout), installer/ (build machinery, not shipped) and CI config.
# robocopy exit codes below 8 are success; 8+ are real failures.
$rc = Start-Process -FilePath 'robocopy.exe' -ArgumentList @(
    "`"$repoRoot`"", "`"$doomDest`"", '/MIR', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/R:1', '/W:1',
    '/XD', "`"$repoRoot\.git`"", "`"$repoRoot\installer`"", "`"$repoRoot\.github`"",
    '/XF', '.git', '.gitmodules', '.gitignore'
) -NoNewWindow -Wait -PassThru
if ($rc.ExitCode -ge 8) {
    Write-Bad "robocopy failed with exit code $($rc.ExitCode)"
    $failed += 'doom'
} else {
    $n = (Get-ChildItem $doomDest -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Ok "$n files"
}

Write-Stage 'shims -> bin'
$filesSrc = Join-Path $scriptDir '..\files'
if (Test-Path $filesSrc) {
    $rc2 = Start-Process -FilePath 'robocopy.exe' -ArgumentList @(
        "`"$((Resolve-Path $filesSrc).Path)`"", "`"$StagingDir`"", '/E', '/NFL', '/NDL', '/NJH', '/NJS', '/NP', '/R:1', '/W:1'
    ) -NoNewWindow -Wait -PassThru
    if ($rc2.ExitCode -ge 8) { Write-Bad "robocopy failed with exit code $($rc2.ExitCode)"; $failed += 'shims' }
    else { Write-Ok 'staged' }
} else {
    Write-Warn "no files/ directory at $filesSrc"
}

Write-Stage 'Configuring bundled git'

# The deepest path in a real install came from a git clone, not from our own
# layout: a test fixture inside the flycheck repo, 150 characters below the
# install root. straight.el clones a couple of hundred repos and any of them may
# nest arbitrarily, so this is unbounded and cannot be designed around.
#
# core.longpaths makes git use the \\?\ prefix internally, which lifts the 260
# character limit for git's own file operations regardless of the machine's
# LongPathsEnabled setting or any manifest. It is the one lever here that fixes
# the unbounded half of the problem.
$gitCfg = Join-Path $StagingDir 'deps\git\etc\gitconfig'
if (Test-Path $gitCfg) {
    $gitExe = Join-Path $StagingDir 'deps\git\cmd\git.exe'
    & $gitExe config --file $gitCfg core.longpaths true
    if ($LASTEXITCODE -eq 0) {
        Write-Ok "core.longpaths=true (lifts git's 260-char limit when cloning packages)"
    } else {
        Write-Warn "could not set core.longpaths (git exit $LASTEXITCODE)"
    }
} else {
    Write-Warn "bundled gitconfig not found at $gitCfg"
}

Write-Stage 'Branding executables'

foreach ($name in @('emacsclient.exe', 'emacsclientw.exe')) {
    & (Join-Path $scriptDir 'set-client-utf8.ps1') -ExePath (Join-Path $StagingDir ('emacs\bin\' + $name))
}

# A shortcut's IconLocation only styles the shortcut. Once Emacs is running, the
# taskbar button, Alt-Tab entry and window all use the icon compiled into the
# binary, so those have to be patched too or the Doom icon vanishes the moment
# the user actually launches it.
#
# Runs on every stage, not just a fresh unpack: the payload-level skip in
# .staged.json would otherwise leave a re-staged emacs.exe wearing the stock icon.
$icoSrc = Join-Path (Resolve-Path (Join-Path $scriptDir '..')).Path 'files\doom.ico'

if (Test-Path $icoSrc) {
    $setIcon = Join-Path $scriptDir 'set-exe-icon.ps1'
    # emacs.exe is what owns the visible window; runemacs.exe is what the shortcut
    # launches; emacs-31.1.exe is the versioned duplicate Emacs ships.
    foreach ($exe in @('emacs\bin\emacs.exe', 'emacs\bin\runemacs.exe', 'emacs\bin\emacs-31.1.exe')) {
        $full = Join-Path $StagingDir $exe
        if (Test-Path $full) {
            try {
                & $setIcon -ExePath $full -IconPath $icoSrc | Out-Null
                Write-Ok "branded $exe"
            } catch {
                Write-Warn "could not brand ${exe}: $($_.Exception.Message)"
            }
        }
    }
} else {
    Write-Warn "no doom.ico at $icoSrc - executables keep the stock Emacs icon"
}

Write-Stage 'Staging layout'
foreach ($d in (Get-ChildItem $StagingDir -Directory -ErrorAction SilentlyContinue)) {
    $sz = (Get-ChildItem $d.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
    $ct = (Get-ChildItem $d.FullName -Recurse -File -ErrorAction SilentlyContinue | Measure-Object).Count
    Write-Host ("    {0,-12} {1,10}  {2,7} files" -f $d.Name, (Format-Size $sz), $ct)
}
$total = (Get-ChildItem $StagingDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
Write-Info "total uncompressed: $(Format-Size $total)"

Write-Stage 'Sanity checks'
$checks = @(
    @{ path = 'emacs\bin\emacs.exe';        why = 'the editor' },
    @{ path = 'emacs\bin\runemacs.exe';     why = 'GUI launcher (no console window)' },
    @{ path = 'emacs\bin\libgccjit-0.dll';  why = 'native-comp JIT' },
    @{ path = 'emacs\bin\gcc.exe';          why = 'native-comp driver' },
    @{ path = 'emacs\bin\as.exe';           why = 'native-comp assembler' },
    @{ path = 'emacs\lib\dllcrt2.o';        why = 'native-comp link would fail without it' },
    @{ path = 'deps\rg\rg.exe';             why = 'doom-doctor hard dependency' },
    @{ path = 'deps\fd\fd.exe';             why = 'doom-doctor soft dependency' },
    @{ path = 'deps\git\cmd\git.exe';       why = 'doom-doctor hard dependency' },
    @{ path = 'deps\git\usr\bin\sh.exe';    why = 'lets bin/doom run without Git Bash installed' },
    @{ path = 'doom\bin\doom';              why = 'the Doom CLI itself' },
    @{ path = 'doom\lisp\doom.el';          why = 'Doom core' },
    @{ path = 'doom\sources\doom+\modules'; why = 'the module tree (submodule)' },
    @{ path = 'bin\doom.cmd';               why = 'PATH shim - the only thing added to PATH' },
    @{ path = 'bin\doom-emacs.cmd';         why = 'GUI launcher' }
)
$missing = 0
foreach ($c in $checks) {
    $full = Join-Path $StagingDir $c.path
    if (Test-Path $full) {
        Write-Ok ("{0,-30} {1}" -f $c.path, $c.why)
    } else {
        Write-Bad ("{0,-30} MISSING - {1}" -f $c.path, $c.why)
        $missing++
    }
}

if ($failed.Count -gt 0) { Write-Bad "failed to stage: $($failed -join ', ')"; exit 1 }
if ($missing -gt 0)      { Write-Bad "$missing expected file(s) missing from staging"; exit 1 }

Write-Host ''
Write-Ok 'Staging complete and sane.'
exit 0
