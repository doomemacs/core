function Get-DoomBridgeEnvironment([string]$Root, [string]$DoomDir) {
    return @{
        HOME = $env:USERPROFILE
        EMACSDIR = (Join-Path $Root 'doom')
        EMACS = (Join-Path $Root 'emacs\bin\emacs.exe').Replace('\', '/')
        DOOMDIR = $DoomDir
        DOOMPROFILE = $null
        ALTERNATE_EDITOR = $null
        PATH = ((Join-Path $Root 'emacs\bin') + ';' + (Join-Path $Root 'deps\git\cmd') + ';' +
            (Join-Path $Root 'deps\git\usr\bin') + ';' + (Join-Path $Root 'deps\rg') + ';' +
            (Join-Path $Root 'deps\fd') + ';' + $env:Path)
    }
}
