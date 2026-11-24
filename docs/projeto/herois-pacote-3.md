# Clockwork Gods — Pacote 3: Hércules, Zeus e Atena

Aprovado pelo usuário em 9 nov. 2026. Três heróis novos, rostos do jogo (capa e divulgação). Pai e dois filhos. O elenco passa a ter 6 heróis: Talos, Ártemis, Asclépio, Hércules, Zeus e Atena.

**Regras:** todo herói segue `docs/projeto/regras-de-herois.md` (aparência, três ganchos, cores, testes, kit, lore, arquivos e ordem de trabalho). Em caso de conflito, vale aquele documento. Este pacote já foi revisado por ele em 9 nov. 2026.

Valores em pixels na resolução base 1280 × 720 (1 m = 30 px). **Números de jogo atualizados em 12 nov. 2026 (PR #35, arena nova Três Corredores)** com os valores finais do balanceamento (docs/projeto/balanceamento.md): Hércules vida 680, dano do básico 34; Zeus vida 335, alcance 270 px, dano do básico 18,5 (salto 8), Corrente de Raios 68/51/38/29; Atena vida 335. Na tabela de resumo, também Talos vida 590, Ártemis dano do básico 17,5 e Asclépio cura 14,1 a cada 0,5 s. Taxas de vitória (2.048 partidas, 1.024 por herói): Hércules 46,4%, Zeus 48,5%, Atena 48,7%. Regras comuns de jogo (cartas sem tecla fixa, pausa de 0,3 s entre habilidades, sem recarga própria, carga da ultimate, recuo da IA) iguais às de docs/projeto/referencia-herois-habilidades.md. **Em caso de dúvida, o número que vale é o de `scripts/data.gd`.**

Decisões do usuário (9 nov. 2026):
- Nome em inglês: **Hercules** (forma romana, mais conhecida). Em português: Hércules.
- Família do mito adotada: Zeus é pai de Hércules, Atena e Ártemis, e avô de Asclépio.
- Comando de Guerra usa o tipo **Mobilidade** (não foi criado um tipo novo).

## Resumo do elenco

| Herói | Função | Origem | Estilo de IA | Vida | Velocidade | Alcance | Dano por segundo do básico |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Talos | Tanque | Lenda | frontline | 590 | 72 px/s | 62 px | ~29 + 50% em área |
| **Hércules** | Tanque | Semideus | dive | 680 | 80 px/s | 58 px | 34, sem área |
| Ártemis | Dano | Deusa | backline_dps | 250 | 96 px/s | 300 px | ~32, alvo único |
| **Zeus** | Dano | Deus | flank | 335 | 92 px/s | 270 px | ~26 (até ~38 com o salto) |
| Asclépio | Suporte | Semideus | backline_support | 280 | 90 px/s | 230 px | ~13 + cura ~28/s |
| **Atena** | Suporte | Deusa | battle_support | 335 | 88 px/s | 180 px | 20 + escudo ~12/s só atacando |

---

## HERÓI: Hércules (EN: Hercules)

### Lore
- **Quem é nos Ritos:** filho de Zeus, completou os doze trabalhos e subiu ao Olimpo como deus. Deu seu Ícor à Grande Engrenagem sem hesitar e trata cada rito como o décimo terceiro trabalho: mais uma chance de ouvir um elogio do pai, que nunca vem.
- **Aparência:** aparência clássica do mito: corpo e rosto humanos, musculoso e de porte largo, pele bronzeada, com as veias de Ícor do corpo forjado. Equipamento steampunk: pele do Leão de Nemeia sobre a cabeça e os ombros, ombreira e braçadeiras de latão, caldeira de Ícor presa às costas. Paleta-base: pele bronzeada, bronze e madeira de oliveira; laranja (#F59933, Tanque) só nos destaques.
- **Três ganchos:**
  - *Silhueta:* corrente de bronze enrolada no braço, com gancho de três pontas. É a corrente com que ele arrastou Cérbero do Hades no 12º trabalho; as três pontas são as três cabeças do cão. Hefesto a forjou de novo, e ela virou a Corrente de Cérbero.
  - *Objeto-assinatura:* clava de oliveira com pistões. No mito, ele mesmo cortou a clava de uma oliveira selvagem; Hefesto pôs pistões que soltam vapor a cada golpe, mas a madeira é a original.
  - *Detalhe de história:* troféus dos doze trabalhos no cinto (presa do javali de Erimanto, pena de ave do Estínfalo, chifre dourado da corça de Cerínia, entre outros) e doze marcas gravadas na braçadeira, uma por trabalho. Ao lado delas há um espaço vazio: é para a décima terceira marca, que ele espera ganhar nos Ritos.
- **Relação com o Ícor e a centelha:** nasceu com metade de Ícor e metade de sangue mortal, e ganhou o resto ao virar deus. O próprio eco ele desafia para uma queda de braço.
- **Personalidade:** fanfarrão, generoso, impulsivo.
- **Motivação:** provar ao pai que merece o Olimpo.
- **Relações:** Zeus é o pai cuja aprovação ele persegue. Atena é a meia-irmã que o ajudou nos trabalhos; em campo, ele a obedece. Ártemis é meia-irmã e ainda está brava porque ele capturou a corça sagrada dela. Com Talos, é rival de força. Asclépio o remenda depois de cada rito. Hefesto é o meio-irmão cuja forja ele admira.
- **Frase marcante:** "Doze trabalhos. Este é o décimo terceiro." / "Twelve labors. This is the thirteenth."
- **Habilidades na história:** Salto de Nemeia é o bote do leão que ele venceu; Pele do Leão é a pele que nenhuma lâmina corta; Corrente de Cérbero é a corrente com que arrastou o cão do Hades no 12º trabalho; Décimo Terceiro Trabalho é o próximo trabalho: arrancar um inimigo do lugar e jogá-lo aos pés do próprio time.

### Ficha de jogo
- **Função:** Tanque, cor #F59933. **Origem:** semideus. **Estilo de IA:** dive.
- **Papel em batalha:** segue a formação de tanque, sem procurar alvos mais longe que o normal, e prefere atacar a linha de trás inimiga (Dano e Suporte), evitando o tanque. (No balanceamento, a busca 150 px mais longe foi retirada: ele abandonava o time.)
- **Atributos:** raio 21 px, vida 680, velocidade 80 px/s (2,7 m/s), alcance do ataque básico 58 px (~1,9 m).
- **Ataque básico:** corpo a corpo com a clava de oliveira com pistões, 34 de dano a cada 1,0 s, sem dano em área. Desenho sugerido: arco de impacto alaranjado + jato de vapor curto.
- **Comparação com o Talos:** mais vida (680 contra 590) e mais rápido, mais dano no alvo único (34 contra ~29 por segundo), mas sem dano em área no básico e sem as proteções de grupo do Talos (Muralha e Válvula). Ultimate de alvo único (Talos: área).

#### Salto de Nemeia (EN: Nemean Leap)
- **Posição:** carta.
- **Texto na carta:** "Salta e desacelera" / "Leap and slow". **Dica:** "Salta até um ponto; ao cair, causa dano e lentidão em área." / "Leaps to a point; on landing, deals damage and slows in an area." **Tipo:** Mobilidade.
- **Custo:** 3 de Ícor.
- **O que faz:** salto até o ponto em 0,45 s. Ao cair, 40 de dano e 30% de lentidão por 1,5 s.
- **Em quem:** inimigos na área de queda.
- **Forma e alcance:** ponto a até 300 px (10 m); área de queda com raio 75 px (2,5 m).
- **Duração:** 0,45 s de salto; lentidão de 1,5 s.
- **Interações:** passa por cima de colunas (é um salto), mas não sai da arena.
- **Arte sugerida:** sombra que cresce no ponto de queda; ao cair, anel laranja-bronze + poeira.
- **Quando a IA usa:** inimigo de Dano ou Suporte a até 300 px; mira nele.

#### Pele do Leão (EN: Lion's Hide)
- **Posição:** carta.
- **Texto na carta:** "-50% dano, imune" / "-50% dmg, immune". **Dica:** "Recebe 50% menos dano e ignora atordoar, prender e empurrar por 3 s." / "Takes 50% less damage and ignores stun, root and knockback for 3 s." **Tipo:** Proteção.
- **Custo:** 2 de Ícor.
- **O que faz:** −50% de dano recebido e imunidade a atordoamento, raiz e empurrão. O dano evitado conta como mitigado.
- **Em quem:** o próprio Hércules.
- **Forma e alcance:** sobre ele.
- **Duração:** 3 s.
- **Arte sugerida:** juba dourada brilhando em volta da cabeça; anel âmbar no corpo.
- **Quando a IA usa:** Hércules abaixo de 70% de vida com inimigo a até 250 px, ou logo depois do Salto de Nemeia.

#### Corrente de Cérbero (EN: Cerberus Chain)
- **Posição:** carta.
- **Texto na carta:** "Puxa um inimigo" / "Pulls an enemy". **Dica:** "Lança uma corrente que puxa o primeiro inimigo atingido." / "Throws a chain that pulls the first enemy hit." **Tipo:** Controle.
- **Custo:** 3 de Ícor.
- **O que faz:** 25 de dano; puxa o alvo 150 px (5 m) em direção ao Hércules e o atordoa por 0,4 s.
- **Em quem:** o primeiro inimigo atingido.
- **Forma e alcance:** projétil (corrente) de 330 px (11 m) a 900 px/s, mirado num ponto.
- **Duração:** instantânea; atordoamento de 0,4 s.
- **Interações:** para em colunas e na Muralha de Bronze inimiga. Colunas também param o puxão.
- **Arte sugerida:** corrente de bronze com elos grossos e um gancho de três pontas (as três cabeças).
- **Quando a IA usa:** inimigo de Dano ou Suporte entre 120 e 330 px.

#### Décimo Terceiro Trabalho (ultimate) (EN: The Thirteenth Labor)
- **Posição:** botão de ultimate.
- **Texto na carta:** "Agarra e arremessa" / "Grab and throw". **Dica:** "Agarra um inimigo e o arremessa em direção ao seu time." / "Grabs an enemy and throws them toward your team." **Tipo:** Controle.
- **Custo:** 100 de carga.
- **O que faz:** 90 de dano; arremessa o alvo 240 px (8 m) na direção da base aliada; atordoamento de 1,2 s ao cair.
- **Em quem:** o inimigo mais próximo.
- **Forma e alcance:** alvo a até 90 px (3 m).
- **Duração:** instantânea; atordoamento de 1,2 s.
- **Interações:** colunas param o arremesso (o alvo para ao bater).
- **Arte sugerida:** silhueta do alvo girando no ar com rastro laranja; impacto com rachaduras curtas.
- **Quando a IA usa:** inimigo de Dano ou Suporte a até 90 px, ou qualquer inimigo com menos de 40% de vida.

---

## HERÓI: Zeus (EN: Zeus)

### Lore
- **Quem é nos Ritos:** o rei dos deuses liderou o sacrifício que selou os Titãs e foi quem mais deu Ícor à Engrenagem. Agora está num corpo como qualquer outro, e a Engrenagem não aceita reis. Disputa os Ritos para voltar a reinar.
- **Aparência:** aparência clássica do mito: corpo e rosto humanos, alto e imponente, barba e cabelos brancos, com as veias de Ícor do corpo forjado. Equipamento steampunk: manto branco curto com filetes dourados, braçadeiras de ouro com engrenagens. Paleta-base: branco e dourado; roxo (#B873FF, Dano) só nos destaques. Raios sempre dourados.
- **Três ganchos:**
  - *Silhueta:* coroa de bobinas quebrada ao meio, com raios dourados saltando pela fenda. A coroa rachou no dia em que ele verteu seu Ícor na Grande Engrenagem; desde então não fecha mais, e o trovão escapa por ali. É o "Rei Sem Trono" visto de longe.
  - *Objeto-assinatura:* águia de latão com um raio nas garras. É a águia sagrada de Zeus, refeita por Hefesto; voa à frente dele no Voo da Águia e carrega o raio que ele lança.
  - *Detalhe de história:* cicatriz de raio em Ícor do peito ao rosto, e um olho dourado. Zeus foi quem mais deu Ícor à Engrenagem; ao sair, o Ícor queimou o caminho do coração até o olho. O corpo forjado, idêntico ao original, reproduziu a cicatriz, que é a veia de Ícor mais grossa do elenco.
- **Relação com o Ícor e a centelha:** acha que a Engrenagem lhe deve algo. Trata o próprio eco como um usurpador: "Só há um rei."
- **Personalidade:** majestoso, vaidoso, explosivo.
- **Motivação:** reinar outra vez.
- **Relações:** pai de Hércules, Atena e Ártemis. Avô de Asclépio, que ele mesmo fulminou; o ressentimento é mútuo, e agora é Asclépio quem cuida do corpo dele. Hefesto é o filho que ele atirou do Olimpo e que hoje manda nos Ritos, uma ironia que Zeus odeia. Talos foi um presente dele a Creta (MITO, em uma das versões): ainda o chama de "senhor", mas obedece a Hefesto.
- **Frase marcante:** "Sem corpo, sem trono. Mas o trovão ainda é meu." / "No body, no throne. But the thunder is still mine."
- **Habilidades na história:** Corrente de Raios é o raio de Zeus, que escapa pela fenda da coroa; Nuvem de Tempestade é o deus do céu chamando o tempo; Voo da Águia vem da águia, seu animal sagrado; Fúria do Olimpo é a ira do rei, que cai sobre todos.

### Ficha de jogo
- **Função:** Dano, cor #B873FF. **Origem:** deus. **Estilo de IA:** flank.
- **Papel em batalha:** contorna pelas laterais, a 150–170 px acima ou abaixo do centro, antes de atacar; foca o inimigo mais ferido; recua quando um inimigo fica a menos de 180 px.
- **Atributos:** raio 16 px, vida 335, velocidade 92 px/s (3,1 m/s), alcance do ataque básico 270 px (9 m).
- **Ataque básico:** raio dourado instantâneo (sem projétil), 18,5 de dano a cada 0,7 s, que salta para 1 inimigo a até 90 px do alvo com 8 de dano. Desenho sugerido: linha dourada em zigue-zague, 0,1 s.
- **Comparação com a Ártemis:** 30 px a menos de alcance (270 contra 300), mais vida (335 contra 250), menos dano no alvo único (~26 contra ~32 por segundo); parte do dano dele vai para um segundo alvo.

#### Corrente de Raios (EN: Chain Lightning)
- **Posição:** carta.
- **Texto na carta:** "Raio em cadeia" / "Chain lightning". **Dica:** "Raio que salta entre até 4 inimigos próximos." / "Lightning that jumps between up to 4 nearby enemies." **Tipo:** Dano.
- **Custo:** 3 de Ícor.
- **O que faz:** 68 de dano no primeiro alvo; salta 3 vezes, cada salto 25% mais fraco (68, 51, 38, 29 = até 186).
- **Em quem:** um inimigo e os mais próximos dele.
- **Forma e alcance:** alvo a até 280 px (9,3 m); saltos para inimigos a até 150 px (5 m) do anterior; cada inimigo é atingido uma vez.
- **Duração:** instantânea.
- **Interações:** não é projétil: a Muralha de Bronze e a Égide não bloqueiam.
- **Arte sugerida:** raios dourados ramificados entre os alvos, faísca em cada um.
- **Quando a IA usa:** escolhe o inimigo a até 280 px com mais inimigos por perto; usa com 2 ou mais alvos, ou alvo com vida abaixo do dano do primeiro raio (hoje 68, ou seja, um raio finaliza). No código, o limite é ligado ao dano atual (`chain_cast[0]`), para acompanhar qualquer ajuste de balanceamento.

#### Nuvem de Tempestade (EN: Storm Cloud)
- **Posição:** carta.
- **Texto na carta:** "Nuvem que atordoa" / "Stunning cloud". **Dica:** "Após 1 s, um raio cai na área, causa dano e atordoa." / "After 1 s, lightning strikes the area, dealing damage and stunning." **Tipo:** Controle.
- **Custo:** 3 de Ícor.
- **O que faz:** marca a área; depois de 1 s, 50 de dano e atordoamento de 0,8 s em quem estiver dentro.
- **Em quem:** inimigos na área.
- **Forma e alcance:** ponto a até 450 px (15 m); círculo de raio 100 px (3,3 m).
- **Duração:** 1 s de aviso; atordoamento de 0,8 s.
- **Arte sugerida:** nuvem cinza-clara com bordas douradas sobre a área; um raio dourado grosso ao cair.
- **Quando a IA usa:** 2 ou mais inimigos a até 100 px um do outro, ou um inimigo preso, atordoado ou parado no ponto.

#### Voo da Águia (EN: Eagle's Flight)
- **Posição:** carta.
- **Texto na carta:** "Avança e carrega" / "Dash and charge". **Dica:** "Avança e o próximo ataque causa mais dano e salta mais." / "Dashes, and the next attack deals more damage and jumps further." **Tipo:** Mobilidade.
- **Custo:** 2 de Ícor.
- **O que faz:** avanço de 200 px (6,7 m) em 0,2 s até o ponto; o próximo ataque básico em até 3 s causa +30 de dano e salta para 2 inimigos.
- **Em quem:** o próprio Zeus.
- **Forma e alcance:** deslocamento em linha de até 200 px.
- **Duração:** 0,2 s; bônus por até 3 s.
- **Interações:** colunas e bordas param o avanço.
- **Arte sugerida:** rastro de penas douradas; asas de luz por um instante.
- **Quando a IA usa:** avança para a faixa lateral (o flanco), nunca para cima do inimigo; ou para fugir com inimigo a menos de 140 px.

#### Fúria do Olimpo (ultimate) (EN: Wrath of Olympus)
- **Posição:** botão de ultimate.
- **Texto na carta:** "Tempestade de raios" / "Lightning storm". **Dica:** "Raios dourados caem em inimigos aleatórios ao redor." / "Golden lightning strikes random enemies nearby." **Tipo:** Dano.
- **Custo:** 100 de carga.
- **O que faz:** a cada 0,5 s, um raio cai num inimigo aleatório: 30 de dano e 20% de lentidão por 0,5 s. São 8 raios, até 240 de dano.
- **Em quem:** inimigos em volta do Zeus.
- **Forma e alcance:** círculo de raio 350 px (11,7 m) em volta dele (acompanha Zeus).
- **Duração:** 4 s.
- **Arte sugerida:** céu escurece levemente em volta; raios dourados verticais com clarão no chão.
- **Quando a IA usa:** 2 ou mais inimigos a até 350 px, ou um inimigo com menos de 40% de vida.

---

## HERÓI: Atena (EN: Athena)

### Lore
- **Quem é nos Ritos:** deusa da sabedoria e da guerra, nascida da cabeça de Zeus. É quem melhor entende os Arquitetos: para ela, os Ritos são estratégia pura. Sua lealdade é ao selo dos Titãs, por isso vigia o pai, que talvez queira mais o trono do que o selo.
- **Aparência:** aparência clássica do mito: corpo e rosto humanos, postura serena, com as veias de Ícor do corpo forjado. Equipamento steampunk: armadura de placas de prata com juntas de engrenagem e lança de prata. Paleta-base: prata e verde-oliva escuro; verde (#54D973, Suporte) só nos destaques, para não lembrar o Asclépio.
- **Três ganchos:**
  - *Silhueta:* elmo coríntio erguido no alto da cabeça, com o rosto à mostra, e crista de folhas de oliveira. Ela usa o elmo levantado porque prefere ver o campo inteiro; a oliveira é a árvore que ela deu a Atenas.
  - *Objeto-assinatura:* a Égide com a cabeça da Medusa, cujas cobras mecânicas se mexem. A cabeça foi um presente de Perseu; Hefesto fez as cobras voltarem a se mover. É o escudo da habilidade Égide.
  - *Detalhe de história:* coruja de latão de asas sempre abertas, pousada no ombro (um autômato, 100% máquina), e olhos cinza-claros. Os olhos vêm de Homero, que a chamava de "Atena de olhos glaucos"; a coruja nunca fecha as asas porque está sempre pronta para o Olhar da Coruja.
- **Relação com o Ícor e a centelha:** usa o próprio eco para prever o inimigo: "Sei exatamente o que eu faria."
- **Personalidade:** calculista, serena, exigente.
- **Motivação:** proteger o selo e garantir que a razão vença a força.
- **Relações:** Hefesto abriu a cabeça de Zeus com um machado para ela nascer; os dois se respeitam como colegas de ofício. Deu a Asclépio o sangue da Górgona, que cura e mata, e daí vêm a cura e o veneno dele (MITO adotado). Ártemis é respeitada como igual. Hércules é o protegido dela. Do Talos, admira a disciplina. Zeus: lealdade com desconfiança.
- **Frase marcante:** "Lute com a cabeça. O escudo cuida do resto." / "Fight with your head. The shield handles the rest."
- **Habilidades na história:** Égide é o escudo dela (com a Medusa); Comando de Guerra é a deusa da estratégia dando ordens; Olhar da Coruja vem da coruja, seu símbolo de sabedoria; Falange de Atenas é a formação de batalha da cidade que leva o nome dela.

### Ficha de jogo
- **Função:** Suporte, cor #54D973. **Origem:** deusa. **Estilo de IA:** battle_support.
- **Papel em batalha:** fica 50 px atrás do tanque e ataca sempre, mesmo protegendo.
- **Atributos:** raio 17 px, vida 335, velocidade 88 px/s (2,9 m/s), alcance do ataque básico 180 px (6 m).
- **Ataque básico:** lança arremessada (projétil), 16 de dano a cada 0,8 s, a 700 px/s. Desenho sugerido: lança de prata curta com rastro verde-oliva.
- **Passiva, Escudo de Palas (EN: Pallas's Shield):** cada acerto do ataque básico dá 10 de escudo ao aliado mais ferido a até 220 px (acumula até 60, dura 4 s). O absorvido conta como mitigado da Atena.
- **Comparação com o Asclépio:** mais vida (335 contra 280) e mais dano, menos alcance; protege só enquanto ataca (~12 por segundo contra ~28 de cura por segundo dele) e não cura.

#### Égide (EN: Aegis)
- **Posição:** carta.
- **Texto na carta:** "Cúpula contra tiros" / "Anti-shot dome". **Dica:** "Cúpula que bloqueia projéteis inimigos vindos de fora." / "Dome that blocks enemy projectiles from outside." **Tipo:** Proteção.
- **Custo:** 3 de Ícor.
- **O que faz:** cria uma cúpula que bloqueia projéteis inimigos que entram de fora; dura 3 s ou até absorver 400 de dano (conta como mitigado).
- **Em quem:** todos os aliados dentro.
- **Forma e alcance:** ponto a até 300 px (10 m); círculo de raio 100 px (3,3 m).
- **Duração:** 3 s.
- **Interações:** não bloqueia corpo a corpo, áreas, armadilhas nem raios do Zeus (não são projéteis).
- **Arte sugerida:** cúpula de prata translúcida com o rosto da Medusa em relevo no topo.
- **Quando a IA usa:** 2 ou mais aliados a até 100 px de um ponto e inimigo de longo alcance (mais de 150 px) a até 450 px.

#### Comando de Guerra (EN: War Command)
- **Posição:** carta.
- **Texto na carta:** "+20% dano e veloc." / "+20% dmg & speed". **Dica:** "Aliados próximos causam 20% mais dano e andam 20% mais rápido." / "Nearby allies deal 20% more damage and move 20% faster." **Tipo:** Mobilidade (decisão de 9 nov. 2026; não há tipo "Fortalecer").
- **Custo:** 3 de Ícor.
- **O que faz:** +20% de dano e +20% de velocidade de movimento.
- **Em quem:** a Atena e os aliados.
- **Forma e alcance:** círculo de raio 200 px (6,7 m) em volta dela.
- **Duração:** 4 s.
- **Arte sugerida:** estandarte de luz verde-oliva por um instante; setas prateadas girando nos aliados.
- **Quando a IA usa:** 2 ou mais aliados a até 200 px e inimigo a até 300 px, ou ponto disputado.

#### Olhar da Coruja (EN: Owl's Gaze)
- **Posição:** carta.
- **Texto na carta:** "Marca: +20% dano" / "Mark: +20% dmg". **Dica:** "A coruja marca um inimigo: recebe mais dano e fica lento." / "The owl marks an enemy: takes more damage and is slowed." **Tipo:** Controle.
- **Custo:** 2 de Ícor.
- **O que faz:** o alvo recebe 20% mais dano e fica 20% mais lento.
- **Em quem:** um inimigo.
- **Forma e alcance:** alvo a até 400 px (13,3 m); a coruja voa até ele.
- **Duração:** 4 s.
- **Arte sugerida:** coruja de latão circulando sobre o alvo; olho dourado pairando acima da cabeça.
- **Quando a IA usa:** o inimigo mais ferido que os aliados estão atacando, a até 400 px.

#### Falange de Atenas (ultimate) (EN: Phalanx of Athens)
- **Posição:** botão de ultimate.
- **Texto na carta:** "Escudo e ataque" / "Shield & attack". **Dica:** "Área onde aliados ganham escudo e atacam mais rápido; inimigos ficam lentos." / "Area where allies gain a shield and attack faster; enemies are slowed." **Tipo:** Proteção.
- **Custo:** 100 de carga.
- **O que faz:** cada aliado que entra ganha 100 de escudo (uma vez) e +25% de velocidade de ataque enquanto estiver dentro; inimigos dentro ficam 30% mais lentos.
- **Em quem:** aliados e inimigos na área.
- **Forma e alcance:** círculo de raio 180 px (6 m) em volta do ponto onde ela finca a lança (fixo).
- **Duração:** 5 s.
- **Arte sugerida:** lança fincada no centro; anel de escudos de prata em volta da borda.
- **Quando a IA usa:** 2 ou mais aliados e 2 ou mais inimigos a até 250 px, ou ponto disputado.

---

## Galeria (PT / EN)

Chaves de tradução no mesmo padrão: `HERO_HERCULES_*`, `HERO_ZEUS_*`, `HERO_ATENA_*` (em `i18n/textos.csv`).

| Campo | Hércules / Hercules | Zeus / Zeus | Atena / Athena |
| --- | --- | --- | --- |
| Epíteto | O Leão do Olimpo / The Lion of Olympus | O Rei Sem Trono / The Throneless King | A Lança da Razão / The Spear of Reason |
| Origem | Semideus / Demigod | Deus / God | Deusa / Goddess |
| Frase | Doze trabalhos. Este é o décimo terceiro. / Twelve labors. This is the thirteenth. | Sem corpo, sem trono. Mas o trovão ainda é meu. / No body, no throne. But the thunder is still mine. | Lute com a cabeça. O escudo cuida do resto. / Fight with your head. The shield handles the rest. |
