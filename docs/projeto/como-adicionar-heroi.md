# Como adicionar um herói (passo a passo técnico)

As regras de criação de herói (escolha, aparência, cores, kit, lore, ids, arquivos e ordem de trabalho) estão em **docs/projeto/regras-de-herois.md**, que vale sobre qualquer outro documento. Este guia só diz onde cada coisa entra no código. Primeiro uso: Pacote 3 (Hércules, Zeus e Atena, 9 nov. 2026).

## 1. Dados — `scripts/data.gd`
1. `HEROES["<id>"]`: `role` ("Tanque", "Dano" ou "Suporte"), `origin` ("deus", "deusa", "semideus", "lenda"), `hp`, `speed` (px/s), `range` (px), `dmg`, `cd` (s), `radius`, `color` (a da função), `style` (estilo de IA), `ult` e `cards` (3 ids).
   - Opcionais: `splash` (fração do golpe corpo a corpo em quem está a até 45 px do alvo; só o Talos usa), `proj_speed` (básico com projétil), `basic` ("chain" = raio instantâneo que salta, com `chain_dmg` e `chain_range`; "spear" = projétil que ativa a passiva `pallas`), `heal` e `heal_range` (curandeiro).
2. `HERO_ORDER`: acrescente o id (ordem da galeria).
3. `ABILITIES["<habilidade>"]`: `id`, `effect` (dano, cura, escudo, controle ou mobilidade — define a engrenagem da Roda), `hero`, `cost` (0 na ultimate), `target`, `range`, `radius` e `ult: true` na ultimate.
4. Padrão 1 herói por função (`ROLE_ORDER`); Modo livre permite até 2.

## 2. Habilidades — `scripts/game.gd`, função `cast()`
- Um `match` por habilidade. Use as funções existentes:
  - controle: `apply_stun`, `apply_root`, `apply_slow`, `apply_knock(vel, tempo, atordoar_ao_terminar, tipo)` (obstáculos param o movimento; a Pele do Leão ignora tudo);
  - dano: `deal_damage` (já aplica Comando de Guerra, Olhar da Coruja, Pele do Leão, Válvula e escudos); cura: `heal`;
  - projétil: `spawn_projectile` (novo tipo → `_projectile_hit` e o desenho em `_draw`);
  - raio em cadeia: `chain_lightning(fonte, primeiro_alvo, [danos], alcance_do_salto)`;
  - zonas que duram: `clouds`, `storms`, `domes`, `phalanxes`, `rains`, `traps`, atualizadas em `_step`.
- Alvo e cura exigem linha livre; deslocamentos param em obstáculos (`scripts/arena.gd`).
- Efeitos visuais: `_burst(pos, raio, cor, tempo, imagem)` e `fx.append({...})`; tipos prontos: ring, puff, plus, cracks, rays, img, bolt, strike, leap_mark, feather, owl.
- Bônus da Roda do Destino: conferir onde cada bônus entra (docs/projeto/roda-do-destino-codigo.md).

## 3. IA — `scripts/hero.gd`, função `decide()`
- Um caso por habilidade, seguindo o "Quando a IA usa" da ficha. Devolve a posição-alvo ou `null` (esperar). Com `forced` (prazo de 5 s da carta armada), sempre devolve algo.
- Atalhos: `_nearest`, `_nearest_soft`, `_count_near`, `_group_center`, `_toward`, `_lead`.
- Estilo de IA em `HEROES.style`; formação em `_formation_pos`; alvo em `_pick_target`. Navegação A* da arena.

## 4. Textos — `i18n/textos.csv` (chave, pt, en)
- `HERO_<ID>_NAME`, `_EPITHET`, `_BIO`, `_QUOTE`; `AB_<ID>_NAME`, `_SHORT` (até 20 caracteres), `_DESC`.
- Toda letra precisa existir na fonte (teste). Revisão de lore: docs/projeto/biblia-de-lore.md.

## 5. Imagens — `scripts/art.gd` e `assets/README.md`
- Tamanho do sprite na tela em `HERO_SPRITE_PX["<id>"]` (ver docs/projeto/decisoes-tecnicas-arte.md; +12% desde o PR #38).
- Sem sprite, o herói usa o emblema de `UI.hero_glyph` (desenhe o objeto-assinatura).
- Efeitos com imagem opcional: nome e tamanho em `FX_EFFECTS` (ou `PROJECTILES`), chamada `Art.draw_fx`/`draw_beam` com desenho por código como reserva, linha na tabela de `assets/README.md`.
- Animação por peças (opcional): camadas em `RIGS` e poses em `pose()` (`scripts/rig.gd`).

## 6. Som — `scripts/audio.gd`
- Um `_add("<habilidade>", ...)` por habilidade em `_make_sfx` (o teste reprova habilidade sem som).

## 7. Testes e equilíbrio
- `tests/tests.gd`: um teste por mecânica nova; acrescente as imagens novas a `ART_SOURCE_SIZES` e os efeitos à cena `_fx_scene` (o teste reprova imagem que nunca é desenhada).
- `tools/run_tests.sh` precisa terminar com TUDO OK.
- Equilíbrio: workflow "Balanceamento" (docs/projeto/balanceamento.md).
