# Balanceamento — números finais no jogo

Meta do usuário (10 nov. 2026): todo herói entre 43% e 57% de vitória. Regras de criação de herói: docs/projeto/regras-de-herois.md. Roda do Destino: docs/projeto/roda-do-destino-codigo.md. Arena: docs/projeto/arena-nova.md.

**O balanceamento é medido pelo workflow "Balanceamento" do GitHub** (`.github/workflows/balance.yml`). Ler apenas o resumo dele; não rodar simulações longas localmente sem necessidade.

## Regra de ajuste (usuário, 11 nov. 2026; atualizada em 12 nov. 2026)
Ajuste autônomo, sem pedir aprovação a cada rodada:
- **Meta:** diferença de até ~8 pontos entre os dois heróis de cada função (padrão 1/1/1) e menos de 30% das partidas decididas pelo relógio.
- **Pode mudar** só números de heróis (vida, dano, cura, intervalos, alcance), no máximo 15% em relação ao valor atual da main. Nada de kits, regras, IA ou Roda do Destino.
- **Até 3 rodadas por vez**, calibrando o passo pelo efeito das rodadas anteriores.
- **Tamanho da rodada:** desde 12 nov. 2026 o repositório é público e os minutos do Actions não têm custo. Rodadas **completas (32 sementes)** são permitidas sempre que reduzirem a dúvida: duelo perto do limite de 8 pontos ou resultados que oscilam entre rodadas. Rodadas leves (16) continuam valendo para passos grandes.
- **Antes de mexer em dano, conferir os pontos de virada:** quantos golpes cada herói precisa para derrubar cada inimigo. Se um ajuste de dano cruza uma virada (1 golpe a menos), prefira ajustar a vida.
- **Bateu a meta:** publica, atualiza este documento e manda ao usuário UM resumo final: números que mudaram, vitória por herói com vitórias/partidas, % decididas pelo relógio e tempo da rodada; e atualiza as fichas de lore com os números novos.
- **Não bateu em 3 rodadas:** para, não publica, e traz o melhor resultado com a explicação do que não convergiu.

**Efeito medido** (para calibrar o passo):
- Arena clássica, rodadas leves: ±1 de dano do básico (Ártemis/Zeus) mexe ~7 pontos no duelo do Dano; 15 de vida a mais num tanque e 10 a menos no outro mexem ~5 pontos; Asclépio −10% de cura + Atena +20 de vida mexeram ~17 pontos.
- Arena Três Corredores: o Dano fica muito sensível (0,5 de dano trocado entre Ártemis e Zeus mexeu de 13 a 28 pontos, por causa das viradas de golpes contra os suportes); 65 de vida trocados entre os tanques mexeram só ~2 pontos.
- **Margem de erro:** cada herói ±4,3 (leve) ou ±3,1 (completa); diferença no duelo ~±8 (leve) ou ~±6 (completa).

## Pontos de virada (números de 12 nov. 2026)
Golpes do ataque básico para derrubar cada herói (sem cura nem escudo):

| Quem bate (dano) | Talos 590 | Hércules 680 | Ártemis 250 | Zeus 335 | Asclépio 280 | Atena 335 |
| --- | --- | --- | --- | --- | --- | --- |
| Ártemis (17,5) | 34 | 39 | — | 20 | 16 | 20 |
| Zeus (18,5) | 32 | 37 | 14 | — | 16 | 19 |

- **Ártemis:** com 17,5 derruba o Asclépio em 16 golpes; abaixo de 17,5, em 17.
- **Zeus:** a partir de 18,67 derruba o Asclépio em 15 golpes, e a partir de 18,61 derruba a Atena em 18.

## Como disparar
1. No GitHub: repositório `ccbarbosa5/clockwork-gods` → **Actions** → **Balanceamento** → **Run workflow** (ou `gh workflow run balance.yml` com os campos abaixo).
2. Campos:

| Campo | Padrão | Para quê |
| --- | --- | --- |
| Sementes do balanceamento principal | 16 (~500 partidas por herói, margem ±4,3 pontos) | 32 = rodada completa (~1.000 por herói, margem ±3,1) |
| Sementes de cada teste da Roda e da IA | 8 | Só vale com a caixa "Testes da Roda e da IA" marcada |
| Níveis dos bots | Difícil × Difícil | Outras combinações, se precisar |
| Roda do Destino | ligada | `off` para medir sem a roda |
| Refazer só o resumo de uma rodada anterior | vazio | Número de uma execução antiga: refaz o resumo sem jogar partidas (~1 min) |
| **Testes da Roda e da IA** | desmarcada | Peso de cada elo da Roda e Difícil × Normal |
| livre | desligado | Mede o Modo livre (até 2 da mesma função) |

3. O resumo aparece na página da execução ("Summary"), no artefato `balance.md` e no log do job "Resumo". Quem estiver fora de 43% a 57% aparece em **negrito**, com a margem de erro de 95%.

**Quando marcar "Testes da Roda e da IA":** só depois de mexer na Roda do Destino (bônus, janela, Cadência, volta completa, tipo de alguma carta) ou na IA dos bots. Para mudanças só de herói, deixe desmarcada.

## Custo
Desde 12 nov. 2026 o repositório é público: os minutos do Actions não têm custo nem limite. Tempo de relógio (8 fatias em paralelo): leve ~12 a 25 min; completa ~24 min; completa com testes ~55 min; só refazer o resumo ~1 min.

## Resultado atual (12 nov. 2026, PR #35; arena Três Corredores; rodada completa, 32 sementes)

2.048 partidas, bots Difícil × Difícil, comportamento Equilibrado, Roda ligada, Frascos e Centelha Viva, progresso 100/68. Execução 43299077818.

| Função | Herói | Vitória | Vitórias / partidas | Diferença no duelo |
| --- | --- | --- | --- | --- |
| Tanque | Talos | 53,6% ± 3,1 | 549 / 1.024 | 7,2 |
| Tanque | Hércules | 46,4% ± 3,1 | 475 / 1.024 | |
| Dano | Ártemis | 51,5% ± 3,1 | 527 / 1.024 | 2,9 |
| Dano | Zeus | 48,5% ± 3,1 | 497 / 1.024 | |
| Suporte | Asclépio | 51,3% ± 3,1 | 525 / 1.024 | 2,5 |
| Suporte | Atena | 48,7% ± 3,1 | 499 / 1.024 | |

- Lado azul 50,8%. **Decididas pelo relógio: 19%.** Duração média 264 s.
- Depois disso, o PR #37 (animação procedural, impacto, HUD) e o PR #38 (sem anel do time, sprites 12% maiores) não mexeram em números de herói; vale medir de novo se a jogabilidade parecer diferente.

**Números no jogo desde o PR #35:**

| Herói | Atributo | Antes (PR #29) | Agora |
| --- | --- | --- | --- |
| Talos | vida | 640 | **590** |
| Hércules | vida | 620 | **680** |
| Hércules | dano do ataque básico | 33 | **34** |
| Ártemis | dano do ataque básico | 18 | **17,5** |
| Zeus | dano do ataque básico | 18 | **18,5** |
| Zeus | vida | 320 | **335** |
| Asclépio | cura automática (a cada 0,5 s) | 14,4 | **14,1** |
| Atena | vida | 330 | **335** |

**Rodadas na arena nova (12 nov.):**

| Rodada | Mudança | Tanque | Dano | Suporte | Relógio |
| --- | --- | --- | --- | --- | --- |
| 0 | números do PR #29 | 15,6 | 27,3 (Ártemis) | 19,1 (Asclépio) | 16% |
| 1 | Talos 610, Hércules 655, Zeus 19,5, Ártemis 16,5, Asclépio 13,2, Atena 350 | 14,1 | 12,1 (Zeus) | 21,1 (Atena) | 19% |
| 2 | Talos 590, Hércules 680 e 34, Zeus 19, Ártemis 17, Asclépio 13,8, Atena 340 | 1,6 | 14,8 (Zeus) | 9,4 | 20% |
| 3 | Zeus 18,5, Ártemis 17,5, Asclépio 14,1, Atena 335 | 7,8 | 12,9 (Ártemis) | 5,1 | 20% |
| Completa (32 sementes) | Zeus 335 de vida (ponto de virada) | 7,2 | 2,9 | 2,5 | 19% |

### Histórico (arena clássica)
- PR #29 (11 nov., leve): Talos 49,2%, Hércules 50,8%, Ártemis 48,2%, Zeus 51,8%, Asclépio 47,7%, Atena 52,3%; relógio 18%.
- PR #28 (progresso 100/68): Talos 47,7%, Hércules 52,3%, Ártemis 43,2%, Zeus 56,8%, Asclépio 57,2%, Atena 42,8%; relógio 18%.
- PR #26 (progresso 100/80, padrão 1/1/1): relógio 55% (por isso o progresso passou a 100/68).
- Modo livre (seleção livre) medido em 11 nov.: times com 2 de Dano venciam até 93%, com 2 Tanques 11 a 19%; por isso o padrão é 1 por função e o livre é experimental.
- Peso de cada elo da Roda (512 partidas cada, sem o bônus de um elo): Movimento→Controle −2,7; Controle→Ataque −0,1; Ataque→Defesa −2,9; Defesa→Movimento (escudo 60) −5,2. Nenhum elo é obrigatório.
- Difícil × Normal (512 partidas): Difícil venceu 52,7% ± 4,3.

## O que mudou em relação às fichas originais do Pacote 3
Hércules vida 560 → 680 e dano 30 → 34, sem busca de alvo mais longe; Zeus vida 260 → 335, alcance 220 → 270 px, dano 14 → 18,5, salto 7 → 8, Corrente de Raios 60/45/34/25 → 68/51/38/29, foca o mais ferido, recua a 180 px, Voo da Águia vai para a faixa lateral; Atena vida 320 → 335. Pacote 1: Talos 650 → 590; Ártemis dano 18 → 17,5; Asclépio cura 15 → 14,1.

## Como funciona por dentro
- `tests/simulate.gd -- --balance` joga as 64 combinações de times (um herói por função de cada lado). Cada herói é contado nas partidas em que está só de um lado (espelhos não contam; empate vale meia vitória). Opções: `--seed=N`, `--part=k/n`, `--diffs=a,b`, `--wheel=off`, `--nobonus=g`, `--arena=<id>`.
- `tools/balance_run.sh` roda uma fatia; `tools/balance_summary.py` junta os logs e escreve o resumo.
- `.github/workflows/balance.yml`: 8 fatias em paralelo e um job "Resumo". Reaproveita o cache do Godot do `publish.yml`.
