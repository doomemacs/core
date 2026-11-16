[CmdletBinding()]
param([switch]$List, [string]$OutFile, [string]$SelectionRoot,
    [string]$SelectionRegistryKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\DoomEmacs')
. (Join-Path $PSScriptRoot 'native-process.ps1')
$script:DoomWslSourceRoot = $PSScriptRoot

function Get-DoomWslExecutable {
    foreach ($relative in @('Sysnative\wsl.exe', 'System32\wsl.exe')) {
        $path = Join-Path $env:SystemRoot $relative
        if (Test-Path -LiteralPath $path) { return $path }
    }
    throw 'WSL is not installed. Install a WSL distribution before enabling this option.'
}

function Get-DoomWslDistributions {
    # Registration can be read without booting distributions or touching VHDs.
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss'
    foreach ($child in @(Get-ChildItem -LiteralPath $key -ErrorAction SilentlyContinue)) {
        $registration = Get-ItemProperty -LiteralPath $child.PSPath
        $name = [string]$registration.DistributionName
        if ($name -and $name -notmatch '^docker-desktop(?:-data)?$' -and $name -notmatch '["\r\n]') {
            [pscustomobject]@{ Name = $name; Id = $child.PSChildName }
        }
    }
}

function Get-DoomWslSelection {
    param([string]$Root, [string]$Key)
    $distributions = @(Get-DoomWslDistributions | Sort-Object Name)
    $saved = @()
    $preferred = ''
    $readFailed = $false
    try {
        $registration = Get-ItemProperty -LiteralPath $Key -ErrorAction SilentlyContinue
        # Never borrow another installation's integration history.
        if ($registration.InstallLocation -eq $Root) {
            $preferred = [string]$registration.LastWslDistributionId
            if ($registration.WslIntegrations) { $saved = @($registration.WslIntegrations | ConvertFrom-Json) }
        }
        $settingsPath = Join-Path $Root 'wsl-bridge.json'
        $manifestPath = Join-Path $Root 'install-manifest.json'
        if (Test-Path -LiteralPath $settingsPath) {
            $saved = @((Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json).integrations)
        } elseif (Test-Path -LiteralPath $manifestPath) {
            $saved = @((Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json).wsl)
        }
    } catch { $readFailed = $true }
    $saved = @($saved | Where-Object { $_ -and $_.distributionId })
    if (-not $preferred -and $saved.Count) { $preferred = $saved[-1].distributionId }
    $suggested = ''
    $statuses = @()
    foreach ($entry in $saved) {
        $current = @($distributions | Where-Object { $_.Id -eq $entry.distributionId })
        if ($current.Count -eq 1) {
            $statuses += "$($current[0].Name): saved connection; select to check or repair."
            if ($entry.distributionId -eq $preferred) { $suggested = $current[0].Name }
        } else {
            $statuses += "$($entry.distro): previous registration not found; its data and saved record are kept."
        }
    }
    if ($readFailed) { $statuses += 'Some saved WSL settings could not be read. Existing integrations are kept.' }
    if (-not $distributions.Count) { $statuses += 'No registered user distributions found. Windows installation can continue without WSL.' }
    elseif (-not $saved.Count) { $statuses += 'Choose a distribution to add integration, or continue without it.' }
    return [pscustomobject]@{ Distributions = $distributions; Suggested = $suggested; Status = ($statuses -join ' ') }
}

function Save-DoomWslRegistryState {
    param([string]$Root, [string]$Key, $Settings, $Selected)
    if (-not (Test-Path -LiteralPath $Key)) { New-Item -Path $Key -Force | Out-Null }
    New-ItemProperty -LiteralPath $Key -Name InstallLocation -Value $Root -PropertyType String -Force | Out-Null
    $json = ConvertTo-Json -InputObject @($Settings.integrations) -Depth 8 -Compress
    New-ItemProperty -LiteralPath $Key -Name WslIntegrations -Value $json -PropertyType String -Force | Out-Null
    if ($Selected) {
        New-ItemProperty -LiteralPath $Key -Name LastWslDistributionId -Value $Selected.distributionId -PropertyType String -Force | Out-Null
        New-ItemProperty -LiteralPath $Key -Name LastWslDistribution -Value $Selected.distro -PropertyType String -Force | Out-Null
    }
}

function Invoke-DoomWslScript {
    param([string]$Distribution, [string]$User, [string]$Script, [string[]]$Arguments = @())
    $argsList = @('--distribution', $Distribution)
    if ($User) { $argsList += @('--user', $User) }
    $argsList += @('--exec', '/bin/sh', '-s', '--') + $Arguments
    $result = Invoke-DoomNativeProcess -File (Get-DoomWslExecutable) -Arguments $argsList -InputText ($Script.Replace("`r`n", "`n") + "`n")
    if ($result.ExitCode -ne 0) {
        throw "WSL '$Distribution' failed ($($result.ExitCode)): $($result.Error) $($result.Output)"
    }
    return $result.Output.Trim()
}

function Get-DoomWslBridgeFiles {
    $path = Join-Path $script:DoomWslSourceRoot 'bridge'
    if (-not (Test-Path -LiteralPath $path)) { $path = Join-Path $script:DoomWslSourceRoot 'files\bridge' }
    return $path
}

function Add-DoomWslIntegration {
    param([string]$InstallRoot, [string]$DoomDir, [string]$Distribution)
    if ([Environment]::OSVersion.Version.Build -lt 18362) {
        throw 'WSL bridge requires Windows 10 version 1903 or newer for UTF-8 client arguments.'
    }
    foreach ($name in @('client.ps1','cli.ps1','server.el','environment.ps1')) {
        if (-not (Test-Path -LiteralPath (Join-Path $InstallRoot ('bridge\' + $name)))) {
            throw "The Windows bridge payload is missing $name. Rebuild or reinstall before enabling WSL."
        }
    }
    $registered = @(Get-DoomWslDistributions | Where-Object { $_.Name -ceq $Distribution })
    if ($registered.Count -ne 1) { throw "WSL distribution '$Distribution' is not registered for this Windows user." }
    $settingsPath = Join-Path $InstallRoot 'wsl-bridge.json'
    $settings = if (Test-Path -LiteralPath $settingsPath) {
        Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
    } else {
        [pscustomobject]@{ schema = 1; installId = [guid]::NewGuid().ToString('N'); doomDir = $DoomDir; integrations = @() }
    }
    if ($settings.installId -notmatch '^[0-9a-f]{32}$') { throw 'Invalid WSL installation ownership id.' }
    $files = Get-DoomWslBridgeFiles
    $helper = Get-Content -LiteralPath (Join-Path $files 'integration.sh') -Raw
    $old = @($settings.integrations | Where-Object { $_.distributionId -eq $registered[0].Id })
    $userName = if ($old.Count) { $old[0].user } else { '' }
    $probe = Invoke-DoomWslScript -Distribution $Distribution -User $userName -Script $helper -Arguments @('probe', $settings.installId)
    $userName = [regex]::Match($probe, '(?m)^DOOM_USER=(.+)\r?$').Groups[1].Value.TrimEnd("`r")
    $linuxHome = [regex]::Match($probe, '(?m)^DOOM_HOME=(.+)\r?$').Groups[1].Value.TrimEnd("`r")
    if (-not $userName -or $linuxHome -notmatch '^/' -or $linuxHome -match '[\r\n]') { throw 'Could not determine the selected WSL user and home directory.' }
    if ($old.Count -and $old[0].home -ne $linuxHome) { throw 'The registered Linux home has changed. Remove the old integration first.' }
    $powershellWindows = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
    $encodedPowerShell = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($powershellWindows))
    $conversion = 'wslpath -u "$(printf %s ' + $encodedPowerShell + ' | base64 -d)"'
    $powershellLinux = Invoke-DoomWslScript -Distribution $Distribution -User $userName -Script $conversion
    $interopProbe = '"$(printf %s ' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($powershellLinux)) + ' | base64 -d)" -NoProfile -NonInteractive -Command "exit 0"'
    [void](Invoke-DoomWslScript -Distribution $Distribution -User $userName -Script $interopProbe)
    $wrappers = @()
    foreach ($pair in @(@('doom-wsl.sh','client.ps1'), @('doom.sh','cli.ps1'))) {
        $template = Get-Content -LiteralPath (Join-Path $files $pair[0]) -Raw
        $client = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((Join-Path $InstallRoot ('bridge\' + $pair[1]))))
        $powerShell = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($powershellLinux))
        $template = $template.Replace('@CLIENT_BASE64@', $client).Replace('@POWERSHELL_BASE64@', $powerShell).Replace("`r`n", "`n")
        $wrappers += [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($template))
    }
    $entry = [pscustomobject]@{
        distro = $Distribution; distributionId = $registered[0].Id; user = $userName
        home = $linuxHome; root = "$linuxHome/.local/share/doom-windows/$($settings.installId)"
        installId = $settings.installId
    }
    $settings.doomDir = $DoomDir
    $settings.integrations = @($settings.integrations | Where-Object { $_.distributionId -ne $entry.distributionId }) + $entry
    # Record the recovery handle BEFORE changing Linux files. Even a partially
    # installed hook is subsequently removable with the same ownership id.
    $settings | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
    [void](Invoke-DoomWslScript -Distribution $Distribution -User $userName -Script $helper -Arguments @('install', $entry.installId, $entry.home, $wrappers[0], $wrappers[1]))
    return $entry
}

function Remove-DoomWslIntegration {
    param($Entry)
    $registered = @(Get-DoomWslDistributions | Where-Object { $_.Id -eq $Entry.distributionId })
    if (-not $registered.Count) {
        # Missing registration is not proof that its backing data is gone.
        # Never direct cleanup at a replacement with the same name.
        return
    }
    $helper = Get-Content -LiteralPath (Join-Path (Get-DoomWslBridgeFiles) 'integration.sh') -Raw
    [void](Invoke-DoomWslScript -Distribution $registered[0].Name -User $Entry.user -Script $helper -Arguments @('remove', $Entry.installId, $Entry.home))
}

if ($List) {
    if (-not $OutFile) { throw '-OutFile is required with -List.' }
    $selection = Get-DoomWslSelection -Root $SelectionRoot -Key $SelectionRegistryKey
    [IO.File]::WriteAllLines($OutFile, [string[]]@($selection.Distributions | ForEach-Object Name), [Text.Encoding]::Unicode)
    [IO.File]::WriteAllLines(($OutFile + '.ini'), [string[]]@('[selection]',
        "Suggested=$($selection.Suggested)", "Status=$($selection.Status)"), [Text.Encoding]::Unicode)
}
