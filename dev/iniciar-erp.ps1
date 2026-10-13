# Sobe o Forven ERP local (API do app + painel) em http://localhost:8008
#
#   .\dev\iniciar-erp.ps1                 # porta 8008, ERP em ..\forven_erp
#   .\dev\iniciar-erp.ps1 -Porta 8010
#
# Usa o PHP 8.4 do Herd. O php.ini do Herd aponta para arquivos que não existem
# mais; o dev\php\zz-forven-dev.ini corrige isso só para este processo.
param(
    [string]$Erp = (Join-Path $PSScriptRoot '..\..\forven_erp'),
    [int]$Porta = 8008
)

$php = Join-Path $env:USERPROFILE '.config\herd\bin\php84\php.exe'
if (-not (Test-Path $php)) { throw "PHP não encontrado em $php" }
$Erp = (Resolve-Path $Erp).Path

$mysql = Get-Service MySQL80 -ErrorAction SilentlyContinue
if ($mysql -and $mysql.Status -ne 'Running') {
    Write-Warning 'O MySQL (serviço MySQL80) está parado. Inicie em services.msc ou, como administrador: Start-Service MySQL80'
}

if (Get-NetTCPConnection -LocalPort $Porta -State Listen -ErrorAction SilentlyContinue) {
    Write-Host "Já existe algo rodando na porta $Porta (provavelmente o ERP). Nada a fazer." -ForegroundColor Yellow
    return
}

$env:PHP_INI_SCAN_DIR = (Resolve-Path (Join-Path $PSScriptRoot 'php')).Path

Write-Host "Forven ERP em http://localhost:$Porta  (emulador Android: http://10.0.2.2:$Porta)" -ForegroundColor Cyan
Write-Host "Painel do cardápio: http://localhost:$Porta/e-commerce/simuladores/cardapio/configuracoes" -ForegroundColor Cyan
Write-Host "Ctrl+C para parar." -ForegroundColor DarkGray

# "artisan serve" perde as variáveis de ambiente no processo filho; o servidor
# embutido do PHP com o router do Laravel funciona igual.
Push-Location (Join-Path $Erp 'public')
try {
    & $php -S "0.0.0.0:$Porta" '..\vendor\laravel\framework\src\Illuminate\Foundation\resources\server.php'
} finally {
    Pop-Location
}
