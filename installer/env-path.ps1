<#
.SYNOPSIS
    Raw read/write of HKCU\Environment\Path, shared by install-doom.ps1 and
    uninstall-doom.ps1.

.DESCRIPTION
    [Environment]::GetEnvironmentVariable/SetEnvironmentVariable expand
    REG_EXPAND_SZ values on read and always write back REG_SZ, permanently
    destroying references like %USERPROFILE% in the user's Path. These helpers
    use Microsoft.Win32.Registry with DoNotExpandEnvironmentNames and preserve
    the original RegistryValueKind.
#>

function Get-DoomUserPath {
    param([string]$ValueName = 'Path')
    $kind  = [Microsoft.Win32.RegistryValueKind]::ExpandString
    $value = ''
    $key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Environment')
    if ($key) {
        try { $kind = $key.GetValueKind($ValueName) } catch { }
        $value = [string]$key.GetValue($ValueName, '', [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        $key.Close()
    }
    return @{ Value = $value; Kind = $kind }
}

function Set-DoomUserPath {
    param(
        [string]$Value,
        [Microsoft.Win32.RegistryValueKind]$Kind,
        [string]$ValueName = 'Path'
    )
    $key = [Microsoft.Win32.Registry]::CurrentUser.CreateSubKey('Environment')
    try {
        if ($Value -eq '') { $key.DeleteValue($ValueName, $false) }
        else { $key.SetValue($ValueName, $Value, $Kind) }
    } finally { $key.Close() }
    Send-DoomEnvironmentChanged
}

function Send-DoomEnvironmentChanged {
    # WM_SETTINGCHANGE to HWND_BROADCAST so already-running processes pick up
    # the change without a logoff. Existing shells and Windows Terminal may keep
    # an inherited environment until their parent application is restarted.
    try {
        if (-not ('DoomInstaller.EnvNotify' -as [type])) {
            Add-Type -Namespace DoomInstaller -Name EnvNotify -MemberDefinition @'
[DllImport("user32.dll", SetLastError = true, CharSet = CharSet.Auto)]
public static extern System.IntPtr SendMessageTimeout(
    System.IntPtr hWnd, uint Msg, System.UIntPtr wParam, string lParam,
    uint fuFlags, uint uTimeout, out System.UIntPtr lpdwResult);
'@
        }
        [UIntPtr]$result = [UIntPtr]::Zero
        [DoomInstaller.EnvNotify]::SendMessageTimeout(
            [IntPtr]0xffff, 0x1A, [UIntPtr]::Zero, 'Environment', 2, 5000, [ref]$result) | Out-Null
    } catch { }
}

function Add-DoomUserPathEntry {
    param([string]$Entry, [string]$ValueName = 'Path')
    $p = Get-DoomUserPath -ValueName $ValueName
    $parts = @($p.Value -split ';' | Where-Object { $_ })
    if ($parts -contains $Entry) { return $false }
    Set-DoomUserPath -Value ((@($parts) + $Entry) -join ';') -Kind $p.Kind -ValueName $ValueName
    return $true
}

function Remove-DoomUserPathEntry {
    param([string]$Entry, [string]$ValueName = 'Path')
    $p = Get-DoomUserPath -ValueName $ValueName
    $before = @($p.Value -split ';' | Where-Object { $_ })
    $after  = @($before | Where-Object { $_ -ne $Entry })
    if ($after.Count -eq $before.Count) { return $false }
    Set-DoomUserPath -Value ($after -join ';') -Kind $p.Kind -ValueName $ValueName
    return $true
}
