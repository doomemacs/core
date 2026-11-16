[CmdletBinding()]
param([string]$Distribution)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\wsl-integration.ps1')
$caseId = [guid]::NewGuid().ToString('N')
$scratch = Join-Path $env:TEMP ('doom-wsl-test-' + $caseId)
New-Item -ItemType Directory -Path $scratch | Out-Null
try {
    # Verify argv quoting against an actual Windows executable, including empty
    # strings, quotes, Unicode, trailing slashes and shell metacharacters.
    $capture = Join-Path $scratch 'capture.exe'
    Add-Type -OutputAssembly $capture -OutputType ConsoleApplication -TypeDefinition @'
using System;
using System.IO;
using System.Text;
public class DoomArgvCapture {
 public static void Main(string[] args) {
  for(int i=0;i<args.Length;i++) args[i]=Convert.ToBase64String(Encoding.UTF8.GetBytes(args[i]));
  File.WriteAllLines(Environment.GetEnvironmentVariable("DOOM_ARGV_TEST"),args);
 }
}
'@
    $log = Join-Path $scratch 'argv.txt'
    $expected = @('', 'a b', 'quote"value', 'C:\with space\', "apostrophe'value", [string][char]0x0444, '$(touch nope)&x', 'a\"b')
    $result = Invoke-DoomNativeProcess -File $capture -Arguments $expected -Environment @{ DOOM_ARGV_TEST = $log }
    if ($result.ExitCode) { throw 'Native argv fixture failed.' }
    $actual = @(Get-Content -LiteralPath $log | ForEach-Object { [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($_)) })
    if ($actual.Count -ne $expected.Count) { throw 'Native argument count changed.' }
    for ($i = 0; $i -lt $expected.Count; $i++) { if ($actual[$i] -cne $expected[$i]) { throw "Native argv mismatch at $i" } }
    Write-Host 'PASS: Windows native arguments are preserved without shell evaluation.'

    if (-not $Distribution) {
        Write-Host 'SKIP: real WSL tests require -Distribution; no user distribution is modified implicitly.'
        return
    }
    $files = Get-DoomWslBridgeFiles
    $fakeClient = Join-Path $scratch 'capture request.ps1'
    $requestLog = Join-Path $scratch 'request.txt'
    $fakeText = 'param([string]$Request)' + "`r`n" + 'Add-Content -LiteralPath ' + "'" + $requestLog.Replace("'", "''") + "' -Encoding ASCII -Value " + '$Request'
    [IO.File]::WriteAllText($fakeClient, $fakeText)
    $psWindows = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $psEncoded = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($psWindows))
    $psLinux = Invoke-DoomWslScript -Distribution $Distribution -Script ('wslpath -u "$(printf %s ' + $psEncoded + ' | base64 -d)"')
    $rendered = @()
    foreach ($name in @('doom-wsl.sh','doom.sh')) {
        $template = (Get-Content -LiteralPath (Join-Path $files $name) -Raw).Replace("`r`n", "`n")
        $template = $template.Replace('@CLIENT_BASE64@', [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($fakeClient)))
        $template = $template.Replace('@POWERSHELL_BASE64@', [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($psLinux)))
        $rendered += [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($template))
    }
    $helper = Get-Content -LiteralPath (Join-Path $files 'integration.sh') -Raw
    $script = @'
set -eu
scratch=$(mktemp -d /tmp/doom-wsl-test.XXXXXXXX)
export HOME="$scratch"
export SHELL=/bin/bash
id=@ID@
printf 'export KEEP_ME=yes\n' > "$HOME/.bashrc"
manage() (
@HELPER@
)
manage probe "$id"
manage install "$id" "$HOME" @GUI@ @CLI@
manage install "$id" "$HOME" @GUI@ @CLI@
[ "$(grep -c '^# >>> Doom Emacs WSL' "$HOME/.bashrc")" -eq 1 ]
. "$HOME/.local/share/doom-windows/$id/env.sh"
doom sync '--flag=space value' 'quote"value' '$(touch SHOULD_NOT_EXIST)'
[ ! -e SHOULD_NOT_EXIST ]
printf 'PASS: WSL doom command forwards into Windows\n'
doom-wsl --wait --new-frame -- +12:3 "$HOME/a b.txt"
printf 'PASS: WSL GUI command forwards paths and wait/frame options\n'
printf '\n# user edit\n' >> "$HOME/.local/share/doom-windows/$id/bin/doom"
if manage remove "$id" "$HOME"; then echo 'Removal accepted an edited wrapper' >&2; exit 1; fi
[ -f "$HOME/.local/share/doom-windows/$id/bin/doom" ]
# Restore the owned wrapper and verify cleanup preserves unrelated shell setup.
printf '%s' @CLI@ | base64 -d > "$HOME/.local/share/doom-windows/$id/bin/doom"
manage remove "$id" "$HOME"
[ "$(cat "$HOME/.bashrc")" = 'export KEEP_ME=yes' ]
[ ! -e "$HOME/.profile" ]
[ ! -e "$HOME/.local/share/doom-windows/$id" ]
printf 'PASS: edited files are protected; managed scripts and PATH hooks are removable\n'
case "$scratch" in /tmp/doom-wsl-test.*) rm -r -- "$scratch" ;; *) exit 1 ;; esac
'@
    $script = $script.Replace('@ID@', $caseId).Replace('@HELPER@', $helper).Replace('@GUI@', $rendered[0]).Replace('@CLI@', $rendered[1])
    Write-Host (Invoke-DoomWslScript -Distribution $Distribution -Script $script)
    $requests = @(Get-Content -LiteralPath $requestLog)
    if ($requests.Count -ne 2) { throw 'A forwarded request was lost.' }
    $cliFields = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($requests[0])).Split([char]0)
    $cliExpected = @('1', $Distribution, 'sync', '--flag=space value', 'quote"value', '$(touch SHOULD_NOT_EXIST)', '')
    if ($cliFields.Count -ne $cliExpected.Count) { throw 'CLI arguments were lost.' }
    for ($i = 0; $i -lt $cliExpected.Count; $i++) { if ($cliFields[$i] -cne $cliExpected[$i]) { throw "CLI request mismatch at $i" } }
    $fields = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($requests[1])).Split([char]0)
    if ($fields[0] -ne '1' -or $fields[1] -ne '1' -or $fields[2] -ne '1' -or $fields[3] -ne $Distribution -or $fields[4] -ne '+12:3' -or $fields[5] -notlike '*a b.txt') {
        throw 'The GUI request lost its options, distribution or filename.'
    }
} finally {
    if ((Split-Path -Parent ([IO.Path]::GetFullPath($scratch))) -eq [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')) {
        Remove-Item -LiteralPath $scratch -Recurse -Force
    }
}
