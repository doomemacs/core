<#
.SYNOPSIS
    Compare two snapshots and report the install footprint.

.DESCRIPTION
    Diffs a baseline snapshot against a later one and reports every file, registry
    value and environment variable that appeared, vanished or changed, after
    subtracting known OS noise.

    Given -Manifest (the installer's own Layer A record), every change is further
    classified as CLAIMED or UNCLAIMED. An UNCLAIMED change is the interesting
    case: the installer touched something it never recorded, so the uninstaller
    will not know to remove it. That is a leak.

.PARAMETER ExpectEmpty
    Assert that no non-noise differences remain. This is assertion A3
    (reversibility): baseline vs post-uninstall must come back clean. Exits 1 on
    any remaining difference.

.EXAMPLE
    .\diff.ps1 -Baseline results\snapshot-baseline.json -After results\snapshot-post-install.json -Manifest results\install-manifest.json
    .\diff.ps1 -Baseline results\snapshot-baseline.json -After results\snapshot-post-uninstall.json -ExpectEmpty
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$Baseline,
    [Parameter(Mandatory = $true)][string]$After,
    [string]$Manifest,
    [string]$AllowlistFile,
    [string]$OutFile,
    [switch]$ExpectEmpty,
    [int]$MaxListed = 60
)

$ErrorActionPreference = 'Stop'

$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $AllowlistFile) { $AllowlistFile = Join-Path $scriptDir 'noise-allowlist.json' }

function Write-Stage([string]$m) { Write-Host ''; Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Ok([string]$m)    { Write-Host "    OK    $m" -ForegroundColor Green }
function Write-Bad([string]$m)   { Write-Host "    LEAK  $m" -ForegroundColor Red }
function Write-Info([string]$m)  { Write-Host "          $m" -ForegroundColor DarkGray }

function Read-Json([string]$p) {
    if (-not (Test-Path $p)) { throw "Snapshot not found: $p" }
    return (Get-Content $p -Raw | ConvertFrom-Json)
}

$base  = Read-Json $Baseline
$afterSnap = Read-Json $After

Write-Stage 'Inputs'
Write-Info "baseline : $($base.label)  ($($base.totalFiles) files, taken $($base.takenUtc))"
Write-Info "after    : $($afterSnap.label)  ($($afterSnap.totalFiles) files, taken $($afterSnap.takenUtc))"

# ------------------------------------------------------------ noise allowlist

$noiseRegex = $null
if (Test-Path $AllowlistFile) {
    $al = Get-Content $AllowlistFile -Raw | ConvertFrom-Json
    $pats = @($al.filePatterns | ForEach-Object { $_.pattern })
    if ($pats.Count -gt 0) { $noiseRegex = [regex]::new(($pats -join '|'), 'IgnoreCase') }
    Write-Info "allowlist: $($pats.Count) file patterns from $(Split-Path -Leaf $AllowlistFile)"
} else {
    Write-Info "allowlist: none found at $AllowlistFile"
}
function Test-Noise([string]$path) {
    if (-not $noiseRegex) { return $false }
    return $noiseRegex.IsMatch($path)
}

# --------------------------------------------------------------- Layer A load

$claimedRegex = $null
if ($Manifest) {
    if (-not (Test-Path $Manifest)) { throw "Manifest not found: $Manifest" }
    $mf = Get-Content $Manifest -Raw | ConvertFrom-Json
    $claims = @()
    foreach ($e in $mf.entries) {
        if ($e.kind -eq 'file' -or $e.kind -eq 'dir') { $claims += [regex]::Escape($e.path) }
    }
    if ($claims.Count -gt 0) { $claimedRegex = [regex]::new(($claims -join '|'), 'IgnoreCase') }
    Write-Info "manifest : $($claims.Count) claimed paths"
}
function Test-Claimed([string]$path) {
    if (-not $claimedRegex) { return $false }
    return $claimedRegex.IsMatch($path)
}

# ------------------------------------------------------------------ file diff

function Get-FileMap($snap) {
    $map = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::OrdinalIgnoreCase)
    foreach ($root in $snap.trees.PSObject.Properties) {
        foreach ($f in $root.Value) {
            if (-not $map.ContainsKey($f.path)) { $map[$f.path] = $f }
        }
    }
    return $map
}

Write-Stage 'Diffing filesystem'
$bMap = Get-FileMap $base
$aMap = Get-FileMap $afterSnap
Write-Info "baseline map: $($bMap.Count)   after map: $($aMap.Count)"

$added = New-Object System.Collections.Generic.List[object]
$removed = New-Object System.Collections.Generic.List[object]
$modified = New-Object System.Collections.Generic.List[object]
$noiseCount = 0

foreach ($k in $aMap.Keys) {
    if ($bMap.ContainsKey($k)) {
        $b = $bMap[$k]; $a = $aMap[$k]
        $changed = ($b.size -ne $a.size)
        if (-not $changed -and $b.PSObject.Properties['sha256'] -and $a.PSObject.Properties['sha256'] -and $b.sha256 -and $a.sha256) {
            $changed = ($b.sha256 -ne $a.sha256)
        }
        if ($changed) {
            if (Test-Noise $k) { $noiseCount++; continue }
            $modified.Add([pscustomobject]@{ path = $k; fromSize = $b.size; toSize = $a.size; claimed = (Test-Claimed $k) })
        }
    } else {
        if (Test-Noise $k) { $noiseCount++; continue }
        $added.Add([pscustomobject]@{ path = $k; size = $aMap[$k].size; claimed = (Test-Claimed $k) })
    }
}
foreach ($k in $bMap.Keys) {
    if (-not $aMap.ContainsKey($k)) {
        if (Test-Noise $k) { $noiseCount++; continue }
        $removed.Add([pscustomobject]@{ path = $k; size = $bMap[$k].size; claimed = (Test-Claimed $k) })
    }
}

# -------------------------------------------------------------- registry diff

Write-Stage 'Diffing registry'
$regDiffs = New-Object System.Collections.Generic.List[object]

function Get-RegMap($snap) {
    $m = @{}
    foreach ($r in $snap.registry) { $m[$r.path] = $r }
    return $m
}
$bReg = Get-RegMap $base
$aReg = Get-RegMap $afterSnap

foreach ($path in $aReg.Keys) {
    $a = $aReg[$path]
    $b = $bReg[$path]
    if (-not $b) { $regDiffs.Add([pscustomobject]@{ path = $path; change = 'key-appeared'; detail = '' }); continue }

    $bSubs = @($b.subkeys); $aSubs = @($a.subkeys)
    foreach ($s in $aSubs) { if ($bSubs -notcontains $s) { $regDiffs.Add([pscustomobject]@{ path = $path; change = 'subkey-added'; detail = $s }) } }
    foreach ($s in $bSubs) { if ($aSubs -notcontains $s) { $regDiffs.Add([pscustomobject]@{ path = $path; change = 'subkey-removed'; detail = $s }) } }

    if ($a.values -and $b.values) {
        $aNames = @($a.values.PSObject.Properties.Name)
        $bNames = @($b.values.PSObject.Properties.Name)
        foreach ($n in $aNames) {
            if ($bNames -notcontains $n) {
                $regDiffs.Add([pscustomobject]@{ path = $path; change = 'value-added'; detail = "$n = $($a.values.$n)" })
            } elseif ([string]$a.values.$n -ne [string]$b.values.$n) {
                $regDiffs.Add([pscustomobject]@{ path = $path; change = 'value-changed'; detail = "$n : '$($b.values.$n)' -> '$($a.values.$n)'" })
            }
        }
        foreach ($n in $bNames) {
            if ($aNames -notcontains $n) { $regDiffs.Add([pscustomobject]@{ path = $path; change = 'value-removed'; detail = $n }) }
        }
    }
}

# ------------------------------------------------------------------- env diff

Write-Stage 'Diffing environment'
$envDiffs = New-Object System.Collections.Generic.List[object]
foreach ($scope in @('envUser', 'envMachine')) {
    $bv = $base.$scope; $av = $afterSnap.$scope
    if (-not $bv -or -not $av) { continue }
    $bn = @($bv.PSObject.Properties.Name); $an = @($av.PSObject.Properties.Name)
    foreach ($n in $an) {
        if ($n -match '^(TEMP|TMP|PSModulePath)$') { continue }
        if ($bn -notcontains $n) {
            $envDiffs.Add([pscustomobject]@{ scope = $scope; name = $n; change = 'added'; detail = [string]$av.$n })
        } elseif ([string]$av.$n -ne [string]$bv.$n) {
            $envDiffs.Add([pscustomobject]@{ scope = $scope; name = $n; change = 'changed'; detail = "'$($bv.$n)' -> '$($av.$n)'" })
        }
    }
    foreach ($n in $bn) {
        if ($n -match '^(TEMP|TMP|PSModulePath)$') { continue }
        if ($an -notcontains $n) { $envDiffs.Add([pscustomobject]@{ scope = $scope; name = $n; change = 'removed'; detail = '' }) }
    }
}

# ------------------------------------------------------------------- report

function Show-List($items, [string]$title, [string]$color) {
    if ($items.Count -eq 0) { return }
    Write-Host ''
    Write-Host "  $title ($($items.Count))" -ForegroundColor $color
    $n = 0
    foreach ($i in $items) {
        if ($n -ge $MaxListed) { Write-Host "      ... and $($items.Count - $MaxListed) more" -ForegroundColor DarkGray; break }
        $tag = ''
        if ($i.PSObject.Properties['claimed']) { if ($i.claimed) { $tag = '[claimed]   ' } else { $tag = '[UNCLAIMED] ' } }
        Write-Host "      $tag$($i.path)"
        $n++
    }
}

Write-Stage "Footprint: $($base.label) -> $($afterSnap.label)"
Write-Info "noise suppressed: $noiseCount file changes"

Show-List $added    'Files added'    'Yellow'
Show-List $removed  'Files removed'  'Yellow'
Show-List $modified 'Files modified' 'Yellow'

if ($regDiffs.Count -gt 0) {
    Write-Host ''
    Write-Host "  Registry changes ($($regDiffs.Count))" -ForegroundColor Yellow
    foreach ($d in $regDiffs | Select-Object -First $MaxListed) {
        Write-Host "      $($d.change.PadRight(16)) $($d.path)  $($d.detail)"
    }
}
if ($envDiffs.Count -gt 0) {
    Write-Host ''
    Write-Host "  Environment changes ($($envDiffs.Count))" -ForegroundColor Yellow
    foreach ($d in $envDiffs) {
        Write-Host "      $($d.scope) $($d.name) $($d.change)  $($d.detail)"
    }
}

$unclaimed = @()
if ($Manifest) {
    $unclaimed = @($added | Where-Object { -not $_.claimed }) + @($modified | Where-Object { -not $_.claimed }) + @($removed | Where-Object { -not $_.claimed })
}

$totalChanges = $added.Count + $removed.Count + $modified.Count + $regDiffs.Count + $envDiffs.Count

$report = [ordered]@{
    schema       = 1
    baselineFile = $Baseline
    afterFile    = $After
    baselineLabel = $base.label
    afterLabel   = $afterSnap.label
    noiseSuppressed = $noiseCount
    totalChanges = $totalChanges
    filesAdded   = $added
    filesRemoved = $removed
    filesModified = $modified
    registry     = $regDiffs
    environment  = $envDiffs
    unclaimedCount = $unclaimed.Count
}
if (-not $OutFile) {
    $OutFile = Join-Path (Split-Path -Parent $After) "diff-$($base.label)-to-$($afterSnap.label).json"
}
$report | ConvertTo-Json -Depth 8 -Compress | Set-Content -Path $OutFile -Encoding utf8

Write-Stage 'Verdict'
Write-Info "total changes : $totalChanges"
Write-Info "report        : $OutFile"

$exit = 0

if ($Manifest) {
    if ($unclaimed.Count -eq 0) {
        Write-Ok 'every change is claimed by the install manifest'
    } else {
        Write-Bad "$($unclaimed.Count) change(s) NOT claimed by the manifest - the uninstaller will not know to remove these:"
        foreach ($u in $unclaimed | Select-Object -First $MaxListed) { Write-Host "          $($u.path)" -ForegroundColor Red }
        $exit = 1
    }
}

if ($ExpectEmpty) {
    if ($totalChanges -eq 0) {
        Write-Ok 'A3 PASS - system returned to baseline'
    } else {
        Write-Bad "A3 FAIL - $totalChanges difference(s) remain after uninstall"
        $exit = 1
    }
}

exit $exit
