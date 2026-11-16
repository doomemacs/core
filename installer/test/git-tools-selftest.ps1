[CmdletBinding()]
param([Parameter(Mandatory=$true)][string]$InstallRoot, [switch]$CheckMagit)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '..\native-process.ps1')
. (Join-Path $PSScriptRoot '..\files\bridge\environment.ps1')
$environment=Get-DoomBridgeEnvironment -Root $InstallRoot -DoomDir (Join-Path $InstallRoot 'test-config')
# No host Git/Unix tools in PATH: test exactly what the bundle supplies.
$environment.PATH=((Join-Path $InstallRoot 'deps\git\cmd')+';'+(Join-Path $InstallRoot 'deps\git\usr\bin')+';'+$env:SystemRoot+'\System32')
$git=Join-Path $InstallRoot 'deps\git\cmd\git.exe'
$result=Invoke-DoomNativeProcess -File $git -Arguments @('-c','alias.X=!x() { which "$1" | cygpath -mf -; }; x','X','git') -Environment $environment -WorkingDirectory $InstallRoot
if ($result.ExitCode -ne 0 -or $result.Error -or -not (Test-Path -LiteralPath $result.Output.Trim())) { throw "Magit's exact discovery alias failed: $($result.Error)" }
$result=Invoke-DoomNativeProcess -File $git -Arguments @('-c','alias.P=!cygpath -wp "$PATH"','P') -Environment $environment -WorkingDirectory $InstallRoot
if ($result.ExitCode -or $result.Error -or $result.Output -notmatch ';') { throw "Magit's PATH conversion failed: $($result.Error)" }
Write-Host 'PASS: actual Magit Git discovery and PATH conversion work with bundled tools only.'
if ($CheckMagit) {
    $build=@(Get-ChildItem -LiteralPath (Join-Path $InstallRoot 'doom\.local\straight') -Directory -Filter 'build-*' | Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'magit\magit-git.el') })
    if (-not $build.Count) { throw 'A synced package tree containing Magit is required.' }
    $path=$build[0].FullName.Replace('\','/').Replace('"','\"')
    $form='(progn (dolist (dir (directory-files "'+$path+'" t "^[^.]") ) (when (file-directory-p dir) (add-to-list (quote load-path) dir))) (require (quote magit-git)) (unless (file-executable-p magit-git-executable) (error "Invalid Magit Git executable: %s" magit-git-executable)) (princ magit-git-executable))'
    $environment.PATH=(Join-Path $InstallRoot 'emacs\bin')+';'+$environment.PATH
    $result=Invoke-DoomNativeProcess -File (Join-Path $InstallRoot 'emacs\bin\emacs.exe') -Arguments @('-Q','--batch','--eval',$form) -Environment $environment -WorkingDirectory $InstallRoot
    if ($result.ExitCode -or $result.Error -match 'Could not run Git') { throw "Real Magit initialization failed: $($result.Error)" }
    Write-Host 'PASS: real Windows Emacs initializes installed Magit with an executable Git path and no Git warning.'
}
