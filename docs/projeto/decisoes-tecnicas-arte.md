# Decisões técnicas de arte (aprovadas em 9 nov. 2026; seção 1 atualizada em 12 nov. 2026)

Em caso de conflito com o guia de arte, vale este documento. Medidas na base 1280 × 720.

## 1. Sprites dos heróis: giram livremente, sem anel do time

- O sprite gira com a direção do herói (giro suavizado, no máximo 720°/s). Desenhar **virado para a direita (0°)**, visto de cima, sem sombra.
- **Sem anel do time** (decisão do usuário, 12 nov. 2026; PR #38). A cor do time aparece:
  - na barra de vida e no filete sob o nome;
  - numa sombra elíptica sob o herói, com leve tom da cor do time, discreta e sem contorno. O código desenha essa sombra, e ela encolhe quando o herói pula.
- Ficam fixos (não giram): sombra, barra de vida, nome, selos e ícones de estado. O triângulo de direção e o emblema sobre o corpo só aparecem quando não há sprite.
- **Arquivo 256 × 256:** o corpo principal cabe no círculo central de 205 px (80% da imagem); arma, escudo e chaminés podem sair dele até a borda; os sprites já entregues continuam valendo.
- **Na tela** (imagem inteira), 12% maior desde o PR #38:

| Herói | Antes | Agora |
| --- | --- | --- |
| Talos e Hércules | 62 px | 69 px |
| Ártemis | 45 px | 50 px |
| Asclépio | 48 px | 54 px |
| Zeus | 47,5 px | 53 px |
| Atena | 50 px | 56 px |

- **Colisão:** não mudou (raio do herói nos dados). O corpo desenhado fica um pouco maior que o círculo de colisão. A barra de vida e o nome se afastaram 3 px.
- **Luz:** tudo o que gira (sprites do mapa, projéteis, auras) usa **luz de cima, neutra**. Luz do alto à esquerda só em retratos, cartas, título e loja.
- **Animação por peças (Pacote 7):** camadas 256 × 256 no mesmo enquadramento, em `heroes/camadas/`, com os pivôs de `docs/projeto/animacao-2d.md`. Sem elas, o código anima o sprite inteiro (balanço, avanço, recuo, pulinho). Detalhes: `docs/projeto/visual-2d-codigo.md`.

## 2. Retrato: dentro do medidor de ultimate

- Círculo de 50 px de diâmetro, recortado em círculo, no miolo do medidor de ultimate. Centros (58, 668), (156, 668) e (254, 668). O anel de carga continua em volta (raio 28, 4 px).
- O ícone da ultimate vira selo pequeno (raio 9) no canto inferior direito do medidor; a porcentagem fica sobre a base do retrato.
- Arquivo 256 × 256: busto centralizado, rosto dentro do círculo central de 180 px (os cantos não aparecem).

## 3. Efeitos: imagem única animada pelo código

Sem sequência de quadros. O código faz crescer, sumir e girar. Todos em `assets/fx/`, detalhes em `assets/README.md`. Efeitos de Hércules, Zeus e Atena: `docs/projeto/fx-pacote-3.md`.

| Grupo | Arquivos (fonte) |
| --- | --- |
| Áreas | `furia_area`, `valvula_area`, `sopro_area`, `segunda_area`, `chuva_area`: 512 × 512 |
| Objetos | `armadilha_aberta`, `armadilha_fechada`: 128 × 128 |
| Presos ao herói | `muralha_arco` 256 × 128 (convexo para a direita) · `soco_arco` 128 × 64 · `feixe_cura` 64 × 16 (repetida na horizontal) |
| Auras | `aura_valvula`, `aura_engrenagem`, `aura_segunda`, `aura_raiz`: 256 × 256 |
| Partículas | `fumaca` 64 × 64 (branca: o código tinge) · `chuva_flecha` 32 × 32 (para a direita) · `cura_mais` 32 × 32 · `veneno_bolha` 16 × 16 · `atordoado_estrela` 32 × 32 |
| Projéteis (para a direita) | `disparo_projetil` 256 × 64 · `veneno_projetil` 160 × 64 · `tiro_basico` 64 × 32 (claro/neutro: o código tinge) |
| Rastro de avanço | sem arquivo (cópias translúcidas do sprite) |

## Onde as imagens entram

Imagens em teste: `D:\Ichor\assets\em-revisao\`. Aprovadas: `D:\Ichor\assets\aprovados\<subpasta>\` e, depois, `assets/<subpasta>/` no repositório. Sem a imagem, o jogo continua desenhando por código. Um teste automático confere nome, tamanho e transparência de toda imagem em `assets/`.
