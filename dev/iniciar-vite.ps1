# Sobe o Vite do ERP (painel Vue com hot reload). Abra o ERP em http://localhost:8008.
#
# --host localhost: sem isso o Vite publica "http://[::]:5173" no public\hot e o
# Chrome não carrega os scripts. A primeira abertura leva ~2 min (otimização de dependências).
param([string]$Erp = (Join-Path $PSScriptRoot '..\..\forven_erp'))

if (Get-NetTCPConnection -LocalPort 5173 -State Listen -ErrorAction SilentlyContinue) {
    Write-Host 'O Vite já está rodando (porta 5173). Nada a fazer.' -ForegroundColor Yellow
    return
}

Push-Location (Resolve-Path $Erp).Path
try {
    node node_modules/vite/bin/vite.js --host localhost
} finally {
    Pop-Location
}
