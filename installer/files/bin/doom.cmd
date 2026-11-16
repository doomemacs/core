@echo off
setlocal EnableExtensions
rem ---------------------------------------------------------------------------
rem Doom Emacs CLI shim. The only thing the installer puts on PATH.
rem
rem The sealed environment lives in doom-env.cmd, shared with the GUI launcher.
rem ---------------------------------------------------------------------------

call "%~dp0doom-env.cmd" || (
    echo Error: cannot initialise the Doom environment.
    echo The installation looks incomplete. Try reinstalling Doom Emacs.
    exit /b 1
)

set "SH=%DOOM_ROOT%\deps\git\usr\bin\sh.exe"
if not exist "%SH%" (
    echo Error: bundled shell missing at "%SH%"
    echo The installation looks incomplete. Try reinstalling Doom Emacs.
    exit /b 1
)
if not exist "%EMACSDIR%\bin\doom" (
    echo Error: Doom not found at "%EMACSDIR%\bin\doom"
    echo The installation looks incomplete. Try reinstalling Doom Emacs.
    exit /b 1
)

rem Run bin/doom through the bundled sh rather than bin/doom.ps1. The sh branch of
rem Doom's CLI restart machinery (lisp/doom-cli.el:1199) is considerably more
rem mature than the pwsh branch, and bundling MinGit means a real shell is always
rem present regardless of what the user has installed.
"%SH%" "%EMACSDIR%/bin/doom" %*
exit /b %ERRORLEVEL%
