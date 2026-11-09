extends SceneTree
## Testes de regras e de regressão.
## Rodar:  godot --headless --path . --script res://tests/tests.gd
## Cada função test_* é um teste. Testes marcados com BUG-xxx protegem
## contra a volta de um bug registrado em docs/BUGS.md.

const Data = preload("res://scripts/data.gd")
const GameScript = preload("res://scripts/game.gd")
const AudioScript = preload("res://scripts/audio.gd")

var _failures: Array = []
var _current := ""
var _checks := 0


var _ran := false


func _process(_delta: float) -> bool:
	# Roda no primeiro quadro, com a árvore de cenas pronta.
	if not _ran:
		_ran = true
		_run_all()
	return false


func _run_all() -> void:
	var names: Array = []
	for m in get_method_list():
		if String(m["name"]).begins_with("test_"):
			names.append(m["name"])
	names.sort()
	var failed := 0
	for n in names:
		_current = n
		var before := _failures.size()
		seed(12345)
		call(n)
		if _failures.size() > before:
			failed += 1
			print("FALHOU  ", n)
			for i in range(before, _failures.size()):
				print("        ", _failures[i])
		else:
			print("ok      ", n)
	print("")
	print("%d testes, %d falharam, %d verificações" % [names.size(), failed, _checks])
	quit(1 if failed > 0 else 0)


# ---------------------------------------------------------------------------
# Utilitários
func check(cond: bool, what: String) -> void:
	_checks += 1
	if not cond:
		_failures.append(what)


func new_game(opts := {}) -> Node2D:
	var o := {"bots": false}
	o.merge(opts, true)
	var g := Node2D.new()
	g.set_script(GameScript)
	root.add_child(g)
	g.setup(o)
	g.set_process(false)
	g.hud.set_process(false)
	return g


func step(g, seconds: float) -> void:
	for i in int(round(seconds * 60.0)):
		g._step(1.0 / 60.0)


func hero(g, t: int, hid: String):
	return g.get_hero(t, hid)


## Coloca um herói parado (atordoado) numa posição.
func pin(h, pos: Vector2) -> void:
	h.position = pos
	h.stun_t = 9999.0


func pin_all_far(g) -> void:
	for h in g.heroes:
		pin(h, g.spawn_pos(h.team) + Vector2(0, (h.slot_index - 1) * 40.0))


func slot_of(c, hid: String) -> int:
	for i in c.HAND_SIZE:
		if c.hand[i] != "" and Data.ABILITIES[c.hand[i]]["hero"] == hid:
			return i
	return -1


func deck_ok(c) -> bool:
	var all: Array = []
	for x in c.hand:
		if x != "":
			all.append(x)
	all.append_array(c.queue)
	all.sort()
	var expected: Array = []
	for hid in Data.HERO_ORDER:
		expected.append_array(Data.HEROES[hid]["cards"])
	expected.sort()
	return all == expected


func done(g) -> void:
	g.free()


# ---------------------------------------------------------------------------
# Cartas, deck e Ícor
func test_deck_starts_with_9_cards_and_full_hand() -> void:
	var g := new_game()
	var c = g.commanders[0]
	check(deck_ok(c), "deck deveria ter exatamente as 9 cartas")
	check(not c.hand.has(""), "mão inicial deveria ter 4 cartas")
	done(g)


func test_deck_integrity_after_many_plays() -> void:
	var g := new_game()
	var c = g.commanders[0]
	for i in 30:
		c.ichor = 10.0
		var slot := i % 4
		if c.hand[slot] != "":
			c.play(slot)
		step(g, 0.5)
		check(deck_ok(c), "deck íntegro após jogada %d" % i)
	done(g)


func test_play_spends_ichor_and_arms_hero() -> void:
	var g := new_game()
	var c = g.commanders[0]
	c.ichor = 10.0
	var card: String = c.hand[0]
	var cost: int = Data.ABILITIES[card]["cost"]
	var h = c.card_hero(card)
	check(c.play(0), "jogar carta deveria funcionar")
	check(is_equal_approx(c.ichor, 10.0 - cost), "Ícor deveria cair pelo custo")
	check(h.has_armed(card), "herói deveria ficar com a habilidade armada")
	check(c.hand[0] != card, "carta deveria sair da mão")
	done(g)


func test_cannot_play_without_ichor() -> void:
	var g := new_game()
	var c = g.commanders[0]
	c.ichor = 0.0
	check(c.can_play(0) == "icor", "sem Ícor a carta não pode ser jogada")
	check(not c.play(0), "play deveria falhar sem Ícor")
	done(g)


func test_dead_hero_cards_leave_hand() -> void:
	var g := new_game()
	var c = g.commanders[0]
	var t = hero(g, 0, "talos")
	g.deal_damage(hero(g, 1, "artemis"), t, 99999.0)
	check(not t.alive, "Talos deveria morrer")
	for x in c.hand:
		check(x == "" or Data.ABILITIES[x]["hero"] != "talos", "carta do herói morto continuou na mão: " + x)
	check(deck_ok(c), "deck íntegro após morte")
	done(g)


func test_refund_ichor_when_hero_dies_with_armed_card() -> void:
	var g := new_game()
	var c = g.commanders[0]
	pin_all_far(g)
	var slot := slot_of(c, "artemis")
	check(slot >= 0, "precisa de carta da Ártemis na mão")
	if slot < 0:
		done(g); return
	c.ichor = 10.0
	var cost: int = Data.ABILITIES[c.hand[slot]]["cost"]
	c.play(slot)
	check(is_equal_approx(c.ichor, 10.0 - cost), "Ícor gasto")
	g.deal_damage(null, hero(g, 0, "artemis"), 99999.0)
	check(is_equal_approx(c.ichor, 10.0), "Ícor deveria voltar ao morrer com carta armada")
	done(g)


func test_refund_ult_when_hero_dies_with_armed_ult() -> void:
	var g := new_game()
	var c = g.commanders[0]
	pin_all_far(g)
	var a = hero(g, 0, "artemis")
	a.ult = 100.0
	check(c.use_ult("artemis"), "usar ultimate carregada")
	check(a.ult == 0.0, "carga zera ao armar")
	g.deal_damage(null, a, 99999.0)
	check(a.ult == 100.0, "carga da ultimate deveria voltar ao morrer antes de usar")
	done(g)


func test_ult_cannot_be_armed_twice() -> void:
	var g := new_game()
	var c = g.commanders[0]
	pin_all_far(g)
	var a = hero(g, 0, "artemis")
	a.ult = 100.0
	c.use_ult("artemis")
	a.ult = 100.0
	check(c.can_ult("artemis") == "armada", "não pode armar a mesma ultimate duas vezes")
	done(g)


# ---------------------------------------------------------------------------
# Cartas armadas
func test_armed_ability_waits_for_good_moment() -> void:
	var g := new_game()
	pin_all_far(g)
	var t = hero(g, 0, "talos")
	t.position = g.CENTER
	t.stun_t = 0.0
	t.arm("investida", false)
	step(g, 1.0)
	check(t.has_armed("investida"), "Investida sem inimigo por perto deveria esperar")
	done(g)


func test_armed_ability_fires_by_timeout() -> void:
	var g := new_game()
	pin_all_far(g)
	var t = hero(g, 0, "talos")
	t.position = g.CENTER
	t.stun_t = 0.0
	t.arm("investida", false)
	step(g, Data.ARM_TIME + 0.5)
	check(not t.has_armed("investida"), "habilidade armada deveria ser usada ao fim do prazo")
	done(g)


func test_armed_ability_fires_immediately_when_good() -> void:
	var g := new_game()
	pin_all_far(g)
	var t = hero(g, 0, "talos")
	var e = hero(g, 1, "artemis")
	t.position = g.CENTER
	t.stun_t = 0.0
	e.position = g.CENTER + Vector2(150, 0)
	t.arm("investida", false)
	step(g, 0.2)
	check(not t.has_armed("investida"), "Investida com inimigo a 150 px deveria sair na hora")
	check(t.dash_t > 0.0 or t.position.x > g.CENTER.x + 20.0, "Talos deveria avançar em direção ao inimigo")
	done(g)


func test_every_ability_can_be_cast() -> void:
	for ab in Data.ABILITIES.keys():
		var g := new_game()
		var h = hero(g, 0, Data.ABILITIES[ab]["hero"])
		check(g.cast(h, ab, h.position + Vector2(100, 0)), "cast falhou: " + ab)
		done(g)


func test_every_ability_decides_when_forced() -> void:
	var g := new_game()
	pin_all_far(g)
	for ab in Data.ABILITIES.keys():
		var h = hero(g, 0, Data.ABILITIES[ab]["hero"])
		check(h.decide(ab, true) != null, "decide forçado deveria sempre retornar alvo: " + ab)
	done(g)


# ---------------------------------------------------------------------------
# Combate e economia
func test_kill_reward_normal() -> void:
	var g := new_game()
	g.commanders[0].ichor = 0.0
	g.deal_damage(hero(g, 0, "talos"), hero(g, 1, "artemis"), 99999.0)
	check(is_equal_approx(g.commanders[0].ichor, 1.0), "abate rende +1 Ícor")
	done(g)


func test_kill_reward_anti_snowball_bonus() -> void:
	var g := new_game()
	g.commanders[0].ichor = 0.0
	g.progress[1] = 50.0
	g.deal_damage(hero(g, 0, "talos"), hero(g, 1, "artemis"), 99999.0)
	check(is_equal_approx(g.commanders[0].ichor, 2.0), "abater o time que lidera rende +2 Ícor")
	done(g)


func test_respawn_after_delay() -> void:
	var g := new_game()
	var a = hero(g, 1, "artemis")
	g.deal_damage(null, a, 99999.0)
	step(g, Data.RESPAWN - 0.5)
	check(not a.alive, "não deveria renascer antes do tempo")
	step(g, 1.0)
	check(a.alive and a.hp == a.max_hp, "deveria renascer com vida cheia")
	done(g)


func test_undying_prevents_death() -> void:
	var g := new_game()
	var a = hero(g, 0, "artemis")
	a.undying_t = 3.0
	g.deal_damage(null, a, 99999.0)
	check(a.alive and a.hp >= 1.0, "Segunda Chance deveria impedir a morte")
	done(g)


func test_wall_blocks_enemy_projectile() -> void:
	var g := new_game()
	pin_all_far(g)
	var t = hero(g, 0, "talos")
	pin(t, g.CENTER)
	t.facing = Vector2.RIGHT
	t.wall_t = 4.0
	t.wall_hp = 450.0
	var e = hero(g, 1, "artemis")
	var hp0: float = t.hp
	g.spawn_projectile(e, g.CENTER + Vector2(200, 0), Vector2(-900, 0), 50.0, 5.0, "basic", Color.WHITE)
	step(g, 0.5)
	check(t.hp == hp0, "Muralha deveria bloquear o tiro frontal")
	check(t.wall_hp < 450.0, "Muralha deveria absorver o dano")
	done(g)


# ---------------------------------------------------------------------------
# Ponto de controle
func test_point_capture_and_progress() -> void:
	var g := new_game()
	pin_all_far(g)
	g.time = Data.UNLOCK_TIME + 0.1
	pin(hero(g, 0, "talos"), g.CENTER)
	step(g, Data.CAPTURE_TIME + 0.3)
	check(g.point_owner == 0, "time azul deveria capturar o ponto sozinho")
	var p0: float = g.progress[0]
	step(g, 10.0)
	check(absf(g.progress[0] - p0 - 10.0 * Data.PROGRESS_RATE) < 0.5, "progresso deveria subir no ritmo definido")
	done(g)


func test_contested_point_pauses_progress() -> void:
	var g := new_game()
	pin_all_far(g)
	g.time = Data.UNLOCK_TIME + 0.1
	g.point_owner = 0
	g.progress[0] = 30.0
	pin(hero(g, 0, "talos"), g.CENTER)
	pin(hero(g, 1, "talos"), g.CENTER + Vector2(30, 0))
	step(g, 3.0)
	check(g.contested, "ponto deveria estar disputado")
	check(absf(g.progress[0] - 30.0) < 0.01, "progresso não sobe com ponto disputado")
	done(g)


func test_contested_with_majority_progresses_slowly() -> void:
	var g := new_game()
	pin_all_far(g)
	g.time = Data.UNLOCK_TIME + 0.1
	g.point_owner = 0
	g.progress[0] = 30.0
	pin(hero(g, 0, "talos"), g.CENTER)
	pin(hero(g, 0, "artemis"), g.CENTER + Vector2(-30, 20))
	pin(hero(g, 1, "talos"), g.CENTER + Vector2(30, 0))
	step(g, 4.0)
	var expected: float = 30.0 + 4.0 * Data.PROGRESS_RATE * Data.CONTESTED_RATE
	check(absf(g.progress[0] - expected) < 0.3, "com mais heróis no ponto o dono avança a meia velocidade (%.1f, esperado %.1f)" % [g.progress[0], expected])
	done(g)


func test_point_locked_before_unlock() -> void:
	var g := new_game()
	pin_all_far(g)
	pin(hero(g, 0, "talos"), g.CENTER)
	step(g, 5.0)
	check(g.point_owner == -1 and g.capture_prog == 0.0, "ponto não pode ser capturado antes de liberar")
	done(g)


func test_bug003_stale_capture_arc_decays() -> void:
	# BUG-003: arco de captura do inimigo ficava parado com o dono no ponto.
	var g := new_game()
	pin_all_far(g)
	g.time = Data.UNLOCK_TIME + 0.1
	g.point_owner = 0
	g.capture_team = 1
	g.capture_prog = 0.5
	pin(hero(g, 0, "talos"), g.CENTER)
	step(g, 3.0)
	check(g.capture_prog == 0.0 and g.capture_team == -1, "captura inimiga deveria zerar com o dono sozinho no ponto")
	done(g)


func test_victory_at_100() -> void:
	var g := new_game()
	pin_all_far(g)
	g.time = Data.UNLOCK_TIME + 0.1
	g.point_owner = 1
	g.progress[1] = 99.9
	step(g, 0.5)
	check(g.ended and g.result == 1, "time vermelho deveria vencer ao chegar a 100%")
	done(g)


func test_overtime_while_contested() -> void:
	var g := new_game()
	pin_all_far(g)
	g.time = Data.MATCH_TIME - 0.05
	g.point_owner = 0
	g.progress = [50.0, 40.0]
	pin(hero(g, 0, "talos"), g.CENTER)
	pin(hero(g, 1, "talos"), g.CENTER + Vector2(30, 0))
	step(g, 1.0)
	check(not g.ended and g.overtime, "deveria entrar em prorrogação com ponto disputado")
	g.deal_damage(null, hero(g, 1, "talos"), 99999.0)
	step(g, 0.5)
	check(g.ended and g.result == 0, "deveria terminar ao acabar a disputa")
	done(g)


# ---------------------------------------------------------------------------
# IA
func test_bug004_heroes_move_before_unlock() -> void:
	# BUG-004: heróis ficavam parados esperando a contagem.
	var g := new_game()
	step(g, 5.0)
	var last := {}
	var path := {}
	for h in g.heroes:
		last[h] = h.position
		path[h] = 0.0
	for i in 240:
		g._step(1.0 / 60.0)
		for h in g.heroes:
			path[h] += h.position.distance_to(last[h])
			last[h] = h.position
	check(g.time < Data.UNLOCK_TIME, "teste deveria rodar antes do ponto abrir")
	for h in g.heroes:
		check(path[h] > 15.0, "%s do time %d ficou parado antes do ponto abrir (%.1f px)" % [h.hid, h.team, path[h]])
	done(g)


func test_bug002_kiting_does_not_trap_in_corner() -> void:
	# BUG-002: herói recuando era empurrado para o canto do mapa.
	var g := new_game()
	pin_all_far(g)
	var a = hero(g, 0, "artemis")
	a.position = Vector2(200, 520)
	a.stun_t = 0.0
	pin(hero(g, 1, "talos"), Vector2(300, 450))
	step(g, 1.5)
	check(a.position.y < g.ARENA.end.y - a.radius - 5.0, "Ártemis ficou presa na borda inferior: %s" % str(a.position))
	done(g)


func test_bug015_losing_team_contests_point_instead_of_chasing() -> void:
	# BUG-015: time perdendo ficava lutando longe do ponto e o inimigo pontuava livre.
	var g := new_game()
	g.time = Data.UNLOCK_TIME + 1.0
	g.point_owner = 1
	g.progress[1] = 60.0
	for h in g.heroes:
		if h.team == 1:
			pin(h, Vector2(520, 150) + Vector2(h.slot_index * 30.0, 0))  # fora do ponto, perto do time azul
		else:
			h.position = Vector2(430, 260) + Vector2(0, h.slot_index * 40.0)
	step(g, 6.0)
	var on := 0
	for h in g.alive_heroes(0):
		if g.in_point(h.position):
			on += 1
	check(on >= 1, "nenhum herói azul foi contestar o ponto do inimigo")
	check(g.point_owner == 0 or g.capture_team == 0 or g.contested or on >= 1, "time azul deveria estar tomando o ponto")
	done(g)


func test_bug016_support_not_frozen_at_point_edge() -> void:
	# BUG-016: contestando, o suporte travava na borda do ponto querendo curar alguém fora.
	var g := new_game()
	pin_all_far(g)
	g.time = Data.UNLOCK_TIME + 1.0
	g.point_owner = 1
	var s = hero(g, 0, "asclepio")
	s.position = g.CENTER + Vector2(-g.POINT_R * 0.72, 0)
	s.stun_t = 0.0
	var a = hero(g, 0, "artemis")
	pin(a, Vector2(330, 420))
	a.hp = a.max_hp * 0.3
	step(g, 0.5)
	var moved := _path_len(g, s, 3.0)
	check(moved > 10.0, "suporte congelou na borda do ponto (%.1f px em 3 s)" % moved)
	check(g.in_point(s.position), "suporte deveria continuar dentro do ponto")
	done(g)


func test_backline_stays_behind_tank() -> void:
	var g := new_game()
	for h in g.heroes:
		if h.team == 1:
			pin(h, g.spawn_pos(1))
	g.time = Data.UNLOCK_TIME + 1.0
	step(g, 10.0)
	var t = hero(g, 0, "talos")
	for hid in ["artemis", "asclepio"]:
		var h = hero(g, 0, hid)
		check(h.position.x <= t.position.x + 45.0, "%s passou à frente do tanque (%.0f > %.0f)" % [hid, h.position.x, t.position.x])
	done(g)


func test_tank_leads_toward_point() -> void:
	var g := new_game()
	for h in g.heroes:
		if h.team == 1:
			pin(h, g.spawn_pos(1))
	g.time = Data.UNLOCK_TIME + 1.0
	step(g, 10.0)
	var t = hero(g, 0, "talos")
	check(t.position.distance_to(g.CENTER) < g.POINT_R + 40.0, "tanque deveria estar no ponto (%.0f px do centro)" % t.position.distance_to(g.CENTER))
	done(g)


func test_heroes_never_inside_obstacles_or_out_of_arena() -> void:
	var g := new_game({"bots": true, "autotest": true})
	for i in 60 * 90:
		g._step(1.0 / 60.0)
		if i % 30 != 0:
			continue
		for h in g.heroes:
			if not h.alive:
				continue
			check(g.ARENA.grow(1.0).has_point(h.position), "%s fora da arena em %s" % [h.hid, str(h.position)])
			for o in g.OBSTACLES:
				var d: float = h.position.distance_to(Vector2(o.x, o.y))
				check(d >= o.z + h.radius - 1.5, "%s dentro de obstáculo" % h.hid)
	done(g)


func _path_len(g, h, seconds: float) -> float:
	var total := 0.0
	var last: Vector2 = h.position
	for i in int(seconds * 60.0):
		g._step(1.0 / 60.0)
		total += h.position.distance_to(last)
		last = h.position
	return total


func test_bug009_collision_never_leaves_hero_in_obstacle() -> void:
	# BUG-009: empurrão do obstáculo e da borda se anulavam e o herói ficava dentro.
	var g := new_game()
	var t = hero(g, 0, "talos")
	for o in g.OBSTACLES:
		for off in [Vector2(0, -10), Vector2(0, 10), Vector2(-10, 0), Vector2(10, 0), Vector2.ZERO]:
			t.position = Vector2(o.x, o.y) + off
			g.resolve_collisions(t)
			for o2 in g.OBSTACLES:
				check(t.position.distance_to(Vector2(o2.x, o2.y)) >= o2.z + t.radius - 1.0, "herói continuou dentro de obstáculo %s" % str(o2))
			check(g.ARENA.grow(0.5).has_point(t.position), "herói saiu da arena ao resolver colisão")
	done(g)


func test_bug010_tanks_do_not_lock_pushing_each_other() -> void:
	# BUG-010: dois tanques frente a frente se empurravam e ficavam congelados.
	var g := new_game()
	pin_all_far(g)
	g.time = Data.UNLOCK_TIME + 1.0
	var a = hero(g, 0, "talos")
	var b = hero(g, 1, "talos")
	a.position = g.CENTER - Vector2(25, 0)
	b.position = g.CENTER + Vector2(25, 0)
	a.stun_t = 0.0
	b.stun_t = 0.0
	var moved := _path_len(g, a, 3.0)
	check(moved > 15.0, "tanque ficou travado empurrando o outro (%.1f px em 3 s)" % moved)
	done(g)


func test_bug011_retreating_tank_not_frozen_near_healer() -> void:
	# BUG-011: tanque recuando parava totalmente ao lado do curandeiro.
	var g := new_game()
	pin_all_far(g)
	var t = hero(g, 0, "talos")
	var s = hero(g, 0, "asclepio")
	t.position = Vector2(560, 230)  # área aberta, longe das colunas
	s.position = Vector2(520, 230)
	t.stun_t = 0.0
	s.stun_t = 9999.0  # curandeiro parado: é quando o bug aparecia
	t.hp = t.max_hp * 0.2
	g._step(1.0 / 60.0)
	check(t.retreating, "tanque com 20% de vida deveria recuar")
	step(g, 2.5)  # chega até o curandeiro
	t.hp = t.max_hp * 0.2
	check(t.retreating, "tanque ainda deveria estar recuando")
	var moved := _path_len(g, t, 3.0)
	check(moved > 10.0, "tanque recuando ficou congelado (%.1f px em 3 s)" % moved)
	done(g)


func test_bug014_retreating_tank_does_not_push_healer() -> void:
	# BUG-014: tanque recuando mirava atrás do curandeiro e o empurrava até a base.
	var g := new_game()
	pin_all_far(g)
	var t = hero(g, 0, "talos")
	var s = hero(g, 0, "asclepio")
	t.position = Vector2(560, 230)
	s.position = Vector2(520, 230)
	t.stun_t = 0.0
	s.stun_t = 9999.0
	var s0: Vector2 = s.position
	for i in 240:
		t.hp = t.max_hp * 0.2
		g._step(1.0 / 60.0)
	check(s.position.distance_to(s0) < 5.0, "curandeiro foi empurrado %.0f px pelo tanque" % s.position.distance_to(s0))
	check(t.position.distance_to(s.position) < 90.0, "tanque deveria ficar perto do curandeiro")
	done(g)


func test_bug012_map_gaps_fit_largest_hero() -> void:
	# BUG-012: vão entre coluna e borda menor que o Talos fazia ele entalar.
	# Todo vão deve ser fechado (<= 0) ou largo o bastante para o maior herói.
	var g := new_game()
	var biggest := 0.0
	for hid in Data.HERO_ORDER:
		biggest = maxf(biggest, Data.HEROES[hid]["radius"] * 2.0)
	var need := biggest + 10.0
	var a: Rect2 = g.ARENA
	for o in g.OBSTACLES:
		var gaps := [o.y - o.z - a.position.y, a.end.y - (o.y + o.z), o.x - o.z - a.position.x, a.end.x - (o.x + o.z)]
		for gap in gaps:
			check(gap <= 0.0 or gap >= need, "vão de %.0f px entre obstáculo %s e a borda" % [gap, str(o)])
		for o2 in g.OBSTACLES:
			if o2 == o:
				continue
			var gap2: float = Vector2(o.x, o.y).distance_to(Vector2(o2.x, o2.y)) - o.z - o2.z
			check(gap2 <= 0.0 or gap2 >= need, "vão de %.0f px entre obstáculos %s e %s" % [gap2, str(o), str(o2)])
	done(g)


func test_behavior_cooldown() -> void:
	var g := new_game()
	var c = g.commanders[0]
	check(c.set_behavior("aggressive"), "primeira troca de comportamento")
	check(not c.set_behavior("defensive"), "troca bloqueada durante a recarga")
	step(g, Data.BEHAVIOR_CD + 0.1)
	check(c.set_behavior("defensive"), "troca liberada após a recarga")
	done(g)


# ---------------------------------------------------------------------------
# Interface (simula o jogador)
func test_hud_key_plays_card() -> void:
	var g := new_game()
	var c = g.commanders[0]
	c.ichor = 10.0
	var card: String = c.hand[0]
	var ev := InputEventKey.new()
	ev.keycode = KEY_1
	ev.pressed = true
	g.hud._input(ev)
	check(c.hand[0] != card, "tecla 1 deveria jogar a primeira carta")
	check(c.card_hero(card).has_armed(card), "herói deveria armar a habilidade")
	done(g)


func test_hud_click_plays_card() -> void:
	var g := new_game()
	var c = g.commanders[0]
	c.ichor = 10.0
	var card: String = c.hand[2]
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = g.hud.base_card_rect(2).get_center()
	ev.global_position = ev.position
	g.hud._input(ev)
	check(c.hand[2] != card, "clique na terceira carta deveria jogá-la")
	done(g)


func test_hud_ult_key() -> void:
	var g := new_game()
	pin_all_far(g)
	var t = hero(g, 0, "talos")
	t.ult = 100.0
	var ev := InputEventKey.new()
	ev.keycode = KEY_Q
	ev.pressed = true
	g.hud._input(ev)
	check(t.has_armed("furia"), "Q deveria armar a ultimate do Talos")
	done(g)


func test_hud_ignores_input_when_paused() -> void:
	var g := new_game()
	var c = g.commanders[0]
	c.ichor = 10.0
	g.paused = true
	var card: String = c.hand[0]
	var ev := InputEventKey.new()
	ev.keycode = KEY_1
	ev.pressed = true
	g.hud._input(ev)
	check(c.hand[0] == card, "com o jogo pausado a carta não deveria ser jogada")
	done(g)


# ---------------------------------------------------------------------------
# Projeto
func test_bug006_no_2d_msaa_on_web() -> void:
	# BUG-006: MSAA 2D gerava aviso no console da versão web (GLES3).
	check(int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_2d", 0)) == 0, "MSAA 2D deve ficar desligado")


func test_bug013_menu_shows_project_version() -> void:
	# BUG-013: menu mostrava "v0.1" fixo depois de novas versões.
	var Menu = load("res://scripts/menu.gd")
	var v: String = ProjectSettings.get_setting("application/config/version", "")
	check(v != "", "projeto precisa ter versão definida")
	check(Menu.version_label().contains("v" + v), "menu deveria mostrar a versão do projeto")


func test_all_cards_have_visual_data() -> void:
	for k in Data.ABILITIES.keys():
		var ab: Dictionary = Data.ABILITIES[k]
		check(Data.EFFECT_NAMES.has(ab.get("effect", "")), "efeito inválido em " + k)
		check(ab.get("short", "") != "", "resumo vazio em " + k)
		check(String(ab["short"]).length() <= 20, "resumo longo demais para a carta em " + k)
	for hid in Data.HERO_ORDER:
		check(Data.ROLE_COLORS.has(Data.HEROES[hid]["role"]), "função sem cor: " + hid)
		check(Data.STYLES.has(Data.HEROES[hid]["style"]), "estilo inválido: " + hid)


# ---------------------------------------------------------------------------
# Áudio
func new_audio() -> Node:
	var a := Node.new()
	a.set_script(AudioScript)
	a.settings_path = "user://test_settings.cfg"
	a.instant = true
	root.add_child(a)
	return a


func test_audio_every_ability_and_event_has_sound() -> void:
	var a := new_audio()
	for ab in Data.ABILITIES.keys():
		check(a.sounds.has(ab), "habilidade sem som: " + ab)
	for n in a.sounds.keys():
		var st: AudioStreamWAV = a.sounds[n]
		check(st.data.size() > 200, "som vazio: " + n)
		check(st.get_length() < 3.0, "som longo demais: " + n)
	a.free()


func test_audio_names_used_in_code_exist() -> void:
	# Um nome de som digitado errado fica mudo sem erro; este teste pega isso.
	var a := new_audio()
	var re := RegEx.new()
	re.compile("sfx\\(\"([a-z_]+)\"|play\\(\"([a-z_]+)\"")
	var found := 0
	for path in ["res://scripts/game.gd", "res://scripts/hero.gd", "res://scripts/hud.gd", "res://scripts/menu.gd"]:
		var txt := FileAccess.get_file_as_string(path)
		for m in re.search_all(txt):
			found += 1
			var name := m.get_string(1) if m.get_string(1) != "" else m.get_string(2)
			check(a.sounds.has(name), "som usado no código não existe: %s (%s)" % [name, path])
	check(found >= 15, "o teste deveria encontrar os usos de som no código (achou %d)" % found)
	# Expressões com operador ternário
	for n in ["capture_us", "capture_them", "victory", "defeat", "death", "kill", "shot", "shot_support", "no_ichor", "click"]:
		check(a.sounds.has(n), "som de evento não existe: " + n)
	a.free()


func test_audio_rate_limit() -> void:
	var a := new_audio()
	check(a.play("hit"), "primeiro som deveria tocar")
	check(not a.play("hit"), "repetição imediata deveria ser barrada")
	check(not a.play("nao_existe"), "som inexistente retorna false")
	a.free()


func test_audio_settings_persist() -> void:
	var a := new_audio()
	a.set_volume(0.3)
	if not a.muted:
		a.toggle_mute()
	if a.music_on:
		a.toggle_music()
	a.free()
	var b := new_audio()
	check(absf(b.volume - 0.3) < 0.01, "volume deveria ser salvo")
	check(b.muted, "mudo deveria ser salvo")
	check(not b.music_on, "música desligada deveria ser salva")
	b.toggle_mute()
	b.toggle_music()
	b.set_volume(0.8)
	b.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://test_settings.cfg"))


func test_audio_music_generates_and_loops() -> void:
	var a := new_audio()
	var guard := 0
	while not a.generate_music_step(50.0) and guard < 400:
		guard += 1
	check(a.music_ready, "música deveria terminar de gerar")
	var st: AudioStreamWAV = a._music_player.stream
	check(st != null and st.loop_mode == AudioStreamWAV.LOOP_FORWARD, "música deveria repetir em loop")
	check(st != null and st.get_length() > 15.0, "música deveria ter pelo menos 15 s")
	a.free()
