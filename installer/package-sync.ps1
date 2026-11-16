# Installer policy only; Doom remains responsible for incremental package builds.
function Get-DoomRuntimeSignature {
    param([string]$Root)
    $emacs = Join-Path $Root 'emacs\bin\emacs.exe'
    $form = '(progn (require (quote json)) (when (native-comp-available-p) (require (quote comp))) (princ (json-encode `((emacsVersion . ,emacs-version) (systemConfiguration . ,system-configuration) (nativeAbi . ,(if (boundp (quote comp-native-version-dir)) comp-native-version-dir "none"))))))'
    $result = Invoke-DoomNativeProcess -File $emacs -Arguments @('-Q', '--batch', '--eval', $form) -WorkingDirectory $Root
    if ($result.ExitCode -ne 0) { throw "Could not inspect bundled Emacs: $($result.Error)" }
    $signature = $result.Output | ConvertFrom-Json
    if (-not $signature.emacsVersion -or -not $signature.systemConfiguration -or -not $signature.nativeAbi) {
        throw 'Bundled Emacs did not report a complete compilation signature.'
    }
    $signature | Add-Member -NotePropertyName executableHash -NotePropertyValue (Get-FileHash -LiteralPath $emacs -Algorithm SHA256).Hash
    # Same-version builds can contain a different compiler/runtime toolchain.
    $markerPath = Join-Path $Root '.staged.json'
    $toolchain = ''
    if (Test-Path -LiteralPath $markerPath) {
        $marker = Get-Content -LiteralPath $markerPath -Raw -Encoding UTF8 | ConvertFrom-Json
        $toolchain = (@($marker.PSObject.Properties | Where-Object {
            $_.Name -in @('emacs', 'libgccjit', 'gcc', 'binutils', 'crt', 'winpthreads')
        } | Sort-Object Name | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ';')
    }
    $signature | Add-Member -NotePropertyName toolchain -NotePropertyValue $toolchain
    $signature | Add-Member -NotePropertyName installRoot -NotePropertyValue ([IO.Path]::GetFullPath($Root))
    return $signature
}

function Get-DoomPackageSyncPlan {
    param($Runtime, $Previous, [bool]$HasPackages, [bool]$AheadOfTime, [bool]$Rebuild)
    $reason = 'Incremental sync: reuse compatible builds and process changed packages.'
    if ($Rebuild) { $reason = 'Full rebuild explicitly requested.' }
    elseif ($HasPackages) {
        if (-not $Previous -or $Previous.schema -ne 1 -or -not $Previous.success) {
            $Rebuild = $true
            $reason = 'Existing packages have no confirmed compilation signature; rebuild once.'
        } else {
            foreach ($name in @('emacsVersion', 'systemConfiguration', 'nativeAbi', 'executableHash', 'toolchain', 'installRoot')) {
                if ([string]$Runtime.$name -cne [string]$Previous.runtime.$name) {
                    $Rebuild = $true
                    $reason = "Compilation environment changed ($name); rebuild packages for this Emacs."
                    break
                }
            }
        }
    }
    # Do not pass -u (upgrade all packages). Normal sync still reconciles pins
    # and config changes using Doom's incremental dependency checks.
    $arguments = @('--no-color', '--force', 'sync')
    if ($Rebuild) { $arguments += '--rebuild' }
    if ($AheadOfTime) { $arguments += '--aot' }
    return [pscustomobject]@{ Arguments = $arguments; Rebuild = $Rebuild; Reason = $reason }
}

function ConvertTo-DoomPlainLog([string]$Text) {
    # Remove OSC (titles/hyperlinks), CSI (colors/cursor movement), then other
    # terminal controls. ReadLineAsync handles CR progress updates as log lines.
    $Text = [regex]::Replace($Text, '\x1B\][^\x07\x1B]*(?:\x07|\x1B\\)', '')
    $Text = [regex]::Replace($Text, '\x1B\[[0-?]*[ -/]*[@-~]', '')
    $Text = [regex]::Replace($Text, '\x1B[@-_]', '')
    return [regex]::Replace($Text, '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]', '')
}

function Invoke-DoomPackageSync {
    param([string]$Root, [string]$Config, [string[]]$Arguments)
    . (Join-Path $Root 'bridge\environment.ps1')
    $environment = Get-DoomBridgeEnvironment -Root $Root -DoomDir $Config
    $environment['NO_COLOR'] = '1'
    $environment['TERM'] = 'dumb'
    $info = New-Object Diagnostics.ProcessStartInfo
    $info.FileName = Join-Path $Root 'deps\git\usr\bin\sh.exe'
    $argv = @((Join-Path $Root 'doom\bin\doom')) + $Arguments
    $info.Arguments = (@($argv | ForEach-Object { ConvertTo-DoomNativeArgument $_ }) -join ' ')
    $info.WorkingDirectory = $Root
    $info.UseShellExecute = $false
    $info.CreateNoWindow = $true
    $info.RedirectStandardInput = $true
    $info.RedirectStandardOutput = $true
    $info.RedirectStandardError = $true
    $info.StandardOutputEncoding = [Text.Encoding]::UTF8
    $info.StandardErrorEncoding = [Text.Encoding]::UTF8
    foreach ($name in $environment.Keys) {
        if ($null -eq $environment[$name]) { $info.EnvironmentVariables.Remove($name) }
        else { $info.EnvironmentVariables[$name] = [string]$environment[$name] }
    }
    $process = [Diagnostics.Process]::Start($info)
    try {
        # EOF instead of a hanging prompt. Read both streams concurrently, so
        # a compiler filling stderr cannot deadlock a stdout reader.
        $process.StandardInput.Close()
        $streams = @($process.StandardOutput, $process.StandardError)
        $pending = @($streams[0].ReadLineAsync(), $streams[1].ReadLineAsync())
        while ($null -ne $pending[0] -or $null -ne $pending[1]) {
            $activity = $false
            for ($i = 0; $i -lt 2; $i++) {
                if ($null -eq $pending[$i] -or -not $pending[$i].IsCompleted) { continue }
                $activity = $true
                $line = $pending[$i].GetAwaiter().GetResult()
                if ($null -eq $line) { $pending[$i] = $null; continue }
                Write-Host (ConvertTo-DoomPlainLog $line)
                $pending[$i] = $streams[$i].ReadLineAsync()
            }
            if (-not $activity) { Start-Sleep -Milliseconds 10 }
        }
        $process.WaitForExit()
        return $process.ExitCode
    } finally { $process.Dispose() }
}
