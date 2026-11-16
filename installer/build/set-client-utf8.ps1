# Windows CRT argv otherwise converts Unicode filenames through the system ANSI
# code page before emacsclient can send them. Preserve the original manifest and
# opt this executable into UTF-8 on Windows 10 1903+.
[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$ExePath)
$ErrorActionPreference = 'Stop'
if (-not ('DoomInstaller.ManifestResource' -as [type])) {
    Add-Type -Namespace DoomInstaller -Name ManifestResource -MemberDefinition @'
[DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
public static extern System.IntPtr LoadLibraryEx(string path, System.IntPtr file, uint flags);
[DllImport("kernel32.dll", SetLastError=true)]
public static extern System.IntPtr FindResource(System.IntPtr module, System.IntPtr name, System.IntPtr type);
[DllImport("kernel32.dll", SetLastError=true)]
public static extern System.IntPtr LoadResource(System.IntPtr module, System.IntPtr resource);
[DllImport("kernel32.dll", SetLastError=true)]
public static extern System.IntPtr LockResource(System.IntPtr resource);
[DllImport("kernel32.dll", SetLastError=true)]
public static extern uint SizeofResource(System.IntPtr module, System.IntPtr resource);
[DllImport("kernel32.dll")] public static extern bool FreeLibrary(System.IntPtr module);
[DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
public static extern System.IntPtr BeginUpdateResource(string path, bool delete);
[DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
public static extern bool UpdateResource(System.IntPtr update, System.IntPtr type, System.IntPtr name, ushort language, byte[] data, uint size);
[DllImport("kernel32.dll", SetLastError=true)]
public static extern bool EndUpdateResource(System.IntPtr update, bool discard);
'@
}
$module = [DoomInstaller.ManifestResource]::LoadLibraryEx($ExePath, [IntPtr]::Zero, 2)
if ($module -eq [IntPtr]::Zero) { throw "Cannot load executable resource table: $ExePath" }
try {
    $resource = [DoomInstaller.ManifestResource]::FindResource($module, [IntPtr]1, [IntPtr]24)
    if ($resource -eq [IntPtr]::Zero) { throw 'The client executable has no expected RT_MANIFEST resource.' }
    $pointer = [DoomInstaller.ManifestResource]::LockResource([DoomInstaller.ManifestResource]::LoadResource($module, $resource))
    $size = [DoomInstaller.ManifestResource]::SizeofResource($module, $resource)
    $bytes = New-Object byte[] $size
    [Runtime.InteropServices.Marshal]::Copy($pointer, $bytes, 0, $size)
    [xml]$manifest = [Text.Encoding]::UTF8.GetString($bytes).Trim([char]0,[char]0xfeff)
} finally { [void][DoomInstaller.ManifestResource]::FreeLibrary($module) }
$asm = 'urn:schemas-microsoft-com:asm.v3'
$windows = 'http://schemas.microsoft.com/SMI/2019/WindowsSettings'
$namespaces = New-Object Xml.XmlNamespaceManager $manifest.NameTable
$namespaces.AddNamespace('v3', $asm)
$namespaces.AddNamespace('ws', $windows)
$application = $manifest.DocumentElement.SelectSingleNode('v3:application', $namespaces)
if (-not $application) {
    $application = $manifest.CreateElement('application', $asm)
    [void]$manifest.DocumentElement.AppendChild($application)
}
$settings = $application.SelectSingleNode('v3:windowsSettings', $namespaces)
if (-not $settings) {
    $settings = $manifest.CreateElement('windowsSettings', $asm)
    [void]$application.AppendChild($settings)
}
$codePage = $settings.SelectSingleNode('ws:activeCodePage', $namespaces)
if (-not $codePage) {
    $codePage = $manifest.CreateElement('activeCodePage', $windows)
    [void]$settings.AppendChild($codePage)
}
$codePage.InnerText = 'UTF-8'
$bytes = [Text.Encoding]::UTF8.GetBytes($manifest.OuterXml)
$update = [DoomInstaller.ManifestResource]::BeginUpdateResource($ExePath, $false)
if ($update -eq [IntPtr]::Zero) { throw "Cannot update client manifest: $ExePath" }
$saved = $false
try {
    if (-not [DoomInstaller.ManifestResource]::UpdateResource($update, [IntPtr]24, [IntPtr]1, 0, $bytes, $bytes.Length)) {
        throw 'Updating the client UTF-8 manifest failed.'
    }
    $saved = [DoomInstaller.ManifestResource]::EndUpdateResource($update, $false)
    $update = [IntPtr]::Zero
    if (-not $saved) { throw 'Saving the client UTF-8 manifest failed.' }
} finally {
    if ($update -ne [IntPtr]::Zero) { [void][DoomInstaller.ManifestResource]::EndUpdateResource($update, $true) }
}
