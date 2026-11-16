@echo off
rem ---------------------------------------------------------------------------
rem Shared environment for every Doom entry point. Both doom.cmd and
rem doom-emacs.cmd call this, so the sealed environment is defined exactly once
rem rather than duplicated and left to drift.
rem
rem Everything here is per-process. Nothing is written to the user's environment,
rem which is why the installer needs no system-wide HOME variable and no reboot,
rem and why uninstalling leaves nothing to unset.
rem ---------------------------------------------------------------------------

rem Resolve the install root from this script's own location rather than baking an
rem absolute path in, so the tree stays relocatable.
pushd "%~dp0.." || exit /b 1
set "DOOM_ROOT=%CD%"
popd

set "EMACSDIR=%DOOM_ROOT%\doom"
set "DOOMDIR=%USERPROFILE%\.config\doom"
set "HOME=%USERPROFILE%"

rem Bundled tools first, so a sealed install never silently picks up a different
rem Emacs, git or ripgrep that happens to be on the user's PATH.
set "PATH=%DOOM_ROOT%\emacs\bin;%DOOM_ROOT%\deps\git\cmd;%DOOM_ROOT%\deps\git\usr\bin;%DOOM_ROOT%\deps\rg;%DOOM_ROOT%\deps\fd;%PATH%"

rem ---------------------------------------------------------------------------
rem Storage mode, decided by whether the install tree is writable.
rem
rem With DOOMPROFILE unset, Doom keeps all data, cache and state under
rem $EMACSDIR\.local (see lisp/doom.el:202-256), which makes a per-user install one
rem self-contained, removable tree.
rem
rem That is exactly wrong for a machine-wide install: Program Files is read-only
rem for normal users, so Doom would fail to write its own package tree. Doom
rem already handles this -- with DOOMPROFILE set, the Windows branch of the same
rem code routes data/cache/state to %LOCALAPPDATA%\doomemacs, which is per-user
rem and writable.
rem
rem So rather than record the install scope somewhere and risk it going stale,
rem detect it: try to write, and pick the mode that works.
rem ---------------------------------------------------------------------------
rem Probe %EMACSDIR% itself, not %EMACSDIR%\.local. The latter does not exist until
rem the first sync, so a fresh install would fail the probe for the wrong reason and
rem wrongly conclude the tree was read-only.
set "DOOM_PROBE=%EMACSDIR%\.doom-write-probe"
2>nul (
    >>"%DOOM_PROBE%" echo. && set "DOOM_TREE_WRITABLE=1"
)
if defined DOOM_TREE_WRITABLE (
    del "%DOOM_PROBE%" >nul 2>&1
) else (
    rem Machine-wide install: keep per-user state out of the read-only tree.
    set "DOOMPROFILE=_default"
)
set "DOOM_PROBE="
set "DOOM_TREE_WRITABLE="

exit /b 0
