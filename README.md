# Clockwork Gods

Hero shooter tático em 2D com cartas. Seus três heróis lutam sozinhos; você é o Arquiteto do Destino e intervém jogando cartas de habilidade com Ícor, o sangue dourado dos deuses.

**Protótipo**: modo Controle contra bot, versão web, em português e inglês.

O jogo se chamava "Ichor: Clockwork Gods". Página: https://ccbarbosa.itch.io/clockwork-gods

## Como jogar

- **Objetivo:** controle o ponto central até chegar a 100% de progresso.
- **Cartas:** clique numa carta (ou tecla 1 a 4). O herói guarda a habilidade e usa sozinho no melhor momento, escolhendo o alvo (em até 5 s). Se ele morrer antes, o Ícor volta. A cor da carta indica a função: laranja Tanque, roxo Dano, verde Suporte.
- **Ícor:** recarrega com o tempo (+1 a cada 2,5 s) e com abates. Abater um herói do time que está na frente rende Ícor extra.
- **Ultimates:** botões redondos (Q, W, E), também usadas pelo herói no melhor momento. Carregam com dano, cura, dano mitigado e tempo no ponto. Não custam Ícor.
- **Comportamento da IA:** Agressivo, Equilibrado ou Defensivo (Z, X, C), com 10 s de recarga entre trocas.
- **ESC** ou **P** abrem o menu de pausa (continuar, como jogar, som, idioma, voltar ao menu). A partida também pausa sozinha quando a janela ou a aba perde o foco. **M** liga e desliga o som.
- Passe o mouse sobre cartas, ultimates, próxima carta e comportamentos para ver o que fazem.
- **Idioma:** botão PT/EN no menu e na pausa. Na primeira vez, o jogo usa português se o navegador estiver em português e inglês nos outros casos.

## Heróis

| Herói | Função | Cartas | Ultimate |
| --- | --- | --- | --- |
| Talos | Tanque | Muralha de Bronze, Investida a Vapor, Válvula de Pressão | Fúria da Forja |
| Ártemis | Dano | Disparo Perfurante, Armadilha de Caça, Salto Lunar | Chuva de Prata |
| Asclépio | Suporte | Sopro Restaurador, Veneno da Serpente, Engrenagem Vital | Segunda Chance |

Todos os números de balanceamento estão em `scripts/data.gd`. Distâncias e velocidades aparecem para o jogador em metros (1 m = 30 px).

## Textos e idiomas

Todo texto que o jogador vê está em `i18n/textos.csv` (colunas `chave`, `pt`, `en`, UTF-8). O Godot importa o arquivo como tradução; uma célula `en` vazia mostra o texto em português. Textos com `%s` ou `%d` recebem valores do jogo (nomes, números): mantenha esses marcadores na tradução. O teste `test_i18n_no_visible_text_literals_in_code` reprova texto visível escrito direto no código.

## Rodar localmente

1. Instale o [Godot 4.7](https://godotengine.org/download).
2. Abra a pasta do projeto no Godot e aperte F5.

## Testes

O projeto tem um sistema de testes automático: testes de regras e regressão, um simulador que joga partidas inteiras procurando anomalias e capturas de tela para revisão visual. O CI roda tudo antes de publicar.

```
GODOT=/caminho/do/godot tools/run_tests.sh
```

Detalhes em [docs/TESTES.md](docs/TESTES.md). Bugs encontrados e corrigidos ficam em [docs/BUGS.md](docs/BUGS.md), cada um com um teste que impede a volta dele.

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
| `scripts/gallery.gd` | Galeria de heróis |
| `scripts/i18n.gd` | Idiomas, metros e atalhos para os textos |
| `i18n/textos.csv` | Todos os textos do jogo em PT e EN |
| `scripts/audio.gd` | Sons e música sintetizados por código |
| `scripts/art.gd` | Imagens (sprites, retratos, ícones, molduras, efeitos, mapa) com cache; sem o PNG, desenho por código |
| `assets/` | PNGs do jogo (opcionais). Nomes e tamanhos em [assets/README.md](assets/README.md) |

## Publicação no itch.io

A cada push na branch `main`, o GitHub Actions testa, exporta a versão web e publica no itch.io com o [butler](https://itch.io/docs/butler/).

Configuração (uma vez):

1. Crie a página do jogo no itch.io (pode ficar como rascunho) e marque o tipo **HTML**.
2. Gere uma chave em *itch.io → Settings → API keys*.
3. No GitHub, em *Settings → Secrets and variables → Actions*:
   - Secret `BUTLER_API_KEY` com a chave do itch.
   - Variável `ITCH_TARGET` com `seu-usuario-itch/nome-do-jogo` (padrão: `ccbarbosa/clockwork-gods`).
4. Depois do primeiro envio, na página do jogo no itch, marque o arquivo `html5` como *This file will be played in the browser* e defina o tamanho 1280 × 720.
