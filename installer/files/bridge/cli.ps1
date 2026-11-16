[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Request)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\native-process.ps1')
. (Join-Path $PSScriptRoot 'environment.ps1')
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
try {
    $fields = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Request)).Split([char]0)
    if ($fields.Count -lt 3 -or $fields[0] -ne '1') { throw 'Invalid WSL CLI request.' }
    $settings = Get-Content -LiteralPath (Join-Path $root 'wsl-bridge.json') -Raw | ConvertFrom-Json
    if ($fields[1] -notin @($settings.integrations.distro)) { throw 'This distribution is not registered with this installation.' }
    $environment = Get-DoomBridgeEnvironment -Root $root -DoomDir $settings.doomDir
    $arguments = @((Join-Path $root 'doom\bin\doom'))
    if ($fields.Count -gt 3) { $arguments += $fields[2..($fields.Count - 2)] }
    # Inherit stdin/stdout rather than buffering them: doom can prompt and stream
    # package build output. Its working directory is the Windows installation.
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = Join-Path $root 'deps\git\usr\bin\sh.exe'
    $info.Arguments = (@($arguments | ForEach-Object { ConvertTo-DoomNativeArgument $_ }) -join ' ')
    $info.WorkingDirectory = $root
    $info.UseShellExecute = $false
    foreach ($name in $environment.Keys) {
        if ($null -eq $environment[$name]) { $info.EnvironmentVariables.Remove($name) }
        else { $info.EnvironmentVariables[$name] = [string]$environment[$name] }
    }
    $process = [Diagnostics.Process]::Start($info)
    $process.WaitForExit()
    exit $process.ExitCode
} catch {
    [Console]::Error.WriteLine("doom: $($_.Exception.Message)")
    exit 1
}
