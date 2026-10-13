# Rodando tudo em localhost

App Flutter + Forven ERP local (Laravel na porta 8008 + Vite) + emulador Android.
Você configura o cardápio no navegador e vê a mudança no emulador em até **10 segundos**.

## Jeito mais rápido: VS Code

1. Abra esta pasta no VS Code (as extensões Flutter e Dart já estão instaladas).
2. Aperte **F5**. Ele sobe o ERP, o Vite e o emulador *Medium Tablet* (se ainda não estiverem
   rodando) e abre o app com hot reload.
3. Abra o painel: <http://localhost:8008/e-commerce/simuladores/cardapio/configuracoes>

Só os serviços, sem rodar o app: **Ctrl+Shift+B**. Outras tarefas em
*Terminal › Executar tarefa*: limpar dados do app (volta ao pareamento) e rodar os testes.

Salvar um arquivo `.dart` aplica o hot reload no emulador.

## Pelo PowerShell

```powershell
.\dev\iniciar-tudo.ps1          # janelas separadas: ERP, Vite e app; abre o painel no navegador
```

Ou peça por peça:

```powershell
.\dev\iniciar-erp.ps1           # http://localhost:8008
.\dev\iniciar-vite.ps1          # painel Vue com hot reload (1ª abertura ≈ 2 min)
.\dev\iniciar-emulador.ps1      # liga o Medium Tablet e espera o boot
.\dev\iniciar-app.ps1           # flutter run (r = hot reload, R = restart, q = sair)
.\dev\iniciar-app.ps1 -Limpar   # apaga os dados do app e volta ao pareamento
```

Os scripts não sobem nada em dobro: se a porta já estiver em uso, avisam e saem.
Os avisos `Unable to load dynamic library ... Herd` na janela do ERP são inofensivos.

## Entrar no ERP

O banco local `saborecia` é uma cópia do de produção: entre com o mesmo e-mail e senha que você
usa no ERP da Sabor & Cia (por exemplo, o usuário `admin`). Entrar no local só
derruba sessões **do banco local**.

## Ver as mudanças do painel no emulador

| O que você muda no painel | Quando aparece no app |
|---|---|
| Qualquer configuração, produto, preço, foto, tema | Em até 10 s (build de desenvolvimento) |
| Mesmo, num tablet com build de produção | No intervalo da aba *Funcionamento* (padrão 5 min), ao reabrir o app ou em *Sincronizar agora* |

O app é **offline-first**: abre com o cardápio guardado no aparelho e busca novidades em segundo
plano mandando `?versao=`; se nada mudou, o ERP responde em poucos bytes.

O emulador já está pareado com o ERP local (`http://10.0.2.2:8008` — é o "localhost do PC" visto
de dentro do emulador). Para parear de novo: tarefa *App: limpar dados*, depois no painel, aba
**Segurança & pareamento**, endereço `http://10.0.2.2:8008` › **Gerar QR Code**, e no app
**Parear › Digitar** com o endereço e o token (botão "copiar" no painel).
Tablet físico na mesma rede: use o IP do PC (`ipconfig`), por exemplo `http://192.168.2.10:8008`.

O build de debug libera `http://` (`android/app/src/debug/AndroidManifest.xml`).
Em produção o ERP deve ser acessado por `https://`.

PIN da área do estabelecimento (segurar o logo no app): o definido no ERP, `1234` nos dados de exemplo.

## Dados de exemplo

Sabor & Cia Café: 8 categorias, 35 produtos com fotos, 6 grupos de complementos, 20 mesas, PIN 1234.
Para recriar do zero:

```powershell
cd ..\forven_erp
$env:PHP_INI_SCAN_DIR = (Resolve-Path '..\Cardapio Digital\dev\php').Path
& "$env:USERPROFILE\.config\herd\bin\php84\php.exe" artisan cardapio:demo 1 --limpar
```

## Fluxo completo: mesa → cozinha (PCP) → caixa

| Quem | Onde | O que acontece |
|---|---|---|
| Cliente | Tablet da mesa | Faz o pedido. Vira **Venda** (Faturamento › Vendas) e **Ordem de Produção** no PCP |
| Cliente | Tablet (sino no topo) | "Chamar garçom": vai para o celular do garçom responsável pela mesa |
| Cozinha | PCP › Ordens de produção | A OP mostra "Mesa 12 · Pedido #105 · opções · obs". **Separar insumos** = em preparo · **Apontar** = pronto |
| Garçom | Celular (modo Garçom) | Vê os chamados e as mesas; o pedido aparece "Pronto" quando a cozinha aponta |
| Caixa | Simulador › Cardápio › **Caixa** | Conta da mesa (comanda) com todos os pedidos · **Fechar conta** · **Faturar** (vira nota fiscal) |

Configurações (todas em E-commerce › Simuladores › Cardápio):

- **Cozinha (PCP)**: liga/desliga, usuário responsável pelas OPs, quais produtos vão para a cozinha.
  Só gera OP o produto com **ficha técnica** (PCP › Formulações).
- **Venda & pagamento**: comanda por mesa e template da nota do consumidor (NFC-e).
- **Garçons & chamados**: botão do sino, motivos, garçons e o responsável de cada mesa.

O status do pedido no app acompanha a OP sozinho (lido do PCP quando o app consulta). A nota
gerada pelo caixa não cria OP de novo, mesmo com "OP automática ao salvar a NF-e" ligada.

## Simular queda de internet

Feche a janela do ERP (ou Ctrl+C), faça um pedido no app — ele aparece como **Na fila** — e suba
o ERP de novo. O pedido é enviado sozinho em até 20 s e vira Venda uma única vez.

## Onde fica cada coisa

| Peça | Onde |
|---|---|
| Cardápio guardado + `?versao=` | `lib/src/state/offline.dart` (`CardapioController`) |
| Fila de pedidos (sem internet) | `lib/src/state/offline.dart` (`FilaPedidosController`) |
| Fotos e cache | `lib/src/data/local/armazenamento_offline.dart` |
| Sincronização periódica e selo "Offline" | `lib/src/features/offline/offline_host.dart` |
| Temas do ERP | `lib/src/core/theme/temas.dart` |
| Painel no ERP | `forven_erp/resources/js/components/e-commerce/simuladores/cardapio/` |
| API do app no ERP | `forven_erp/app/Http/Controllers/Ecommerce/Cardapio/CardapioAppController.php` |

## Problemas conhecidos do ambiente local

- O `APP_URL` do `.env` do ERP aponta para `192.168.1.100`; o IP atual da máquina é outro.
  As fotos usam a URL da requisição, então funcionam mesmo assim.
- `php artisan route:list` falha por um controller ausente que já existia antes
  (`EtapaTransicaoController`); não afeta o cardápio.
- Os campos criptografados do emitente (`csc`, `ibpt_token`, `dominio_integration_key`) foram
  zerados **só no banco local** porque foram gravados com a chave de produção. O backup está na
  tabela `_backup_emitentes_criptografados`.
