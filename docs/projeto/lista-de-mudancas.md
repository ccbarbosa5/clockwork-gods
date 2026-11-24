# Lista de mudanças — Clockwork Gods

As ideias entram aqui; quando o usuário diz "fechar o pacote", tudo é feito e publicado numa versão só. Revisão geral em 11 nov. 2026; status atualizados na migração para o Claude Code (24 nov. 2026).

Status: IDEIA · NO PACOTE · EM ANDAMENTO · FEITO
Dono (das antigas conversas do claude.ai; hoje tudo é feito no Claude Code): C = código · L = lore e textos · A = arte · U = usuário (ação manual)

## Concluído
- **Pacote 1:** arte dos 3 primeiros heróis, efeitos (22), galeria de heróis com ilustrações e textos (PRs #1 a #8).
- **Pacote 2:** nome "Clockwork Gods", idiomas PT/EN, menu de pausa, dicas de mouse, metros, mapa com arte, novos endereços (PRs #9 a #13).
- **Pacote 3:** seleção de time (6 heróis), Hércules, Zeus e Atena com arte completa, balanceamento entre 43% e 57% (PR #14), logo, ícone, fundo do título e capa definitiva (PR #15).
- **Pacote 4:** Roda do Destino (combos de cartas), com HUD, bot e simulação (PR #15). Detalhes em docs/projeto/roda-do-destino-codigo.md.
- Tradução EN completa (245 de 245 textos).

## Pendências do que foi combinado

| # | Mudança | Dono | Status |
| --- | --- | --- | --- |
| 31 | Atualizar a ficha de Hércules e Zeus com os números finais | L | FEITO (falta trocar 60 → 68 na condição da IA da Corrente de Raios, se o Código ajustou) |
| 32 | Arte dos 19 efeitos do Pacote 3 + sprite novo do Hércules | A → C | FEITO (PRs #20 e #22) |
| 33 | Balanceamento: ajustar os pares Ártemis × Zeus e Talos × Hércules | C | FEITO (PR #23); remedido no item 46 |
| 37 | Workflow Balanceamento no GitHub (manual, leve por padrão, testes da Roda opcionais) | C | FEITO (PRs #17 a #21) |
| 34 | Arte da Roda do Destino (opcional; hoje desenhada por código): roda ~56 px, engrenagens 14 px, selo 20 px, faísca | A | IDEIA |
| 35 | Subir a capa definitiva (store/itch_cover.png) e o ícone na página do itch.io | U | CONFERIR |
| 36 | Referência de heróis com os 6 heróis | C ou L | FEITO na migração: Pacote 1 em referencia-herois-habilidades.md, Pacote 3 em herois-pacote-3.md |

## Pacote 5 — Telas e mecânicas — FEITO (12 nov. 2026)

| # | Mudança | Dono | Etapa | Status |
| --- | --- | --- | --- | --- |
| 40 | Tela inicial limpa (sem frase, versão sem nº de heróis) + tela de seleção de personagens ao clicar em Jogar (time, dificuldade, comportamento; partida só começa ao confirmar) | C | 1 | FEITO (PR #24) |
| 41 | Tela de Heróis e seleção agrupadas por função, com a função bem visível | C | 1 | FEITO (PR #24) |
| 42 | Seleção livre: máx. 2 por função, sem repetir herói; aviso quando faltar engrenagem da Roda; bot monta time livre | C | 1 | FEITO (PR #24) |
| 43 | Pacotes de vida espelhados (2 por lado + 1 no meio), reaparecem após um tempo; IA decide pacote × base | C + A + L | 1 | FEITO (PRs #24 a #27; imagem e nomes da Lore no jogo) |
| 44 | Regeneração passiva após 5 s sem dano; lenta; não funciona no ponto; Defensivo usa mais, Agressivo quase nunca | C | 1 | FEITO (PR #24) |
| 45 | Trocar comportamento sem tempo de espera | C | 1 | FEITO (PR #24) |
| 46 | Rodada leve de balanceamento depois de 42 a 45 | C | 1 | FEITO (PRs #26 a #29: padrão 1/1/1 + Modo livre opcional; cura reduzida; progresso 100/68; funções com 1,6 / 3,5 / 4,7 pontos de diferença; 18% pelo relógio) |
| 47 | "Como jogar" interativo, com abas e capturas do jogo | C + L | 2 | FEITO (PR #30 + revisão; faltam 2 legendas e a frase da aba 1) |

| 48 | Atualizar fichas com os números do balanceamento de 11 nov. (Talos 640, Hércules 620, Ártemis e Zeus 18 de dano, Asclépio cura 14,4, Atena 330) | L | — | FEITO |

## Pacote 6 — Mapa (coletando observações)

| # | Mudança | Dono | Status |
| --- | --- | --- | --- |
| 50 | Redesenhar a arena no mesmo tamanho de tela, com mais dinamismo: tipos variados de cobertura (muretas, paredes em L, caldeiras, estátuas), rota central + 2 flancos, gargalos perto do ponto. Exige colisão e linha de tiro em retângulos e IA que contorna obstáculos. Proposta de layout aprovada pelo usuário antes da arte | C + A | FEITO (PRs #33 a #36, com arte; rodada completa: Tanque 7,2 · Dano 2,9 · Suporte 2,5; relógio 19%) |
| 51 | Mais arenas no lugar de uma maior (ex.: forja de Hefesto, Creta, Atlântida a vapor) | L + A + C | IDEIA (depois do 50) |
| 52 | Mapa 1,5–2× com câmera e minimapa | C | PLANO B, só se o 50 não bastar |

| 53 | Repositório público (Actions sem limite de minutos); rodadas completas liberadas | U | FEITO (12 nov.) |

## Pacote 7 — Salto visual (12 nov. 2026)

| # | Mudança | Dono | Status |
| --- | --- | --- | --- |
| 60 | Polimento 2D: animação procedural (andar, atacar, levar dano), impacto (clarão, tremor leve, partículas) e HUD mais limpo (registro e avisos) | C | FEITO (PR #37) |
| 61 | Protótipo 3D | — | CANCELADO (usuário escolheu 2D, 12 nov.) |
| 63 | Animação por peças (recorte 2D): teste com o Talos (camadas da Assets + Skeleton2D no Código); depois os outros 5 | A + C | EM ANDAMENTO: código pronto (PR #37, scripts/rig.gd); camadas do Talos em D:\Ichor\assets\em-revisao\heroes\camadas\ esperando aprovação do usuário |
| 64 | Tirar o anel do time (cor do time só na barra de vida e na sombra) e sprites 12% maiores | C | FEITO (PR #38) |

## Ideias soltas

| # | Mudança | Dono | Observação |
| --- | --- | --- | --- |
| 11 | Lore em aberto: o que o vencedor dos Ritos ganha, por que as bases curam, por que os heróis obedecem ao Arquiteto | L | — |
| 12 | Onde a história aparece no jogo (menu, dicas das cartas, falas) | L + C | — |

## Atualizações futuras

| # | Mudança | Observação |
| --- | --- | --- |
| 30 | Sobrecarga: pagar +2 de Ícor por uma versão turbinada da carta | Combina com a Roda do Destino |
