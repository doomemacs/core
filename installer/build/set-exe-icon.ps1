<#
.SYNOPSIS
    Replace the icon resource embedded in a Windows executable.

.DESCRIPTION
    A shortcut's IconLocation only controls how the shortcut looks. The moment the
    program runs, the taskbar button, Alt-Tab entry and window corner all show the
    icon compiled into the .exe itself. Changing that means rewriting the PE
    resource table, which is what this does, via the Win32 resource update API --
    no external tool such as Resource Hacker required.

    Replacing an icon means updating two resource types together:

      RT_ICON (3)        one entry per image in the .ico
      RT_GROUP_ICON (14) the directory telling Windows which images exist and
                         which RT_ICON id each one lives at

    Updating only RT_ICON leaves the group pointing at the old images, and
    Explorer keeps showing the previous icon. Both must change in one update
    session or the file is left inconsistent.

.PARAMETER ExePath
    Executable to patch. Modified in place, so copy it first if you need the original.

.PARAMETER IconPath
    Source .ico. Multi-resolution icons are fully supported and preferred: Windows
    picks per context, so a missing 16x16 shows as a blurry downscale in the taskbar.

.PARAMETER GroupId
    Resource id of the icon group to overwrite. 1 is the conventional main icon and
    is what Explorer shows.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$ExePath,
    [Parameter(Mandatory = $true)][string]$IconPath,
    [int]$GroupId = 1
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $ExePath))  { throw "Executable not found: $ExePath" }
if (-not (Test-Path $IconPath)) { throw "Icon not found: $IconPath" }

$ExePath  = (Resolve-Path $ExePath).Path
$IconPath = (Resolve-Path $IconPath).Path

if (-not ([System.Management.Automation.PSTypeName]'DoomIconPatch.Native').Type) {
    Add-Type -Namespace 'DoomIconPatch' -Name 'Native' -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
public static extern IntPtr BeginUpdateResource(string pFileName, bool bDeleteExistingResources);

[DllImport("kernel32.dll", SetLastError=true)]
public static extern bool UpdateResource(IntPtr hUpdate, IntPtr lpType, IntPtr lpName,
                                         ushort wLanguage, byte[] lpData, uint cb);

// Second overload for NAMED resources, where lpName is a string pointer rather
// than a MAKEINTRESOURCE integer. Emacs' binaries name their icon group, so
// without this we could only ever add a numeric group beside it.
[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode, EntryPoint="UpdateResourceW")]
public static extern bool UpdateResourceByName(IntPtr hUpdate, IntPtr lpType, string lpName,
                                               ushort wLanguage, byte[] lpData, uint cb);

[DllImport("kernel32.dll", SetLastError=true)]
public static extern bool EndUpdateResource(IntPtr hUpdate, bool fDiscard);

[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode)]
public static extern IntPtr LoadLibraryEx(string lpFileName, IntPtr hFile, uint dwFlags);

[DllImport("kernel32.dll", SetLastError=true)]
public static extern bool FreeLibrary(IntPtr hModule);

public delegate bool EnumResNameProc(IntPtr hModule, IntPtr lpType, IntPtr lpName, IntPtr lParam);

// Must be the W entry point explicitly. DllImport defaults to Ansi, which binds
// EnumResourceNamesA and hands back ANSI name pointers -- decoding those as UTF-16
// turns "EMACS" into CJK mojibake ('䵅䍁S'), because 0x45 0x4D reads as U+4D45.
[DllImport("kernel32.dll", SetLastError=true, CharSet=CharSet.Unicode, EntryPoint="EnumResourceNamesW")]
public static extern bool EnumResourceNames(IntPtr hModule, IntPtr lpType, EnumResNameProc lpEnumFunc, IntPtr lParam);

[DllImport("kernel32.dll", CharSet=CharSet.Unicode)]
public static extern int lstrlenW(IntPtr ptr);
'@
}

# Read back which icon resources the target already has, so we replace them
# rather than piling a new group on top of the old one.
# Resource enumeration runs at script scope with a global accumulator, and the
# callback body is wrapped so it can never throw.
#
# Both details are load-bearing. A ScriptBlock converted to a native callback does
# not reliably close over an enclosing *function's* locals, so collecting into one
# silently produced an empty list; and an exception escaping across the native
# callback boundary is undefined behaviour that left the following
# BeginUpdateResource/UpdateResource pair failing with ERROR_INTERNAL_ERROR (1359).
# Identical code at script scope, with a callback that always returns $true, works.
$global:DoomEnumAccum = New-Object System.Collections.ArrayList

$global:DoomEnumCallback = [DoomIconPatch.Native+EnumResNameProc]{
    param($hm, $t, $n, $l)
    try {
        if ([int64]$n -lt 65536) {
            $null = $global:DoomEnumAccum.Add([pscustomobject]@{ IsNamed = $false; Id = [int][int64]$n; Name = $null })
        } else {
            $len = [DoomIconPatch.Native]::lstrlenW($n)
            $s = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($n, $len)
            $null = $global:DoomEnumAccum.Add([pscustomobject]@{ IsNamed = $true; Id = 0; Name = $s })
        }
    } catch { }
    return $true
}

$RT_ICON       = [IntPtr]3
$RT_GROUP_ICON = [IntPtr]14
# 0 = MAKELANGID(LANG_NEUTRAL, SUBLANG_NEUTRAL). Emacs' own resources are neutral;
# writing to a different language would add a second icon rather than replace it.
$LANG_NEUTRAL  = 0

# ------------------------------------------------------------- parse the .ico

$bytes = [System.IO.File]::ReadAllBytes($IconPath)
if ($bytes.Length -lt 6) { throw "Not a valid .ico: $IconPath" }

$reserved = [BitConverter]::ToUInt16($bytes, 0)
$type     = [BitConverter]::ToUInt16($bytes, 2)
$count    = [BitConverter]::ToUInt16($bytes, 4)
if ($reserved -ne 0 -or $type -ne 1 -or $count -eq 0) {
    throw "Not a valid icon file (reserved=$reserved type=$type count=$count): $IconPath"
}

$images = @()
for ($i = 0; $i -lt $count; $i++) {
    $o = 6 + ($i * 16)
    $images += [pscustomobject]@{
        Width      = $bytes[$o]
        Height     = $bytes[$o + 1]
        ColorCount = $bytes[$o + 2]
        Reserved   = $bytes[$o + 3]
        Planes     = [BitConverter]::ToUInt16($bytes, $o + 4)
        BitCount   = [BitConverter]::ToUInt16($bytes, $o + 6)
        BytesInRes = [BitConverter]::ToUInt32($bytes, $o + 8)
        ImageOffset= [BitConverter]::ToUInt32($bytes, $o + 12)
        IconId     = [uint16]($i + 1)
    }
}

Write-Host "    icon   : $(Split-Path -Leaf $IconPath) - $count image(s)" -ForegroundColor DarkGray
Write-Host "    target : $(Split-Path -Leaf $ExePath)" -ForegroundColor DarkGray

# Work out which group the binary already uses instead of assuming one. Inlined at
# script scope deliberately -- see the note above the callback.
$LOAD_LIBRARY_AS_DATAFILE = 0x2
$existingGroups = @()
$existingIcons  = @()
$mod = [DoomIconPatch.Native]::LoadLibraryEx($ExePath, [IntPtr]::Zero, $LOAD_LIBRARY_AS_DATAFILE)
if ($mod -ne [IntPtr]::Zero) {
    $global:DoomEnumAccum = New-Object System.Collections.ArrayList
    $null = [DoomIconPatch.Native]::EnumResourceNames($mod, $RT_GROUP_ICON, $global:DoomEnumCallback, [IntPtr]::Zero)
    $existingGroups = @($global:DoomEnumAccum.ToArray())

    $global:DoomEnumAccum = New-Object System.Collections.ArrayList
    $null = [DoomIconPatch.Native]::EnumResourceNames($mod, $RT_ICON, $global:DoomEnumCallback, [IntPtr]::Zero)
    $existingIcons = @($global:DoomEnumAccum.ToArray())

    $null = [DoomIconPatch.Native]::FreeLibrary($mod)
}

if ($existingGroups.Count -gt 0) {
    $targetGroup = $existingGroups[0]
    $desc = if ($targetGroup.IsNamed) { "named '$($targetGroup.Name)'" } else { "id #$($targetGroup.Id)" }
    Write-Host "    group  : replacing existing $desc ($($existingIcons.Count) old image(s) dropped)" -ForegroundColor DarkGray
} else {
    $targetGroup = [pscustomobject]@{ IsNamed = $false; Id = $GroupId; Name = $null }
    Write-Host "    group  : no existing icon group, creating id #$GroupId" -ForegroundColor DarkGray
}

# --------------------------------------------- build the RT_GROUP_ICON payload

# GRPICONDIR: 6-byte header, then a 14-byte GRPICONDIRENTRY per image. It mirrors
# the file's ICONDIRENTRY except the trailing 4-byte file offset is replaced by a
# 2-byte resource id -- which is exactly why this cannot just be memcpy'd.
$grp = New-Object System.IO.MemoryStream
$bw  = New-Object System.IO.BinaryWriter($grp)
$bw.Write([uint16]0)
$bw.Write([uint16]1)
$bw.Write([uint16]$count)
foreach ($img in $images) {
    $bw.Write([byte]$img.Width)
    $bw.Write([byte]$img.Height)
    $bw.Write([byte]$img.ColorCount)
    $bw.Write([byte]$img.Reserved)
    $bw.Write([uint16]$img.Planes)
    $bw.Write([uint16]$img.BitCount)
    $bw.Write([uint32]$img.BytesInRes)
    $bw.Write([uint16]$img.IconId)
}
$bw.Flush()
$groupData = $grp.ToArray()
$bw.Close(); $grp.Close()

# ------------------------------------------------------------------- patch it

# bDeleteExistingResources = $false: Emacs' executables carry version info,
# manifests and other resources that must survive. Wiping the table would strip
# the manifest and change how Windows treats the binary.
$h = [DoomIconPatch.Native]::BeginUpdateResource($ExePath, $false)
if ($h -eq [IntPtr]::Zero) {
    throw "BeginUpdateResource failed (win32 error $([System.Runtime.InteropServices.Marshal]::GetLastWin32Error())). Is the file in use or read-only?"
}

$committed = $false
try {
    # Drop only the old RT_ICON entries we are NOT about to overwrite, so the
    # binary keeps no orphaned images.
    #
    # Deleting an id and then writing it again inside the same update session
    # fails with ERROR_INTERNAL_ERROR (1359); a straight overwrite is fine. So
    # ids 1..N are left for the write loop below to replace in place, and only
    # surplus entries beyond our image count get removed.
    $reusedIds = 1..$count
    foreach ($old in $existingIcons) {
        if (-not $old.IsNamed -and $reusedIds -contains $old.Id) { continue }
        if ($old.IsNamed) {
            $null = [DoomIconPatch.Native]::UpdateResourceByName($h, $RT_ICON, $old.Name, $LANG_NEUTRAL, $null, 0)
        } else {
            $null = [DoomIconPatch.Native]::UpdateResource($h, $RT_ICON, [IntPtr]$old.Id, $LANG_NEUTRAL, $null, 0)
        }
    }

    foreach ($img in $images) {
        $data = New-Object byte[] $img.BytesInRes
        [Array]::Copy($bytes, [int]$img.ImageOffset, $data, 0, [int]$img.BytesInRes)
        $ok = [DoomIconPatch.Native]::UpdateResource($h, $RT_ICON, [IntPtr][int]$img.IconId,
                                                    $LANG_NEUTRAL, $data, [uint32]$data.Length)
        if (-not $ok) {
            throw "UpdateResource(RT_ICON id=$($img.IconId)) failed (win32 error $([System.Runtime.InteropServices.Marshal]::GetLastWin32Error()))"
        }
    }

    # Overwrite the group the binary actually uses, preserving its name or id.
    # Writing a fresh numeric group instead only *appears* to work: Windows
    # resolves numeric ids ahead of named ones, so a new #1 shadows the original
    # while leaving the stock icon embedded and still reachable by name.
    if ($targetGroup.IsNamed) {
        $ok = [DoomIconPatch.Native]::UpdateResourceByName($h, $RT_GROUP_ICON, $targetGroup.Name,
                                                           $LANG_NEUTRAL, $groupData, [uint32]$groupData.Length)
        $label = $targetGroup.Name
    } else {
        $ok = [DoomIconPatch.Native]::UpdateResource($h, $RT_GROUP_ICON, [IntPtr]$targetGroup.Id,
                                                     $LANG_NEUTRAL, $groupData, [uint32]$groupData.Length)
        $label = "#$($targetGroup.Id)"
    }
    if (-not $ok) {
        throw "UpdateResource(RT_GROUP_ICON $label) failed (win32 error $([System.Runtime.InteropServices.Marshal]::GetLastWin32Error()))"
    }

    if (-not [DoomIconPatch.Native]::EndUpdateResource($h, $false)) {
        throw "EndUpdateResource failed (win32 error $([System.Runtime.InteropServices.Marshal]::GetLastWin32Error()))"
    }
    $committed = $true
} finally {
    # Discard on any failure, so a half-written resource table is never committed.
    if (-not $committed) { [void][DoomIconPatch.Native]::EndUpdateResource($h, $true) }
}

Write-Host "    OK    icon replaced ($count image(s), group $label)" -ForegroundColor Green
exit 0
