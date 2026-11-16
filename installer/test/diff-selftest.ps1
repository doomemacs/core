$ErrorActionPreference = 'Stop'

$testDir = Join-Path $env:TEMP ("doom-installer-diff-test-" + [guid]::NewGuid())
New-Item -ItemType Directory -Path $testDir | Out-Null

try {
    $snapshot = [pscustomobject]@{
        schema      = 1
        label       = 'same'
        takenUtc    = [datetime]::UtcNow.ToString('o')
        totalFiles  = 0
        trees       = [pscustomobject]@{}
        registry    = @()
        envUser     = [pscustomobject]@{}
        envMachine  = [pscustomobject]@{}
    }
    $baselinePath = Join-Path $testDir 'baseline.json'
    $afterPath = Join-Path $testDir 'after.json'
    $reportPath = Join-Path $testDir 'diff.json'

    ConvertTo-Json -InputObject $snapshot -Depth 5 | Set-Content -LiteralPath $baselinePath -Encoding UTF8
    ConvertTo-Json -InputObject $snapshot -Depth 5 | Set-Content -LiteralPath $afterPath -Encoding UTF8

    & (Join-Path $PSScriptRoot 'diff.ps1') -Baseline $baselinePath -After $afterPath -ExpectEmpty -OutFile $reportPath

    $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
    if ($report.totalChanges -ne 0 -or
        $report.baselineLabel -ne 'same' -or
        $report.afterLabel -ne 'same') {
        throw "Unexpected diff report: $($report | ConvertTo-Json -Compress)"
    }

    Write-Host 'PASS: identical snapshots preserve both labels and produce no changes.'

    # Case 2: a file present at baseline and gone afterwards, not claimed by the
    # manifest, must surface as an unclaimed removal. Previously only additions
    # and modifications counted, so deletions the uninstaller would miss went
    # unreported.
    $now = [datetime]::UtcNow.ToString('o')
    $base2 = [pscustomobject]@{
        schema      = 1
        label       = 'with-file'
        takenUtc    = $now
        totalFiles  = 1
        trees       = [pscustomobject]@{ 'C:\root' = @([pscustomobject]@{ path = 'C:\root\gone.txt'; size = 1; mtime = $now }) }
        registry    = @()
        envUser     = [pscustomobject]@{}
        envMachine  = [pscustomobject]@{}
    }
    $after2 = [pscustomobject]@{
        schema      = 1
        label       = 'file-removed'
        takenUtc    = $now
        totalFiles  = 0
        trees       = [pscustomobject]@{ 'C:\root' = @() }
        registry    = @()
        envUser     = [pscustomobject]@{}
        envMachine  = [pscustomobject]@{}
    }
    $baseline2Path = Join-Path $testDir 'baseline2.json'
    $after2Path = Join-Path $testDir 'after2.json'
    $report2Path = Join-Path $testDir 'diff2.json'
    $manifestPath = Join-Path $testDir 'manifest.json'
    ConvertTo-Json -InputObject $base2 -Depth 5 | Set-Content -LiteralPath $baseline2Path -Encoding UTF8
    ConvertTo-Json -InputObject $after2 -Depth 5 | Set-Content -LiteralPath $after2Path -Encoding UTF8
    [pscustomobject]@{
        schema  = 1
        entries = @([pscustomobject]@{ kind = 'dir'; path = 'C:\root\claimed'; state = 'created' })
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

    & (Join-Path $PSScriptRoot 'diff.ps1') -Baseline $baseline2Path -After $after2Path -Manifest $manifestPath -OutFile $report2Path
    if ($LASTEXITCODE -eq 0) { throw 'diff.ps1 exited 0 despite an unclaimed removal' }

    $report2 = Get-Content -LiteralPath $report2Path -Raw | ConvertFrom-Json
    if ($report2.unclaimedCount -ne 1) { throw "expected 1 unclaimed removal, got $($report2.unclaimedCount)" }
    if (@($report2.filesRemoved).Count -ne 1 -or @($report2.filesRemoved)[0].path -ne 'C:\root\gone.txt') {
        throw "filesRemoved not reported as expected: $($report2.filesRemoved | ConvertTo-Json -Compress)"
    }

    Write-Host 'PASS: an unclaimed file removal exits 1 and is reported in filesRemoved.'
} finally {
    Remove-Item -LiteralPath $testDir -Recurse -Force -ErrorAction SilentlyContinue
}
