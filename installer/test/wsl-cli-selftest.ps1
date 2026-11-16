# Full Windows toolchain required. Exercise WSL -> Windows Doom, using an
# isolated Linux HOME instead of editing the user's actual shell profiles.
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Distribution,
    [Parameter(Mandatory = $true)][string]$InstallRoot
)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\wsl-integration.ps1')
$originalInvoke = ${function:Invoke-DoomWslScript}
$settingsPath = Join-Path $InstallRoot 'wsl-bridge.json'
if (Test-Path -LiteralPath $settingsPath) { throw 'Use a staging tree without existing WSL integration for this test.' }
$linuxHome = & $originalInvoke -Distribution $Distribution -Script 'mktemp -d /tmp/doom-host-test.XXXXXXXX'
$encodedHome = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($linuxHome))
function Invoke-DoomWslScript {
    param([string]$Distribution, [string]$User, [string]$Script, [string[]]$Arguments = @())
    $prefix = 'export HOME="$(printf %s ' + $encodedHome + ' | base64 -d)"' + "`n"
    & $originalInvoke -Distribution $Distribution -User $User -Script ($prefix + $Script) -Arguments $Arguments
}
$entry = $null
try {
    $entry = Add-DoomWslIntegration -InstallRoot $InstallRoot -DoomDir (Join-Path $InstallRoot 'test-config') -Distribution $Distribution
    $command = '. "$HOME/.local/share/doom-windows/' + $entry.installId + '/env.sh"' + "`n" + 'doom info --json'
    $report = Invoke-DoomWslScript -Distribution $Distribution -User $entry.user -Script $command
    $data = $report | ConvertFrom-Json
    if (-not $data.emacs -or -not $data.doom -or $report -notmatch 'mingw|windows-nt|w64') {
        throw 'The forwarded command did not report a Windows Emacs/Doom environment.'
    }
    Write-Host 'PASS: doom info from a real WSL shell uses the bundled Windows Emacs and Doom.'
    $command = '. "$HOME/.local/share/doom-windows/' + $entry.installId + '/env.sh"' + "`n" + 'doom not-a-command-that-exists'
    $failed = $false
    try { [void](Invoke-DoomWslScript -Distribution $Distribution -User $entry.user -Script $command) } catch { $failed = $true }
    if (-not $failed) { throw 'The Windows CLI failure was swallowed.' }
    Write-Host 'PASS: Windows Doom failures propagate to the WSL shell.'
} finally {
    if (-not $entry -and (Test-Path -LiteralPath $settingsPath)) {
        $entry = @((Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json).integrations)[0]
    }
    if ($entry) { Remove-DoomWslIntegration -Entry $entry }
    if (Test-Path -LiteralPath $settingsPath) { Remove-Item -LiteralPath $settingsPath -Force }
    if ($linuxHome -match '^/tmp/doom-host-test\.[A-Za-z0-9]+$') {
        [void](& $originalInvoke -Distribution $Distribution -Script ('rmdir -- "$(printf %s ' + $encodedHome + ' | base64 -d)/.local/share/doom-windows" "$(printf %s ' + $encodedHome + ' | base64 -d)/.local/share" "$(printf %s ' + $encodedHome + ' | base64 -d)/.local" "$(printf %s ' + $encodedHome + ' | base64 -d)"'))
    }
}
