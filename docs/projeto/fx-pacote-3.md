# Efeitos do Pacote 3 (Hércules, Zeus, Atena)

11 nov. 2026. Mesmo padrão de docs/projeto/decisoes-tecnicas-arte.md (seção 3): **uma imagem por efeito**, animada pelo código (cresce, some, gira); sem sequência de quadros. Regras de herói: docs/projeto/regras-de-herois.md. Estilo e luz: docs/projeto/guia-de-arte.md. Medidas na tela na base 1280 × 720. Quais já foram entregues: ver `assets/fx/` e `assets/README.md`.

## Situação
- Os 19 efeitos abaixo já são **desenhados por código** e o **carregamento com fallback já está pronto**: basta pôr o PNG em `assets/fx/` com o nome exato. Sem o arquivo, o desenho por código continua.
- Um teste automático confere cada imagem entregue (PNG com transparência real, nome conhecido, tamanho de fonte proporcional ao da tabela).
- Caminho de entrega: `D:\Ichor\assets\aprovados\fx\` → `assets/fx/`.

## Regras gerais
- PNG RGBA com transparência real, sem sombra (o código desenha sombras).
- **Luz de cima, neutra** em tudo o que gira ou aponta.
- O que aponta (projéteis, coruja) aponta **para a direita (0°)**.
- Faixas repetidas (corrente, raio) emendam na horizontal sem costura, como `feixe_cura`.
- Áreas e auras: miolo vazio ou bem transparente. Áreas grandes são desenhadas a 55% de opacidade (algumas menos).
- **Nenhum destes é tingido** pelo código (só `tiro_basico` e `fumaca`, do Pacote 1, são).
- Cores: Hércules laranja-bronze e couro; Zeus dourado e branco-azulado; Atena prata e verde-oliva.

## Hércules

| Arquivo (fx/) | Fonte | Na tela | Gira? | Descrição |
| --- | --- | --- | --- | --- |
| `nemeia_alvo.png` | 256 × 256 | 150 × 150 (raio 75) | não | Marca no chão onde ele vai cair no Salto de Nemeia (0,45 s no ar). Poeira/pegada de leão laranja-bronze, miolo vazio. 50% a 100% de opacidade |
| `nemeia_queda.png` | 256 × 256 | 150 × 150 | não | Impacto da queda: anel de poeira e rachaduras. Cresce e some em 0,5 s |
| `pele_juba.png` | 256 × 256 | ~70 × 70 (escala pelo raio) | sim, devagar | Aura da Pele do Leão (3 s): juba dourada, centro vazio (55–60% do diâmetro) |
| `corrente_elo.png` | 64 × 16 | faixa de 8 px | aponta para o gancho | Corrente de Cérbero: elos de bronze escuro, repetidos na horizontal |
| `corrente_gancho.png` | 64 × 64 | 20 × 20 | aponta para o voo | Gancho de três pontas (cabeças de cão estilizadas, se couber), para a direita |
| `trabalho_impacto.png` | 128 × 128 | 60 × 60 | não | Décimo Terceiro Trabalho (ultimate): onde o inimigo arremessado cai. Some em 0,5 s |

## Zeus

| Arquivo (fx/) | Fonte | Na tela | Gira? | Descrição |
| --- | --- | --- | --- | --- |
| `raio_cadeia.png` | 64 × 16 | faixa de 6 a 12 px | aponta para o alvo | Raio dourado-branco do básico e da Corrente de Raios. Repete na horizontal; o código faz o zigue-zague |
| `nuvem_area.png` | 512 × 512 | 200 × 200 (raio 100) | sim, devagar | Nuvem de Tempestade vista de cima: cinza-clara com borda dourada. ~75% |
| `raio_queda.png` | 64 × 320 | 28 × 140, vertical | não | Raio do céu (Nuvem e Fúria do Olimpo). De pé: topo largo e difuso, ponta no chão |
| `olimpo_area.png` | 512 × 512 | 700 × 700 (raio 350) | sim, devagar | Fúria do Olimpo (ultimate, 4 s): céu escurecido, brilho dourado na borda. A só 35% |
| `aguia_pena.png` | 32 × 32 | 12 × 12 | sim (cai girando) | Voo da Águia: pena dourada |

## Atena

| Arquivo (fx/) | Fonte | Na tela | Gira? | Descrição |
| --- | --- | --- | --- | --- |
| `lanca_projetil.png` | 128 × 32 | 34 × 8 | aponta para o voo | Básico: lança de prata com ponta de bronze, para a direita |
| `egide_cupula.png` | 512 × 512 | 200 × 200 (raio 100) | não | Égide (3 s): cúpula de prata translúcida, Medusa em relevo no centro. Até 80% |
| `comando_area.png` | 512 × 512 | 400 × 400 (raio 200) | não | Comando de Guerra: onda verde-oliva com setas para fora. Cresce e some em 0,5 s |
| `comando_aura.png` | 256 × 256 | ~72 × 72 (escala pelo raio) | sim (anti-horário) | Aliado sob o Comando: setas prateadas em volta, centro vazio |
| `coruja_voo.png` | 64 × 64 | 24 × 24 | aponta para o alvo | Olhar da Coruja: coruja de latão voando, asas abertas, para a direita |
| `coruja_olho.png` | 80 × 48 | 20 × 12 | não | Marca do Olhar da Coruja (+20% de dano recebido): olho dourado |
| `falange_area.png` | 512 × 512 | 360 × 360 (raio 180) | não | Falange de Atenas (ultimate): anel de escudos de prata, lança no centro, miolo vazio. 55% |
| `escudo_palas.png` | 256 × 256 | ~68 × 68 (escala pelo raio) | sim, devagar | Escudo de Palas (passiva e Falange): anel de prata, centro vazio |

## Fora desta lista
- Rastro e arremesso do Hércules no ar: usam o próprio sprite.
- Roda do Destino: desenhada por código (docs/projeto/roda-do-destino-codigo.md).

## Prioridade sugerida
1. Os que aparecem o tempo todo: `raio_cadeia`, `lanca_projetil`, `escudo_palas`.
2. Áreas grandes: `nuvem_area`, `olimpo_area`, `egide_cupula`, `falange_area`, `comando_area`.
3. O resto.
