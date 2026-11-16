# Fonts stay in this installation. Only installer-created HKCU font values are
# removed, and existing font families/registry values are never overwritten.
[CmdletBinding()]
param([string]$CheckInstallRoot)
function Initialize-DoomFontApi {
    if ('DoomFontApi' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
public static class DoomFontApi {
 [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern int AddFontResourceEx(string file, uint flags, IntPtr reserved);
 [DllImport("gdi32.dll", CharSet=CharSet.Unicode)] public static extern bool RemoveFontResourceEx(string file, uint flags, IntPtr reserved);
 [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hwnd, uint message, IntPtr wparam, IntPtr lparam);
}
'@
}
function Get-DoomInstalledFontFamilies {
    Add-Type -AssemblyName System.Drawing
    $collection = New-Object Drawing.Text.InstalledFontCollection
    try { return @($collection.Families | ForEach-Object Name) }
    finally { $collection.Dispose() }
}
function Add-DoomFontResource([string]$Path) {
    Initialize-DoomFontApi
    if ([DoomFontApi]::AddFontResourceEx($Path, 0, [IntPtr]::Zero) -eq 0) { throw "Windows could not load font: $Path" }
}
function Remove-DoomFontResource([string]$Path) {
    Initialize-DoomFontApi
    [void][DoomFontApi]::RemoveFontResourceEx($Path, 0, [IntPtr]::Zero)
}
function Send-DoomFontChange {
    Initialize-DoomFontApi
    [void][DoomFontApi]::PostMessage([IntPtr]0xffff, 0x1d, [IntPtr]::Zero, [IntPtr]::Zero)
}
function Get-DoomFontRegistryName([string]$Root, [string]$Path) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $normalized = ([IO.Path]::GetFullPath($Root)).TrimEnd('\').ToLowerInvariant()
    try { $id = ([BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($normalized)))).Replace('-','').Substring(0,12) }
    finally { $sha.Dispose() }
    return "Doom Emacs $id - $([IO.Path]::GetFileNameWithoutExtension($Path)) (TrueType)"
}
function Save-DoomFontState([string]$Root, $State) {
    $path = Join-Path $Root 'font-state.json'
    $temporary = $path + '.' + [guid]::NewGuid().ToString('N') + '.tmp'
    [IO.File]::WriteAllText($temporary, (ConvertTo-Json -InputObject $State -Depth 8), (New-Object Text.UTF8Encoding $false))
    if (Test-Path -LiteralPath $path) { [IO.File]::Replace($temporary, $path, [System.Management.Automation.Language.NullString]::Value) }
    else { [IO.File]::Move($temporary, $path) }
}
function Get-DoomFontState([string]$Root) {
    $path = Join-Path $Root 'font-state.json'
    if (-not (Test-Path -LiteralPath $path)) { return [pscustomobject]@{ schema=1; installRoot=$Root; entries=@() } }
    $state = Get-Content -LiteralPath $path -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($state.schema -ne 1 -or [string]$state.installRoot -ne $Root) { throw 'Font ownership metadata does not match this installation.' }
    foreach ($entry in @($state.entries)) {
        $fontRoot = [IO.Path]::GetFullPath((Join-Path $Root 'fonts')).TrimEnd('\')
        $path = [IO.Path]::GetFullPath([string]$entry.path)
        if (-not $path.StartsWith($fontRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or
            $entry.name -cne (Get-DoomFontRegistryName $Root $path) -or $entry.sha256 -notmatch '^[0-9a-f]{64}$') {
            throw 'Invalid font ownership entry; no font registrations were changed.'
        }
        # Refuse redirected paths before inspecting/removing registrations.
        $cursor = $path
        while ($cursor -and $cursor.Length -ge $fontRoot.Length) {
            if ((Test-Path -LiteralPath $cursor) -and ((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
                throw "Redirected font path; preserving registration: $cursor"
            }
            $cursor = Split-Path -Parent $cursor
        }
        if ((Test-Path -LiteralPath $path) -and (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $entry.sha256) {
            throw "Installed font was modified; preserving it and its registration: $path"
        }
    }
    return $state
}
function Install-DoomFonts {
    param([string]$Root, [string]$RegistryKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts')
    $Root = [IO.Path]::GetFullPath($Root)
    $state = Get-DoomFontState $Root
    $manifest = Get-Content -LiteralPath (Join-Path $Root 'fonts\manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.schema -ne 1) { throw 'Unsupported font payload manifest.' }
    $installed = @(Get-DoomInstalledFontFamilies)
    foreach ($font in $manifest.fonts) {
        $path = [IO.Path]::GetFullPath((Join-Path (Join-Path $Root 'fonts') $font.file))
        $fontRoot = [IO.Path]::GetFullPath((Join-Path $Root 'fonts')).TrimEnd('\')
        if (-not $path.StartsWith($fontRoot + '\', [StringComparison]::OrdinalIgnoreCase) -or
            -not (Test-Path -LiteralPath $path -PathType Leaf) -or
            (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $font.sha256) { throw "Invalid bundled font: $($font.file)" }
        $name = Get-DoomFontRegistryName $Root $path
        $old = @($state.entries | Where-Object { $_.name -eq $name })
        # A preexisting family belongs to the user, including fonts from another
        # installation. Keep it instead of replacing it with our preferred build.
        $ownedFamily = @($state.entries | Where-Object { $_.family -eq $font.family })
        if (-not $old.Count -and -not $ownedFamily.Count -and $installed -contains $font.family) { continue }
        if (-not (Test-Path -LiteralPath $RegistryKey)) { New-Item -Path $RegistryKey -Force | Out-Null }
        $key = Get-Item -LiteralPath $RegistryKey
        $current = $key.GetValue($name, $null)
        if ($null -ne $current -and (-not $old.Count -or $current -ne $path)) {
            Write-Warning "Font registry value was already present or changed; kept: $name"
            continue
        }
        if (-not $old.Count) {
            $state.entries = @($state.entries) + [pscustomobject]@{ name=$name; family=$font.family; path=$path; sha256=$font.sha256 }
            Save-DoomFontState $Root $state
        }
        # Persist the recovery handle before the first registry/GDI mutation.
        if ($null -eq $current) { New-ItemProperty -LiteralPath $RegistryKey -Name $name -Value $path -PropertyType String | Out-Null }
        if (-not $old.Count -or $installed -notcontains $font.family) { Add-DoomFontResource $path }
    }
    Save-DoomFontState $Root $state
    Send-DoomFontChange
    return @($state.entries)
}
function Remove-DoomFonts {
    param([string]$Root, [string]$RegistryKey = 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts')
    $state = Get-DoomFontState ([IO.Path]::GetFullPath($Root))
    # Validate every recorded file before changing any value. This function never
    # deletes font files or the shared Windows Fonts registry key.
    foreach ($entry in @($state.entries)) {
        if (-not (Test-Path -LiteralPath $RegistryKey)) { continue }
        $key = Get-Item -LiteralPath $RegistryKey
        $current = $key.GetValue($entry.name, $null)
        if ($null -eq $current) { continue }
        if ($current -ne $entry.path) { Write-Warning "Changed font registration kept: $($entry.name)"; continue }
        Remove-DoomFontResource $entry.path
        Remove-ItemProperty -LiteralPath $RegistryKey -Name $entry.name
    }
    Send-DoomFontChange
}

if ($CheckInstallRoot) { [void](Get-DoomFontState ([IO.Path]::GetFullPath($CheckInstallRoot))) }
