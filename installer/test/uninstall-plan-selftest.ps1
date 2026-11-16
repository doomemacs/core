$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
$uninstaller = Join-Path $here '..\uninstall-doom.ps1'

function New-Case([string]$RootState) {
    $root = Join-Path $env:TEMP ('doom-uninst-plan-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $root | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $root 'bin') | Out-Null
    Set-Content -LiteralPath (Join-Path $root 'bin\doom.cmd') -Value '@echo off' -Encoding ascii
    $manifestPath = Join-Path $root 'install-manifest.json'
    $entries = @(
        [pscustomobject]@{ kind = 'dir'; path = $root; state = $RootState; note = 'install root' },
        [pscustomobject]@{ kind = 'dir'; path = (Join-Path $root 'bin'); state = 'created'; note = '' },
        [pscustomobject]@{ kind = 'file'; path = $manifestPath; state = 'created'; note = 'install ownership manifest' }
    )
    if ($RootState -eq 'preexisting') {
        # A preexisting root means root-level files must be recorded individually.
        $entries += [pscustomobject]@{ kind = 'file'; path = (Join-Path $root 'bin\doom.cmd'); state = 'created'; note = '' }
    }
    $manifest = [pscustomobject]@{
        schema      = 1
        product     = 'Doom Emacs'
        version     = '0.0.0'
        installRoot = $root
        doomDir     = (Join-Path $env:TEMP 'doom-config-that-does-not-exist')
        entries     = $entries
    }
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    return $root
}

$rootA = $null
$rootB = $null
$rootC = $null
$rootD = $null
$rootE = $null
$rootF = $null
$lock = $null
$testRegKey = $null
$successRegKey = $null
$ownedRegKey = $null
try {
    # Case A: manifest owns the root -> the root itself is planned for deletion.
    $rootA = New-Case 'created'
    $outA = & $uninstaller -InstallRoot $rootA -WhatIf 6>&1 | Out-String
    if ($outA -notmatch 'the installation itself') { throw "owned root not planned as the installation itself`n$outA" }

    # Case B: root predates the install -> root survives, our content goes.
    $rootB = New-Case 'preexisting'
    $outB = & $uninstaller -InstallRoot $rootB -WhatIf 6>&1 | Out-String
    if ($outB -match 'the installation itself') { throw "preexisting root was planned for deletion`n$outB" }
    if ($outB -notmatch [regex]::Escape((Join-Path $rootB 'bin'))) { throw "created child dir missing from delete plan`n$outB" }
    if ($outB -notmatch 'doom\.cmd') { throw 'created file missing from delete plan' }

    if ($outB -notmatch 'predates the install - kept') { throw "preexisting root not listed as kept`n$outB" }

    Write-Host 'PASS: owned root is deleted; preexisting root survives with only manifest-owned content removed.'

    # A copied or moved manifest must never redirect deletion to the old path.
    $rootC = New-Case 'created'
    $manifestPath = Join-Path $rootC 'install-manifest.json'
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $manifest.installRoot = $rootC + '-different'
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding UTF8
    $outC = ''
    try {
        & $uninstaller -InstallRoot $rootC -WhatIf 6>&1 | Out-String | Out-Null
    } catch {
        $outC = $_.Exception.Message
    }
    if ($outC -notmatch 'does not match requested install root') {
        throw "moved-manifest root mismatch was not rejected: $outC"
    }
    Write-Host 'PASS: a manifest cannot redirect deletion to a different root.'

    # A real removal failure must leave both recovery handles in place: the
    # manifest on disk and the Add/Remove Programs registry key.
    $rootD = New-Case 'created'
    $testRegKey = 'HKCU:\Software\DoomEmacsInstallerSelfTest\' + [guid]::NewGuid().ToString('N')
    New-Item -Path $testRegKey -Force | Out-Null
    $lockedFile = Join-Path $rootD 'bin\doom.cmd'
    $lock = [System.IO.File]::Open($lockedFile, 'Open', 'ReadWrite', 'None')
    $outD = & $uninstaller -InstallRoot $rootD -Yes -RegistryKey $testRegKey 6>&1 | Out-String
    if ($LASTEXITCODE -ne 1) { throw "locked-file uninstall unexpectedly exited $LASTEXITCODE`n$outD" }
    if (-not (Test-Path (Join-Path $rootD 'install-manifest.json'))) { throw 'failed uninstall removed its recovery manifest' }
    if (-not (Test-Path $testRegKey)) { throw 'failed uninstall removed its Add/Remove recovery key' }
    Write-Host 'PASS: a partial failure keeps the manifest and registry entry for retry.'

    $lock.Dispose()
    $lock = $null
    $rootE = New-Case 'preexisting'
    $successRegKey = 'HKCU:\Software\DoomEmacsInstallerSelfTest\' + [guid]::NewGuid().ToString('N')
    New-Item -Path $successRegKey -Force | Out-Null
    $outE = & $uninstaller -InstallRoot $rootE -Yes -RegistryKey $successRegKey 6>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "clean uninstall exited $LASTEXITCODE`n$outE" }
    Start-Sleep -Seconds 4
    if (-not (Test-Path $rootE)) { throw 'preexisting install root was removed' }
    if (Test-Path (Join-Path $rootE 'install-manifest.json')) { throw 'clean uninstall left its manifest behind' }
    if (Test-Path $successRegKey) { throw 'clean uninstall left its registry entry behind' }
    Write-Host 'PASS: a clean uninstall succeeds and keeps a preexisting root.'

    $rootF = New-Case 'created'
    $ownedRegKey = 'HKCU:\Software\DoomEmacsInstallerSelfTest\' + [guid]::NewGuid().ToString('N')
    New-Item -Path $ownedRegKey -Force | Out-Null
    $outF = & $uninstaller -InstallRoot $rootF -Yes -RegistryKey $ownedRegKey 6>&1 | Out-String
    if ($LASTEXITCODE -ne 0) { throw "owned-root uninstall exited $LASTEXITCODE`n$outF" }
    Start-Sleep -Seconds 4
    if (Test-Path $rootF) { throw 'clean uninstall left its owned install root behind' }
    if (Test-Path $ownedRegKey) { throw 'owned-root uninstall left its registry entry behind' }
    Write-Host 'PASS: a clean uninstall removes an installer-owned root.'
} finally {
    if ($lock) { $lock.Dispose() }
    if ($rootA) { Remove-Item -LiteralPath $rootA -Recurse -Force -ErrorAction SilentlyContinue }
    if ($rootB) { Remove-Item -LiteralPath $rootB -Recurse -Force -ErrorAction SilentlyContinue }
    if ($rootC) { Remove-Item -LiteralPath $rootC -Recurse -Force -ErrorAction SilentlyContinue }
    if ($rootD) { Remove-Item -LiteralPath $rootD -Recurse -Force -ErrorAction SilentlyContinue }
    if ($rootE) { Remove-Item -LiteralPath $rootE -Recurse -Force -ErrorAction SilentlyContinue }
    if ($rootF) { Remove-Item -LiteralPath $rootF -Recurse -Force -ErrorAction SilentlyContinue }
    if ($testRegKey) { Remove-Item -Path $testRegKey -Recurse -Force -ErrorAction SilentlyContinue }
    if ($successRegKey) { Remove-Item -Path $successRegKey -Recurse -Force -ErrorAction SilentlyContinue }
    if ($ownedRegKey) { Remove-Item -Path $ownedRegKey -Recurse -Force -ErrorAction SilentlyContinue }
}
