# Roda o app no emulador (ou aparelho) com hot reload. Liga o emulador se precisar.
#
#   .\dev\iniciar-app.ps1                      # primeiro dispositivo conectado
#   .\dev\iniciar-app.ps1 -Dispositivo emulator-5554
#   .\dev\iniciar-app.ps1 -Limpar              # apaga os dados do app (volta ao pareamento)
#
# No terminal do flutter run: r = hot reload · R = hot restart · q = sair.
param(
    [string]$Dispositivo = '',
    [switch]$Limpar
)

$flutter = Join-Path $env:USERPROFILE 'flutter\bin\flutter.bat'
$adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
$app = Split-Path $PSScriptRoot -Parent

if (-not $Dispositivo) { & (Join-Path $PSScriptRoot 'iniciar-emulador.ps1') }

if ($Limpar) {
    $alvo = if ($Dispositivo) { @('-s', $Dispositivo) } else { @() }
    & $adb @alvo shell pm clear br.com.forven.cardapio_digital
}

Push-Location $app
try {
    if ($Dispositivo) { & $flutter run -d $Dispositivo } else { & $flutter run }
} finally {
    Pop-Location
}
