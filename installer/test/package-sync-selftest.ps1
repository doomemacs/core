[CmdletBinding()]
param([string]$EmacsRoot)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\native-process.ps1')
. (Join-Path $PSScriptRoot '..\package-sync.ps1')
$runtime = [pscustomobject]@{ emacsVersion = '31.1'; systemConfiguration = 'windows'; nativeAbi = '31.1-abc'; executableHash = 'a'; toolchain = 'gcc=a'; installRoot = 'C:\Doom' }
$previous = @{ schema = 1; success = $true; runtime = $runtime }
$plan = Get-DoomPackageSyncPlan $runtime $previous $true $false $false
if ($plan.Rebuild -or $plan.Arguments -contains '--aot') { throw 'Compatible reinstall was not incremental.' }
foreach ($name in @('emacsVersion', 'systemConfiguration', 'nativeAbi', 'executableHash', 'toolchain', 'installRoot')) {
    $changed = $runtime | Select-Object *
    $changed.$name += '-changed'
    $plan = Get-DoomPackageSyncPlan $changed $previous $true $false $false
    if (-not $plan.Rebuild -or $plan.Arguments -notcontains '--rebuild') { throw "Missed invalidation: $name" }
}
$plan = Get-DoomPackageSyncPlan $runtime $null $true $false $false
if (-not $plan.Rebuild) { throw 'Unverified legacy build was trusted.' }
$plan = Get-DoomPackageSyncPlan $runtime @{ schema = 1; success = $false; runtime = $runtime } $true $false $false
if (-not $plan.Rebuild) { throw 'Failed previous sync was trusted.' }
$plan = Get-DoomPackageSyncPlan $runtime $null $false $true $false
if ($plan.Rebuild -or $plan.Arguments -notcontains '--aot') { throw 'Fresh AOT setup has the wrong plan.' }
$plan = Get-DoomPackageSyncPlan $runtime $previous $true $true $true
if ($plan.Arguments -notcontains '--rebuild' -or $plan.Arguments -notcontains '--aot') { throw 'Explicit rebuild/AOT request was ignored.' }
Write-Host 'PASS: compatible reuse, runtime/ABI/toolchain/path invalidation, legacy and failed-sync recovery, optional AOT.'
$esc = [char]27
$sample = "$esc[32mNatively compiling$esc[0m$esc[1A$esc[K"
if ((ConvertTo-DoomPlainLog $sample) -cne 'Natively compiling') { throw 'ANSI color/cursor controls leaked.' }
if ((ConvertTo-DoomPlainLog "$esc]0;title$([char]7)hello") -cne 'hello') { throw 'OSC title leaked.' }
Write-Host 'PASS: installer output removes ANSI colors, cursor controls and OSC titles.'
$scratch = Join-Path $env:TEMP ('doom-sync-stream-' + [guid]::NewGuid().ToString('N'))
try {
    foreach ($relative in @('deps\git\usr\bin', 'bridge')) {
        New-Item -ItemType Directory -Path (Join-Path $scratch $relative) -Force | Out-Null
    }
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\files\bridge\environment.ps1') -Destination (Join-Path $scratch 'bridge\environment.ps1')
    Add-Type -OutputAssembly (Join-Path $scratch 'deps\git\usr\bin\sh.exe') -OutputType ConsoleApplication -TypeDefinition @'
using System;
public class DoomLogFixture {
 public static int Main() {
  if (Console.In.Read() != -1) return 99;
  for (int i=0; i<2000; i++) Console.Error.WriteLine("\u001b[31mstderr message padding padding padding padding\u001b[0m");
  Console.Write("\u001b[Kcompiling 2\u001b[1A\r\u001b[Kcompiling 1\u001b[1A\n");
  return 7;
 }
}
'@
    $records = @(Invoke-DoomPackageSync -Root $scratch -Config $scratch -Arguments @('sync') 6>&1)
    if ($records[-1] -ne 7) { throw 'Streaming runner lost the child exit code.' }
    $log = ($records[0..($records.Count - 2)] | Out-String)
    if ($log.Contains([string][char]27) -or $log -notmatch 'compiling 1' -or $log -notmatch 'stderr message') {
        throw 'Streaming runner lost output or leaked terminal controls.'
    }
    Write-Host 'PASS: real child output streams without ANSI, drains both pipes, receives EOF and preserves failure exit code.'
} finally {
    if ((Split-Path -Parent ([IO.Path]::GetFullPath($scratch))) -eq [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')) {
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
}
if ($EmacsRoot) {
    $signature = Get-DoomRuntimeSignature -Root $EmacsRoot
    if (-not $signature.nativeAbi -or -not $signature.executableHash) { throw 'Real Emacs probe is incomplete.' }
    Write-Host "PASS: real bundled Emacs reports $($signature.emacsVersion), native ABI $($signature.nativeAbi)."
}
