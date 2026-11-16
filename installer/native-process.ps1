# ProcessStartInfo.ArgumentList is unavailable in Windows PowerShell 5.1.
# Quote arguments using the Windows argv rules, without invoking cmd.exe.
function ConvertTo-DoomNativeArgument([AllowEmptyString()][string]$Argument) {
    if ($Argument -and $Argument -notmatch '[\s"]') { return $Argument }
    $escaped = [regex]::Replace($Argument, '(\\*)"', '$1$1\"')
    $escaped = [regex]::Replace($escaped, '(\\+)$', '$1$1')
    return '"' + $escaped + '"'
}

function Invoke-DoomNativeProcess {
    param(
        [Parameter(Mandatory = $true)][string]$File,
        [string[]]$Arguments = @(),
        [string]$InputText,
        [string]$WorkingDirectory,
        [hashtable]$Environment = @{},
        [Text.Encoding]$OutputEncoding = [Text.Encoding]::UTF8,
        [int]$TimeoutMilliseconds = 60000
    )
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = $File
    $info.Arguments = (@($Arguments | ForEach-Object { ConvertTo-DoomNativeArgument $_ }) -join ' ')
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = $OutputEncoding
    $info.StandardErrorEncoding = $OutputEncoding
    if ($WorkingDirectory) { $info.WorkingDirectory = $WorkingDirectory }
    foreach ($name in $Environment.Keys) {
        if ($null -eq $Environment[$name]) { $info.EnvironmentVariables.Remove($name) }
        else { $info.EnvironmentVariables[$name] = [string]$Environment[$name] }
    }
    $process = [Diagnostics.Process]::Start($info)
    $timer = [Diagnostics.Stopwatch]::StartNew()
    try {
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if ($InputText) {
            $write = $process.StandardInput.WriteAsync($InputText)
            if ($TimeoutMilliseconds -eq 0) { $write.GetAwaiter().GetResult() }
            elseif (-not $write.Wait($TimeoutMilliseconds)) {
                $process.Kill()
                throw "Process stopped accepting input: $File"
            }
        }
        $process.StandardInput.Close()
        if ($TimeoutMilliseconds -eq 0) { $process.WaitForExit() }
        elseif (-not $process.WaitForExit([math]::Max(1, $TimeoutMilliseconds - [int]$timer.ElapsedMilliseconds))) {
            $process.Kill()
            throw "Process timed out: $File. Check that the WSL distribution and its disk are accessible."
        }
        $process.WaitForExit()
        return [pscustomobject]@{
            ExitCode = $process.ExitCode
            Output = $stdout.GetAwaiter().GetResult()
            Error = $stderr.GetAwaiter().GetResult()
        }
    } finally { $process.Dispose() }
}
