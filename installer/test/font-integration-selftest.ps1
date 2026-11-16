$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\font-integration.ps1')
$caseId = [guid]::NewGuid().ToString('N')
$scratch = Join-Path $env:TEMP ('doom-font-test-' + $caseId)
$key = 'HKCU:\Software\DoomEmacsInstallerSelfTest\' + $caseId
New-Item -ItemType Directory -Path (Join-Path $scratch 'fonts') -Force | Out-Null
$script:fontLoads = 0
$script:fontRemovals = 0
$script:families = @()
function Get-DoomInstalledFontFamilies { return $script:families }
function Add-DoomFontResource([string]$Path) { $script:fontLoads++ }
function Remove-DoomFontResource([string]$Path) { $script:fontRemovals++ }
function Send-DoomFontChange {}
try {
    $fonts = @()
    foreach ($style in @('Regular','Bold')) {
        $file = $style + '.ttf'
        $path = Join-Path $scratch ('fonts\' + $file)
        Set-Content -LiteralPath $path -Value $style -Encoding ASCII
        $fonts += @{ file=$file; family='DoomFontFixture'; sha256=(Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLower() }
    }
    @{ schema=1; fonts=$fonts } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $scratch 'fonts\manifest.json') -Encoding UTF8
    $entries = @(Install-DoomFonts -Root $scratch -RegistryKey $key)
    if ($entries.Count -ne 2 -or $script:fontLoads -ne 2) { throw 'Font registration was not recorded and loaded.' }
    New-ItemProperty -LiteralPath $key -Name UserFont -Value 'C:\user-font.ttf' -PropertyType String | Out-Null
    $script:families = @('DoomFontFixture')
    [void](Install-DoomFonts -Root $scratch -RegistryKey $key)
    if ($script:fontLoads -ne 2) { throw 'Reinstall added duplicate GDI font references.' }
    Write-Host 'PASS: font registration is recorded before use; reinstall preserves ownership without duplicate loads.'
    $modified = Join-Path $scratch 'fonts\Bold.ttf'
    Set-Content -LiteralPath $modified -Value 'user edits' -Encoding ASCII
    $blocked = $false
    try { Remove-DoomFonts -Root $scratch -RegistryKey $key } catch { $blocked=$true }
    if (-not $blocked -or $script:fontRemovals -ne 0) { throw 'Modified font was not protected before cleanup.' }
    Set-Content -LiteralPath $modified -Value 'Bold' -Encoding ASCII
    New-ItemProperty -LiteralPath $key -Name $entries[0].name -Value 'C:\replacement-font.ttf' -PropertyType String -Force | Out-Null
    Remove-DoomFonts -Root $scratch -RegistryKey $key
    $remaining = Get-Item -LiteralPath $key
    if ($remaining.GetValue($entries[0].name) -ne 'C:\replacement-font.ttf' -or $remaining.GetValue('UserFont') -ne 'C:\user-font.ttf') {
        throw 'Cleanup modified an unrelated/replaced font value.'
    }
    if ($null -ne $remaining.GetValue($entries[1].name)) { throw 'Owned font registration was left behind.' }
    if (-not (Test-Path -LiteralPath $modified)) { throw 'Font helper deleted a font file.' }
    Write-Host 'PASS: changed font files block cleanup; replaced/unrelated registry values and font files are preserved.'
    # An installed family without our ownership record must never be adopted.
    Remove-Item -LiteralPath (Join-Path $scratch 'font-state.json')
    $entries = @(Install-DoomFonts -Root $scratch -RegistryKey $key)
    if ($entries.Count) { throw 'Installer adopted a preexisting font family.' }
    Write-Host 'PASS: preexisting font families are kept without taking ownership.'
} finally {
    if (Test-Path -LiteralPath $key) { Remove-Item -LiteralPath $key -Recurse -Force }
    if ((Split-Path -Parent ([IO.Path]::GetFullPath($scratch))) -eq [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')) {
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
}
