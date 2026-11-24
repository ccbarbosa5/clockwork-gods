# Clockwork Gods — Referência de heróis e habilidades (índice)

Índice dos heróis e fichas do Pacote 1 (Talos, Ártemis, Asclépio). **Os números que valem são os de `scripts/data.gd`**; os desta página podem estar atrasados (última revisão completa: 11 nov. 2026, PR #29; números do PR #35 em docs/projeto/balanceamento.md). Em conflito, vale `docs/projeto/regras-de-herois.md` para regras de herói e o código para números. As descrições do "desenho por código" de cada habilidade foram omitidas nesta cópia (hoje só aparecem quando falta a imagem); a versão integral ficou no Projeto "Ichor" do claude.ai.

## Onde está cada coisa

| Assunto | Documento |
| --- | --- |
| Regras obrigatórias para qualquer herói | `docs/projeto/regras-de-herois.md` |
| Fichas completas de Hércules, Zeus e Atena | `docs/projeto/herois-pacote-3.md` |
| Números que mudaram no jogo e taxas de vitória | `docs/projeto/balanceamento.md` |
| Fichas de Talos, Ártemis e Asclépio | seção "Fichas do Pacote 1" abaixo |
| Textos de herói e habilidade (PT e EN) | `i18n/textos.csv` |
| Sprites, retratos, efeitos e tamanhos na tela | `docs/projeto/decisoes-tecnicas-arte.md`, `docs/projeto/fx-pacote-3.md` e `assets/README.md` |
| Roda do Destino (combos de cartas) | `docs/projeto/sistema-engrenar.md` e `docs/projeto/roda-do-destino-codigo.md` |
| Como colocar um herói novo no código | `docs/projeto/como-adicionar-heroi.md` |

## Os 6 heróis

Distâncias em px (1 m = 30 px). Engrenagem da Roda do Destino entre parênteses: Mov = Movimento, Ctrl = Controle, Atq = Ataque, Def = Defesa. Vida e dano: ver `scripts/data.gd`.

| Herói | Função · origem · IA | Vel. (px/s) | Raio | Básico (intervalo / alcance) | Cartas (custo em Ícor) | Ultimate |
| --- | --- | --- | --- | --- | --- | --- |
| Talos | Tanque · lenda · frontline | 72 | 22 | 0,9 s / 62, corpo a corpo, 50% em volta | Muralha de Bronze 3 (Def) · Investida a Vapor 4 (Mov) · Válvula de Pressão 2 (Def) | Fúria da Forja |
| Hércules | Tanque · semideus · dive | 80 | 21 | 1,0 s / 58, corpo a corpo | Salto de Nemeia 3 (Mov) · Pele do Leão 2 (Def) · Corrente de Cérbero 3 (Ctrl) | Décimo Terceiro Trabalho |
| Ártemis | Dano · deusa · backline_dps | 96 | 15 | 0,55 s / 300, projétil | Disparo Perfurante 3 (Atq) · Armadilha de Caça 2 (Ctrl) · Salto Lunar 3 (Mov) | Chuva de Prata |
| Zeus | Dano · deus · flank | 92 | 16 | 0,7 s / 270, raio instantâneo que salta para um 2º alvo | Corrente de Raios 3 (Atq) · Nuvem de Tempestade 3 (Ctrl) · Voo da Águia 2 (Mov) | Fúria do Olimpo |
| Asclépio | Suporte · semideus · backline_support | 90 | 16 | 0,75 s / 230, projétil; cura automática a até 260 | Sopro Restaurador 3 (Def) · Veneno da Serpente 2 (Atq) · Engrenagem Vital 4 (Def) | Segunda Chance |
| Atena | Suporte · deusa · battle_support | 88 | 17 | 0,8 s / 180, lança; Escudo de Palas (+10 de escudo num aliado a até 220, máx. 60, 4 s) | Égide 3 (Def) · Comando de Guerra 3 (Mov) · Olhar da Coruja 2 (Ctrl) | Falange de Atenas |

## Regras comuns a todos os heróis
- **Cartas:** não têm tecla fixa. Cada carta ocupa uma das 4 posições da mão (teclas 1 a 4) conforme o sorteio do deck. O jogador clica e o herói usa a habilidade sozinho no melhor momento, em até 5 s; se não surgir chance, usa assim mesmo. Entre duas habilidades armadas do mesmo herói há uma pausa de 0,3 s.
- **Recarga:** nenhuma habilidade tem tempo de recarga próprio. O limite é o custo em Ícor (máximo 10, +1 a cada 2,5 s) e o giro do deck de 9 cartas.
- **Ultimate:** botão fixo (teclas Q, W, E na ordem Tanque, Dano, Suporte), sem custo de Ícor. Carrega até 100 pontos: 0,06 por ponto de dano, 0,07 por ponto de cura, 0,06 por ponto de dano evitado, 0,45 por segundo no ponto e 0,3 por segundo sempre.
- **Recuo da IA:** no Equilibrado o herói recua com menos de 30% de vida (Agressivo 15%, Defensivo 35%) e volta com 80%. Se o inimigo passar de 85% de progresso, ninguém recua. (Pacote 5 acrescentou Frascos de Ambrosia, Centelha Viva e cobertura: docs/projeto/pacote-5-codigo.md.)

## Fichas do Pacote 1

### Talos
- Função: Tanque, cor #F59933. Origem: lenda. IA: frontline.
- Papel em batalha: lidera o time. Fica no ponto ou à frente dele (Equilibrado 20 px à frente do centro, Agressivo 150 px, Defensivo no centro). Antes do ponto abrir, espera na borda do ponto (140 px do centro). Se os aliados ficam a mais de 280 px atrás dele, espera o grupo (menos no Agressivo). Avança no alvo até ficar no alcance do soco. Quando precisa contestar, fica 25 px à frente do centro do ponto.
- Ataque básico: corpo a corpo, 26 de dano a cada 0,9 s; inimigos a até 45 px do alvo levam 50%.

**Muralha de Bronze** (carta, 3 Ícor, Proteção). "Bloqueia tiros" / "Escudo frontal que bloqueia projéteis por 4 s." Escudo preso ao Talos, voltado para onde ele olha: bloqueia projéteis que chegam entre 18 e 50 px do centro, dentro de 58,7° para cada lado (~117°). Dura 4 s ou até absorver 450 de dano (conta como mitigado). Só bloqueia projéteis (não corpo a corpo, áreas nem armadilhas). IA: inimigo de longo alcance (mais de 150 px) a menos de 450 px; senão, qualquer inimigo a menos de 250 px.

**Investida a Vapor** (carta, 4 Ícor, Mobilidade). "Avança e atordoa" / "Avança em linha, causa 45 de dano e atordoa." Avanço de 260 px em 0,35 s. Cada inimigo atingido leva 45, fica atordoado 0,6 s e é empurrado ~114 px na direção do avanço (uma vez cada). Obstáculos param o Talos e os empurrados. IA: inimigo a menos de 300 px; escolhe o mais próximo e mais ferido e mira 0,15 s à frente do movimento dele.

**Válvula de Pressão** (carta, 2 Ícor, Proteção). "-40% dano no grupo" / "Aliados próximos recebem 40% menos dano por 4 s." Círculo de raio 190 px em volta do Talos; o dano evitado conta como mitigado. IA: inimigo a menos de 350 px e (2 ou mais aliados a até 190 px, contando o Talos, ou Talos com menos de 60% de vida).

**Fúria da Forja** (ultimate, tecla do Tanque, Controle). "Atordoa em área" / "Golpe no chão: 60 de dano e atordoa em área." Círculo de raio 210 px em volta do Talos: 60 de dano e 1,6 s de atordoamento. IA: 2 ou mais inimigos a menos de 200 px, ou 1 inimigo com menos de 35% de vida.

### Ártemis
- Função: Dano, cor #B873FF. Origem: deusa. IA: backline_dps.
- Papel em batalha: atira de trás do tanque. Fica 90 px atrás do tanque e 55 px acima dele (40 px atrás no Agressivo) e nunca passa mais de 30 px à frente dele. Prefere alvos com pouca vida. Chega até 255 px do alvo (85% do alcance) e recua quando um inimigo fica a menos de 150 px, puxando para a própria base. Quando precisa contestar, fica 40 px atrás e 35 px acima do centro do ponto.
- Ataque básico: projétil a cada 0,55 s, a 900 px/s, raio 5, vida de 1,2 s.

**Disparo Perfurante** (carta, 3 Ícor, Dano). "Tiro perfurante" / "Tiro que atravessa inimigos causando 90 de dano." Projétil de raio 8 a 1100 px/s por 0,85 s (~935 px), sai 20 px à frente; atravessa heróis (cada um uma vez), para em obstáculos e na Muralha de Bronze inimiga. IA: entre os inimigos a até 700 px, o que deixa mais inimigos alinhados (a até 32 px da linha) e mira 0,15 s à frente.

**Armadilha de Caça** (carta, 2 Ícor, Controle). "Prende inimigo" / "Prende o primeiro inimigo por 1,8 s e causa 30 de dano." Colocada a até 380 px; arma em 0,6 s e fica 20 s no chão; dispara com inimigo a menos de 30 px + o raio dele. Máximo de 2 por time (a terceira remove a mais antiga). O preso ainda ataca e usa habilidades. IA: inimigo a menos de 320 px (posição prevista); no fim do prazo, coloca no ponto, 20 px para o próprio lado.

**Salto Lunar** (carta, 3 Ícor, Mobilidade). "Recua e acelera" / "Recua e ganha 60% de velocidade de ataque por 3 s." Salto de 180 px em 0,25 s, para longe do inimigo mais próximo (se houver um a menos de 400 px) ou em direção à base; depois +60% de velocidade de ataque por 3 s. Obstáculos param o salto. IA: inimigo a menos de 160 px, ou Ártemis com menos de 50% de vida e inimigo a menos de 300 px.

**Chuva de Prata** (ultimate, tecla do Dano, Dano). "Dano em área" / "Chuva de flechas: dano contínuo e lentidão em área." Círculo de raio 170 px num ponto a até 650 px; a cada 0,25 s, 22 de dano e 30% de lentidão (10 pulsos, até 220). Dura 2,5 s. IA: 2 ou mais inimigos a até 160 px um do outro e a até 650 px (mira no centro do grupo); ou 1 inimigo a até 600 px no ponto ou com menos de 40% de vida.

### Asclépio
- Função: Suporte, cor #54D973. Origem: semideus. IA: backline_support.
- Papel em batalha: cura sem parar e segue quem precisa. A cada 0,5 s cura o aliado mais ferido (abaixo de 97%) a até 260 px; procura aliados a até 600 px. Se o ferido está a mais de 160 px, vai até 60 px atrás dele, sem passar à frente do tanque. Sem feridos, fica 120 px atrás do tanque e 50 px abaixo dele. Recua quando um inimigo fica a menos de 110 px. Só ataca quando não está curando alguém no alcance. Quando precisa contestar, fica 50 px atrás e 35 px abaixo do centro do ponto.
- Ataque básico: projétil de 10 de dano a cada 0,75 s, a 620 px/s, raio 5, vida de 1,2 s.

**Sopro Restaurador** (carta, 3 Ícor, Cura). "Cura em área" / "Cura 120 de vida dos aliados ao redor." Círculo de raio 210 px em volta dele; metade em quem estiver com cura reduzida. IA: a soma da vida que falta nos aliados a até 210 px chega a 90.

**Veneno da Serpente** (carta, 2 Ícor, Dano). "Veneno, corta cura" / "Dano contínuo e reduz a cura do alvo pela metade." Projétil de raio 7 a 750 px/s por 1 s; 15 no impacto, depois 12/s por 5 s, e a cura recebida cai pela metade por 5 s. Para no primeiro inimigo, em obstáculos e na Muralha inimiga. IA: inimigo a menos de 500 px (mira 0,15 s à frente).

**Engrenagem Vital** (carta, 4 Ícor, Proteção). "Escudo no aliado" / "Escudo de 150 em um aliado por 5 s." Alvo único, sem limite de distância; dura 5 s ou até acabar (conta como mitigado). IA: aliado com menos de 85% de vida e inimigo a até 450 px dele (o mais ferido); no fim do prazo, aplica no tanque ou nele mesmo.

**Segunda Chance** (ultimate, tecla do Suporte, Cura). "Ninguém morre" / "Aliados próximos não podem morrer por 3 s." Círculo de raio 240 px: a vida não cai abaixo de 1 por 3 s e cura 40 na hora. Continuam levando dano e controle. Durante a proteção, o herói não recua. IA: aliado a até 240 px com menos de 35% de vida.
