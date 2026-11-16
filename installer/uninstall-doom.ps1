<#
.SYNOPSIS
    Remove Doom Emacs, either cleanly or completely.

.DESCRIPTION
    Reads install-manifest.json and removes only what that file records as created
    by the install. Anything tagged 'preexisting' is never touched in default mode,
    and in full mode is called out explicitly before deletion.

    Two modes:

      DEFAULT  Removes the install tree, the single PATH entry, the Start Menu
               shortcut and the Add/Remove Programs key. LEAVES your config at
               %USERPROFILE%\.config\doom, and leaves any git/ripgrep/fd you had
               installed yourself. Reinstalling later picks your config back up.

      -Full    Everything above, plus your Doom config. Prints an itemised list
               of every path with its real size and makes you confirm before
               deleting anything. Only manifest-owned paths are ever removed.

    Shared tools are deliberately left dangling in both modes unless they were
    installed by us into the install tree. We do not uninstall your system git.

.PARAMETER Full
    Also remove user config and leftover state. Prompts with an itemised list.

.PARAMETER Yes
    Skip the confirmation prompt. Required for unattended runs; with -Full this
    deletes your Doom config without asking, so be sure.

.PARAMETER WhatIf
    Show exactly what would be deleted and exit without touching anything.

.EXAMPLE
    .\uninstall-doom.ps1              # keep my config
    .\uninstall-doom.ps1 -Full        # remove everything, after confirming
    .\uninstall-doom.ps1 -Full -WhatIf
#>
[CmdletBinding()]
param(
    [string]$InstallRoot,
    [switch]$Full,
    [switch]$Yes,
    [switch]$WhatIf,
    [string]$RegistryKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\DoomEmacs'
)

$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $InstallRoot) { $InstallRoot = $scriptDir }

# Raw HKCU\Environment\Path helpers; shared with install-doom.ps1 via env-path.ps1.
. (Join-Path $scriptDir 'env-path.ps1')

$REGKEY   = $RegistryKey
$MANIFEST_FILE = 'install-manifest.json'

function Write-Stage([string]$m) { Write-Host ''; Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok([string]$m)    { Write-Host "    OK    $m" -ForegroundColor Green }
function Write-Info([string]$m)  { Write-Host "          $m" -ForegroundColor DarkGray }
function Write-Warn([string]$m)  { Write-Host "    WARN  $m" -ForegroundColor Yellow }
function Write-Bad([string]$m)   { Write-Host "    FAIL  $m" -ForegroundColor Red }

function Format-Size([long]$b) {
    if ($b -ge 1GB) { return ('{0,8:N2} GB' -f ($b / 1GB)) }
    if ($b -ge 1MB) { return ('{0,8:N1} MB' -f ($b / 1MB)) }
    if ($b -ge 1KB) { return ('{0,8:N1} KB' -f ($b / 1KB)) }
    return ('{0,8} B' -f $b)
}
function Get-PathSize([string]$p) {
    if (-not (Test-Path $p)) { return 0 }
    try {
        if (Test-Path $p -PathType Leaf) { return (Get-Item $p).Length }
        return [long]((Get-ChildItem $p -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum)
    } catch { return 0 }
}

# ------------------------------------------------------------------- manifest

Write-Stage 'Doom Emacs uninstaller'

$manifestPath = Join-Path $InstallRoot $MANIFEST_FILE
if (-not (Test-Path $manifestPath)) {
    Write-Bad "No install manifest at $manifestPath"
    Write-Info 'Without it this uninstaller cannot know what it created, and it will'
    Write-Info 'not guess. Point -InstallRoot at the real install directory.'
    exit 1
}
$mf = Get-Content $manifestPath -Raw | ConvertFrom-Json
$InstallRoot = [System.IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
$manifestRoot = [System.IO.Path]::GetFullPath([string]$mf.installRoot).TrimEnd('\')
if (-not [string]::Equals($manifestRoot, $InstallRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Manifest root '$manifestRoot' does not match requested install root '$InstallRoot'. Refusing to remove anything."
}
$mf.installRoot = $manifestRoot
Write-Info "product : $($mf.product) $($mf.version)"
Write-Info "root    : $($mf.installRoot)"
Write-Info "config  : $($mf.doomDir)"
Write-Info "mode    : $(if ($Full) { 'FULL - config and state included' } else { 'default - config kept' })"

# -------------------------------------------------------------- build the plan

$plan     = New-Object System.Collections.Generic.List[object]
$keeping  = New-Object System.Collections.Generic.List[object]

function Add-Plan([string]$Kind, [string]$Path, [string]$Why, [bool]$UserData = $false) {
    $plan.Add([pscustomobject]@{ kind = $Kind; path = $Path; why = $Why; userData = $UserData; size = (Get-PathSize $Path) })
}
function Add-Keep([string]$Path, [string]$Why) {
    $keeping.Add([pscustomobject]@{ path = $Path; why = $Why })
}
function Test-PathAtOrBelow([string]$Path, [string]$Root) {
    $p = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
    $r = [System.IO.Path]::GetFullPath($Root).TrimEnd('\')
    return [string]::Equals($p, $r, [StringComparison]::OrdinalIgnoreCase) -or
           $p.StartsWith($r + '\', [StringComparison]::OrdinalIgnoreCase)
}

# The install tree itself goes only if the manifest says we created it. A
# 'preexisting' root is the user's own folder: the install merged into it, so
# the uninstall removes only what the manifest recorded inside it and keeps
# the folder.
$rootOwned = $false
foreach ($e in $mf.entries) {
    if ($e.kind -eq 'dir' -and $e.path -eq $mf.installRoot) { $rootOwned = ($e.state -eq 'created'); break }
}
if ((Test-Path $mf.installRoot) -and $rootOwned) {
    Add-Plan 'dir' $mf.installRoot 'the installation itself'
} elseif (Test-Path $mf.installRoot) {
    Add-Keep $mf.installRoot 'install folder predates the install - kept'
}

foreach ($e in $mf.entries) {
    switch ($e.kind) {
        'shortcut' {
            if ($e.state -eq 'created' -and (Test-Path $e.path)) { Add-Plan 'shortcut' $e.path 'Start Menu entry' }
        }
        'dir' {
            # User config is the sensitive one: only in -Full, and flagged as user data.
            if ($e.path -eq $mf.doomDir) {
                if ($Full) {
                    $why = if ($e.state -eq 'preexisting') {
                        'YOUR Doom config - this PREDATES the install, we did not create it'
                    } else {
                        'your Doom config, created by the installer'
                    }
                    if (Test-Path $e.path) { Add-Plan 'dir' $e.path $why $true }
                } else {
                    Add-Keep $e.path 'your Doom config - kept (use -Full to remove)'
                }
            } elseif ($e.state -eq 'created' -and $e.path -like "$($mf.installRoot)\*" -and (Test-Path $e.path)) {
                # Remove owned children first, even when the root is ours, so a
                # lock fails synchronously while the manifest is still present.
                Add-Plan 'dir' $e.path 'installed content'
            }
        }
        'file' {
            if ($e.state -eq 'created' -and
                -not [string]::Equals($e.path, $manifestPath, [System.StringComparison]::OrdinalIgnoreCase) -and
                (Test-Path $e.path)) {
                Add-Plan 'file' $e.path 'installed file'
            }
        }
    }
}

# PATH entry: remove only one the manifest says this installer created.
$binDir = Join-Path $mf.installRoot 'bin'
$userPath = (Get-DoomUserPath).Value
$pathHasUs = @($userPath -split ';') -contains $binDir
$pathEntry = @($mf.entries | Where-Object {
    $_.kind -eq 'env' -and $_.path -eq "Path:$binDir"
} | Select-Object -First 1)
if ($pathHasUs -and $pathEntry.Count -and $pathEntry[0].state -eq 'created') {
    Add-Plan 'env' $binDir 'PATH entry'
} elseif ($pathHasUs) {
    Add-Keep $binDir 'PATH entry predates the install - kept'
}

# Registry
if (Test-Path $REGKEY) { Add-Plan 'regkey' $REGKEY 'Add/Remove Programs entry' }

# Shared tools are never ours to remove.
foreach ($t in @('git', 'rg', 'fd')) {
    $c = Get-Command "$t.exe" -ErrorAction SilentlyContinue
    if ($c -and -not (Test-PathAtOrBelow $c.Source $mf.installRoot)) {
        Add-Keep $c.Source "$t found outside the install - left alone, it is not ours"
    }
}

# -------------------------------------------------------------------- the nag

foreach ($integration in @($mf.wsl)) {
    if ($integration) { Add-Plan 'wsl' ("$($integration.distro):$($integration.root)") 'managed WSL commands and PATH blocks (user configuration is kept)' }
}

Write-Stage 'This will DELETE the following'
$total = 0
$userDataPresent = $false
foreach ($p in $plan) {
    $tag = if ($p.userData) { '  [YOUR DATA]' } else { '' }
    if ($p.userData) { $userDataPresent = $true }
    $sizeCol = if ($p.kind -in @('dir', 'shortcut')) { Format-Size $p.size } else { '        -' }
    Write-Host ("    {0}  {1}" -f $sizeCol, $p.path) -ForegroundColor $(if ($p.userData) { 'Red' } else { 'White' })
    Write-Host ("               {0}{1}" -f $p.why, $tag) -ForegroundColor DarkGray
    $total += $p.size
}
Write-Host ''
Write-Host ("    total: {0}" -f (Format-Size $total).Trim()) -ForegroundColor Yellow

if ($keeping.Count -gt 0) {
    Write-Stage 'This will KEEP the following'
    foreach ($k in $keeping) {
        Write-Host ("    $($k.path)") -ForegroundColor Green
        Write-Host ("        $($k.why)") -ForegroundColor DarkGray
    }
}

if ($plan.Count -eq 0) {
    Write-Stage 'Nothing to do'
    exit 0
}

if ($WhatIf) {
    Write-Stage 'WhatIf - nothing was changed'
    exit 0
}

# ----------------------------------------------------------------- confirm

if (-not $Yes) {
    Write-Host ''
    if ($userDataPresent) {
        Write-Host '  This includes YOUR OWN configuration, which cannot be recovered.' -ForegroundColor Red
        Write-Host '  Type FULL (in capitals) to confirm, or anything else to abort:' -ForegroundColor Yellow
        $answer = Read-Host '  >'
        if ($answer -cne 'FULL') { Write-Host ''; Write-Warn 'aborted, nothing deleted'; exit 1 }
    } else {
        $answer = Read-Host '  Proceed? [y/N]'
        if ($answer -notmatch '^[Yy]') { Write-Host ''; Write-Warn 'aborted, nothing deleted'; exit 1 }
    }
}

# ------------------------------------------------------------------- remove

Write-Stage 'Removing'
# Complete WSL cleanup before deleting the Windows scripts it depends on.
# An inaccessible distro/disk leaves the manifest and Windows install intact.
if (@($mf.wsl).Count -and $mf.wsl) {
    . (Join-Path $scriptDir 'wsl-integration.ps1')
    try {
        foreach ($integration in @($mf.wsl)) { Remove-DoomWslIntegration -Entry $integration }
    } catch {
        Write-Bad "WSL cleanup failed: $($_.Exception.Message)"
        Write-Info 'The Windows installation and ownership manifest were kept. Restore access to the distribution and retry.'
        exit 1
    }
}
$failed = 0
$deferredPaths = @(
    $manifestPath,
    (Join-Path $mf.installRoot 'Uninstall.exe')
)
if (Test-PathAtOrBelow $PSCommandPath $mf.installRoot) { $deferredPaths += $PSCommandPath }
foreach ($p in $plan) {
    # Keep the manifest, running uninstallers, owned root, and ARP key until
    # every other removal has succeeded. A failure must remain retryable.
    if (($rootOwned -and $p.path -eq $mf.installRoot) -or
        $p.kind -eq 'wsl' -or
        $p.kind -eq 'regkey' -or
        $deferredPaths -contains $p.path) { continue }
    if ($p.kind -in @('dir', 'file', 'shortcut') -and -not (Test-Path $p.path)) { continue }
    try {
        switch ($p.kind) {
            'env' {
                if (Remove-DoomUserPathEntry -Entry $p.path) { Write-Ok "PATH entry removed" }
                else { Write-Info 'PATH entry already absent' }
            }
            'shortcut' { Remove-Item $p.path -Force; Write-Ok "removed $($p.path)" }
            default {
                Remove-Item $p.path -Recurse -Force
                Write-Ok "removed $($p.path)"
            }
        }
    } catch {
        Write-Bad "$($p.path): $($_.Exception.Message)"
        $failed++
    }
}

if ($failed -eq 0) {
    try {
        # Prepare deferred cleanup before removing the ARP entry. The script,
        # manifest, and NSIS uninstaller may be locked by this process tree.
        $bat = Join-Path ([System.IO.Path]::GetTempPath()) ('doom-cleanup-' + [guid]::NewGuid().ToString('N') + '.cmd')
        $cleanup = @('@echo off', 'ping 127.0.0.1 -n 3 >nul')
        if ($rootOwned) {
            $cleanup += "rmdir /s /q `"$($mf.installRoot)`""
        } else {
            foreach ($path in $deferredPaths) { $cleanup += "del /f /q `"$path`"" }
        }
        $cleanup += 'del "%~f0"'
        $cleanup | Set-Content -Path $bat -Encoding ascii

        if (Test-Path $REGKEY) { Remove-Item $REGKEY -Recurse -Force }
        Start-Process -FilePath $bat -WindowStyle Hidden
        Write-Ok 'registry entry removed; final cleanup runs in a moment'
    } catch {
        Write-Bad "final cleanup: $($_.Exception.Message)"
        $failed++
    }
}

Write-Stage 'Done'
if ($failed -gt 0) {
    Write-Bad "$failed item(s) could not be removed"
    Write-Info 'Emacs may still be running. Close it and run this again.'
    exit 1
}
Write-Ok 'Doom Emacs removed.'
if (-not $Full) {
    Write-Info "Your config was kept at $($mf.doomDir)"
}
exit 0
