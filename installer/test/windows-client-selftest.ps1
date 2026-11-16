# Exercises the real GNU Windows Emacs server/client without loading a user's
# configuration. All editor files and server state use a temporary directory.
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$EmacsRoot, [string]$Distribution)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\native-process.ps1')
$root = Join-Path $env:TEMP ('doom-client-test-' + [guid]::NewGuid().ToString('N'))
$editor = $null
$waiting = $null
$client = Join-Path $root 'emacs\bin\emacsclient.exe'
$serverFile = Join-Path $root 'bridge-state\server\doom-windows'
function Call-TestServer([string]$Expression) {
    $result = Invoke-DoomNativeProcess -File $client -Arguments @('-f', $serverFile, '--eval', $Expression)
    if ($result.ExitCode) { throw "Emacs evaluation failed: $($result.Error)" }
    return $result.Output.Trim()
}
function New-ClientRequest([bool]$Wait, [string]$File) {
    $fields = @('1', $(if ($Wait) { '1' } else { '0' }), '0', 'selftest', '+4:2', $File, '')
    return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($fields -join [char]0)))
}
try {
    New-Item -ItemType Directory -Path (Join-Path $root 'emacs\bin'),(Join-Path $root 'doom') -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\native-process.ps1') -Destination $root
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\files\bridge') -Destination $root -Recurse
    Copy-Item -LiteralPath (Join-Path $EmacsRoot 'bin\emacsclient.exe') -Destination $client
    & (Join-Path $PSScriptRoot '..\build\set-client-utf8.ps1') -ExePath $client
    @{installId=[guid]::NewGuid().ToString('N'); doomDir=(Join-Path $root 'config'); integrations=@(@{distro='selftest'})} |
        ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $root 'wsl-bridge.json') -Encoding UTF8
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = Join-Path $EmacsRoot 'bin\emacs.exe'
    $info.UseShellExecute = $false
    $info.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
    $info.Arguments = (@('-Q', "--init-directory=$(Join-Path $root 'doom')", ('--load=' + (Join-Path $root 'bridge\server.el'))) |
        ForEach-Object { ConvertTo-DoomNativeArgument $_ }) -join ' '
    $editor = [Diagnostics.Process]::Start($info)
    $deadline = [DateTime]::UtcNow.AddSeconds(20)
    while (-not (Test-Path -LiteralPath $serverFile)) {
        if ($editor.HasExited -or [DateTime]::UtcNow -gt $deadline) { throw 'The test Windows Emacs server did not start.' }
        Start-Sleep -Milliseconds 100
    }
    if ((Call-TestServer 't') -ne 't') { throw 'Server did not answer.' }
    [void](Call-TestServer '(progn (setq server-raise-frame nil) (add-hook (quote server-switch-hook) (lambda () (setq doom-test-file (buffer-file-name) doom-test-position (format "%s:%s" (line-number-at-pos) (current-column))))))')
    $unicodeName = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String('0YTQsNC50Lsg0YEg0L/RgNC+0LHQtdC70LDQvNC4'))
    $file = Join-Path $root ("space & value $unicodeName.txt")
    [IO.File]::WriteAllText($file, "one`ntwo`nthree`nfour`nfive`n")
    $powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $request = New-ClientRequest $false $file
    $result = Invoke-DoomNativeProcess -File $powershell -Arguments @('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'bridge\client.ps1'),'-Request',$request)
    if ($result.ExitCode) { throw "GUI request failed: $($result.Error)" }
    $lispFile = '"' + $file.Replace('\','/').Replace('"','\"') + '"'
    $position = Call-TestServer 'doom-test-position'
    if ($position -ne '"4:1"') { throw "File or position was lost: $position" }
    Write-Host 'PASS: real Windows GUI server opens Unicode paths at the requested line/column.'
    $request = New-ClientRequest $true $file
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $powershell
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.Arguments = (@('-NoProfile','-ExecutionPolicy','Bypass','-File',(Join-Path $root 'bridge\client.ps1'),'-Request',$request) |
        ForEach-Object { ConvertTo-DoomNativeArgument $_ }) -join ' '
    $waiting = [Diagnostics.Process]::Start($info)
    Start-Sleep -Seconds 2
    if ($waiting.HasExited) { throw 'The --wait client returned before editing was completed.' }
    [void](Call-TestServer "(server-buffer-done (find-buffer-visiting $lispFile))")
    if (-not $waiting.WaitForExit(10000) -or $waiting.ExitCode -ne 0) { throw 'The --wait client did not finish after server-buffer-done.' }
    Write-Host 'PASS: wait mode holds the shell until the server completes editing.'
    if ($Distribution) {
        . (Join-Path $PSScriptRoot '..\wsl-integration.ps1')
        $originalInvoke = ${function:Invoke-DoomWslScript}
        $linuxHome = & $originalInvoke -Distribution $Distribution -Script 'mktemp -d /tmp/doom-gui-test.XXXXXXXX'
        $encodedHome = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($linuxHome))
        function Invoke-DoomWslScript {
            param([string]$Distribution, [string]$User, [string]$Script, [string[]]$Arguments = @())
            $prefix = 'export HOME="$(printf %s ' + $encodedHome + ' | base64 -d)"' + "`n"
            & $originalInvoke -Distribution $Distribution -User $User -Script ($prefix + $Script) -Arguments $Arguments
        }
        $entry = $null
        try {
            $entry = Add-DoomWslIntegration -InstallRoot $root -DoomDir (Join-Path $root 'config') -Distribution $Distribution
            $script = '. "$HOME/.local/share/doom-windows/' + $entry.installId + '/env.sh"' + "`n" + @'
name=$(printf %s 0YTQsNC50Lsg0YEg0L/RgNC+0LHQtdC70LDQvNC4 | base64 -d)
printf 'one\ntwo\nthree\n' > "$HOME/$name.txt"
doom-wsl -- +2:1 "$HOME/$name.txt"
'@
            [void](Invoke-DoomWslScript -Distribution $Distribution -User $entry.user -Script $script)
            $encoded = (Call-TestServer '(base64-encode-string (encode-coding-string doom-test-file (quote utf-8)) t)').Trim('"')
            $visited = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($encoded))
            if ($visited -notmatch [regex]::Escape($Distribution) -or -not $visited.Contains($unicodeName) -or (Call-TestServer 'doom-test-position') -ne '"2:0"') {
                throw "The WSL file was not opened in the Windows GUI server: $visited"
            }
            Write-Host 'PASS: real WSL command opens a Linux Unicode filename in the same Windows GUI server.'
        } finally {
            if ($entry) { Remove-DoomWslIntegration -Entry $entry }
            if ($linuxHome -match '^/tmp/doom-gui-test\.[A-Za-z0-9]+$') {
                $cleanup = 'root="$(printf %s ' + $encodedHome + ' | base64 -d)"' + "`n" + 'name=$(printf %s 0YTQsNC50Lsg0YEg0L/RgNC+0LHQtdC70LDQvNC4 | base64 -d); rm -f -- "$root/$name.txt"; rmdir -- "$root/.local/share/doom-windows" "$root/.local/share" "$root/.local" "$root"'
                [void](& $originalInvoke -Distribution $Distribution -Script $cleanup)
            }
        }
    }
} finally {
    if ($waiting -and -not $waiting.HasExited) { $waiting.Kill() }
    if ($editor -and -not $editor.HasExited) {
        [void](Invoke-DoomNativeProcess -File $client -Arguments @('-f',$serverFile,'--eval','(kill-emacs)'))
        if (-not $editor.WaitForExit(5000)) { $editor.Kill() }
    }
    if ((Split-Path -Parent ([IO.Path]::GetFullPath($root))) -eq [IO.Path]::GetFullPath($env:TEMP).TrimEnd('\')) {
        Remove-Item -LiteralPath $root -Recurse -Force
    }
}
