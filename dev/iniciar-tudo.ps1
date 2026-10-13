# Sobe o ambiente completo, cada serviço na sua janela do PowerShell:
# ERP (porta 8008), Vite (painel) e o app no emulador com hot reload.
# Liga o emulador Medium Tablet se nenhum estiver aberto e abre o painel no navegador.
$shell = if (Get-Command pwsh -ErrorAction SilentlyContinue) { 'pwsh' } else { 'powershell' }
function Janela([string]$script) {
    # Aspas explícitas: a pasta "Cardapio Digital" tem espaço e o Start-Process não as coloca sozinho.
    $arquivo = '"{0}"' -f (Join-Path $PSScriptRoot $script)
    Start-Process $shell -ArgumentList '-NoExit', '-ExecutionPolicy', 'Bypass', '-File', $arquivo
}

Janela 'iniciar-erp.ps1'
Janela 'iniciar-vite.ps1'
& (Join-Path $PSScriptRoot 'iniciar-emulador.ps1')
Janela 'iniciar-app.ps1'

# Espera o ERP responder e abre o painel do cardápio.
$painel = 'http://localhost:8008/e-commerce/simuladores/cardapio/configuracoes'
foreach ($i in 1..30) {
    try {
        Invoke-WebRequest -UseBasicParsing -TimeoutSec 2 'http://localhost:8008/login' | Out-Null
        Start-Process $painel
        break
    } catch {
        Start-Sleep -Seconds 1
    }
}
Write-Host "Painel do cardápio: $painel" -ForegroundColor Cyan
Write-Host 'O app confere o ERP a cada 10 s (build de desenvolvimento): salve no painel e olhe o emulador.' -ForegroundColor Cyan
