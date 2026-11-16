; Doom Emacs for Windows - installer
;
; Deliberately thin. NSIS does what NSIS is good at -- being a self-extracting
; container with a progress bar and an Add/Remove Programs presence -- and
; nothing else. Every decision about what an install IS lives in
; install-doom.ps1, so the standalone path and this .exe cannot drift apart.
;
; Per-user by design: everything lands under %LOCALAPPDATA% and HKCU, so this
; never raises a UAC prompt and never needs administrator rights.
;
; Built by build-installer.ps1, which supplies VERSION, STAGING and OUTFILE.

Unicode true

!ifndef VERSION
  !define VERSION "0.0.0"
!endif
!ifndef STAGING
  !error "STAGING not defined. Build via build-installer.ps1, not makensis directly."
!endif
!ifndef OUTFILE
  !define OUTFILE "DoomEmacs-${VERSION}-x86_64-setup.exe"
!endif

!define PRODUCT      "Doom Emacs"
!define PUBLISHER    "Doom Emacs community build"
!ifndef REGKEY
  !define REGKEY "Software\Microsoft\Windows\CurrentVersion\Uninstall\DoomEmacs"
!endif

Name "${PRODUCT} ${VERSION}"
OutFile "${OUTFILE}"
InstallDir "$LOCALAPPDATA\Programs\DoomEmacs"
InstallDirRegKey HKCU "${REGKEY}" "InstallLocation"

; No elevation. This is the whole reason the install is per-user.
RequestExecutionLevel user

; The details pane is shown, not collapsed. Package sync is the long pole of this
; install and streams a few hundred package names through it; with the pane hidden
; the installer looks frozen for ten minutes and people kill it.
ShowInstDetails show
ShowUninstDetails show

!ifdef NOCOMPRESS
  SetCompress off
!else
  ; Solid LZMA on a 1.4GB payload is slow to build but roughly halves the
  ; download. Pass -SkipCompress to build-installer.ps1 when iterating.
  SetCompressor /SOLID lzma
  SetCompressorDictSize 64
!endif

!include "MUI2.nsh"
!include "FileFunc.nsh"
!include "LogicLib.nsh"
; Required for ${RunningX64}; without it LogicLib sees an undefined token and
; fails with the unhelpful '"_If" requires 4 parameter(s), passed 2'.
!include "x64.nsh"
; Required for ${SectionIsSelected}, which otherwise degrades into a raw
; SectionGetFlags usage error.
!include "Sections.nsh"
; Required for ${AtLeastWin10}.
!include "WinVer.nsh"
!include "nsDialogs.nsh"
!include "TextFunc.nsh"

Var RootOwnerArg
Var ExistingInstall
Var MaintenanceDialog
Var RemoveRadio
Var EngineOptions
Var ConfigSummary
Var WslDistro
Var WslCheck
Var WslCombo
Var WslSelectionLoaded
Var ConfigPath
Var LegacyConfigPath
Var WslCommandPath
Var ConfigStatus

!macro LocationField LABEL VALUE LABELY FIELDY
  ${NSD_CreateLabel} 0 ${LABELY} 100% 10u "${LABEL}"
  Pop $0
  ${NSD_CreateText} 0 ${FIELDY} 100% 14u "${VALUE}"
  Pop $0
  ${NSD_Edit_SetReadOnly} $0 1
!macroend

!macro LoadConfigSummary ROOT
  InitPluginsDir
  SetOutPath "$PLUGINSDIR\ui"
  File "config-info.ps1"
  nsExec::ExecToLog '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -NonInteractive -File "$PLUGINSDIR\ui\config-info.ps1" -InstallRoot "${ROOT}" -OutFile "$PLUGINSDIR\config-info.txt"'
  Pop $0
  ${If} $0 != 0
    MessageBox MB_ICONSTOP "The configuration locations could not be read. Setup will not guess which folder is used." /SD IDOK
    SetErrorLevel 1
    Quit
  ${EndIf}
  FileOpen $0 "$PLUGINSDIR\config-info.txt" r
  StrCpy $ConfigSummary ""
  ${Do}
    ClearErrors
    FileReadUTF16LE $0 $1
    ${If} ${Errors}
      ${ExitDo}
    ${EndIf}
    StrCpy $ConfigSummary "$ConfigSummary$1"
  ${Loop}
  FileClose $0
  ReadINIStr $ConfigPath "$PLUGINSDIR\config-info.txt.ini" "paths" "Config"
  ReadINIStr $ConfigStatus "$PLUGINSDIR\config-info.txt.ini" "paths" "ConfigStatus"
  ReadINIStr $LegacyConfigPath "$PLUGINSDIR\config-info.txt.ini" "paths" "Legacy"
  ReadINIStr $WslCommandPath "$PLUGINSDIR\config-info.txt.ini" "paths" "Wsl"
!macroend

!define MUI_ABORTWARNING
; NSIS needs a real .ico and cannot pull one out of a DLL. Paths here resolve
; relative to this .nsi file. Deliberately the same file that ships in the
; payload, so the installer, the Start Menu shortcut and the Add/Remove entry
; all show one icon rather than three near-misses.
!define MUI_ICON   "files\doom.ico"
!define MUI_UNICON "files\doom.ico"

!define MUI_WELCOMEPAGE_TITLE "${PRODUCT} ${VERSION}"
!define MUI_WELCOMEPAGE_TEXT "This installs ${PRODUCT}, GNU Emacs 31.1, git, ripgrep, fd, and a native-compilation toolchain.$\r$\n$\r$\nInternet access is required to download Emacs packages during setup.$\r$\n$\r$\nIt installs for your user account only, without administrator rights.$\r$\n$\r$\nIf Doom is already installed, the next page offers reinstall or removal. Your existing Doom configuration is kept."

!define MUI_COMPONENTSPAGE_SMALLDESC
!insertmacro MUI_PAGE_WELCOME
Page custom MaintenanceCreate MaintenanceLeave
Page custom ConfigLocationCreate
!insertmacro MUI_PAGE_LICENSE "${STAGING}\doom\LICENSE"
!insertmacro MUI_PAGE_COMPONENTS
!define MUI_PAGE_CUSTOMFUNCTION_LEAVE CheckInstallPath
!insertmacro MUI_PAGE_DIRECTORY
Page custom WslCreate WslLeave
Page custom InstallSummaryCreate
!insertmacro MUI_PAGE_INSTFILES

!define MUI_FINISHPAGE_TITLE "${PRODUCT} is ready"
!define MUI_FINISHPAGE_TEXT "Required package setup is complete. Native optimization can continue as you use Emacs unless you selected pre-compilation.$\r$\n$\r$\nTo use the command line tools, open a NEW terminal (existing terminals may still have the old PATH) and run:$\r$\n$\r$\n    doom doctor"
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Launch Doom Emacs now"
!define MUI_FINISHPAGE_RUN_FUNCTION LaunchDoom
!define MUI_FINISHPAGE_SHOWREADME "$INSTDIR\doom\docs\getting_started.org"
!define MUI_FINISHPAGE_SHOWREADME_TEXT "Open the getting started guide"
!define MUI_FINISHPAGE_SHOWREADME_NOTCHECKED
!insertmacro MUI_PAGE_FINISH

UninstPage custom un.ConfigLocationCreate
!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_LANGUAGE "English"

VIProductVersion "1.0.0.0"
VIAddVersionKey "ProductName"     "${PRODUCT}"
VIAddVersionKey "FileDescription" "${PRODUCT} installer"
VIAddVersionKey "FileVersion"     "${VERSION}"
VIAddVersionKey "ProductVersion"  "${VERSION}"
VIAddVersionKey "LegalCopyright"  "MIT licensed"
VIAddVersionKey "CompanyName"     "${PUBLISHER}"

; ---------------------------------------------------------------------------

Function GuardInstallPath
  ${If} ${FileExists} "$INSTDIR\font-state.json"
    nsExec::ExecToLog '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -NonInteractive -File "$PLUGINSDIR\font-integration.ps1" -CheckInstallRoot "$INSTDIR"'
    Pop $0
    ${If} $0 != 0
      MessageBox MB_ICONSTOP "Installed font files or ownership metadata were changed. Setup stopped before copying payload files; review the details above." /SD IDOK
      SetErrorLevel 1
      Abort
    ${EndIf}
  ${EndIf}
  ; Never merge into an arbitrary non-empty folder. The uninstaller removes an
  ; installer-owned tree recursively, so accepting one here could delete files
  ; that Doom did not create. A manifest identifies a Doom reinstall and is safe.
  ${IfNot} ${FileExists} "$INSTDIR\install-manifest.json"
    ${DirState} "$INSTDIR" $R0
    ${If} $R0 == 1
      MessageBox MB_ICONSTOP \
        "That folder is not empty and is not an existing Doom Emacs installation.$\r$\n$\r$\nChoose a new or empty folder so uninstall can never remove files it did not create." /SD IDOK
      Abort
    ${EndIf}
  ${EndIf}
FunctionEnd

Function CheckInstallPath
  Call GuardInstallPath

  ; MAX_PATH headroom, checked when the folder is actually chosen rather than in
  ; .onInit, where $INSTDIR is still only the default.
  ;
  ; A minimal install already reaches ~200 characters deep on its own: straight.el
  ; build directories and native-comp trampoline filenames are long, and enabling
  ; more Doom modules makes it worse. The limit is 259 unless LongPathsEnabled is
  ; set, which it is not by default on either Windows 10 or 11. A long install root
  ; eats that headroom directly, and the failures surface deep inside a package
  ; build where the cause is far from obvious.
  StrLen $R9 "$INSTDIR"
  ${If} $R9 > 90
    MessageBox MB_ICONEXCLAMATION|MB_OKCANCEL \
      "That folder path is $R9 characters long.$\r$\n$\r$\nDoom nests files deeply and Windows limits paths to 260 characters, so installing here may fail partway through with errors that do not point back to this choice.$\r$\n$\r$\nSomething shorter, such as C:\DoomEmacs, is safer.$\r$\n$\r$\nContinue anyway?" \
      IDOK +2
    Abort
  ${EndIf}
FunctionEnd

Function LaunchDoom
  ; Via the shim, which seals EMACSDIR/DOOMDIR/HOME and passes --init-directory.
  ; Launching runemacs.exe directly would start stock Emacs with none of Doom
  ; loaded, because Doom is not at Emacs' default user-emacs-directory.
  Exec '"$INSTDIR\bin\doom-emacs.cmd"'
FunctionEnd

Function WslToggle
  Pop $0
  ${NSD_GetState} $WslCheck $0
  EnableWindow $WslCombo $0
FunctionEnd

Function WslCreate
  !insertmacro MUI_HEADER_TEXT "WSL integration (optional)" "Use Windows Doom and its GUI from a selected Linux distribution."
  nsDialogs::Create 1018
  Pop $0
  ${NSD_CreateCheckbox} 0 0 100% 18u "Enable Windows Doom commands in WSL"
  Pop $WslCheck
  ${NSD_OnClick} $WslCheck WslToggle
  ${NSD_CreateLabel} 0 25u 100% 12u "Choose a registered WSL distribution:"
  Pop $0
  ${NSD_CreateDropList} 0 40u 100% 100u ""
  Pop $WslCombo
  nsExec::ExecToLog '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -NonInteractive -File "$PLUGINSDIR\wsl-integration.ps1" -List -SelectionRoot "$INSTDIR" -SelectionRegistryKey "HKCU:\${REGKEY}" -OutFile "$PLUGINSDIR\wsl-list.txt"'
  Pop $0
  ${If} $0 == 0
    FileOpen $0 "$PLUGINSDIR\wsl-list.txt" r
    FileSeek $0 2 SET
    ${Do}
      ClearErrors
      FileReadUTF16LE $0 $1
      ${If} ${Errors}
        ${ExitDo}
      ${EndIf}
      ${TrimNewLines} $1 $1
      ${If} $1 != ""
        ${NSD_CB_AddString} $WslCombo $1
      ${EndIf}
    ${Loop}
    FileClose $0
  ${EndIf}
  ${If} $WslSelectionLoaded == ""
    ${If} $WslDistro == ""
      ReadINIStr $WslDistro "$PLUGINSDIR\wsl-list.txt.ini" "selection" "Suggested"
    ${EndIf}
    StrCpy $WslSelectionLoaded "1"
  ${EndIf}
  ${If} $WslDistro != ""
    ${NSD_Check} $WslCheck
    ${NSD_CB_SelectString} $WslCombo $WslDistro
  ${Else}
    EnableWindow $WslCombo 0
  ${EndIf}
  ReadINIStr $1 "$PLUGINSDIR\wsl-list.txt.ini" "selection" "Status"
  nsDialogs::CreateControl EDIT ${DEFAULT_STYLES}|${WS_TABSTOP}|${ES_MULTILINE}|${ES_AUTOVSCROLL}|${ES_READONLY}|${WS_VSCROLL} ${WS_EX_CLIENTEDGE} 0 60u 100% 36u "$1"
  Pop $0
  ${NSD_Edit_SetReadOnly} $0 1
  nsDialogs::CreateControl EDIT ${DEFAULT_STYLES}|${WS_TABSTOP}|${ES_MULTILINE}|${ES_AUTOVSCROLL}|${ES_READONLY}|${WS_VSCROLL} ${WS_EX_CLIENTEDGE} 0 100u 100% 48u "Adds doom and doom-wsl under ~/.local/share/doom-windows/ and marked Bash/Zsh PATH blocks. Restart the shell afterward. Existing integrations are kept when this option is cleared.$\r$\n$\r$\nDoom, packages, configuration and the GUI server run in Windows. doom-wsl --wait supports editor workflows. WSL terminal frames are not supported."
  Pop $0
  ${NSD_Edit_SetReadOnly} $0 1
  nsDialogs::Show
FunctionEnd

Function WslLeave
  ${NSD_GetState} $WslCheck $0
  StrCpy $WslDistro ""
  ${If} $0 == ${BST_CHECKED}
    ${NSD_GetText} $WslCombo $WslDistro
    ${If} $WslDistro == ""
      MessageBox MB_ICONEXCLAMATION "Choose a WSL distribution, or clear the integration checkbox. Install a user distribution first if the list is empty."
      Abort
    ${EndIf}
  ${EndIf}
FunctionEnd

Function MaintenanceCreate
  ${If} $ExistingInstall == ""
    Abort
  ${EndIf}
  !insertmacro MUI_HEADER_TEXT "Existing installation" "Reinstall or remove Doom Emacs."
  nsDialogs::Create 1018
  Pop $MaintenanceDialog
  ${If} $MaintenanceDialog == error
    Abort
  ${EndIf}
  !insertmacro LocationField "Installed application (select text, Ctrl+C):" "$ExistingInstall" 0u 12u
  !insertmacro LocationField "$ConfigStatus" "$ConfigPath" 30u 42u
  ${If} $LegacyConfigPath != ""
    !insertmacro LocationField "Other existing configuration (kept):" "$LegacyConfigPath" 60u 72u
  ${ElseIf} $WslCommandPath != ""
    !insertmacro LocationField "Managed WSL command directory:" "$WslCommandPath" 60u 72u
  ${EndIf}
  ${NSD_CreateRadioButton} 0 96u 100% 18u "Reinstall / repair this installation"
  Pop $0
  ${NSD_Check} $0
  ${NSD_CreateRadioButton} 0 116u 100% 18u "Uninstall Doom Emacs and its bundled tools"
  Pop $RemoveRadio
  ${NSD_CreateLabel} 0 140u 100% 18u "Configuration stays in place. No backup copy or automatic migration is made."
  Pop $0
  nsDialogs::Show
FunctionEnd

Function ConfigLocationCreate
  ${If} $ExistingInstall != ""
    Abort
  ${EndIf}
  !insertmacro MUI_HEADER_TEXT "Configuration folders" "Review where your configuration lives."
  nsDialogs::Create 1018
  Pop $0
  !insertmacro LocationField "$ConfigStatus (select text, Ctrl+C)" "$ConfigPath" 0u 12u
  ${If} $LegacyConfigPath != ""
    !insertmacro LocationField "Other existing configuration (kept):" "$LegacyConfigPath" 36u 48u
  ${EndIf}
  ${NSD_CreateMLText} 0 76u 100% 78u "$ConfigSummary"
  Pop $0
  ${NSD_Edit_SetReadOnly} $0 1
  nsDialogs::Show
FunctionEnd

Function un.onInit
  !insertmacro LoadConfigSummary "$INSTDIR"
FunctionEnd

Function un.ConfigLocationCreate
  !insertmacro MUI_HEADER_TEXT "Remove Doom Emacs" "Your configuration remains in the folders shown below."
  nsDialogs::Create 1018
  Pop $0
  !insertmacro LocationField "Application to remove (select text, Ctrl+C):" "$INSTDIR" 0u 12u
  !insertmacro LocationField "$ConfigStatus" "$ConfigPath" 31u 43u
  ${If} $LegacyConfigPath != ""
    !insertmacro LocationField "Other existing configuration (kept):" "$LegacyConfigPath" 62u 74u
  ${EndIf}
  ${If} $WslCommandPath != ""
    !insertmacro LocationField "Managed WSL command directory to remove:" "$WslCommandPath" 93u 105u
  ${EndIf}
  ${NSD_CreateLabel} 0 128u 100% 27u "Configuration and preexisting fonts stay in place. Bundled tools and owned Windows/WSL PATH and font registrations are removed."
  Pop $0
  GetDlgItem $0 $HWNDPARENT 1
  SendMessage $0 ${WM_SETTEXT} 0 "STR:Uninstall"
  nsDialogs::Show
FunctionEnd

Function MaintenanceLeave
  ${NSD_GetState} $RemoveRadio $0
  ${If} $0 == ${BST_CHECKED}
    MessageBox MB_YESNO|MB_ICONQUESTION "Remove Doom Emacs and its bundled tools from:$\r$\n$ExistingInstall$\r$\n$\r$\n$ConfigSummary" IDYES +2
    Abort
    Call RemoveExistingInstall
  ${EndIf}
FunctionEnd

Function RemoveExistingInstall
  Call PrepareExistingInstall
  nsExec::ExecToLog '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -NonInteractive -File "$PLUGINSDIR\uninstall-doom.ps1" -InstallRoot "$ExistingInstall" -RegistryKey "HKCU:\${REGKEY}" -Yes'
  Pop $0
  ${If} $0 != 0
    MessageBox MB_ICONSTOP "Removal failed. Close Emacs and try again. The installation metadata has been kept for retry." /SD IDOK
    SetErrorLevel 1
    Quit
  ${EndIf}
  MessageBox MB_ICONINFORMATION "Doom Emacs was removed.$\r$\n$\r$\n$ConfigSummary" /SD IDOK
  SetErrorLevel 0
  Quit
FunctionEnd

Function PrepareExistingInstall
  ; Recovery only records recognized payload paths; unknown files are kept.
  ${IfNot} ${FileExists} "$ExistingInstall\install-manifest.json"
    nsExec::ExecToLog '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -NonInteractive -File "$PLUGINSDIR\repair-doom.ps1" -InstallRoot "$ExistingInstall" -RegistryKey "HKCU:\${REGKEY}"'
    Pop $0
    ${If} $0 != 0
      MessageBox MB_ICONSTOP "The incomplete installation could not be recovered. No files were removed." /SD IDOK
      SetErrorLevel 1
      Quit
    ${EndIf}
  ${EndIf}
FunctionEnd

Function .onInit
  StrCpy $EngineOptions ""
  ${GetParameters} $R0
  ClearErrors
  ${GetOptions} $R0 "/NoShortcuts" $R1
  ${IfNot} ${Errors}
    StrCpy $EngineOptions " -NoShortcut"
  ${EndIf}
  ; ARM64 must be rejected explicitly and FIRST. ${RunningX64} is true on ARM64
  ; Windows because x64 code runs there under emulation, so checking it alone lets
  ; an ARM machine install a payload of x86_64 binaries -- Emacs, git, ripgrep, fd
  ; and a native-compilation toolchain -- which would at best run slowly emulated
  ; and at worst fail opaquely. Every bundled binary here is x86_64.
  ${If} ${IsNativeARM64}
    MessageBox MB_ICONSTOP "${PRODUCT} does not support ARM64 Windows.$\r$\n$\r$\nEverything in this installer is built for x86_64. An ARM64 build would need a separately compiled Emacs and toolchain." /SD IDOK
    Abort
  ${EndIf}

  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "${PRODUCT} requires 64-bit Windows." /SD IDOK
    Abort
  ${EndIf}

  ; Windows 10 or newer. Below that the bundled Emacs' UCRT dependency and the
  ; shims' assumptions stop being safe to claim, and those releases are long
  ; out of support.
  ${IfNot} ${AtLeastWin10}
    MessageBox MB_ICONSTOP "${PRODUCT} requires Windows 10 or Windows 11." /SD IDOK
    Abort
  ${EndIf}


  InitPluginsDir
  ; Include management scripts directly from source, even for compile-only builds
  ; using an older staging tree. Missing scripts must fail the build.
  SetOutPath "$PLUGINSDIR"
  File "install-doom.ps1"
  File "uninstall-doom.ps1"
  File "env-path.ps1"
  File "repair-doom.ps1"
  File "native-process.ps1"
  File "wsl-integration.ps1"
  File "package-sync.ps1"
  File "font-integration.ps1"
  SetOutPath "$PLUGINSDIR\bridge"
  File /r "files\bridge\*.*"
  SetOutPath "$PLUGINSDIR"

  ReadRegStr $0 HKCU "${REGKEY}" "InstallLocation"
  ${If} $0 == ""
    ; The original broken build wrote only UninstallString, no InstallLocation.
    ReadRegStr $0 HKCU "${REGKEY}" "UninstallString"
    StrCpy $1 $0 1
    ${If} $1 == '$\"'
      StrCpy $0 $0 -1 1
      ${GetParent} $0 $0
    ${Else}
      StrCpy $0 $INSTDIR
    ${EndIf}
  ${EndIf}
  ${If} ${FileExists} "$0\install-manifest.json"
    StrCpy $ExistingInstall $0
    StrCpy $INSTDIR $0
  ${ElseIf} ${FileExists} "$0\bin\doom-env.cmd"
  ${AndIf} ${FileExists} "$0\.staged.json"
    StrCpy $ExistingInstall $0
    StrCpy $INSTDIR $0
  ${EndIf}

  !insertmacro LoadConfigSummary "$INSTDIR"

  ${GetParameters} $R0
  ${GetOptions} $R0 "/WslDistro=" $WslDistro

  ; The same removal path is available for unattended maintenance.
  ${GetParameters} $R0
  ClearErrors
  ${GetOptions} $R0 "/Uninstall" $R1
  ${IfNot} ${Errors}
    ${If} $ExistingInstall == ""
      MessageBox MB_ICONSTOP "No Doom Emacs installation was found at $INSTDIR." /SD IDOK
      SetErrorLevel 1
      Quit
    ${EndIf}
    Call RemoveExistingInstall
  ${EndIf}
FunctionEnd

; ---------------------------------------------------------------------------

; Optional components. Everything except the payload itself is a choice, and each
; maps to a flag on install-doom.ps1 so the .exe and a standalone run of the
; script stay capable of exactly the same things.
; Optional components, all selected by default. Each maps to a flag on
; install-doom.ps1, so the .exe and a standalone run of the script stay capable
; of exactly the same things rather than the GUI growing options the script lacks.
;
; These are markers only -- the work happens in SecMain, which reads their state.
; Selections are made on the components page before any section runs, so SecMain
; can rely on them despite executing first.
Section "Doom Emacs" SecMain
  SectionIn RO

  ${If} $ExistingInstall != ""
    Call PrepareExistingInstall
  ${EndIf}

  ; Directory-page callbacks do not run under /S, so enforce the ownership guard
  ; again here before the first payload file is extracted.
  Call GuardInstallPath

  ; Preserve whether the root existed before extraction. Once File /r runs the
  ; PowerShell engine cannot infer this safely from an InPlace payload.
  StrCpy $RootOwnerArg ""
  ${DirState} "$INSTDIR" $R0
  ${If} $R0 == -1
    StrCpy $RootOwnerArg " -OwnInstallRoot"
  ${EndIf}

  DetailPrint "Unpacking Emacs, Doom and dependencies (about 1.4 GB)..."
  SetOutPath "$INSTDIR"
  File /r "${STAGING}\*.*"
  ; Always overwrite any stale scripts shipped in the staging tree.
  CopyFiles /SILENT "$PLUGINSDIR\*.ps1" "$INSTDIR"
  CreateDirectory "$INSTDIR\bridge"
  CopyFiles /SILENT "$PLUGINSDIR\bridge\*.*" "$INSTDIR\bridge"

SectionEnd

; Marker sections. They carry no instructions; the configure section below reads
; whether each is selected and passes the matching flag to the install engine.
; All default to selected -- note the absence of /o, which would invert that.
;
; They must be declared BEFORE the code that reads them: a section's index is
; defined by its declaration, so referencing ${SecAOT} earlier expands to nothing
; and SectionGetFlags fails with a bare usage error naming neither the section
; nor the line.
Section /o "Native pre-compilation (slower setup, optional)" SecAOT
SectionEnd

Section "Meslo and Nerd Icons fonts (current user)" SecFonts
SectionEnd

Section "Desktop shortcut" SecDesktop
SectionEnd

Section "Start Menu shortcut" SecStartMenu
SectionEnd

Section "Add doom to PATH" SecPath
SectionEnd

Function InstallSummaryCreate
  !insertmacro MUI_HEADER_TEXT "Review installation" "Check locations and integration changes before installing."
  nsDialogs::Create 1018
  Pop $0
  !insertmacro LocationField "Program and dependencies (select text, Ctrl+C):" "$INSTDIR" 0u 10u
  !insertmacro LocationField "Windows packages and caches:" "$INSTDIR\doom\.local" 26u 36u
  !insertmacro LocationField "Configured folder:" "$ConfigPath" 52u 62u
  ${If} ${SectionIsSelected} ${SecPath}
    !insertmacro LocationField "Entry added to Windows user PATH:" "$INSTDIR\bin" 78u 88u
  ${EndIf}
  StrCpy $1 ""
  ${If} $WslDistro != ""
    StrCpy $1 "WSL distribution: $WslDistro. Adds Windows doom and doom-wsl commands and marked Linux shell PATH blocks.$\r$\n"
  ${EndIf}
  ${If} ${SectionIsSelected} ${SecFonts}
    StrCpy $1 "$1Fonts: $INSTDIR\fonts. Registers under HKCU\Software\Microsoft\Windows NT\CurrentVersion\Fonts; existing families kept.$\r$\n"
  ${EndIf}
  ; Keep the footer inside the 150-DU page. Wrap long distro names and allow
  ; scrolling at larger text sizes instead of clipping a fixed-height label.
  nsDialogs::CreateControl EDIT ${DEFAULT_STYLES}|${WS_TABSTOP}|${ES_MULTILINE}|${ES_AUTOVSCROLL}|${ES_READONLY}|${WS_VSCROLL} ${WS_EX_CLIENTEDGE} 0 106u 100% 44u "$1Uninstall through setup or Windows Settings. Deleting the folder leaves integration behind. Provided AS IS, without warranty; see LICENSE and bundled licenses."
  Pop $0
  nsDialogs::Show
FunctionEnd

; Hidden (leading dash) and last, so it runs once every choice above is known.
Section "-Configure" SecConfigure
  ; Translate the component choices into engine flags.
  StrCpy $R0 ""
  ${IfNot} ${SectionIsSelected} ${SecFonts}
    StrCpy $R0 "$R0 -NoFonts"
  ${EndIf}
  ${If} $WslDistro != ""
    StrCpy $R0 '$R0 -WslDistro "$WslDistro"'
  ${EndIf}
  ${If} ${SectionIsSelected} ${SecAOT}
    StrCpy $R0 "$R0 -AOT"
  ${Else}
    StrCpy $R0 "$R0 -NoAOT"
  ${EndIf}
  ${IfNot} ${SectionIsSelected} ${SecPath}
    StrCpy $R0 "$R0 -NoPathUpdate"
  ${EndIf}
  ${IfNot} ${SectionIsSelected} ${SecDesktop}
    StrCpy $R0 "$R0 -NoDesktopShortcut"
  ${EndIf}
  ${IfNot} ${SectionIsSelected} ${SecStartMenu}
    StrCpy $R0 "$R0 -NoStartMenuShortcut"
  ${EndIf}

  ; Hand off to the install engine. It owns PATH, the shortcuts, the Add/Remove
  ; registration, the manifest and the package sync -- so a standalone run of the
  ; same script produces a byte-identical footprint.
  ;
  ; Sync runs HERE rather than being offered afterwards. Doom without it is not a
  ; slimmer Doom, it is a broken one: doom-modules is never defined and the first
  ; launch dies with "(void-variable doom-modules)", which tells the user nothing.
  ; An installer that finishes and leaves the program unable to start has not
  ; finished. It is the slow part, which is why the details pane is open.
  DetailPrint "Checking required packages and reusing compatible builds."
  DetailPrint "First-time setup downloads packages; repeated setup uses the existing package tree."
  ${If} ${SectionIsSelected} ${SecAOT}
    DetailPrint "Pre-compiling packages as well, so expect roughly twice that."
  ${EndIf}
  nsExec::ExecToLog '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -NonInteractive -File "$INSTDIR\install-doom.ps1" -SourceMode InPlace -InstallRoot "$INSTDIR" -RegistryKey "HKCU:\${REGKEY}" -Force$RootOwnerArg$R0$EngineOptions'
  Pop $0
  ${If} $0 != 0
    DetailPrint "Configuration step reported exit code $0"
    MessageBox MB_ICONEXCLAMATION "Files were copied, but setup is incomplete (code $0).$\r$\n$\r$\nSee the details above for the failed step and run setup again to repair it.$\r$\n$\r$\nFor package synchronization errors, run doom sync and doom doctor in a Windows terminal." /SD IDOK
    SetErrorLevel 1
    Abort
  ${EndIf}

  ${IfNot} ${FileExists} "$INSTDIR\install-manifest.json"
    MessageBox MB_ICONSTOP "Setup did not create its installation manifest. Configuration is incomplete." /SD IDOK
    SetErrorLevel 1
    Abort
  ${EndIf}

  WriteUninstaller "$INSTDIR\Uninstall.exe"

  ; install-doom.ps1 wrote the Add/Remove entry pointing at uninstall-doom.ps1.
  ; Repoint it at Uninstall.exe so Windows' own Uninstall button behaves the way
  ; people expect; the PowerShell uninstaller still works directly, which is what
  ; a standalone install relies on.
  WriteRegStr HKCU "${REGKEY}" "UninstallString" '"$INSTDIR\Uninstall.exe"'
  WriteRegStr HKCU "${REGKEY}" "QuietUninstallString" '"$INSTDIR\Uninstall.exe" /S'
SectionEnd

!insertmacro MUI_FUNCTION_DESCRIPTION_BEGIN
  !insertmacro MUI_DESCRIPTION_TEXT ${SecMain}      "Emacs 31.1, Doom, git, ripgrep, fd and a native-compilation toolchain. Everything needed to run, with no other downloads. Required."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecAOT}       "Natively compile every package during installation, so Doom is fast from the very first launch. Leave this off and packages compile gradually in the background over your first few sessions instead. Roughly doubles how long installation takes."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecDesktop}   "Put a Doom Emacs shortcut on your Desktop."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecStartMenu} "Put a Doom Emacs shortcut in your Start Menu."
  !insertmacro MUI_DESCRIPTION_TEXT ${SecPath}      "Add the doom command to your PATH, so 'doom sync' and 'doom doctor' work in any new terminal."
!insertmacro MUI_FUNCTION_DESCRIPTION_END

; ---------------------------------------------------------------------------

Section "Uninstall"
  ; Delegate to the PowerShell uninstaller so there is exactly one implementation
  ; of what removal means. -Yes because the NSIS confirm page already asked;
  ; default mode, so the user's config survives. Removing that too is the
  ; -Full flag, which is deliberately not reachable from this button.
  ${If} ${FileExists} "$INSTDIR\uninstall-doom.ps1"
    nsExec::ExecToLog '"$SYSDIR\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -NonInteractive -File "$INSTDIR\uninstall-doom.ps1" -InstallRoot "$INSTDIR" -RegistryKey "HKCU:\${REGKEY}" -Yes'
    Pop $0
    DetailPrint "uninstall-doom.ps1 exited with $0"
    ${If} $0 != 0
      MessageBox MB_ICONSTOP "${PRODUCT} could not be removed completely.$\r$\n$\r$\nClose Emacs and run uninstall again." /SD IDOK
      SetErrorLevel $0
      Abort
    ${EndIf}
  ${Else}
    MessageBox MB_ICONSTOP "The ownership manifest uninstaller is missing, so setup will not guess which files are safe to remove." /SD IDOK
    SetErrorLevel 1
    Abort
  ${EndIf}

  ; The PowerShell uninstaller schedules its own deferred cleanup for the tree it
  ; is running from, but Uninstall.exe itself is held open by Windows until we
  ; exit, so let NSIS handle that one file.
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"

  MessageBox MB_ICONINFORMATION|MB_OK \
    "${PRODUCT} has been removed.$\r$\n$\r$\n$ConfigSummary" /SD IDOK
SectionEnd
