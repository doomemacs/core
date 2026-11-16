$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
if (-not $here) { $here = Split-Path -Parent $MyInvocation.MyCommand.Path }
$installer = Join-Path $here '..\install-doom.ps1'

$root = Join-Path $env:TEMP ('doom-guard-test-' + [guid]::NewGuid().ToString('N'))
$payload = Join-Path $env:TEMP ('doom-guard-payload-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $root | Out-Null
New-Item -ItemType Directory -Path $payload | Out-Null
Set-Content -LiteralPath (Join-Path $root 'precious.txt') -Value 'do not delete' -Encoding ascii

try {
    $out = ''
    try {
        $out = & $installer -InstallRoot $root -SourceMode Staging -SourcePath $payload -Silent *>&1 | Out-String
    } catch {
        $out = $_.Exception.Message
    }
    if ($out -notmatch 'not empty') { throw "guard did not fire with the expected message`n$out" }
    if (-not (Test-Path (Join-Path $root 'precious.txt'))) { throw 'guard test file vanished' }

    Write-Host 'PASS: install refuses a non-empty folder that is not a Doom install.'

    # MUI page callbacks are skipped by silent NSIS installs. The guard must also
    # run inside SecMain, before extraction starts.
    $nsi = Get-Content -LiteralPath (Join-Path $here '..\doom.nsi') -Raw
    $section = $nsi.IndexOf('Section "Doom Emacs" SecMain')
    $guard = $nsi.IndexOf('Call GuardInstallPath', $section)
    $extract = $nsi.IndexOf('File /r', $section)
    if ($section -lt 0 -or $guard -lt $section -or $extract -lt 0 -or $guard -gt $extract) {
        throw 'NSIS silent-install guard is missing or runs after payload extraction'
    }
    Write-Host 'PASS: NSIS enforces the ownership guard before extraction, including /S.'

    if ($nsi -notmatch 'StrCpy \$RootOwnerArg " -OwnInstallRoot"' -or
        $nsi -notmatch '-Force\$RootOwnerArg\$R0') {
        throw 'NSIS does not pass pre-extraction root ownership to the install engine'
    }

    # Standalone installs must carry their own engine, uninstaller, and PATH helper.
    $engine = Get-Content -LiteralPath $installer -Raw
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($installer, [ref]$tokens, [ref]$parseErrors)
    $parameterNames = @($ast.ParamBlock.Parameters.Name.VariablePath.UserPath)
    if ($parameterNames -notcontains 'OwnInstallRoot') {
        throw 'NSIS passes -OwnInstallRoot but the install engine does not declare it'
    }
    $copyLoop = [regex]::Match(
        $engine,
        '(?s)foreach \(\$name in @\((?<files>.*?)\)\) \{\s*Copy-Item \(Join-Path \$scriptDir \$name\)'
    )
    if (-not $copyLoop.Success) { throw 'standalone management-script copy loop is missing' }
    foreach ($name in @('install-doom.ps1', 'uninstall-doom.ps1', 'env-path.ps1', 'repair-doom.ps1')) {
        if ($copyLoop.Groups['files'].Value -notmatch [regex]::Escape("'$name'")) {
            throw "standalone install does not copy $name into the install root"
        }
    }
    if ($engine -notmatch '\$previousRootEntry' -or $engine -notmatch '\$previousRootEntry\[0\]\.state') {
        throw 'reinstall does not inherit install-root ownership from the prior manifest'
    }
    Write-Host 'PASS: standalone installs copy all management scripts.'
} finally {
    Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $payload -Recurse -Force -ErrorAction SilentlyContinue
}
