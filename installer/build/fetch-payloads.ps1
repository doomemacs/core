<#
.SYNOPSIS
    Fetch and verify the bundled payloads for the Doom Emacs Windows installer.

.DESCRIPTION
    Downloads every payload named in payloads.lock.json into installer/cache/,
    resuming partial transfers, and verifies each against its pinned SHA256.

    Designed for unattended use: idempotent, resumable, and loud on failure.
    A second run with everything already cached costs zero bytes and a few seconds
    of hashing.

.PARAMETER Update
    Pin hashes for payloads whose lock entry has "sha256": null. Where the
    publisher supplies a digest out-of-band, it is cross-checked first so pinning
    is not blind trust-on-first-use.

.PARAMETER Force
    Re-download even if a cached copy already verifies.

.EXAMPLE
    .\fetch-payloads.ps1 -Update     # first run: download and pin
    .\fetch-payloads.ps1             # later runs: verify against pins
#>
[CmdletBinding()]
param(
    [switch]$Update,
    [switch]$Force,
    [string]$LockFile,
    [string]$CacheDir
)

$ErrorActionPreference = 'Stop'

# $PSScriptRoot is not reliably populated while param() defaults are evaluated
# under `powershell -File`, so resolve the script directory in the body instead.
$scriptDir = $PSScriptRoot
if (-not $scriptDir) { $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path }
if (-not $scriptDir) { throw 'Could not determine script directory.' }

if (-not $LockFile) { $LockFile = Join-Path $scriptDir 'payloads.lock.json' }
if (-not $CacheDir) { $CacheDir = Join-Path $scriptDir '..\cache' }
$script:failed = @()
$script:pinned = @()

function Write-Stage([string]$msg) {
    Write-Host ''
    Write-Host "==> $msg" -ForegroundColor Cyan
}
function Write-Ok([string]$msg)   { Write-Host "    OK    $msg" -ForegroundColor Green }
function Write-Info([string]$msg) { Write-Host "          $msg" -ForegroundColor DarkGray }
function Write-Bad([string]$msg)  { Write-Host "    FAIL  $msg" -ForegroundColor Red }

function Format-Size([long]$bytes) {
    if ($bytes -ge 1GB) { return ('{0:N1} GB' -f ($bytes / 1GB)) }
    if ($bytes -ge 1MB) { return ('{0:N1} MB' -f ($bytes / 1MB)) }
    if ($bytes -ge 1KB) { return ('{0:N1} KB' -f ($bytes / 1KB)) }
    return "$bytes B"
}

# curl.exe ships in System32 on Windows 10+ and, unlike Invoke-WebRequest,
# resumes a partial transfer with -C -. On a 264 MB payload that matters.
function Get-CurlPath {
    $c = Get-Command curl.exe -ErrorAction SilentlyContinue
    if (-not $c) { throw 'curl.exe not found. Expected at C:\Windows\System32\curl.exe on Windows 10+.' }
    return $c.Source
}

function Invoke-Download {
    param([string]$Url, [string]$OutFile, [string]$Curl)

    $dir = Split-Path -Parent $OutFile
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }

    # -C - resumes; --retry rides out transient FTP/CDN hiccups during long unattended runs.
    $curlArgs = @(
        '--location', '--fail', '--show-error',
        '--continue-at', '-',
        '--retry', '5', '--retry-delay', '3', '--retry-connrefused',
        '--connect-timeout', '30',
        '--output', $OutFile,
        $Url
    )
    & $Curl @curlArgs
    if ($LASTEXITCODE -ne 0) {
        # curl 33 = server refused a range request; restart from scratch once.
        if ($LASTEXITCODE -eq 33 -and (Test-Path $OutFile)) {
            Write-Info 'Server refused resume; restarting download from byte 0'
            Remove-Item $OutFile -Force
            & $Curl @curlArgs
            if ($LASTEXITCODE -ne 0) { throw "curl failed with exit code $LASTEXITCODE" }
        } else {
            throw "curl failed with exit code $LASTEXITCODE"
        }
    }
}

function Get-PublishedSha256 {
    param([string]$Url, [string]$Kind, [string]$Curl)

    if (-not $Url -or $Kind -ne 'sha256-file') { return $null }
    try {
        $tmp = [System.IO.Path]::GetTempFileName()
        & $Curl '--location' '--fail' '--silent' '--output' $tmp $Url
        if ($LASTEXITCODE -ne 0) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue; return $null }
        $text = (Get-Content $tmp -Raw).Trim()
        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
        # Format is "<hash>  <filename>" or a bare hash.
        if ($text -match '([0-9a-fA-F]{64})') { return $Matches[1].ToLower() }
        return $null
    } catch {
        return $null
    }
}

# ---------------------------------------------------------------- main

Write-Stage 'Doom Emacs installer - payload fetch'

if (-not (Test-Path $LockFile)) { throw "Lockfile not found: $LockFile" }
$curl = Get-CurlPath
$lock = Get-Content $LockFile -Raw | ConvertFrom-Json

if (-not (Test-Path $CacheDir)) { New-Item -ItemType Directory -Force -Path $CacheDir | Out-Null }
$CacheDir = (Resolve-Path $CacheDir).Path
Write-Info "Lockfile : $LockFile"
Write-Info "Cache    : $CacheDir"
Write-Info "Mode     : $(if ($Update) { 'UPDATE (will pin unpinned hashes)' } else { 'VERIFY' })"

$totalPlanned = 0
foreach ($p in $lock.payloads) { $totalPlanned += [long]$p.expectedBytes }
Write-Info "Payloads : $($lock.payloads.Count), roughly $(Format-Size $totalPlanned) total"

foreach ($p in $lock.payloads) {
    Write-Stage "$($p.id) $($p.version)  ($(Format-Size ([long]$p.expectedBytes)))"
    Write-Info $p.description

    $target = Join-Path $CacheDir $p.filename

    try {
        $needsDownload = $true
        if ((Test-Path $target) -and -not $Force) {
            $existing = (Get-FileHash $target -Algorithm SHA256).Hash.ToLower()
            if ($p.sha256 -and $existing -eq $p.sha256.ToLower()) {
                Write-Ok "cached and verified  ($(Format-Size (Get-Item $target).Length))"
                continue
            } elseif ($p.sha256) {
                Write-Info 'Cached copy does not match the pinned hash; discarding and refetching'
                Remove-Item $target -Force
            } else {
                # Unpinned but present: likely a completed download from a prior -Update run.
                Write-Info 'Cached copy present but no pinned hash yet'
                $needsDownload = $false
            }
        }

        if ($needsDownload) {
            Write-Info "Downloading $($p.url)"
            Invoke-Download -Url $p.url -OutFile $target -Curl $curl
        }

        $size = (Get-Item $target).Length
        $hash = (Get-FileHash $target -Algorithm SHA256).Hash.ToLower()
        Write-Info "size   $(Format-Size $size)  ($size bytes)"
        Write-Info "sha256 $hash"

        # Size sanity check. expectedBytes is approximate for some payloads, so this
        # warns rather than fails; the hash is the real gate.
        $expected = [long]$p.expectedBytes
        if ($expected -gt 0) {
            $drift = [math]::Abs($size - $expected) / [double]$expected
            if ($drift -gt 0.05) {
                Write-Info "NOTE: size differs from lockfile expectation by $('{0:P0}' -f $drift)"
            }
        }

        if ($p.sha256) {
            if ($hash -eq $p.sha256.ToLower()) {
                Write-Ok 'hash matches pin'
            } else {
                Write-Bad "HASH MISMATCH`n          expected $($p.sha256)`n          actual   $hash"
                $script:failed += $p.id
                continue
            }
        } elseif ($Update) {
            $published = Get-PublishedSha256 -Url $p.publishedDigestUrl -Kind $p.publishedDigestKind -Curl $curl
            if ($published) {
                if ($published -eq $hash) {
                    Write-Ok "cross-checked against publisher digest"
                } else {
                    Write-Bad "PUBLISHER DIGEST MISMATCH - refusing to pin`n          published $published`n          actual    $hash"
                    $script:failed += $p.id
                    continue
                }
            } elseif ($p.publishedDigestKind -eq 'gpg') {
                Write-Info 'Publisher supplies a GPG signature, not a digest. Signature authentication is not implemented; pinning uses trust-on-first-use.'
            } else {
                Write-Info 'No publisher digest available. Pinning trust-on-first-use.'
            }
            $p.sha256 = $hash
            $script:pinned += $p.id
            Write-Ok 'pinned'
        } else {
            Write-Bad 'No pinned hash in lockfile. Re-run with -Update to pin it.'
            $script:failed += $p.id
            continue
        }
    } catch {
        Write-Bad "$($p.id): $($_.Exception.Message)"
        $script:failed += $p.id
    }
}

if ($script:pinned.Count -gt 0) {
    Write-Stage 'Writing pinned hashes back to lockfile'
    $lock | ConvertTo-Json -Depth 12 | Set-Content -Path $LockFile -Encoding utf8
    Write-Ok "pinned: $($script:pinned -join ', ')"
}

Write-Stage 'Summary'
foreach ($p in $lock.payloads) {
    $t = Join-Path $CacheDir $p.filename
    if (Test-Path $t) {
        Write-Host ("    {0,-10} {1,10}  {2}" -f $p.id, (Format-Size (Get-Item $t).Length), $p.filename)
    } else {
        Write-Host ("    {0,-10} {1,10}  {2}" -f $p.id, 'MISSING', $p.filename) -ForegroundColor Red
    }
}

if ($script:failed.Count -gt 0) {
    Write-Bad "FAILED: $($script:failed -join ', ')"
    exit 1
}

Write-Host ''
Write-Ok 'All payloads present and verified.'
exit 0
