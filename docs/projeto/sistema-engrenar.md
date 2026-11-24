# Clockwork Gods — Roda do Destino (sistema de combos de cartas)

Aprovado pelo usuário em 10 nov. 2026 (nome de trabalho: "Engrenar"; nome final: **Roda do Destino / Wheel of Fate**). Como ficou no código: docs/projeto/roda-do-destino-codigo.md.

## Ideia
Cartas de tipos diferentes, jogadas em sequência, se encaixam como engrenagens e ganham bônus. A graça é montar a sequência certa com cartas de heróis diferentes, o que também valoriza a seleção de time.

## As 4 engrenagens
Os 5 tipos de carta viram 4 engrenagens (Cura junta com Proteção, porque só há 1 carta de Cura):

| Engrenagem | Tipos de carta | Cartas hoje (18) |
| --- | --- | --- |
| **Movimento** | Mobilidade | investida, salto, nemeia, aguia, comando (5) |
| **Controle** | Controle | armadilha, corrente, nuvem, coruja (4) |
| **Ataque** | Dano | disparo, veneno, raios (3) |
| **Defesa** | Proteção + Cura | muralha, valvula, engrenagem, sopro, pele, egide (6) |

Todo time possível (1 Tanque, 1 Dano, 1 Suporte) tem as 4 engrenagens no deck. No Modo livre, a tela de seleção avisa quando falta alguma.

## A roda
Cada engrenagem "engrena" a seguinte, em ciclo:

**Movimento → Controle → Ataque → Defesa → Movimento**

Quando o efeito de uma carta acontece, a engrenagem dela fica **engatada por 5 s** para o time. Se a próxima carta que acontecer for da engrenagem seguinte na roda, ela **engrena** e ganha o bônus:

| Engrenou | Bônus na carta que fecha |
| --- | --- |
| Movimento → **Controle** | controle dura +50% |
| Controle → **Ataque** | +30% de dano |
| Ataque → **Defesa** | +30% de cura, escudo ou redução de dano |
| Defesa → **Movimento** | o herói que se desloca chega com 60 de escudo por 3 s |

**Cadência** (nome técnico no código: "corrente"): a partir do 3º elo seguido, cada elo devolve 1 de Ícor. **Volta completa** (4 elos seguidos): todos os heróis do time ganham +10 de carga de ultimate.

Regras:
- Conta o momento em que o efeito acontece (o herói usa a carta), não o clique.
- Carta fora da ordem quebra a Cadência e vira a nova engrenagem engatada. Passar de 5 s também quebra.
- Ultimates ficam fora do sistema nesta versão.
- Cada time tem a sua roda; o inimigo não interfere.

## Na tela
- Roda de 4 engrenagens perto do medidor de Ícor: a engatada brilha, com o tempo restante em volta; os elos da Cadência aparecem acesos.
- Cartas na mão que continuariam a Cadência ganham um selo de engrenagem dourada e brilho leve.
- Ao engrenar: "ENGRENOU!" sobre o herói, faísca dourada; na volta completa, um aviso maior.
- Dica ao passar o mouse na roda explicando a ordem e os bônus. Aba própria em "Como jogar".

## Bot
- Fácil: ignora a roda. Normal: segue a roda quando a carta certa está na mão e cabe no Ícor. Difícil: guarda Ícor para fechar Cadências.

## Equilíbrio
**Situação (11 nov. 2026):** números finais no jogo = os desta página (janela 5 s, +50% / +30% / +30% / 60 de escudo, Cadência +1 Ícor, volta completa +10). Simulado com e sem a roda: todos os heróis entre 43% e 57%, nenhum elo obrigatório. O ajuste escudo 40 e Ataque +40% foi testado a pedido do usuário e não ficou (Ártemis e Talos 62,5%, Zeus e Hércules 37,5%).

## Futuro (não fazer agora)
- **Sobrecarga:** pagar +2 de Ícor por uma versão turbinada da carta. Atualização futura, combina com a roda (item 30 da lista de mudanças).

## Textos e nomes (Lore, aprovados em 10 nov. 2026)

| Termo | PT | EN | Observação |
| --- | --- | --- | --- |
| Sistema | Roda do Destino | Wheel of Fate | Liga as cartas ("intervenções do destino") ao Arquiteto do Destino |
| Ação de encaixar | engrenar ("ENGRENOU!") | in gear ("IN GEAR!") | — |
| Engrenagens | Movimento · Controle · Ataque · Defesa | Move · Control · Attack · Defense | "Avanço" foi descartado porque o Salto Lunar é um recuo |
| Sequência de elos | Cadência | Cadence | Evita confusão com Corrente de Cérbero e Corrente de Raios |
| Volta completa | Volta completa | Full Turn | — |

**Lore:** cada carta é uma intervenção do destino que gira uma das quatro engrenagens da Roda do Destino, o reflexo da Grande Engrenagem que todo Arquiteto carrega. Quando as intervenções seguem a ordem da roda, os dentes se encaixam e o Ícor passa de uma para a outra sem se perder, chegando mais forte à carta seguinte. E, quando a roda dá uma volta completa, a própria Grande Engrenagem sente o giro, e um pouco do seu poder transborda para os campeões. (A devolução de Ícor da Cadência é o Ícor que "não se perdeu" no encaixe.)

Os textos do jogo (avisos, dica da roda em 7 linhas, "Como jogar") estão em `i18n/textos.csv`. No jogo, as setas "→" viram "›", porque a fonte não tem a seta. Linhas da dica com até 37 caracteres (EN nunca maior que PT).
