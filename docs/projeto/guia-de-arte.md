# Clockwork Gods — Guia de Arte

Nome do jogo: **Clockwork Gods**, igual em português e inglês (antes "Ichor: Clockwork Gods"). O Ícor continua no jogo como o sangue dourado dos deuses e recurso das cartas.

Versão longa (arquivo, nome antigo): https://claude.ai/artifact/CNZgsQ1PxYCRuMaWgTDibU
Decisões técnicas (rotação, retrato, efeitos, sem anel do time): `docs/projeto/decisoes-tecnicas-arte.md`, que vale sobre este guia. Regras de heróis: `docs/projeto/regras-de-herois.md`, que também vale sobre este guia.

## Contexto do jogo

- Hero shooter 2D com cartas, visto de cima, para PC (versão web no itch.io).
- O jogador não controla os heróis: eles lutam sozinhos por IA, e o jogador joga cartas de habilidade pagas com Ícor.
- Cenário: Olimpo steampunk — mitologia grega em bronze, mármore, vapor e engrenagens de Hefesto.
- Partidas 1v1 entre times de 3 heróis (azul x vermelho) num ponto de controle central, mapa simétrico. Resolução base 1280 × 720.

## Direção de arte

- 2D estilizado, cel shading, contorno escuro leve, silhueta forte. Sem fotorrealismo. **Decisão de 12 nov. 2026: o jogo segue em 2D** (3D foi avaliado e descartado); o salto visual vem de animação (procedural e por peças), impacto e interface limpa.
- Materiais: bronze envelhecido, latão, mármore branco, cobre, couro, vapor branco; ícor = brilho dourado líquido.
- Heróis, mapa, obstáculos e efeitos vistos de cima. Retratos, cartas e título podem ser de frente.
- Luz: **de cima, neutra** em tudo o que gira no jogo (sprites dos heróis, projéteis, auras e efeitos). **Do alto à esquerda** em retratos, cartas, mapa, título e loja.

### Enquadramento dos sprites vistos de cima (12 nov. 2026)

- O anel do time saiu do jogo; a cor do time fica na barra de vida e numa sombra sob o herói. A antiga faixa livre de 85 a 102 px do centro deixa de existir.
- Arquivo 256 × 256, virado para a direita, centro do corpo em (128, 128), sem sombra. Corpo, armas e acessórios podem usar a imagem inteira, com margem de ~4 px na borda; manter a escala parecida com a dos heróis já aprovados.
- Camadas de animação: deixar folga dentro dos 256 px para o movimento das peças (ex.: o soco do Talos avança até 14 px).

## Paleta

| Uso | Hex |
| --- | --- |
| Ícor (dourado) | #F2C24F |
| Bronze | #C78A3B |
| Tanque (laranja) | #F59933 |
| Dano (roxo) | #B873FF |
| Suporte (verde) | #54D973 |
| Time do jogador (azul) | #4DA8FF |
| Time inimigo (vermelho) | #FF5C4D |
| Piso da arena | #29211C |
| Fundo/interface | #0E0C0A |

A cor da função domina nas cartas e nos ícones; no herói, ela é só destaque. Azul e vermelho são dos times; heróis e objetos não devem ter azul ou vermelho dominante.

## Lista de imagens

- **Por herói (7):** `heroes/{id}_top.png`, `heroes/{id}_portrait.png`, `heroes/{id}_full.png` e 4 `icons/{habilidade}.png` (detalhes em regras-de-herois.md, seção 8). Camadas de animação em `heroes/camadas/` (docs/projeto/animacao-2d.md).
- **Cartas:** `cards/frame_{tanque,dano,suporte}.png` (240×236, só moldura; faixa do topo clara).
- **Mapa clássico:** `map/arena_floor.png` (2560×1040) · `map/pillar_large.png` (160) · `map/pillar_small.png` (112) · `map/control_point.png` (512) · `map/spawn_base.png` (384, neutra) · `map/health_pack.png` (128; Frasco de Ambrosia).
- **Arena Três Corredores:** `map/wall.png`, `map/wall_corner.png`, `map/low_wall.png`, `map/boiler.png`, `map/statue.png`, `map/floor_tres_corredores.png` (docs/projeto/arena-nova.md).
- **Efeitos:** `fx/` (decisoes-tecnicas-arte.md e fx-pacote-3.md).
- **Interface e loja:** `ui/logo.png` (1200×400, "CLOCKWORK GODS") · `ui/title_bg.png` (1920×1080, com Hércules, Zeus e Atena; sem texto) · `store/itch_cover.png` (630×500) · `store/icon.png` (512×512).

## Técnica e entrega

PNG com transparência real, tamanho exato, desenho centralizado. Fluxo: imagem em teste → `D:\Ichor\assets\em-revisao\`; aprovada → `D:\Ichor\assets\aprovados\<subpasta>\<nome>.png` → `assets/<subpasta>/` no repositório. Prévias de teste em `D:\Ichor\capturas\<assunto>\`.

## Estilo base para prompts de IA de imagem

Sprites, projéteis e efeitos (giram no jogo):
```
Stylized 2D game art, clean cel shading, bold readable silhouette, thin dark outline, Greek mythology meets steampunk: aged bronze, polished brass, white marble, copper pipes, rivets, gears and white steam, glowing liquid gold accents (ichor). Strict top-down view, neutral overhead lighting (no directional shadow). Consistent style for a top-down hero shooter.
```

Retratos, cartas, mapa, título e loja:
```
Stylized 2D game art, clean cel shading, bold readable silhouette, thin dark outline, Greek mythology meets steampunk: aged bronze, polished brass, white marble, copper pipes, rivets, gears and white steam, glowing liquid gold accents (ichor). Light from top-left. Consistent style for a top-down hero shooter.
```
