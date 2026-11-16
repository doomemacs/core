# Read-only UI information. Keep the manifest's configured path distinct from
# other existing configurations; displaying a folder must not imply migration.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InstallRoot,
    [Parameter(Mandatory = $true)][string]$OutFile
)
$ErrorActionPreference = 'Stop'
$configured = Join-Path $env:USERPROFILE '.config\doom'
$manifestPath = Join-Path $InstallRoot 'install-manifest.json'
if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    if ([string]::IsNullOrWhiteSpace([string]$manifest.doomDir)) {
        throw 'The installation manifest does not specify its configuration folder.'
    }
    $configured = [IO.Path]::GetFullPath([string]$manifest.doomDir)
}
$lines = @(
    'Configuration files stay in their original folders when Doom is removed.',
    'No backup copy is created.', '',
    'Configured folder:', $configured
)
if (-not (Test-Path -LiteralPath $configured -PathType Container)) {
    $lines += 'This folder does not exist yet.'
}
$legacy = Join-Path $env:USERPROFILE '.doom.d'
if ($legacy.TrimEnd('\') -ne $configured.TrimEnd('\') -and (Test-Path -LiteralPath $legacy -PathType Container)) {
    $lines += @('', 'Other existing configuration (also kept):', $legacy,
        'This installer does not select or migrate this folder automatically.')
}
foreach ($integration in @($manifest.wsl)) {
    if ($integration) {
        $lines += @('', "WSL commands/PATH to remove: $($integration.distro) / $($integration.user)", $integration.root)
    }
}
# UTF-16 avoids corrupting non-ASCII profile paths through nsExec stdout/OEM.
[IO.File]::WriteAllText($OutFile, ($lines -join "`r`n"), [Text.Encoding]::Unicode)
$legacyPath = if ($legacy.TrimEnd('\') -ne $configured.TrimEnd('\') -and (Test-Path -LiteralPath $legacy -PathType Container)) { $legacy } else { '' }
$configStatus = if (Test-Path -LiteralPath $configured -PathType Container) { 'Configured folder (kept):' } else { 'Configured folder (not created yet):' }
$wsl = @($manifest.wsl | Where-Object { $_ })
[IO.File]::WriteAllLines(($OutFile + '.ini'), [string[]]@(
    '[paths]', "Config=$configured", "ConfigStatus=$configStatus", "Legacy=$legacyPath",
    $(if ($wsl.Count) { "Wsl=$($wsl[0].root)" } else { 'Wsl=' })
), [Text.Encoding]::Unicode)
