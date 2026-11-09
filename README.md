# Ichor: Clockwork Gods

Hero shooter tático em 2D com cartas. Seus três heróis lutam sozinhos; você é o Arquiteto do Destino e intervém jogando cartas de habilidade com Ícor, o sangue dourado dos deuses.

**Protótipo v0.1**: modo Controle contra bot, versão web.

## Como jogar

- **Objetivo:** controle o ponto central até chegar a 100% de progresso.
- **Cartas:** clique numa carta (ou tecla 1 a 4). Se ela pedir alvo, clique no mapa. Também dá para arrastar a carta até o mapa. Botão direito ou Esc cancela.
- **Ícor:** recarrega com o tempo (+1 a cada 2,5 s) e com abates. Abater um herói do time que está na frente rende Ícor extra.
- **Ultimates:** botões redondos (Q, W, E). Carregam com dano, cura, dano mitigado e tempo no ponto. Não custam Ícor.
- **Comportamento da IA:** Agressivo, Equilibrado ou Defensivo (Z, X, C), com 10 s de recarga entre trocas.
- **P** pausa a partida.

## Heróis

| Herói | Função | Cartas | Ultimate |
| --- | --- | --- | --- |
| Talos | Tanque | Muralha de Bronze, Investida a Vapor, Válvula de Pressão | Fúria da Forja |
| Ártemis | Dano | Disparo Perfurante, Armadilha de Caça, Salto Lunar | Chuva de Prata |
| Asclépio | Suporte | Sopro Restaurador, Veneno da Serpente, Engrenagem Vital | Segunda Chance |

Todos os números de balanceamento estão em `scripts/data.gd`.

## Rodar localmente

1. Instale o [Godot 4.7](https://godotengine.org/download).
2. Abra a pasta do projeto no Godot e aperte F5.

Teste automático bot contra bot (sem janela):

```
godot --headless --path . -- --autotest
```

## Estrutura

| Arquivo | Conteúdo |
| --- | --- |
| `scripts/data.gd` | Heróis, cartas e números de balanceamento |
| `scripts/game.gd` | Partida: mapa, ponto de controle, combate e habilidades |
| `scripts/hero.gd` | Herói: estados, IA e desenho |
| `scripts/commander.gd` | Deck, mão, Ícor, ultimates e comportamento (jogador e bot) |
| `scripts/bot.gd` | Decisões do bot |
| `scripts/hud.gd` | Interface do jogador |
| `scripts/menu.gd` | Tela inicial |

## Publicação no itch.io

A cada push na branch `main`, o GitHub Actions testa, exporta a versão web e publica no itch.io com o [butler](https://itch.io/docs/butler/).

Configuração (uma vez):

1. Crie a página do jogo no itch.io (pode ficar como rascunho) e marque o tipo **HTML**.
2. Gere uma chave em *itch.io → Settings → API keys*.
3. No GitHub, em *Settings → Secrets and variables → Actions*:
   - Secret `BUTLER_API_KEY` com a chave do itch.
   - Variável `ITCH_TARGET` com `seu-usuario-itch/nome-do-jogo` (padrão: `ccbarbosa/ichor-clockwork-gods`).
4. Depois do primeiro envio, na página do jogo no itch, marque o arquivo `html5` como *This file will be played in the browser* e defina o tamanho 1280 × 720.
