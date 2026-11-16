[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$Request)
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '..\native-process.ps1')
. (Join-Path $PSScriptRoot 'environment.ps1')
$root = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
try {
    $fields = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($Request)).Split([char]0)
    if ($fields.Count -lt 5 -or $fields[0] -ne '1' -or $fields[1] -notin @('0','1') -or $fields[2] -notin @('0','1')) {
        throw 'Invalid WSL client request.'
    }
    $waitForEdit = $fields[1] -eq '1'
    $newFrame = $fields[2] -eq '1'
    $distro = $fields[3]
    $settings = Get-Content -LiteralPath (Join-Path $root 'wsl-bridge.json') -Raw | ConvertFrom-Json
    if ($distro -notin @($settings.integrations.distro)) { throw 'This WSL distribution is not registered with this installation.' }
    $serverFile = Join-Path $root 'bridge-state\server\doom-windows'
    $client = Join-Path $root 'emacs\bin\emacsclient.exe'
    $environment = Get-DoomBridgeEnvironment -Root $root -DoomDir $settings.doomDir
    function Test-BridgeServer {
        if (-not (Test-Path -LiteralPath $serverFile)) { return $false }
        $probe = Invoke-DoomNativeProcess -File $client -Arguments @('-f', $serverFile, '--timeout=1', '--eval', 't') -Environment $environment -WorkingDirectory $root -TimeoutMilliseconds 5000
        return $probe.ExitCode -eq 0
    }
    $startupLock = New-Object Threading.Mutex ($false, ('Local\DoomWslBridge-' + $settings.installId))
    $lockHeld = $false
    try {
    try { $lockHeld = $startupLock.WaitOne(60000) } catch [Threading.AbandonedMutexException] { $lockHeld = $true }
    if (-not $lockHeld) { throw 'Another Windows Emacs startup is still in progress.' }
    if (-not (Test-BridgeServer)) {
        if (-not @(Get-ChildItem (Join-Path $root 'doom\.local\straight') -Filter 'build-*' -Directory -ErrorAction SilentlyContinue).Count) {
            throw 'Doom packages are not synchronized. Run doom sync in Windows first.'
        }
        $startup = New-Object Diagnostics.ProcessStartInfo
        $startup.FileName = Join-Path $root 'emacs\bin\runemacs.exe'
        $startup.Arguments = (@("--init-directory=$(Join-Path $root 'doom')", "--load=$(Join-Path $PSScriptRoot 'server.el')") |
            ForEach-Object { ConvertTo-DoomNativeArgument $_ }) -join ' '
        $startup.UseShellExecute = $false
        $startup.WorkingDirectory = $root
        foreach ($name in $environment.Keys) {
            if ($null -eq $environment[$name]) { $startup.EnvironmentVariables.Remove($name) }
            else { $startup.EnvironmentVariables[$name] = [string]$environment[$name] }
        }
        [void][Diagnostics.Process]::Start($startup)
        $deadline = [DateTime]::UtcNow.AddSeconds(45)
        while (-not (Test-BridgeServer)) {
            if ([DateTime]::UtcNow -gt $deadline) { throw 'Windows Emacs did not start its server. Check the Emacs window for a startup error.' }
            Start-Sleep -Milliseconds 250
        }
    }
    } finally {
        if ($lockHeld) { $startupLock.ReleaseMutex() }
        $startupLock.Dispose()
    }
    $arguments = @('-f', $serverFile)
    if (-not $waitForEdit) { $arguments += '-n' }
    if ($newFrame) { $arguments += '-c' } else { $arguments += '-r' }
    $arguments += '--'
    # One final empty field is the trailing NUL, not an empty filename.
    if ($fields.Count -gt 5) { $arguments += $fields[4..($fields.Count - 2)] }
    $result = Invoke-DoomNativeProcess -File $client -Arguments $arguments -Environment $environment -WorkingDirectory $root -TimeoutMilliseconds 0
    if ($result.Output) { [Console]::Out.Write($result.Output) }
    if ($result.Error) { [Console]::Error.Write($result.Error) }
    exit $result.ExitCode
} catch {
    [Console]::Error.WriteLine("doom-wsl: $($_.Exception.Message)")
    exit 1
}
