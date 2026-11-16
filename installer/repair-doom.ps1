<#
.SYNOPSIS
    Restore uninstall metadata for the first Windows installer build, which
    omitted the installation engine and its manifest. Does not download packages.
.DESCRIPTION
    Only recognized payload directories and files are adopted. The root and
    unknown content remain unowned, so removal preserves them. User configuration
    is always treated as preexisting. Run with -WhatIf to inspect the plan.
#>
[CmdletBinding()]
param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'Programs\DoomEmacs'),
    [switch]$WhatIf,
    [string]$RegistryKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\DoomEmacs'
)

$ErrorActionPreference = 'Stop'
$InstallRoot = [IO.Path]::GetFullPath($InstallRoot).TrimEnd('\')
$manifestPath = Join-Path $InstallRoot 'install-manifest.json'
if (Test-Path -LiteralPath $manifestPath) {
    throw 'An install manifest already exists. Use the normal installer or uninstaller.'
}

# These markers distinguish our incomplete bundle from a random Emacs directory.
foreach ($relative in @('.staged.json', 'doom\.doom', 'doom\lisp\doom.el',
    'bin\doom.cmd', 'bin\doom-env.cmd', 'emacs\bin\emacs.exe',
    'deps\git\cmd\git.exe')) {
    if (-not (Test-Path -LiteralPath (Join-Path $InstallRoot $relative) -PathType Leaf)) {
        throw "Not a recognized incomplete Doom installation: missing $relative."
    }
}
$marker = Get-Content -LiteralPath (Join-Path $InstallRoot '.staged.json') -Raw | ConvertFrom-Json
foreach ($id in @('emacs', 'git', 'ripgrep', 'fd')) {
    if ([string]$marker.$id -notmatch '^[0-9a-fA-F]{64}$') {
        throw "Invalid staging marker: missing hash for $id."
    }
}

$entries = New-Object System.Collections.Generic.List[object]
function Add-RecoveryEntry([string]$Kind, [string]$Path, [string]$State, [string]$Note = '') {
    $entries.Add([pscustomobject]@{ kind = $Kind; path = $Path; state = $State; note = $Note })
}
Add-RecoveryEntry 'dir' $InstallRoot 'preexisting' 'recovered root; unknown content is kept'
$doomDir = Join-Path $env:USERPROFILE '.config\doom'
Add-RecoveryEntry 'dir' $doomDir 'preexisting' 'user configuration is kept'
foreach ($name in @('bin', 'deps', 'doom', 'emacs')) {
    $path = Join-Path $InstallRoot $name
    if (Test-Path -LiteralPath $path -PathType Container) {
        # Do not adopt redirected trees (junctions/symlinks) as removable content.
        if ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
            throw "Cannot recover a redirected payload directory: $path"
        }
        Add-RecoveryEntry 'dir' $path 'created' 'recognized bundled payload'
    }
}
foreach ($name in @('.staged.json', 'doom.ico', 'Uninstall.exe')) {
    $path = Join-Path $InstallRoot $name
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        Add-RecoveryEntry 'file' $path 'created' 'recognized bundled file'
    }
}
$managementFiles = @('install-doom.ps1', 'uninstall-doom.ps1', 'env-path.ps1', 'repair-doom.ps1')
foreach ($name in $managementFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $name) -PathType Leaf)) {
        throw "Recovery script dependency missing: $name"
    }
    Add-RecoveryEntry 'file' (Join-Path $InstallRoot $name) 'created' 'restored management script'
}
Add-RecoveryEntry 'file' $manifestPath 'created' 'recovered ownership manifest'
Add-RecoveryEntry 'regkey' $RegistryKey 'created' 'restored uninstall registration'
$version = '0.0.0'
foreach ($line in (Get-Content -LiteralPath (Join-Path $InstallRoot 'doom\.doom') -TotalCount 4)) {
    if ($line -match '"([0-9]+\.[0-9]+[^"]*)"') { $version = $Matches[1]; break }
}
$manifest = [ordered]@{
    schema = 1; product = 'Doom Emacs'; version = $version
    installedUtc = (Get-Date).ToUniversalTime().ToString('o')
    installRoot = $InstallRoot; doomDir = $doomDir; sourceMode = 'Recovery'
    entries = $entries.ToArray()
}

if ($WhatIf) {
    $manifest | ConvertTo-Json -Depth 8
    return
}
foreach ($name in $managementFiles) {
    $source = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot $name))
    $destination = Join-Path $InstallRoot $name
    if ($source -ne $destination) { Copy-Item -LiteralPath $source -Destination $destination -Force }
}
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
New-Item -Path $RegistryKey -Force | Out-Null
$values = @{
    DisplayName = 'Doom Emacs'; DisplayVersion = $version; InstallLocation = $InstallRoot
    Publisher = 'Doom Emacs community build'
    UninstallString = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$InstallRoot\uninstall-doom.ps1`" -InstallRoot `"$InstallRoot`" -Yes"
}
foreach ($name in $values.Keys) {
    New-ItemProperty -Path $RegistryKey -Name $name -Value $values[$name] -PropertyType String -Force | Out-Null
}
# The old Uninstall.exe could not remove its payload; don't leave a stale silent command.
Remove-ItemProperty -Path $RegistryKey -Name QuietUninstallString -ErrorAction SilentlyContinue
Write-Host "Recovered uninstall metadata at $manifestPath. User configuration and unknown root content are kept."
