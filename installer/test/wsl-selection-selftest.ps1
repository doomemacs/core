$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\wsl-integration.ps1')
$id = [guid]::NewGuid().ToString('N')
$scratch = Join-Path $env:TEMP ('doom-wsl-selection-' + $id)
$key = 'HKCU:\Software\DoomEmacsInstallerSelfTest\' + $id
New-Item -ItemType Directory -Path $scratch | Out-Null
$script:registrations = @([pscustomobject]@{ Name = 'Ubuntu-26.04'; Id = 'new-id' })
function Get-DoomWslDistributions { return $script:registrations }
$old = [pscustomobject]@{ distro = 'Ubuntu-20.04'; distributionId = 'old-id'; user = 'test'; home = '/home/test'; root = '/home/test/.local/share/doom-windows/test' }
$settings = @{ integrations = @($old) }
try {
    Save-DoomWslRegistryState -Root $scratch -Key $key -Settings $settings -Selected $old
    $selection = Get-DoomWslSelection -Root $scratch -Key $key
    if ($selection.Suggested -or $selection.Status -notmatch 'not found' -or $selection.Distributions.Count -ne 1) {
        throw 'A replacement distro was selected by name or the new distro was not offered.'
    }
    $script:registrations = @([pscustomobject]@{ Name = 'Ubuntu-renamed'; Id = 'old-id' })
    $selection = Get-DoomWslSelection -Root $scratch -Key $key
    if ($selection.Suggested -cne 'Ubuntu-renamed') { throw 'Saved registration was not recognized after renaming.' }
    # An old installer had JSON metadata but no WSL registry values.
    Remove-Item -LiteralPath $key -Recurse -Force
    $settings | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $scratch 'wsl-bridge.json') -Encoding UTF8
    $selection = Get-DoomWslSelection -Root $scratch -Key $key
    if ($selection.Suggested -cne 'Ubuntu-renamed') { throw 'Legacy JSON integration was not offered.' }
    $script:registrations = @()
    $selection = Get-DoomWslSelection -Root $scratch -Key $key
    if ($selection.Suggested -or $selection.Status -notmatch 'No registered') { throw 'Missing WSL did not allow Windows-only setup.' }
    if (@((Get-Content -LiteralPath (Join-Path $scratch 'wsl-bridge.json') -Raw | ConvertFrom-Json).integrations).Count -ne 1) {
        throw 'Read-only selection lost an unavailable integration.'
    }
    Write-Host 'PASS: available/missing/renamed WSL, registry persistence, legacy JSON fallback and no mutation of saved integrations.'
} finally {
    if (Test-Path -LiteralPath $key) { Remove-Item -LiteralPath $key -Recurse -Force }
    if ((Split-Path -Parent ([IO.Path]::GetFullPath($scratch))) -eq [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')) {
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
}
