$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
. (Join-Path $here '..\env-path.ps1')

# Use a disposable registry value so a killed test process cannot damage the
# developer's real Path.
$valueName = 'DoomInstallerPathSelfTest-' + [guid]::NewGuid().ToString('N')
$added = 'C:\doom-env-path-selftest-added'
try {
    Set-DoomUserPath -Value '%USERPROFILE%\bin' -Kind ([Microsoft.Win32.RegistryValueKind]::ExpandString) -ValueName $valueName

    $p = Get-DoomUserPath -ValueName $valueName
    if ($p.Kind -ne [Microsoft.Win32.RegistryValueKind]::ExpandString) { throw "kind not preserved on read: $($p.Kind)" }
    if ($p.Value -notlike '*%USERPROFILE%\bin*') { throw 'REG_EXPAND_SZ reference was expanded on read' }

    if (-not (Add-DoomUserPathEntry -Entry $added -ValueName $valueName)) { throw 'Add-DoomUserPathEntry reported no change on first add' }
    $p = Get-DoomUserPath -ValueName $valueName
    if ($p.Kind -ne [Microsoft.Win32.RegistryValueKind]::ExpandString) { throw 'kind lost after add' }
    if ($p.Value -notlike '*%USERPROFILE%\bin*') { throw '%refs% destroyed by add' }
    if ((@($p.Value -split ';') | Where-Object { $_ -eq $added }).Count -ne 1) { throw 'entry not added exactly once' }
    if (Add-DoomUserPathEntry -Entry $added -ValueName $valueName) { throw 'add is not idempotent' }

    if (-not (Remove-DoomUserPathEntry -Entry $added -ValueName $valueName)) { throw 'Remove-DoomUserPathEntry reported no change' }
    $p = Get-DoomUserPath -ValueName $valueName
    if ($p.Value -like "*$added*") { throw 'entry not removed' }
    if ($p.Kind -ne [Microsoft.Win32.RegistryValueKind]::ExpandString) { throw 'kind lost after remove' }
    if ($p.Value -notlike '*%USERPROFILE%\bin*') { throw '%refs% destroyed by remove' }
    if (Remove-DoomUserPathEntry -Entry $added -ValueName $valueName) { throw 'remove is not idempotent' }

    Write-Host 'PASS: raw Path round-trip preserves RegistryValueKind and %refs%.'
} finally {
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
    try { $key.DeleteValue($valueName, $false) } finally { $key.Close() }
}
