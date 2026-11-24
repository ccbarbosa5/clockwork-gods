# Clockwork Gods — instruções para o Claude Code

**Sempre responda ao usuário (Caio) em português do Brasil.** Ele não é programador: explique em linguagem simples, sem jargão, e entregue resultado em vez de relato de esforço.

## O jogo
Hero shooter 2D com cartas, visto de cima, em Godot 4.7 (GDScript). Os heróis lutam sozinhos por IA; o jogador joga cartas pagas com Ícor (até 10, +1 a cada 2,5 s), dispara ultimates (Q/W/E) e escolhe o comportamento do time (Agressivo, Equilibrado, Defensivo). Partidas 3 contra 3 por um ponto de controle central (300 s + prorrogação), arena padrão "Três Corredores". Cenário: Olimpo steampunk ("Os Ritos da Engrenagem"). Idiomas PT e EN.

- **Heróis (6):** Talos e Hércules (Tanque) · Ártemis e Zeus (Dano) · Asclépio e Atena (Suporte). Números atuais em `scripts/data.gd` (vale sobre qualquer documento).
- **Sistemas:** Roda do Destino (combos de cartas), Frascos de Ambrosia, Centelha Viva, seleção 1 por função (Modo livre experimental até 2), galeria, "Como jogar" interativo, pausa, animação procedural.
- **Publicado em:** https://ccbarbosa.itch.io/clockwork-gods — todo merge na `main` publica sozinho (workflow `publish.yml`).
- **Repositório:** `ccbarbosa5/clockwork-gods` (público; o nome antigo `ichor-clockwork-gods` redireciona).

## Onde está cada coisa
- `scripts/` — código (data.gd = números; game.gd = regras e habilidades; hero.gd = IA; rig.gd = animação por peças; art.gd = imagens; i18n.gd + `i18n/textos.csv` = textos PT/EN).
- `arenas/` — arenas em JSON (`tres_corredores.json` padrão, `classica.json`).
- `assets/` — imagens aprovadas (heroes, icons, cards, map, ui, store, fx); `assets/README.md` lista nomes e tamanhos.
- `tests/` e `tools/` — testes (`tools/run_tests.sh`), simulação e balanceamento.
- `docs/capturas/<assunto>/` — capturas de tela para o usuário revisar (nunca colar imagens na conversa).
- **`docs/projeto/`** — documentação de design, arte, lore e decisões (migrada do claude.ai em 24 nov. 2026):

| Documento | Para quê |
| --- | --- |
| `combinados-do-projeto.md` | Autorizações permanentes e regras de documentação |
| `lista-de-mudancas.md` | Backlog e histórico por pacotes (status de tudo) |
| `regras-de-herois.md` | Regras para criar herói (vale sobre os outros docs) |
| `como-adicionar-heroi.md` | Onde cada parte de um herói entra no código |
| `referencia-herois-habilidades.md` · `herois-pacote-3.md` | Fichas dos heróis e habilidades |
| `biblia-de-lore.md` | Lore: DEFINIDO, PROPOSTA, A DEFINIR, MITO; glossário PT/EN |
| `sistema-engrenar.md` · `roda-do-destino-codigo.md` | Roda do Destino: design e como ficou no código |
| `balanceamento.md` | Regras de ajuste, pontos de virada, como rodar o workflow, resultados |
| `arena-nova.md` | Arena Três Corredores |
| `pacote-5-codigo.md` | Telas, seleção, frascos, Centelha Viva, "Como jogar" |
| `visual-2d-codigo.md` · `animacao-2d.md` | Animação procedural e por peças (Pacote 7) |
| `guia-de-arte.md` · `decisoes-tecnicas-arte.md` · `fx-pacote-3.md` | Estilo, paleta, tamanhos, efeitos (decisões técnicas valem sobre o guia) |

## Pasta compartilhada do usuário: `D:\Ichor`
Quando a sessão tiver acesso a ela (`claude --add-dir D:\Ichor`):
- `assets\em-revisao\` — imagens em teste, esperando aprovação do usuário.
- `assets\aprovados\<subpasta>\` — aprovadas; daí são copiadas para `assets/<subpasta>/` no repositório.
- `assets\referencias\` — referências visuais.
- `capturas\<assunto>\` — prints que o usuário quer que você veja (leia daí, ele não cola na conversa).
- `entregas\` — entregas antigas (ex.: `entregas\codigo\traducao.csv`).

## Regras permanentes
1. **Publicar:** pode juntar na `main` sem pedir, sempre que `tools/run_tests.sh` terminar com **TUDO OK**. Trabalhe numa branch, abra PR e junte.
2. **Arquivos novos:** pode criar sem permissão; avise em uma linha. **Peça aprovação** para: apagar arquivos, sobrescrever arte aprovada, marcar lore como DEFINIDO.
3. **Balanceamento:** autônomo dentro das regras de `docs/projeto/balanceamento.md` (só números de herói, ≤15%, até 3 rodadas, conferir pontos de virada, meta ≤ ~8 pontos por duelo e < 30% pelo relógio). Bateu: publica e manda UM resumo.
4. **Heróis novos:** seguir `regras-de-herois.md` (aparência clássica do mito, steampunk só no equipamento; sem anel do time — a cor do time fica na barra de vida e na sombra).
5. **Arte:** imagens geradas vão primeiro para `D:\Ichor\assets\em-revisao\`; só entram no jogo depois que o usuário aprovar. Sem a imagem, o jogo desenha por código.
6. **Textos:** sempre em PT e EN em `i18n/textos.csv`; toda letra precisa existir na fonte (há teste).
7. **Mudanças em lote:** o usuário prefere juntar ideias em pacotes (`lista-de-mudancas.md`) e publicar de uma vez. Ideia nova entra na lista; só executa quando ele pedir.
8. **Documentação:** algo novo que precise de lore ou arte ganha documento em `docs/projeto/` (regras em `combinados-do-projeto.md`). Ao mudar números, atualize as fichas.
9. **Economia:** evite rodar simulações longas localmente; use o workflow "Balanceamento" do GitHub e leia só o resumo.

## Em andamento / próximos passos (24 nov. 2026)
- **Pacote 7, item 63 — animação por peças:** código pronto (`scripts/rig.gd`). Camadas do Talos em `D:\Ichor\assets\em-revisao\heroes\camadas\`, esperando aprovação do usuário; aprovadas → copiar para `assets/heroes/camadas/` e publicar. Depois, os outros 5 heróis.
- **Lore em aberto:** #11 (o que o vencedor dos Ritos ganha, por que as bases curam, por que os heróis obedecem ao Arquiteto) e #12 (onde a história aparece no jogo).
- **Futuro:** #30 Sobrecarga de cartas; #34 arte da Roda do Destino (opcional); #51 novas arenas (Forja de Hefesto, Creta, Atlântida); #52 câmera e mapa maior (plano B).
- **Usuário:** #35 conferir capa e ícone na página do itch.io.
- O balanceamento foi medido antes dos PRs #37 e #38 (só visuais); remedir se a jogabilidade parecer diferente.

## Histórico
Até 24 nov. 2026 o projeto foi tocado em 4 conversas do claude.ai (Chefe, Código, Lore, Assets) no Projeto "Ichor". Elas continuam lá como arquivo, com documentos originais e artefatos (links em `docs/projeto/combinados-do-projeto.md`). A partir de agora, tudo é feito aqui no Claude Code.
