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

Efeitos ligados por imagem única. Sem o arquivo, o efeito continua desenhado por código.
Tamanhos "na tela" são em escala 1; o código anima por escala, transparência e giro.
Tudo que gira (projéteis, auras, partículas) usa luz de cima, neutra.

### Áreas no chão (512×512)

Desenhadas no diâmetro da área; crescem de 30% a 100%, somem e giram devagar.
A arte deve preencher o círculo inteiro da imagem (o centro da imagem é o centro da área).

| Arquivo | Habilidade | Na tela | Duração |
| --- | --- | --- | --- |
| `furia_area.png` | Fúria da Forja (onda + rachaduras) | 420 px | 0,7 s (substitui também as rachaduras desenhadas) |
| `valvula_area.png` | Válvula de Pressão (onda de vapor) | 380 px | 0,5 s |
| `sopro_area.png` | Sopro Restaurador (onda de cura) | 420 px | 0,6 s |
| `segunda_area.png` | Segunda Chance (explosão dourada) | 480 px | 0,7 s (substitui também os raios desenhados) |
| `chuva_area.png` | Chuva de Prata (área no chão) | 340 px | 2,5 s, girando 0,3 rad/s, 90% de opacidade |

Nas áreas com imagem, um anel fino na cor do time continua por código (Chuva de Prata), para mostrar de quem é.

### Objetos no chão (128×128)

| Arquivo | Uso | Na tela |
| --- | --- | --- |
| `armadilha_aberta.png` | Armadilha armada (35% de opacidade enquanto arma, 0,6 s) | 44 px, com anel do time por cima |
| `armadilha_fechada.png` | Armadilha disparada, some em 0,6 s | 44 px |

### Presa ao herói

| Arquivo | Fonte | Na tela | Observação |
| --- | --- | --- | --- |
| `muralha_arco.png` | 256×128 | 179×90 | Arco convexo virado para a DIREITA (frente), alto e estreito (meia-lua de ~78×123 px no centro da imagem). Desenhado a 70%, com o centro da imagem a 33 px à frente do Talos: o escudo fica de 34 a 60 px do centro dele, com ~86 px de altura. Gira com ele. Opacidade cai com a resistência (mínimo 30%) |
| `soco_arco.png` | 128×64 | 64×32 (Talos) | Arco de impacto virado para a direita, a raio + 12 px à frente; some em 0,18 s |
| `feixe_cura.png` | 64×16 | 6 px de espessura | Textura horizontal repetida do Asclépio até o aliado (até 260 px) |

### Auras e estados (256×256)

Feitas no tamanho do Talos e reduzidas pelo raio dos outros heróis (Ártemis 68%, Asclépio 73%).

| Arquivo | Estado | Na tela (Talos) | Animação |
| --- | --- | --- | --- |
| `aura_valvula.png` | Protegido pela Válvula de Pressão | 64 px | gira 1 rad/s, 85% |
| `aura_engrenagem.png` | Escudo da Engrenagem Vital | 72 px | gira -1,8 rad/s, 95% |
| `aura_segunda.png` | Imortal (Segunda Chance) | 76 px | gira 1,5 rad/s, 90% |
| `aura_raiz.png` | Preso pela Armadilha | 64 px | fixa, 4 px abaixo do centro |

### Partículas

| Arquivo | Fonte | Na tela | Uso |
| --- | --- | --- | --- |
| `fumaca.png` | 64×64 | 20 a 32 px, crescendo até 130% | Vapor da Válvula e rastro da Investida/Salto (tingida pela cor do efeito: desenhe branca) |
| `chuva_flecha.png` | 32×32 | 12 px | Flechas da Chuva de Prata, desenhadas apontando para a DIREITA (o código inclina para a queda) |
| `cura_mais.png` | 32×32 | 14 px | Sinais de cura do Sopro Restaurador, sobem 26 px |
| `veneno_bolha.png` | 16×16 | 5 a 8 px | Bolhas sobre o envenenado |
| `atordoado_estrela.png` | 32×32 | 8 px | 3 estrelas girando sobre o atordoado |

O rastro de avanço não tem arquivo: com sprite, usa cópias translúcidas do próprio herói.

Para ligar um efeito novo: `Art.draw_fx(ci, "nome", centro, tamanho, escala, alfa, giro)` devolve
false sem a imagem, e aí o código desenha como hoje. Todo nome novo vai em `Art.FX_EFFECTS`
(`scripts/art.gd`) e nesta lista; os testes conferem as duas coisas.
