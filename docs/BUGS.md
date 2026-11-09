# Registro de bugs

Todo bug encontrado entra aqui com a causa, a correção e o que impede a volta dele. A regra é simples: **bug corrigido ganha um teste de regressão** em `tests/tests.gd`, com o número do bug no nome (`test_bugXXX_...`). Assim, se o bug voltar, o CI reprova o build antes de chegar ao itch.io.

Quando não é possível automatizar (visual ou configuração), a proteção fica descrita na coluna correspondente e entra no checklist de revisão de `docs/TESTES.md`.

## Como registrar um bug novo

1. Use o próximo número livre (`BUG-015`, `BUG-016`...).
2. Escreva o sintoma do ponto de vista de quem joga, a causa técnica e a correção.
3. Crie o teste de regressão e confirme que ele **falha com o código antigo** e passa com a correção.
4. Comente o número do bug no código corrigido (ex.: `# BUG-010`).

## Bugs

| ID | Versão | Encontrado por | Sintoma | Causa | Correção | Proteção |
| --- | --- | --- | --- | --- | --- | --- |
| BUG-001 | 0.1 | Compilação | O jogo não abria: erro de script | Variáveis com `:=` recebendo valores sem tipo (Dictionary/Array) | Tipo explícito nessas variáveis | Etapa de compilação no CI (`tools/run_tests.sh`) |
| BUG-002 | 0.1 | Revisão visual | Herói recuando ficava preso no canto do mapa | Recuo fugia em linha reta do inimigo | Recuo puxa para a própria base (`_kite`) | `test_bug002_kiting_does_not_trap_in_corner` |
| BUG-003 | 0.1 | Revisão visual | Arco de captura do inimigo ficava parado no ponto | Captura antiga não diminuía com o dono sozinho no ponto | Captura inimiga zera com o dono no ponto | `test_bug003_stale_capture_arc_decays` |
| BUG-004 | 0.2 | Jogador | Heróis parados esperando a contagem inicial | IA parava ao chegar na posição de espera | Formação com movimento contínuo e escaramuças | `test_bug004_heroes_move_before_unlock` |
| BUG-005 | 0.1 | CI | Publicação no itch falhava ("bad user") | Usuário do itch diferente do GitHub | Destino configurável `ITCH_TARGET` (`ccbarbosa/ichor-clockwork-gods`) | Etapa de publicação falha com a mensagem do itch; documentado no README |
| BUG-006 | 0.1 | Teste web | Aviso de MSAA no console da versão web | MSAA 2D não suportado no GLES3 | MSAA 2D desligado | `test_bug006_no_2d_msaa_on_web` |
| BUG-007 | 0.1 | Revisão visual | Nome da próxima carta cortado pelo selo de custo | Selo desenhado em cima do texto | Selo movido para o topo da miniatura | Checklist visual |
| BUG-008 | 0.3 | Teste de regressão | Herói atirando deslizava até grudar na borda | Movimento lateral sempre vertical, sem olhar as bordas | Movimento perpendicular ao alvo, inverte perto das bordas | `test_bug002_kiting_does_not_trap_in_corner` |
| BUG-009 | 0.3 | Simulador | Herói ficava dentro de uma coluna | Empurrão da coluna e da borda se anulavam | Várias passadas de colisão e saída lateral | `test_bug009_collision_never_leaves_hero_in_obstacle` + invariante do simulador |
| BUG-010 | 0.3 | Simulador | Dois tanques travados frente a frente | Ambos empurravam o alvo mesmo já no alcance | Tanque para de avançar quando o alvo está no alcance | `test_bug010_tanks_do_not_lock_pushing_each_other` + invariante "congelado" |
| BUG-011 | 0.3 | Simulador | Tanque recuando ficava totalmente parado | Parada total ao chegar no curandeiro | Espera com movimento leve | `test_bug011_retreating_tank_not_frozen_near_healer` |
| BUG-012 | 0.3 | Simulador | Talos entalava entre coluna e borda | Vão de 33 px, menor que o Talos (44 px) | Colunas afastadas da borda | `test_bug012_map_gaps_fit_largest_hero` (confere todos os vãos do mapa) |
| BUG-013 | 0.3 | Revisão visual | Menu mostrava "v0.1" em versões novas | Versão escrita fixa no código | Menu lê a versão do projeto | `test_bug013_menu_shows_project_version` |
| BUG-014 | 0.3 | Teste de regressão | Tanque recuando empurrava o curandeiro até a base | Destino do recuo ficava atrás do curandeiro | Tanque fica a 60 px do curandeiro, do lado em que está | `test_bug014_retreating_tank_does_not_push_healer` |

## Melhorias encontradas pelos testes

| ID | Versão | Encontrado por | Observação | Mudança |
| --- | --- | --- | --- | --- |
| MEL-001 | 0.3 | Simulador | Investida a Vapor e Engrenagem Vital quase nunca eram usadas | Condições de uso mais amplas e bot passa a guardar Ícor para cartas caras |
