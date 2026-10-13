# Liga o emulador Android (tablet deitado) e espera o boot terminar.
# Se já houver um emulador/aparelho conectado, não faz nada.
#
#   .\dev\iniciar-emulador.ps1
#   .\dev\iniciar-emulador.ps1 -Avd Medium_Phone_API_37.0
param([string]$Avd = 'Medium_Tablet')

$sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$adb = Join-Path $sdk 'platform-tools\adb.exe'
$emulador = Join-Path $sdk 'emulator\emulator.exe'

$conectados = & $adb devices | Select-String -Pattern '\tdevice$'
if ($conectados) {
    Write-Host "Dispositivo já conectado: $($conectados[0].Line.Split("`t")[0])" -ForegroundColor Green
    return
}

Write-Host "Ligando o emulador $Avd..." -ForegroundColor Cyan
Start-Process -FilePath $emulador -ArgumentList '-avd', $Avd, '-no-boot-anim' -WindowStyle Minimized

& $adb wait-for-device
do {
    Start-Sleep -Seconds 2
    $boot = (& $adb shell getprop sys.boot_completed 2>$null) -join ''
} until ($boot.Trim() -eq '1')
Write-Host 'Emulador pronto.' -ForegroundColor Green
