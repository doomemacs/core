<#
.SYNOPSIS
    Capture a system snapshot for install-footprint diffing.

.DESCRIPTION
    Records the filesystem, registry and environment state that a per-user install
    could plausibly touch, into a single JSON file.

    This exists to catch what the installer's own manifest (Layer A) forgot. If a
    diff turns up a path the manifest never claimed, that is a leak and a bug.

    Meant to run inside Windows Sandbox, where the baseline is byte-identical on
    every boot. Run on the live host it still works, but OS churn will bury the
    signal - treat host runs as smoke tests only.

.PARAMETER Label
    Name for this snapshot, e.g. baseline / post-install / post-uninstall.

.PARAMETER OutFile
    Where to write the JSON. Defaults to .\results\snapshot-<label>.json

.PARAMETER Hash
    Also SHA256 every file. Much slower. Needed for A2 (determinism) but not for
    A3 (reversibility), which only asks whether a path came back.

.EXAMPLE
    .\snapshot.ps1 -Label baseline
    .\snapshot.ps1 -Label post-install -Hash
#>
[CmdletBinding()]
param(
    [string]$Label,
    [string]$OutFile,
    [switch]$Hash,
    [string[]]$ExtraRoots = @(),
    [switch]$SelfTest
)

$ErrorActionPreference = 'Stop'
$sw = [System.Diagnostics.Stopwatch]::StartNew()

# See fetch-payloads.ps1: $PSScriptRoot is unreliable under `powershell -File`.
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }

if (-not $OutFile) {
    $resultsDir = Join-Path $scriptDir 'results'
    if (-not (Test-Path $resultsDir)) { New-Item -ItemType Directory -Force -Path $resultsDir | Out-Null }
    $OutFile = Join-Path $resultsDir "snapshot-$Label.json"
}

function Write-Stage([string]$m) { Write-Host "==> $m" -ForegroundColor Cyan }
function Write-Info([string]$m)  { Write-Host "    $m" -ForegroundColor DarkGray }

# Paths that churn on their own and would bury the signal. Kept here rather than
# in diff.ps1 so the snapshot stays small; diff.ps1 has its own allowlist for
# things that must be captured but tolerated.
$excludePatterns = @(
    '\\Microsoft\\Windows\\(INetCache|WebCache|Explorer|Caches)\\',
    '\\Microsoft\\Windows\\Recent\\',
    '\\Packages\\.*\\(AC|LocalCache|TempState)\\',
    '\\CrashDumps\\',
    '\\Temp\\',
    '\\WindowsApps\\',
    '\\Microsoft\\Edge\\User Data\\',
    '\\NVIDIA Corporation\\',
    '\\D3DSCache\\',
    '\\ConnectedDevicesPlatform\\',
    '\\Microsoft\\Windows\\PowerShell\\',
    # Editor and developer-tool state directories. These churn constantly on a
    # development machine and have nothing to do with the install footprint.
    '\\AppData\\(Local|Roaming)\\(Code|JetBrains|nvim|\.vscode)\\',
    # Editor/tool dot-directories under AppData only. A generic dot-dir pattern
    # also matched Doom's own doom\.local\cache, hiding install footprint from
    # the diff.
    '\\AppData\\(Local|Roaming)\\\.[A-Za-z0-9_-]+\\(logs|sessions|projects)\\',
    '\\AppData\\Local\\Temp\\'
)
$excludeRegex = [regex]::new(($excludePatterns -join '|'), 'IgnoreCase')

if ($SelfTest) {
    # Doom's own cache must stay visible; dev-tool noise must stay hidden.
    $mustKeep = @(
        (Join-Path $env:LOCALAPPDATA 'Programs\DoomEmacs\doom\.local\cache\straight\build-31.1\x.elc'),
        (Join-Path $env:USERPROFILE '.cache\doom-installer-selftest')
    )
    foreach ($mp in $mustKeep) {
        if ($excludeRegex.IsMatch($mp)) { throw "exclusion hides install footprint: $mp" }
    }
    $mustDrop = @(
        (Join-Path $env:LOCALAPPDATA '.toolbox\logs\a.log'),
        (Join-Path $env:APPDATA '.editor\sessions\b.xml')
    )
    foreach ($mp in $mustDrop) {
        if (-not $excludeRegex.IsMatch($mp)) { throw "exclusion no longer hides dev-tool noise: $mp" }
    }
    Write-Host 'PASS: exclusions hide dev-tool noise but keep Doom .local\cache visible.'
    exit 0
}

if (-not $Label) { throw '-Label is required (any name, e.g. baseline).' }

function Get-FileTree {
    param([string]$Root, [int]$MaxFiles = 400000)

    $files = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $Root)) { return ,$files }

    # Hand-rolled stack walk rather than SearchOption::AllDirectories. Two reasons:
    # System.IO.EnumerationOptions is .NET Core only (absent under PowerShell 5.1's
    # .NET Framework), and AllDirectories aborts the *entire* enumeration on the
    # first unreadable directory. Per-directory try/catch degrades gracefully instead.
    $stack = New-Object System.Collections.Generic.Stack[string]
    $stack.Push($Root)
    $truncated = $false

    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()

        try {
            foreach ($sub in [System.IO.Directory]::EnumerateDirectories($dir)) {
                if ($excludeRegex.IsMatch($sub + '\')) { continue }
                # Don't follow junctions/symlinks - Windows seeds the profile with
                # legacy ones ("My Music" -> Music) that would double-count or loop.
                try {
                    $attrs = [System.IO.File]::GetAttributes($sub)
                    if ($attrs -band [System.IO.FileAttributes]::ReparsePoint) { continue }
                } catch { continue }
                $stack.Push($sub)
            }
        } catch { }

        try {
            foreach ($p in [System.IO.Directory]::EnumerateFiles($dir)) {
                if ($excludeRegex.IsMatch($p)) { continue }
                if ($files.Count -ge $MaxFiles) { $truncated = $true; break }
                try {
                    $fi = New-Object System.IO.FileInfo($p)
                    $rec = [ordered]@{
                        path  = $p
                        size  = $fi.Length
                        mtime = $fi.LastWriteTimeUtc.ToString('o')
                    }
                    if ($Hash -and $fi.Length -lt 100MB) {
                        try { $rec.sha256 = (Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower() } catch { $rec.sha256 = $null }
                    }
                    $files.Add([pscustomobject]$rec)
                } catch { }
            }
        } catch { }

        if ($truncated) { break }
    }

    if ($truncated) { Write-Info "TRUNCATED at $MaxFiles files under $Root" }
    return ,$files
}

function Get-RegKeyValues {
    param([string]$Path, [switch]$SubkeyNamesOnly, [string]$SubkeyFilter)

    $out = [ordered]@{ path = $Path; exists = $false; values = @{}; subkeys = @() }
    if (-not (Test-Path $Path)) { return [pscustomobject]$out }
    $out.exists = $true

    try {
        if (-not $SubkeyNamesOnly) {
            $item = Get-ItemProperty -Path $Path -ErrorAction SilentlyContinue
            if ($item) {
                $h = @{}
                foreach ($prop in $item.PSObject.Properties) {
                    if ($prop.Name -like 'PS*') { continue }
                    $h[$prop.Name] = [string]$prop.Value
                }
                $out.values = $h
            }
        }
        $subs = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue
        if ($SubkeyFilter) { $subs = $subs | Where-Object { $_.PSChildName -like $SubkeyFilter } }
        $out.subkeys = @($subs | ForEach-Object { $_.PSChildName } | Sort-Object)
    } catch { }

    return [pscustomobject]$out
}

# ------------------------------------------------------------------ capture

Write-Stage "Snapshot: $Label"

$roots = @(
    $env:LOCALAPPDATA,
    $env:APPDATA,
    $env:ProgramData,
    $env:ProgramFiles,
    ${env:ProgramFiles(x86)},
    (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu'),
    (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu')
) + $ExtraRoots | Where-Object { $_ } | Select-Object -Unique

$trees = [ordered]@{}
foreach ($r in $roots) {
    $t0 = $sw.Elapsed.TotalSeconds
    $tree = Get-FileTree -Root $r
    $trees[$r] = $tree
    Write-Info ("{0,-55} {1,7} files  {2,6:N1}s" -f $r, $tree.Count, ($sw.Elapsed.TotalSeconds - $t0))
}

# %USERPROFILE% top-level only - recursing it would re-walk AppData, already covered.
$profileTop = @()
if (Test-Path $env:USERPROFILE) {
    $profileTop = @(Get-ChildItem -LiteralPath $env:USERPROFILE -Force -ErrorAction SilentlyContinue |
        ForEach-Object { [pscustomobject]@{ name = $_.Name; isDir = $_.PSIsContainer } } | Sort-Object name)
}
Write-Info "USERPROFILE top-level: $($profileTop.Count) entries"

Write-Stage 'Registry'
$registry = @(
    (Get-RegKeyValues -Path 'HKCU:\Environment'),
    (Get-RegKeyValues -Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall' -SubkeyNamesOnly),
    (Get-RegKeyValues -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall' -SubkeyNamesOnly),
    (Get-RegKeyValues -Path 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall' -SubkeyNamesOnly),
    (Get-RegKeyValues -Path 'HKCU:\Software\Classes' -SubkeyNamesOnly -SubkeyFilter '.*'),
    (Get-RegKeyValues -Path 'HKCU:\Software\GNU'),
    (Get-RegKeyValues -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths' -SubkeyNamesOnly)
)
foreach ($r in $registry) { Write-Info ("{0,-72} {1}" -f $r.path, $(if ($r.exists) { "$($r.subkeys.Count) subkeys, $($r.values.Count) values" } else { 'absent' })) }

Write-Stage 'Environment'
$envUser    = [Environment]::GetEnvironmentVariables('User')
$envMachine = [Environment]::GetEnvironmentVariables('Machine')
Write-Info "user vars: $($envUser.Count)   machine vars: $($envMachine.Count)"

$totalFiles = 0
foreach ($k in $trees.Keys) { $totalFiles += $trees[$k].Count }

$snapshot = [ordered]@{
    schema      = 1
    label       = $Label
    takenUtc    = (Get-Date).ToUniversalTime().ToString('o')
    machine     = $env:COMPUTERNAME
    user        = $env:USERNAME
    hashed      = [bool]$Hash
    elapsedSec  = [math]::Round($sw.Elapsed.TotalSeconds, 1)
    totalFiles  = $totalFiles
    roots       = @($roots)
    trees       = $trees
    profileTop  = $profileTop
    registry    = $registry
    envUser     = $envUser
    envMachine  = $envMachine
}

$dir = Split-Path -Parent $OutFile
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$snapshot | ConvertTo-Json -Depth 8 -Compress | Set-Content -Path $OutFile -Encoding utf8

$sw.Stop()
Write-Stage 'Done'
Write-Info "files captured : $totalFiles"
Write-Info "elapsed        : $([math]::Round($sw.Elapsed.TotalSeconds,1))s"
Write-Info "written        : $OutFile  ($('{0:N1} MB' -f ((Get-Item $OutFile).Length / 1MB)))"
