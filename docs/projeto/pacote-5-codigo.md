# Pacote 5 — telas, seleção, cura e "Como jogar" (como ficou no jogo)

Itens 40 a 46 de docs/projeto/lista-de-mudancas.md. Etapa 1 nos PRs #24 a #29; etapa 2 ("Como jogar" interativo) no PR #30 (11 nov. 2026); "Como jogar" refeito para a arena nova no PR #35. Textos PT/EN em `i18n/textos.csv`. Equilíbrio: docs/projeto/balanceamento.md.

## Tela "Como jogar" (scripts/howto.gd)
- Abre pelo menu principal e pelo menu de pausa (ESC).
- 8 abas: Objetivo, Seu time, Cartas e Ícor, Roda do Destino, Ultimates, Comportamentos, Vida e cura, Controles. Navegação por clique, botões ‹ ›, setas do teclado e teclas 1 a 8. ESC ou "‹ Voltar" fecha. A última aba fica salva (user://settings.cfg, geral/como_jogar_aba).
- Cada aba: captura real 800 × 450 de uma cena preparada (tools/howto_shots.gd; uma por idioma), com contornos, setas e legendas por código; à direita, título, abertura e tópicos (a letra diminui sozinha se não couber).
- Aba Roda do Destino: lupa na roda do HUD e faixa animada com o bônus de cada elo. Números lidos de data.gd.
- Todos os {valor} vêm do código: abertura do ponto 12 s, captura 6 s, até 2 por função no Modo livre, carta armada 5 s, Ícor até 10, janela da roda 5 s, Cadência a partir do 3º elo (+1 Ícor), Volta completa +10, renascer 6 s, frasco 60 de vida / 30 s, Centelha Viva 7 s.
- Regras do ponto: fique 6 s no ponto sem inimigos para capturá-lo; enquanto for seu, seu progresso enche. Com os dois times, fica disputado: só o dono avança, à metade, se tiver mais heróis lá. Tempo acabando com o ponto disputado ou sendo capturado → prorrogação. Empate em progresso no fim = empate. A base cura 90 de vida por segundo.
- Chaves: HOWTO_TITLE, HOWTO_BACK, HOWTO_KEYS, HOWTO_TAB_1..8, HOWTO_OPEN_1..8, HOWTO_n_k, HOWTO_M_n_k.

## Telas
- **Tela inicial:** logo, Jogar, Como jogar, Heróis, idioma e som; versão no canto inferior esquerdo.
- **Seleção de personagens** (Jogar): lista por função à esquerda; ficha à direita; "Seu time" com 3 espaços; dificuldade do bot e comportamento inicial; Modo livre (experimental); **Começar partida**. ESC ou Voltar retorna.
- **Heróis (Galeria)** e seleção usam os mesmos cartões (scripts/hero_cards.gd), com ilustração, função e ordem fixa.

## Times: padrão 1/1/1 e Modo livre (experimental)
- **Padrão:** 1 Tanque, 1 Dano e 1 Suporte; clicar em outro herói da mesma função troca.
- **Modo livre:** no máximo 2 da mesma função, sem repetir herói; só nele aparece o aviso de engrenagem faltando.
- O mesmo herói pode estar nos dois times. O bot segue o modo escolhido.

## Comportamentos
Agressivo, Equilibrado e Defensivo; a troca é instantânea (sem recarga).

## Frascos de Ambrosia
- Curam **60** de vida na hora e voltam em **30 s**. Posições na arena: docs/projeto/arena-nova.md. Imagem map/health_pack.png.
- IA: Agressivo só pega frasco no caminho (abaixo de 50% de vida, até 90 px); Equilibrado abaixo de 65%, até 160 px; Defensivo abaixo de 80%, até 240 px.

## Centelha Viva e cobertura
- Depois de **7 s** sem dano, regenera **5**/s, fora do ponto. "+" verde ao lado da barra de vida.
- Cobertura: abaixo de 60% (Defensivo) ou 40% (Equilibrado), sem inimigo a 230 px, vai para trás de um obstáculo que bloqueia tiro até 85%. Agressivo nunca. Com o inimigo a 85% de progresso, todos vão ao ponto.

## Ritmo
Progresso no ponto 100/68 por segundo; partida de 300 s + prorrogação (vence quem lidera).
