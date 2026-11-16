<#
.SYNOPSIS
    Compile the real NSIS installer with a tiny payload, then install, reinstall,
    recover a legacy install, and uninstall. Uses a temporary profile, a unique
    uninstall registry key, and a temporary PATH entry removed in finally.
    The CLI is a stub: this checks packaging/lifecycle, not Emacs package builds.
#>
[CmdletBinding()]
param([string]$MakeNsis)
$ErrorActionPreference = 'Stop'
$installerDir = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $MakeNsis) { $MakeNsis = Join-Path $installerDir 'build\tools\nsis-3.11\makensis.exe' }
if (-not (Test-Path -LiteralPath $MakeNsis)) { throw 'Pass -MakeNsis with the path to makensis.exe.' }
. (Join-Path $installerDir 'env-path.ps1')

$caseId = [guid]::NewGuid().ToString('N')
$scratch = Join-Path $env:TEMP ('doom-nsis-' + $caseId)
$stage = Join-Path $scratch 'stage'
$root = Join-Path $scratch 'installed'
$profile = Join-Path $scratch 'profile'
$regSubkey = 'Software\DoomEmacsInstallerSelfTest\' + $caseId
$regKey = 'HKCU:\' + $regSubkey
$setup = Join-Path $scratch 'doom-lifecycle-test.exe'
$binDir = Join-Path $root 'bin'
$passed = $false

function Invoke-TestProcess([string]$File, [string]$Arguments) {
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $File
    $info.Arguments = $Arguments
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.EnvironmentVariables['USERPROFILE'] = $profile
    $info.EnvironmentVariables['LOCALAPPDATA'] = Join-Path $profile 'AppData\Local'
    $process = [Diagnostics.Process]::Start($info)
    if (-not $process.WaitForExit(90000)) {
        $process.Kill()
        throw "Test process timed out: $File"
    }
    return $process.ExitCode
}
function Assert-Installed {
    foreach ($name in @('install-manifest.json', 'install-doom.ps1', 'uninstall-doom.ps1', 'env-path.ps1', 'repair-doom.ps1', 'Uninstall.exe')) {
        if (-not (Test-Path -LiteralPath (Join-Path $root $name))) { throw "Installed file missing: $name" }
    }
    if (@((Get-DoomUserPath).Value -split ';') -notcontains $binDir) { throw 'Installer did not add its bin to user PATH.' }
    $registration = Get-ItemProperty -Path $regKey
    if ($registration.InstallLocation -ne $root -or $registration.DisplayName -ne 'Doom Emacs') {
        throw 'Installer did not register a complete uninstall entry.'
    }
    if (-not (Test-Path -LiteralPath (Join-Path $profile '.config\doom\init.el'))) {
        throw 'Installer did not seed the isolated user configuration.'
    }
}

try {
    foreach ($relative in @('emacs\bin', 'deps\git\cmd', 'doom\lisp', 'doom\static', 'bin')) {
        New-Item -ItemType Directory -Path (Join-Path $stage $relative) -Force | Out-Null
    }
    New-Item -ItemType Directory -Path (Join-Path $profile 'AppData\Local') -Force | Out-Null
    foreach ($relative in @('emacs\bin\emacs.exe', 'deps\git\cmd\git.exe', 'doom\lisp\doom.el', 'bin\doom-env.cmd')) {
        Set-Content -LiteralPath (Join-Path $stage $relative) -Value 'fixture' -Encoding ASCII
    }
    Copy-Item -LiteralPath (Join-Path $installerDir '..\.doom') -Destination (Join-Path $stage 'doom\.doom')
    Copy-Item -LiteralPath (Join-Path $installerDir '..\LICENSE') -Destination (Join-Path $stage 'doom\LICENSE')
    foreach ($name in @('init', 'config', 'packages')) {
        Set-Content -LiteralPath (Join-Path $stage "doom\static\$name.example.el") -Value '; test config' -Encoding ASCII
    }
    $marker = @{}
    foreach ($id in @('emacs', 'git', 'ripgrep', 'fd')) { $marker[$id] = 'a' * 64 }
    $marker | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $stage '.staged.json') -Encoding UTF8
    @'
@echo off
if exist "%~dp0fail-sync" exit /b 7
mkdir "%~dp0..\doom\.local\straight\build-test\package" 2>nul
exit /b 0
'@ | Set-Content -LiteralPath (Join-Path $stage 'bin\doom.cmd') -Encoding ASCII
    # A compile-only build must replace management scripts from an obsolete stage.
    Set-Content -LiteralPath (Join-Path $stage 'install-doom.ps1') -Value 'exit 0' -Encoding ASCII
    & $MakeNsis '-V2' '-DNOCOMPRESS=1' "-DSTAGING=$stage" "-DOUTFILE=$setup" "-DREGKEY=$regSubkey" (Join-Path $installerDir 'doom.nsi')
    if ($LASTEXITCODE -ne 0) { throw 'NSIS compilation failed.' }

    $exitCode = Invoke-TestProcess $setup "/S /NoShortcuts /D=$root"
    if ($exitCode -ne 0) { throw "Install exited $exitCode" }
    Assert-Installed
    $manifest = Get-Content -LiteralPath (Join-Path $root 'install-manifest.json') -Raw | ConvertFrom-Json
    $originalRootState = @($manifest.entries | Where-Object { $_.path -eq $root })[0].state
    $exitCode = Invoke-TestProcess $setup "/S /NoShortcuts /D=$root"
    if ($exitCode -ne 0) { throw "Reinstall exited $exitCode" }
    Assert-Installed
    $manifest = Get-Content -LiteralPath (Join-Path $root 'install-manifest.json') -Raw | ConvertFrom-Json
    if (@($manifest.entries | Where-Object { $_.path -eq $root })[0].state -ne $originalRootState) {
        throw 'Reinstall lost root ownership.'
    }
    Write-Host 'PASS: compiled installer installs/reinstalls its engine, manifest, PATH and uninstall registration.'

    # Model the actual broken release, including an unrelated root file to preserve.
    [void](Remove-DoomUserPathEntry -Entry $binDir)
    Remove-Item -LiteralPath (Join-Path $root 'install-manifest.json') -Force
    foreach ($name in @('install-doom.ps1', 'uninstall-doom.ps1', 'env-path.ps1', 'repair-doom.ps1')) {
        Remove-Item -LiteralPath (Join-Path $root $name) -Force
    }
    Set-Content -LiteralPath (Join-Path $root 'precious.txt') -Value 'keep me' -Encoding ASCII
    $exitCode = Invoke-TestProcess $setup "/S /NoShortcuts /D=$root"
    if ($exitCode -ne 0) { throw "Legacy recovery exited $exitCode" }
    Assert-Installed
    # Another reinstall must not adopt the unknown file after recovery.
    $exitCode = Invoke-TestProcess $setup "/S /NoShortcuts /D=$root"
    if ($exitCode -ne 0) { throw "Post-recovery reinstall exited $exitCode" }
    $manifest = Get-Content -LiteralPath (Join-Path $root 'install-manifest.json') -Raw | ConvertFrom-Json
    if (@($manifest.entries | Where-Object { $_.path -like '*precious.txt' }).Count) {
        throw 'Recovery or reinstall adopted unrelated root content.'
    }
    Write-Host 'PASS: legacy recovery preserves unknown content across repeated reinstalls.'

    # A nonzero sync exit with an old package tree must still fail setup.
    Set-Content -LiteralPath (Join-Path $stage 'bin\fail-sync') -Value 'fail' -Encoding ASCII
    & $MakeNsis '-V2' '-DNOCOMPRESS=1' "-DSTAGING=$stage" "-DOUTFILE=$setup" "-DREGKEY=$regSubkey" (Join-Path $installerDir 'doom.nsi')
    if ($LASTEXITCODE -ne 0) { throw 'Failed-sync fixture compilation failed.' }
    $exitCode = Invoke-TestProcess $setup "/S /NoShortcuts /D=$root"
    if ($exitCode -eq 0) { throw 'Failed sync was reported as successful setup.' }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'install-manifest.json'))) { throw 'Failed sync lost recovery metadata.' }
    Write-Host 'PASS: a failed sync cannot report success, even with previously built packages.'

    # This is the same removal handler called by the maintenance page.
    $exitCode = Invoke-TestProcess $setup "/S /Uninstall /D=$root"
    if ($exitCode -ne 0) { throw "Uninstall exited $exitCode" }
    Start-Sleep -Seconds 4
    foreach ($name in @('bin', 'deps', 'emacs', 'doom', 'install-manifest.json')) {
        if (Test-Path -LiteralPath (Join-Path $root $name)) { throw "Uninstall left $name" }
    }
    if (Test-Path -LiteralPath $regKey) { throw 'Uninstall left its registry key.' }
    if (@((Get-DoomUserPath).Value -split ';') -contains $binDir) { throw 'Uninstall left its PATH entry.' }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'precious.txt'))) { throw 'Uninstall removed unknown root content.' }
    if (-not (Test-Path -LiteralPath (Join-Path $profile '.config\doom\init.el'))) { throw 'Uninstall removed user config.' }
    Write-Host 'PASS: uninstall removes bundled tools and PATH, keeping configuration and unknown files.'

    # Remove a legacy installation directly, without reinstalling its payload.
    foreach ($name in @('bin', 'deps', 'doom', 'emacs', '.staged.json')) {
        Copy-Item -LiteralPath (Join-Path $stage $name) -Destination $root -Recurse -Force
    }
    $exitCode = Invoke-TestProcess $setup "/S /Uninstall /D=$root"
    if ($exitCode -ne 0) { throw "Legacy uninstall exited $exitCode" }
    Start-Sleep -Seconds 4
    foreach ($name in @('bin', 'deps', 'doom', 'emacs', 'install-manifest.json')) {
        if (Test-Path -LiteralPath (Join-Path $root $name)) { throw "Legacy uninstall left $name" }
    }
    if (-not (Test-Path -LiteralPath (Join-Path $root 'precious.txt'))) { throw 'Legacy uninstall removed unknown content.' }
    Write-Host 'PASS: installer can directly remove a legacy installation without its manifest or engine.'
    $passed = $true
} finally {
    [void](Remove-DoomUserPathEntry -Entry $binDir)
    if (Test-Path -LiteralPath $regKey) { Remove-Item -LiteralPath $regKey -Recurse -Force }
    # Scratch is a generated direct child of TEMP, verified before recursive cleanup.
    if ($passed -and (Split-Path -Parent ([IO.Path]::GetFullPath($scratch))) -eq [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')) {
        Remove-Item -LiteralPath $scratch -Recurse -Force
    } elseif (-not $passed) {
        Write-Host "Test artifacts retained at $scratch"
    }
}
