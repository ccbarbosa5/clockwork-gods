# Roda do Destino — como ficou no jogo (Código)

Regras e textos aprovados: docs/projeto/sistema-engrenar.md. Publicado no PR #15 (10 nov. 2026); teste de ajuste no PR #16 (11 nov. 2026).

## Números no jogo (scripts/data.gd)
Nenhum número mudou em relação a docs/projeto/sistema-engrenar.md.

| O quê | Valor |
| --- | --- |
| Janela da engrenagem engatada | 5 s após o efeito da carta |
| Movimento → Controle | controle dura +50% |
| Controle → Ataque | +30% de dano |
| Ataque → Defesa | +30% de cura, escudo ou redução de dano |
| Defesa → Movimento | 60 de escudo por 3 s no herói que joga a carta |
| Cadência | a partir do 3º elo seguido, cada elo devolve 1 Ícor |
| Volta completa | a cada 4 elos seguidos, +10 de carga de ultimate para cada herói vivo do time |

"Elo" = uma carta que engrenou (a primeira carta da sequência só engata). Ultimates não contam nem quebram.

## Onde cada bônus entra
- Controle +50%: Armadilha (prender), Corrente de Cérbero (atordoar depois do puxão), Nuvem de Tempestade (atordoar), Olhar da Coruja (marca e lentidão).
- Dano +30%: Disparo Perfurante, Veneno da Serpente (impacto e dano por segundo), Corrente de Raios.
- Defesa +30%: Muralha de Bronze (vida do escudo), Válvula de Pressão (redução 40% → 52%), Sopro Restaurador (cura), Engrenagem Vital (escudo), Pele do Leão (redução 50% → 65%), Égide (vida da cúpula).
- Escudo de 60: Investida, Salto Lunar, Salto de Nemeia, Voo da Águia e Comando de Guerra. O Comando não desloca ninguém, então o escudo vai para a Atena.

## Na tela
- A roda fica entre as ultimates e as cartas, ao lado do começo da barra de Ícor. A engrenagem engatada brilha e tem o tempo restante em volta; os elos da Cadência atual ficam acesos; a próxima engrenagem pisca de leve.
- Cartas da mão que engrenariam ganham um selo de engrenagem dourada e uma borda pulsando. As cartas já armadas que ainda não aconteceram contam para isso.
- Ao engrenar: "ENGRENOU!" sobre o herói, com uma faísca de engrenagem e um som curto de encaixe. Da Cadência em diante aparece "CADÊNCIA xN" sobre o herói. A volta completa mostra um aviso grande e "+10 de carga de ultimate" (só para o seu time).
- Dica: 7 linhas, com caixa mais alta. Linha nova em "Como jogar".
- Os textos usam "›" no lugar de "→", porque a fonte do jogo não tem a seta (no navegador ela vira um quadrado). Outro símbolo precisa existir na fonte; um teste confere todas as letras de i18n/textos.csv.

## Bot
- Fácil: ignora a roda.
- Normal: entre as cartas com bom momento, joga primeiro a que engrena, se cabe no Ícor.
- Difícil: igual ao Normal e, além disso, guarda Ícor quando a carta que engrena chega a ser paga antes de a engrenagem soltar.

## Simulação (64 combinações de times, sementes 0 e 5000, bots difíceis; números da época, arena clássica)

| Herói | Com a roda | Sem a roda |
| --- | --- | --- |
| Talos | 53,1% | 56,2% |
| Hércules | 46,9% | 43,8% |
| Ártemis | 56,2% | 54,7% |
| Zeus | 43,8% | 45,3% |
| Asclépio | 51,6% | 51,6% |
| Atena | 48,4% | 48,4% |

Por time e partida: ~50 cartas, ~13 elos, 1,3 a 1,7 Cadências e 0,3 a 0,45 voltas completas (Normal e Difícil); Fácil faz ~5 elos, só por acaso.

**Algum elo é obrigatório?** Sem o bônus de uma engrenagem só de um time (128 partidas cada), o time sem o bônus venceu: sem Movimento 39%, sem Controle 42%, sem Ataque 49%, sem Defesa 41% (com a roda inteira dos dois lados: 48%). Medição maior e mais nova em docs/projeto/balanceamento.md (nenhum elo obrigatório).

**Difícil × Normal** (64 partidas): Difícil venceu 53%. Os dois fecham correntes quase igual (13,6 × 13,7 elos).

## Teste de 11 nov.: escudo 40 e Ataque +40% (não aplicado)

| Herói | Números atuais (60 / +30%) | Testado (40 / +40%) |
| --- | --- | --- |
| Talos | 57,0% | 62,5% |
| Hércules | 43,0% | 37,5% |
| Ártemis | 54,7% | 62,5% |
| Zeus | 45,3% | 37,5% |
| Asclépio | 51,6% | 56,2% |
| Atena | 48,4% | 43,8% |

Com 40 / +40%, quatro heróis saíam da faixa de 43% a 57% (o +40% favorece muito o Disparo Perfurante, 90 → 126; o escudo menor tira força do mergulho do Hércules). Os números voltaram para 60 / +30%. Amostras de 64 partidas variam muito; para comparar ajustes, usar sempre as mesmas sementes (hoje: workflow de balanceamento).

## Ferramentas
- `tests/simulate.gd -- --balance --wheel=off` desliga a roda; `--nobonus=g` tira o bônus da engrenagem g (0 a 3) do time 0; `--diffs=hard,normal` troca os níveis.
- `main.gd -- --shot-tip=wheel` captura a partida com a dica da roda aberta; `--shot-help` captura "Como jogar"; `--shot-team=hercules,zeus,atena` escolhe o seu time.

## A DEFINIR (arte opcional)
A roda, as engrenagens, o selo da carta e a faísca são desenhados por código. Tamanhos na tela, se um dia houver imagens: roda inteira ~56 × 56 px, cada engrenagem 14 px, selo da carta 20 px, faísca 70 a 180 px. Ainda não há nomes de arquivo nem pedido (item 34 da lista de mudanças).
