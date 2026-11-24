# Arena Três Corredores (Pacote 6; item 50)

Atualizado em 12 nov. 2026. Arena padrão do jogo.

**Decisão do usuário:** opção A · Três Corredores, com dois ajustes: paredes em L mais longe do ponto (folga de 150 px) e vão de 60 px no meio de cada parede longa. As opções B e C estão na branch `arena-nova-proposta` (`docs/arena-nova/`).

## Histórico
| PR | O quê |
| --- | --- |
| #33 | Arena em dados (`arenas/<id>.json`, `scripts/arena.gd`), colisão em círculos e retângulos, linha de tiro (muretas deixam passar), avanços e empurrões param em obstáculos, alvo e cura exigem linha livre |
| #34 | Navegação A* (grade de 8 px por arena, raio 22) e cobertura da Centelha Viva atrás de qualquer obstáculo que bloqueia tiro |
| #35 | Arena padrão = Três Corredores, "Como jogar" refeito, testes e balanceamento |
| #36 | Arte ligada: paredes, canto do L, muretas, caldeira (brilho pulsando), estátua e piso próprio |

A arena clássica continua em `arenas/classica.json` (opção `"arena": "classica"` e `--arena=classica` na simulação), com o piso `arena_floor.png`.

## Planta (`arenas/tres_corredores.json`, espelhada)

| Peça | Lado azul (o vermelho é o espelho em x = 1280 − x) |
| --- | --- |
| Paredes longas (24 px) | [235, 168, 75 × 24] e [370, 168, 76 × 24] (vão de 60 px entre x 310 e 370); iguais em y 408 |
| Paredes em L | horizontal [446, 190, 74 × 20] + perna [446, 190, 20 × 52]; embaixo [446, 390, 74 × 20] + [446, 358, 20 × 52] |
| Coluna | (330, 300), raio 22 |
| Muretas (tiros passam) | [270, 96, 64 × 14] e [270, 490, 64 × 14] |
| Estátuas | (165, 124) e (165, 476), raio 26 |
| Caldeiras (no eixo) | (640, 82) e (640, 518), raio 42 |
| Frascos (5) | (440, 100), (440, 500), espelhos e (640, 168) |

- Folga em volta do ponto 150 px. Vão central entre as L 116 px. Todo vão tem 0 ou pelo menos 54 px (teste).
- Base › ponto: centro 498 px, 5,8 s (Talos 6,9 s); flancos 619 px, 7,2 s (Talos 8,6 s).
- Capturas em `docs/capturas/arena-nova/` (planta_rotas, partida_15s/70s/140s, detalhes ampliados).

## Balanceamento
Rodadas e números: docs/projeto/balanceamento.md (meta batida na rodada completa: Tanque 7,2, Dano 2,9, Suporte 2,5; relógio 19%). A arte não muda colisão nem números.

## Imagens (`assets/map/`, no jogo desde o PR #36)

Vistas de cima, sem sombra, luz de cima e neutra. Detalhes técnicos em `assets/README.md`.

| Arquivo (map/) | Fonte | Na tela | Como o código usa |
| --- | --- | --- | --- |
| `wall.png` | 256 × 48 | faixa de 24 px (20 nas L) | Painéis de junta a junta (128 px da imagem); cada peça recebe um número inteiro de painéis, esticados, para fechar numa junta. Na vertical, gira 90° |
| `wall_corner.png` | 48 × 48 | 20 × 20 | No quadrado onde as pernas do L se encontram |
| `low_wall.png` | 256 × 28 | faixa de 14 px | Painéis de pilarete a pilarete (64 px da imagem = 32 na tela) |
| `boiler.png` | 192 × 192 | 93 px (raio 42 = 90%) | Brilho laranja pulsando sobre a fornalha |
| `statue.png` | 128 × 128 | 61 px (raio 26 = 85%) | Fixa |
| `floor_tres_corredores.png` | 2560 × 1040 | 1280 × 520 | Campo `"piso"` da arena; sem a imagem, cai no `arena_floor.png` |

A coluna (raio 22) usa a `pillar_small.png`.

## Próximas arenas (ideias, item 51)
Forja de Hefesto, Creta, Atlântida — A DEFINIR.
