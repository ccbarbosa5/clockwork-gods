# Sistema de testes

O jogo é testado em três camadas, todas rodando sem janela (headless). O CI roda as duas primeiras a cada push e **não publica no itch.io se algo falhar**.

## Rodar tudo

```
GODOT=/caminho/do/godot tools/run_tests.sh
```

Opções: `--matches=30` para uma simulação mais longa, `--shots pasta/` para salvar capturas de tela (precisa de `xvfb-run`).

## 1. Testes de regras e regressão (`tests/tests.gd`)

Cada função `test_*` cria uma partida isolada, posiciona heróis e verifica uma regra. Cobrem deck e mão, Ícor, cartas armadas, reembolso ao morrer, ponto de controle, prorrogação, IA de formação, colisões, interface (teclas e cliques simulados) e configuração do projeto.

```
godot --headless --path . --script res://tests/tests.gd
```

Testes `test_bugXXX_*` protegem contra a volta dos bugs de `docs/BUGS.md`.

## 2. Simulador de partidas (`tests/simulate.gd`)

Joga várias partidas completas, bot contra bot, alternando dificuldades e comportamentos, e verifica a cada passo:

| Invariante | O que indica |
| --- | --- |
| Herói fora da arena, dentro de obstáculo ou na base inimiga | Bug de colisão ou movimento |
| Herói congelado por mais de 3 s fora da base | IA travada |
| Vida, Ícor ou progresso fora dos limites | Bug de regra |
| Deck sem 9 cartas, carta de herói morto na mão, espaço vazio com carta disponível | Bug no deck |
| Carta armada passando do prazo ou herói morto com carta armada | Bug no sistema de cartas armadas |
| Partida que não termina | Bug de regra de vitória |

Também mede o equilíbrio e reprova se sair dos limites:

| Métrica | Limite |
| --- | --- |
| Duração média | 100 a 330 s |
| Abates por partida | pelo menos 5 |
| Vitórias com bots iguais | cada lado pelo menos 15% |
| Formação (linha de trás atrás do tanque) | pelo menos 80% do tempo |
| Espera média de carta armada | no máximo 4 s |
| Toda habilidade usada | pelo menos uma vez |

Cartas usadas menos de 25% da média aparecem como "pontos de melhoria" (avisam, não reprovam).

```
godot --headless --path . --script res://tests/simulate.gd -- --matches=12
```

## 3. Revisão visual

`tools/run_tests.sh --shots pasta/` salva o menu e capturas de uma partida aos 5, 30, 70, 120 e 180 s. Checklist da revisão:

- [ ] Textos legíveis, nada cortado ou sobreposto (cartas, miniatura da próxima carta, painéis)
- [ ] Versão correta no menu
- [ ] Formação visível: tanque na frente, dano e suporte atrás
- [ ] Selos de habilidade e registro lateral aparecendo
- [ ] Cores das cartas batendo com a função do herói
- [ ] Nenhum herói preso em borda ou coluna

## Fluxo para corrigir um bug

1. Reproduza com um teste (`test_bugXXX_*`) e confirme que ele falha.
2. Corrija o código e comente o número do bug.
3. Confirme que o teste passa e que `tools/run_tests.sh` termina com `TUDO OK`.
4. Registre em `docs/BUGS.md`.
