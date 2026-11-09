# Imagens do jogo

Tudo aqui é opcional: se um PNG não existir, o jogo desenha por código como antes.
O carregamento fica em `scripts/art.gd` (com cache). Basta colocar o arquivo com o
nome certo e abrir o projeto no Godot para importar.

Tamanhos na tela são para a base 1280×720.

## heroes/

| Arquivo | Fonte | Na tela | Observação |
| --- | --- | --- | --- |
| `talos_top.png` | 256×256 | 62×62 | Vista de cima, virada para a direita (0°). Gira com o herói (até 720°/s). O anel do time deve ocupar 80% da imagem. |
| `artemis_top.png` | 256×256 | 45×45 | Idem |
| `asclepio_top.png` | 256×256 | 48×48 | Idem |
| `talos_portrait.png` | 256×256 | círculo de 50 px | Recortado em círculo no medidor da ultimate |
| `artemis_portrait.png` | 256×256 | círculo de 50 px | Idem |
| `asclepio_portrait.png` | 256×256 | círculo de 50 px | Idem |

Com sprite, o triângulo de direção e o emblema sobre o corpo não são desenhados.
Anel do time, sombra, barra de vida, nome, selos e estados continuam por código, sem girar.
O anel do time (3 px) é desenhado por cima do sprite: na imagem de 256 ele cobre a faixa
entre ~85 e 102 px do centro (Talos 90 a 102). O corpo fica dentro dele; armas e detalhes
podem passar para fora até a borda da imagem.

O retrato também é coberto pelas bordas do medidor: a porcentagem fica sobre a base
(faixa inferior de ~10 px) e o selo da ultimate no canto inferior direito.

## icons/

256×256, um por habilidade. Desenhados no mesmo tamanho do ícone por código
(carta 24 px, próxima carta 18 px, medidor 18 px, selos e registro lateral 8 a 20 px).

`muralha.png`, `investida.png`, `valvula.png`, `furia.png`, `disparo.png`, `armadilha.png`,
`salto.png`, `chuva.png`, `sopro.png`, `veneno.png`, `engrenagem.png`, `segunda.png`

## cards/

| Arquivo | Fonte | Na tela |
| --- | --- | --- |
| `frame_tanque.png` | 240×236 | 120×118 |
| `frame_dano.png` | 240×236 | 120×118 |
| `frame_suporte.png` | 240×236 | 120×118 |

A moldura substitui o fundo, a faixa do topo e a borda da carta; nome, ícone, custo e textos continuam por código.
Por isso: faixa do topo (48 px na fonte) clara, porque o nome do herói é escrito em escuro;
o resto escuro, porque nome e resumo da habilidade são brancos/claros. Custo no canto superior
esquerdo e ícone no centro (círculo em y ≈ 108 px na fonte). A miniatura da próxima carta não usa moldura.

## fx/

Imagem única, animada pelo código (escala, transparência, giro). Projéteis desenhados apontando para a direita:

| Arquivo | Fonte | Na tela |
| --- | --- | --- |
| `disparo_projetil.png` | 256×64 | 70×18 |
| `veneno_projetil.png` | 160×64 | 35×14 |
| `tiro_basico.png` | 64×32 | 12×6 (tingido com a cor do herói: desenhe claro/neutro) |

Os demais efeitos (áreas, auras, partículas) ainda são só desenho por código. Para ligar
um deles, use `Art.draw_fx(ci, "nome", centro, tamanho, escala, alfa, giro)`: ela devolve
false sem a imagem, e aí o código desenha como hoje.
