@echo off
setlocal EnableExtensions
rem ---------------------------------------------------------------------------
rem Doom Emacs GUI launcher.
rem
rem Shares its environment with the CLI shim via doom-env.cmd, then hands off to
rem runemacs.exe (not emacs.exe) because runemacs does not attach a console.
rem
rem KNOWN WART: launching a GUI app from a .cmd still flashes a console briefly.
rem Shortcuts are created minimized to reduce it; the real fix is a small compiled
rem launcher stub. See installer/README.org for known limitations.
rem ---------------------------------------------------------------------------

call "%~dp0doom-env.cmd" || (
    echo Error: cannot initialise the Doom environment.
    echo The installation looks incomplete. Try reinstalling Doom Emacs.
    exit /b 1
)

set "RUNEMACS=%DOOM_ROOT%\emacs\bin\runemacs.exe"
if not exist "%RUNEMACS%" (
    echo Error: Emacs not found at "%RUNEMACS%"
    echo The installation looks incomplete. Try reinstalling Doom Emacs.
    exit /b 1
)

rem Refuse to launch an unsynced install. Without `doom sync` the package tree does
rem not exist, doom-modules is never defined, and Emacs comes up with a useless
rem "(void-variable doom-modules)" that gives no clue what is wrong. Better to say
rem so plainly and offer to fix it.
dir /b "%EMACSDIR%\.local\straight\build-*" >nul 2>&1
if errorlevel 1 (
    echo.
    echo   Doom's packages are not installed yet, so Emacs would start broken.
    echo.
    echo   This normally happens during installation. It can be missing if setup
    echo   was interrupted, or if Doom was installed with sync skipped.
    echo.
    choice /C YN /N /M "  Download and compile them now? This takes several minutes. [Y/N] "
    if errorlevel 2 (
        echo   Cancelled. Run 'doom sync' when ready.
        exit /b 1
    )
    call "%DOOM_ROOT%\bin\doom.cmd" sync
    if errorlevel 1 (
        echo.
        echo   Sync failed. Run 'doom doctor' to see why.
        pause
        exit /b 1
    )
)

rem --init-directory is load-bearing, for two separate reasons.
rem
rem 1. CORRECTNESS. Doom lives at %DOOM_ROOT%\doom, which is not Emacs' default
rem    user-emacs-directory. Without this flag runemacs loads ~/.emacs.d and starts
rem    STOCK Emacs, silently ignoring Doom entirely. The CLI does not need it
rem    because bin/doom loads Doom explicitly.
rem
rem 2. CONTAINMENT. The native-comp eln write location derives from
rem    user-emacs-directory at startup, so without this flag Emacs writes trampoline
rem    .eln files into %USERPROFILE%\.emacs.d\eln-cache, outside the install tree
rem    where the uninstaller would not think to look. Doom redirects
rem    native-comp-eln-load-path itself (lisp/doom.el:457) but too late to catch
rem    trampolines compiled during early startup.
rem
rem Requires Emacs 29+; we bundle 31.1.
if exist "%DOOM_ROOT%\wsl-bridge.json" (
    start "" "%RUNEMACS%" --init-directory="%EMACSDIR%" --load="%DOOM_ROOT%\bridge\server.el" %*
) else (
    start "" "%RUNEMACS%" --init-directory="%EMACSDIR%" %*
)
exit /b 0
