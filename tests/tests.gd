extends SceneTree
## Testes de regras e de regressão.
## Rodar:  godot --headless --path . --script res://tests/tests.gd
## Cada função test_* é um teste. Testes marcados com BUG-xxx protegem
## contra a volta de um bug registrado em docs/BUGS.md.

const Data = preload("res://scripts/data.gd")
const GameScript = preload("res://scripts/game.gd")
const AudioScript = preload("res://scripts/audio.gd")
const Art = preload("res://scripts/art.gd")
const T = preload("res://scripts/i18n.gd")
const HudScript = preload("res://scripts/hud.gd")
const GalleryScript = preload("res://scripts/gallery.gd")
const MainScript = preload("res://scripts/main.gd")

var _failures: Array = []
var _current := ""
var _checks := 0


var _ran := false
var _failed := 0
var _test_count := 0

## Testes de desenho: o _draw só roda no fim do quadro, então estes testes
## montam a cena (start), esperam alguns quadros e então verificam (check).
## Rodam um de cada vez, depois dos testes comuns. Registre com after_draw().
var _draw_tests: Array = []
var _draw_wait := -1
var scene: Node2D = null


func _process(_delta: float) -> bool:
	# Roda no primeiro quadro, com a árvore de cenas pronta.
	if not _ran:
		_ran = true
		_run_all()
	elif _draw_wait > 0:
		_draw_wait -= 1
		if _draw_wait == 0:
			_check_draw_test()
	return false


func _run_all() -> void:
	var names: Array = []
	for m in get_method_list():
		if String(m["name"]).begins_with("test_"):
			names.append(m["name"])
	names.sort()
	_test_count = names.size()
	for n in names:
		_current = n
		var before := _failures.size()
		seed(12345)
		call(n)
		if _draw_tests.size() > 0 and _draw_tests[-1]["name"] == n:
			# O resultado sai depois do desenho, junto com as falhas desta parte.
			_draw_tests[-1]["pre"] = _failures.slice(before)
			_failures.resize(before)
			continue
		_report(n, _failures.slice(before))
	_start_draw_test()


func _report(n: String, fails: Array) -> void:
	if fails.size() > 0:
		_failed += 1
		print("FALHOU  ", n)
		for f in fails:
			print("        ", f)
	else:
		print("ok      ", n)


func after_draw(start: Callable, check_fn: Callable) -> void:
	_draw_tests.append({"name": _current, "start": start, "check": check_fn, "pre": []})


func _start_draw_test() -> void:
	if _draw_tests.is_empty():
		print("")
		print("%d testes, %d falharam, %d verificações" % [_test_count, _failed, _checks])
		quit(1 if _failed > 0 else 0)
		return
	var d: Dictionary = _draw_tests[0]
	_current = d["name"]
	d["start"].call()
	_draw_wait = 3


func _check_draw_test() -> void:
	var d: Dictionary = _draw_tests.pop_front()
	_current = d["name"]
	var before := _failures.size()
	d["check"].call()
	var fails: Array = d["pre"]
	fails.append_array(_failures.slice(before))
	_report(d["name"], fails)
	_start_draw_test()


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
		check(Data.EFFECTS.has(ab.get("effect", "")), "efeito inválido em " + k)
		check(ab.get("id", "") == k, "id da habilidade diferente da chave em " + k)
		for l in T.LANGS:
			var short := T.in_lang("AB_%s_SHORT" % k.to_upper(), l)
			check(short != "" and short != "AB_%s_SHORT" % k.to_upper(), "resumo vazio em " + k)
			check(short.length() <= 20, "resumo longo demais para a carta em %s (%s)" % [k, l])
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


# ---------------------------------------------------------------------------
# Imagens (scripts/art.gd)
func _all_art_paths() -> Array:
	var paths: Array = []
	for hid in Data.HERO_ORDER:
		paths.append(Art.HERO_SPRITE % hid)
		paths.append(Art.HERO_PORTRAIT % hid)
		paths.append(Art.HERO_FULL % hid)
	for ab in Data.ABILITIES.keys():
		paths.append(Art.ICON % ab)
	for role in Data.ROLE_COLORS.keys():
		paths.append(Art.CARD_FRAME % String(role).to_lower())
	for kind in Art.PROJECTILES.keys():
		paths.append(Art.FX % Art.PROJECTILES[kind]["fx"])
	for name in Art.FX_EFFECTS.keys():
		paths.append(Art.FX % name)
	for name in Art.MAP_IMAGES.keys():
		paths.append(Art.MAP % name)
	return paths


## Partida parada com tudo que usa imagem na tela: sprites, selos armados,
## retratos (uma ultimate pronta), cartas (uma em destaque), próxima carta,
## os três tipos de projétil, avisos de habilidade e registro lateral.
func _art_scene() -> Node2D:
	var g := new_game()
	var c = g.commanders[0]
	var t = hero(g, 0, "talos")
	var a = hero(g, 0, "artemis")
	var s = hero(g, 0, "asclepio")
	pin(t, Vector2(600, 300))
	pin(a, Vector2(520, 260))
	pin(s, Vector2(520, 340))
	t.ult = 100.0
	t.hit_flash = 0.1
	a.arm("salto", false)
	t.arm("furia", true)
	g.cast(a, "disparo", Vector2(900, 260))
	g.cast(s, "veneno", Vector2(900, 340))
	g.spawn_projectile(a, Vector2(560, 300), Vector2(900, 100), 10.0, 5.0, "basic", Color.WHITE)
	g.hud.hover = 0
	for h in g.heroes:
		h.queue_redraw()
	g.queue_redraw()
	g.hud.queue_redraw()
	check(c.hand[0] != "" and c.next_card() != "", "cena de teste precisa de cartas na mão e na fila")
	return g


## Simula um projeto sem nenhuma imagem (independe do que já existe em assets/).
func _no_images() -> void:
	Art.clear_cache()
	for p in _all_art_paths():
		Art.set_texture(p, null)


func test_art_without_images_returns_null() -> void:
	# Arquivo inexistente devolve null; com todas as imagens ausentes, os atalhos também.
	Art.clear_cache()
	check(Art.tex("res://assets/fx/nao_existe.png") == null, "arquivo inexistente deveria devolver null")
	_no_images()
	check(Art.hero_sprite("talos") == null and Art.hero_portrait("artemis") == null, "atalhos de herói devolvem null")
	check(Art.icon("muralha") == null and Art.card_frame("Tanque") == null and Art.fx("tiro_basico") == null, "atalhos devolvem null")
	Art.clear_cache()
	check(not Art.draw_fx(null, "nao_existe", Vector2.ZERO, Vector2.ONE), "efeito sem imagem retorna false (quem chama desenha por código)")
	for k in Data.ABILITIES.keys():
		check(Art.ability_id(Data.ABILITIES[k]) == k, "chave da habilidade a partir do dicionário: " + k)
	for hid in Data.HERO_ORDER:
		check(Art.HERO_SPRITE_PX.has(hid), "tamanho do sprite definido: " + hid)


func test_art_draw_without_images_uses_code_drawing() -> void:
	# Sem imagens, a partida desenha só por código e nada quebra.
	after_draw(func():
		_no_images()
		Art.drawn = 0
		scene = _art_scene(),
	func():
		check(Art.drawn == 0, "sem imagens nada deveria ser desenhado por textura (desenhou %d)" % Art.drawn)
		done(scene)
		scene = null
		Art.clear_cache())


func test_art_draw_with_images_in_memory() -> void:
	# Com texturas criadas em memória em todos os caminhos, o desenho com
	# sprite, retrato, ícones, moldura e projéteis roda sem erro.
	after_draw(func():
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 1))
		var tx := ImageTexture.create_from_image(img)
		Art.clear_cache()
		for p in _all_art_paths():
			Art.set_texture(p, tx)
		Art.drawn = 0
		scene = _art_scene(),
	func():
		# 6 sprites + 3 retratos + 4 cartas + próxima + 3 projéteis + selos e ícones.
		check(Art.drawn >= 20, "deveria desenhar as imagens (desenhou %d)" % Art.drawn)
		check(scene.hud.hover == 0, "carta em destaque continua com moldura")
		done(scene)
		scene = null
		Art.clear_cache())


## Partida parada com todos os efeitos de imagem única ativos ao mesmo tempo:
## áreas, armadilha armada e disparada, Chuva de Prata, Muralha, auras,
## estados, soco, feixe de cura, fumaça e sinais de cura.
func _fx_scene() -> Node2D:
	var g := new_game()
	var t = hero(g, 0, "talos")
	var a = hero(g, 0, "artemis")
	var s = hero(g, 0, "asclepio")
	var e = hero(g, 1, "talos")
	pin(t, Vector2(600, 300))
	pin(a, Vector2(520, 220))
	pin(s, Vector2(520, 380))
	pin(e, Vector2(760, 300))
	g.cast(t, "valvula", t.position)
	g.cast(t, "furia", t.position)
	g.cast(s, "sopro", s.position)
	g.cast(s, "segunda", s.position)
	g.cast(a, "chuva", Vector2(800, 300))
	g.cast(t, "muralha", Vector2(800, 300))
	g.traps.append({"pos": Vector2(400, 300), "team": 0, "arm": 0.0, "life": 20.0, "src": a})
	g.fx.append({"type": "img", "img": "armadilha_fechada", "pos": Vector2(420, 330), "r": 22.0, "col": Color.WHITE, "t": 0.6, "max": 0.6})
	g.add_puff(Vector2(640, 200), Color.WHITE)
	t.shield_hp = 100.0
	t.shield_t = 5.0
	a.root_t = 2.0
	a.poison_t = 3.0
	e.stun_t = 2.0
	t.swing_t = 0.15
	s.heal_target = a
	s.heal_beam_t = 0.3
	for h in g.heroes:
		h.queue_redraw()
	g.queue_redraw()
	return g


func test_art_effects_without_images_draw_by_code() -> void:
	after_draw(func():
		_no_images()
		Art.drawn = 0
		Art.drawn_names.clear()
		scene = _fx_scene(),
	func():
		check(Art.drawn == 0 and Art.drawn_names.is_empty(), "sem imagens os efeitos deveriam sair só por código (texturas: %d)" % Art.drawn)
		done(scene)
		scene = null
		Art.clear_cache())


func test_art_every_effect_image_is_used() -> void:
	# Com uma textura em cada caminho fx/, todo efeito listado em Art.FX_EFFECTS
	# precisa aparecer na cena: se algum nome não for desenhado, a imagem
	# entregue pela arte nunca apareceria no jogo.
	after_draw(func():
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color(1, 1, 1, 1))
		var tx := ImageTexture.create_from_image(img)
		Art.clear_cache()
		for p in _all_art_paths():
			Art.set_texture(p, tx)
		Art.drawn_names.clear()
		scene = _fx_scene(),
	func():
		for name in Art.FX_EFFECTS.keys():
			check(Art.drawn_names.has(name), "a imagem fx/%s.png nunca é desenhada" % name)
		done(scene)
		scene = null
		Art.clear_cache())


## Tamanho de fonte esperado de cada imagem (assets/README.md).
const ART_SOURCE_SIZES := {
	"heroes/talos_full": Vector2i(512, 768), "heroes/artemis_full": Vector2i(512, 768), "heroes/asclepio_full": Vector2i(512, 768),
	"map/arena_floor": Vector2i(2560, 1040), "map/pillar_large": Vector2i(160, 160), "map/pillar_small": Vector2i(112, 112),
	"map/control_point": Vector2i(512, 512), "map/spawn_base": Vector2i(384, 384),
	"heroes": Vector2i(256, 256), "icons": Vector2i(256, 256), "cards": Vector2i(240, 236),
	"fx/disparo_projetil": Vector2i(256, 64), "fx/veneno_projetil": Vector2i(160, 64), "fx/tiro_basico": Vector2i(64, 32),
	"fx/furia_area": Vector2i(512, 512), "fx/valvula_area": Vector2i(512, 512), "fx/sopro_area": Vector2i(512, 512),
	"fx/segunda_area": Vector2i(512, 512), "fx/chuva_area": Vector2i(512, 512),
	"fx/armadilha_aberta": Vector2i(128, 128), "fx/armadilha_fechada": Vector2i(128, 128),
	"fx/muralha_arco": Vector2i(256, 128), "fx/soco_arco": Vector2i(128, 64), "fx/feixe_cura": Vector2i(64, 16),
	"fx/aura_valvula": Vector2i(256, 256), "fx/aura_engrenagem": Vector2i(256, 256), "fx/aura_segunda": Vector2i(256, 256),
	"fx/aura_raiz": Vector2i(256, 256), "fx/fumaca": Vector2i(64, 64), "fx/chuva_flecha": Vector2i(32, 32),
	"fx/cura_mais": Vector2i(32, 32), "fx/veneno_bolha": Vector2i(16, 16), "fx/atordoado_estrela": Vector2i(32, 32),
}


func test_art_delivered_images_are_valid() -> void:
	# Toda imagem que já está em assets/ precisa ter nome conhecido, tamanho
	# certo e transparência. Pega entregas com nome ou tamanho errado.
	var known := {}
	for p in _all_art_paths():
		known[p] = true
	var found := 0
	for sub in ["heroes", "icons", "cards", "fx", "map"]:
		var dir := DirAccess.open("res://assets/" + sub)
		if dir == null:
			continue
		for f in dir.get_files():
			if not f.ends_with(".png"):
				continue
			found += 1
			var path := "res://assets/%s/%s" % [sub, f]
			check(known.has(path), "imagem com nome desconhecido (não seria usada): " + path)
			var t: Texture2D = load(path)
			check(t != null, "imagem não carrega: " + path)
			if t == null:
				continue
			var key: String = sub + "/" + f.get_basename()
			var want: Vector2i = ART_SOURCE_SIZES.get(key, ART_SOURCE_SIZES.get(sub, Vector2i.ZERO))
			if want != Vector2i.ZERO:
				check(Vector2i(t.get_width(), t.get_height()) == want, "%s tem %dx%d, esperado %dx%d" % [path, t.get_width(), t.get_height(), want.x, want.y])
			var img := t.get_image()
			if key == "map/arena_floor":
				continue  # o piso é opaco de propósito
			check(img != null and img.detect_alpha() != Image.ALPHA_NONE, "imagem sem transparência: " + path)
	print("        (imagens entregues conferidas: %d)" % found)


func test_art_effects_documented_in_assets_readme() -> void:
	var readme := FileAccess.get_file_as_string("res://assets/README.md")
	for name in Art.FX_EFFECTS.keys():
		check(readme.contains(name + ".png"), "assets/README.md deveria listar fx/%s.png" % name)


func test_art_hero_sprite_turns_smoothly() -> void:
	# O sprite gira no máximo 720°/s em direção a `facing`.
	var g := new_game()
	var t = hero(g, 0, "talos")
	pin(t, Vector2(600, 300))
	t.facing = Vector2.RIGHT
	t.sprite_angle = 0.0
	t.facing = Vector2.LEFT
	step(g, 0.1)
	check(absf(t.sprite_angle) <= deg_to_rad(72.0) + 0.02, "em 0,1 s gira no máximo 72° (girou %.1f°)" % rad_to_deg(absf(t.sprite_angle)))
	check(absf(t.sprite_angle) > deg_to_rad(60.0), "deveria estar girando (girou %.1f°)" % rad_to_deg(absf(t.sprite_angle)))
	step(g, 0.2)
	check(absf(angle_difference(t.sprite_angle, PI)) < 0.01, "em 0,3 s já deveria apontar para a esquerda")
	done(g)


# ---------------------------------------------------------------------------
# Galeria de heróis (scripts/gallery.gd)
func new_gallery() -> Node2D:
	var g := Node2D.new()
	g.set_script(GalleryScript)
	root.add_child(g)
	g.open()
	return g


func _click(pos: Vector2, button := MOUSE_BUTTON_LEFT) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	e.pressed = true
	e.position = pos
	return e


func _key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.keycode = k
	e.pressed = true
	return e


func test_gallery_texts_every_hero_both_languages() -> void:
	# Todo herói precisa de epíteto, bio (até 3 linhas) e frase (até 2 linhas)
	# em PT e EN, origem e função conhecidas.
	var f := ThemeDB.fallback_font
	var w := GalleryScript.INFO_R - GalleryScript.INFO_X
	for hid in Data.HERO_ORDER:
		var origin_key := "ORIGIN_" + String(Data.HEROES[hid]["origin"]).to_upper()
		check(T.in_lang(origin_key, "pt") != origin_key, "origem desconhecida: " + hid)
		var role_key := "ROLE_" + String(Data.HEROES[hid]["role"]).to_upper()
		check(T.in_lang(role_key, "pt") != role_key, "função sem texto: " + hid)
		for l in T.LANGS:
			for field in ["name", "epithet", "bio", "quote"]:
				var key := "HERO_%s_%s" % [hid.to_upper(), field.to_upper()]
				var tr := TranslationServer.get_translation_object(l)
				check(tr != null and String(tr.get_message(key)) != "", "%s sem %s em %s" % [hid, field, l])
			var bio_h := f.get_multiline_string_size(T.hero_text(hid, "bio", l), HORIZONTAL_ALIGNMENT_LEFT, w, 15).y
			check(bio_h <= f.get_height(15) * 3 + 1, "bio de %s (%s) passa de 3 linhas" % [hid, l])
			var q_h := f.get_multiline_string_size("“" + T.hero_text(hid, "quote", l) + "”", HORIZONTAL_ALIGNMENT_LEFT, w - 10, 16).y
			check(q_h <= f.get_height(16) * 2 + 1, "frase de %s (%s) passa de 2 linhas" % [hid, l])
	check(T.hero_text("artemis", "name", "en") == "Artemis" and T.hero_text("artemis", "name", "pt") == "Ártemis", "nome por idioma")
	check(T.hero_text("talos", "quote", "xx") == T.hero_text("talos", "quote", "pt"), "idioma sem tradução cai para PT")


func test_gallery_stat_bars_come_from_data() -> void:
	for key in ["hp", "speed", "range"]:
		var top := 0.0
		for hid in Data.HERO_ORDER:
			var fr: float = GalleryScript.stat_fraction(hid, key)
			check(fr > 0.0 and fr <= 1.0, "barra de %s de %s fora de 0..1" % [key, hid])
			top = maxf(top, fr)
		check(is_equal_approx(top, 1.0), "o maior %s deveria encher a barra" % key)
	check(is_equal_approx(GalleryScript.stat_fraction("talos", "hp"), 1.0), "Talos tem a maior vida")


func test_gallery_list_supports_many_heroes() -> void:
	# Com 9 heróis a grade rola, os cartões não se sobrepõem e o selecionado fica visível.
	var g := new_gallery()
	g.heroes = []
	for i in 9:
		g.heroes.append(Data.HERO_ORDER[i % 3])
	check(g.rows() == 5, "9 heróis em 2 colunas = 5 linhas")
	check(g.max_scroll() > 0.0, "lista com 9 heróis deveria rolar")
	for i in 9:
		var r: Rect2 = g.card_rect(i)
		check(r.position.x >= GalleryScript.LIST_RECT.position.x and r.end.x <= GalleryScript.LIST_RECT.end.x, "cartão %d dentro da coluna" % i)
		for j in range(i + 1, 9):
			check(not r.intersects(g.card_rect(j)), "cartões %d e %d sobrepostos" % [i, j])
	g.select(8)
	check(g.scroll > 0.0 and GalleryScript.LIST_RECT.encloses(g.card_rect(8)), "selecionar o último rola até ele")
	g.select(0)
	check(g.scroll == 0.0, "selecionar o primeiro volta ao topo")
	g.handle(_click(GalleryScript.LIST_RECT.get_center(), MOUSE_BUTTON_WHEEL_DOWN))
	check(g.scroll > 0.0, "roda do mouse rola a lista")
	g.free()


func test_gallery_click_selects_and_esc_returns() -> void:
	var g := new_gallery()
	var backs := [0]
	g.back.connect(func(): backs[0] += 1)
	check(g.selected_id() == "talos", "abre no primeiro herói")
	g.handle(_click(g.card_rect(1).get_center()))
	check(g.selected_id() == "artemis", "clique no cartão seleciona o herói")
	g.handle(_key(KEY_RIGHT))
	check(g.selected_id() == "asclepio", "seta para a direita vai ao próximo")
	g.handle(_key(KEY_ESCAPE))
	check(backs[0] == 1 and not g.visible, "ESC volta ao menu")
	g.open("artemis")
	check(g.visible and g.selected_id() == "artemis", "abre direto num herói")
	g.handle(_click(g.back_rect().get_center()))
	check(backs[0] == 2 and not g.visible, "botão Voltar volta ao menu")
	g.free()


func test_gallery_opens_from_menu_and_back() -> void:
	var m := Node2D.new()
	m.set_script(MainScript)
	root.add_child(m)
	var menu = m.menu
	check(not menu.heroes_rect().intersects(menu.help_rect()) and not menu.heroes_rect().intersects(menu.play_rect()), "botão Heróis não cobre outros botões")
	check(absf(menu.heroes_rect().position.y - menu.help_rect().position.y) < 1.0, "botão Heróis ao lado de Como jogar")
	menu.open_gallery.emit()
	check(m.gallery.visible and not menu.visible, "botão Heróis abre a galeria")
	m.gallery.close()
	check(menu.visible and not m.gallery.visible, "Voltar mostra o menu de novo")
	m.free()


func test_gallery_draws_without_images() -> void:
	# Sem nenhuma imagem a galeria desenha só por código (emblemas no lugar dos retratos).
	after_draw(func():
		_no_images()
		Art.drawn = 0
		scene = new_gallery(),
	func():
		check(Art.drawn == 0, "sem imagens nada deveria ser desenhado por textura (desenhou %d)" % Art.drawn)
		check(not scene.used_full, "sem ilustração não usa o corpo inteiro")
		scene.free()
		scene = null
		Art.clear_cache())


func test_gallery_full_art_and_portrait_fallback() -> void:
	# Só com retratos: a reserva é o retrato ampliado. Com a ilustração, ela é usada.
	after_draw(func():
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		var tx := ImageTexture.create_from_image(img)
		_no_images()
		for hid in Data.HERO_ORDER:
			Art.set_texture(Art.HERO_PORTRAIT % hid, tx)
		Art.drawn = 0
		scene = new_gallery(),
	func():
		check(not scene.used_full, "sem _full.png deveria usar o retrato")
		check(Art.drawn >= 4, "retratos da lista e o ampliado (desenhou %d)" % Art.drawn)
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		var tx := ImageTexture.create_from_image(img)
		Art.set_texture(Art.HERO_FULL % "talos", tx)
		scene.queue_redraw()
		after_draw_check_full())


func after_draw_check_full() -> void:
	# Segunda etapa: a ilustração entra no lugar do retrato ampliado.
	_draw_tests.push_front({"name": _current, "start": func(): pass, "check": func():
		check(scene.used_full, "com _full.png a galeria deveria desenhar a ilustração")
		scene.free()
		scene = null
		Art.clear_cache(), "pre": []})


# ---------------------------------------------------------------------------
# Nome, idiomas, metros, dicas, pausa e mapa (pacote 2)

## Textos PT do arquivo de tradução, lidos direto do CSV (chave -> pt).
func _csv_pt() -> Dictionary:
	var f := FileAccess.open("res://i18n/textos.csv", FileAccess.READ)
	var out := {}
	var head := f.get_csv_line()
	check(head.size() == 3 and head[1] == "pt" and head[2] == "en" and head[0].ends_with("chave"), "cabeçalho do CSV deveria ser chave,pt,en")
	while not f.eof_reached():
		var row := f.get_csv_line()
		if row.size() < 2 or row[0] == "":
			continue
		check(not out.has(row[0]), "chave repetida no CSV: " + row[0])
		check(row[1] != "", "texto PT vazio: " + row[0])
		out[row[0]] = row[1]
	return out


func test_project_renamed_clockwork_gods() -> void:
	check(ProjectSettings.get_setting("application/config/name") == "Clockwork Gods", "nome do projeto deveria ser Clockwork Gods")
	var Menu = load("res://scripts/menu.gd")
	check(Menu.game_title() == "CLOCKWORK GODS", "título do menu vem do nome do projeto")
	var readme := FileAccess.get_file_as_string("res://README.md")
	check(readme.begins_with("# Clockwork Gods"), "README com o nome novo")


func test_i18n_every_key_in_code_exists() -> void:
	# Toda chave fixa usada no código e toda chave montada a partir dos dados existe no CSV.
	var pt := _csv_pt()
	var re := RegEx.create_from_string("T\\.tf?\\(\"([A-Z0-9_]+)\"\\s*[,)]")
	var used := 0
	for path in _script_paths():
		for line in FileAccess.get_file_as_string(path).split("\n"):
			if line.strip_edges().begins_with("#"):
				continue
			for m in re.search_all(line):
				used += 1
				check(pt.has(m.get_string(1)), "chave sem texto no CSV: %s (%s)" % [m.get_string(1), path])
	check(used > 60, "deveria achar as chaves usadas no código (achou %d)" % used)
	var keys: Array = []
	for k in Data.ABILITIES.keys():
		for f in ["NAME", "SHORT", "DESC"]:
			keys.append("AB_%s_%s" % [k.to_upper(), f])
	for hid in Data.HERO_ORDER:
		for f in ["NAME", "EPITHET", "BIO", "QUOTE"]:
			keys.append("HERO_%s_%s" % [hid.to_upper(), f])
		keys.append("ORIGIN_" + String(Data.HEROES[hid]["origin"]).to_upper())
	for role in Data.ROLE_COLORS.keys():
		keys.append("ROLE_" + String(role).to_upper())
	for e in Data.EFFECTS:
		keys.append("EFFECT_" + e.to_upper())
	for b in Data.BEHAVIORS:
		keys.append("BEH_" + b.to_upper())
		keys.append("BEH_%s_DESC" % b.to_upper())
	for d in ["EASY", "NORMAL", "HARD"]:
		keys.append("DIFF_" + d)
	for r in ["icor", "morto", "armada", "carga", "vazio", "cd"]:
		keys.append("FLASH_" + r.to_upper())
	for l in T.LANGS:
		keys.append("LANG_" + l.to_upper())
	keys.append_array(["TEAM_0", "TEAM_1"])
	for key in UI_HELP_KEYS():
		keys.append(key)
	for key in keys:
		check(pt.has(key), "chave sem texto no CSV: " + key)


func UI_HELP_KEYS() -> Array:
	var out: Array = []
	for k in load("res://scripts/ui.gd").HELP_LINES:
		if k != "":
			out.append(k)
	return out


func _script_paths() -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at("res://scripts"):
		if f.ends_with(".gd"):
			out.append("res://scripts/" + f)
	return out


func test_i18n_no_visible_text_literals_in_code() -> void:
	# Nenhum texto visível escrito direto no código: só chaves de tradução.
	var calls := RegEx.create_from_string("(text_[clr]|text_box|draw_string|draw_multiline_string|announce|add_text|italic_text|_draw_tip|button)\\(")
	# Literais em sequência (sem pular de um para o outro). Ficam de fora os
	# identificadores ("role", "continue") e as chaves de tradução ("MUSIC_OFF").
	var literal := RegEx.create_from_string("\"((?:[^\"\\\\]|\\\\.)*)\"")
	var ident := RegEx.create_from_string("^([a-z0-9_]+|[A-Z0-9_%sd]+)$")
	var letters := RegEx.create_from_string("[A-Za-zÀ-ú]{2,}")
	for path in _script_paths():
		var n := 0
		for line in FileAccess.get_file_as_string(path).split("\n"):
			n += 1
			if line.strip_edges().begins_with("#") or calls.search(line) == null:
				continue
			for m in literal.search_all(line):
				var s := m.get_string(1)
				if letters.search(s) == null or ident.search(s) != null or s.begins_with("res://"):
					continue
				check(false, "texto visível fora do CSV em %s:%d: \"%s\"" % [path.get_file(), n, s])


func test_i18n_detect_language() -> void:
	check(T.detect("pt_BR") == "pt" and T.detect("pt") == "pt" and T.detect("pt-PT") == "pt", "português → PT")
	check(T.detect("en_US") == "en" and T.detect("es") == "en" and T.detect("fr_FR") == "en" and T.detect("") == "en", "outros → EN")


func test_i18n_choice_is_saved_and_kept_by_audio() -> void:
	var old_path := T.settings_path
	T.settings_path = "user://test_settings.cfg"
	DirAccess.remove_absolute(T.settings_path)
	T.init()
	check(T.lang() == T.detect(OS.get_locale()), "sem escolha salva usa o idioma do sistema")
	T.set_lang("en")
	TranslationServer.set_locale("pt")
	T.init()
	check(T.lang() == "en", "a escolha salva vale na próxima abertura")
	var a := new_audio()
	a.save_settings()
	T.init()
	check(T.lang() == "en", "salvar o som não apaga o idioma")
	a.free()
	T.set_lang("pt")
	T.settings_path = old_path
	TranslationServer.set_locale("pt")


func test_i18n_english_falls_back_to_portuguese() -> void:
	T.set_lang("en", false)
	check(T.hero_name("asclepio") == "Asclepius", "nome em inglês na galeria")
	check(T.t("MENU_PLAY") != "JOGAR CONTRA BOT" and T.t("MENU_PLAY") != "MENU_PLAY", "botão Jogar traduzido: " + T.t("MENU_PLAY"))
	check(ProjectSettings.get_setting("internationalization/locale/fallback") == "pt", "texto sem tradução cai para PT")
	check(T.origin_name("deusa") == "Goddess", "origem em inglês")
	T.set_lang("pt", false)
	check(T.hero_name("asclepio") == "Asclépio", "volta ao PT")


func test_meters_display() -> void:
	T.set_lang("pt", false)
	check(T.meters(300.0) == "10,0 m", "300 px = 10,0 m (veio %s)" % T.meters(300.0))
	check(T.mps(72.0) == "2,4 m/s", "72 px/s = 2,4 m/s (veio %s)" % T.mps(72.0))
	check(GalleryScript.stat_text("artemis", "range") == "10,0 m", "alcance da Ártemis em metros")
	check(GalleryScript.stat_text("talos", "hp") == "650", "vida continua número")
	T.set_lang("en", false)
	check(T.meters(62.0) == "2.1 m", "EN usa ponto (veio %s)" % T.meters(62.0))
	T.set_lang("pt", false)


func test_behavior_tips_use_real_numbers() -> void:
	T.set_lang("pt", false)
	var bal: Array = HudScript.behavior_lines("balanced")
	var text := " | ".join(bal)
	check(text.contains("0,7 m"), "tanque 20 px à frente = 0,7 m: " + text)
	check(text.contains("13,3 m") and text.contains("15,8 m"), "persegue a 13,3 m, até 15,8 m do ponto: " + text)
	check(text.contains("30%") and text.contains("80%"), "recua com 30%, volta com 80%: " + text)
	var agg := " | ".join(HudScript.behavior_lines("aggressive"))
	check(agg.contains("5,0 m") and agg.contains("18,7 m") and agg.contains("15%"), "agressivo: " + agg)
	var def := " | ".join(HudScript.behavior_lines("defensive"))
	check(def.contains(T.t("TIP_BEH_FRONT_CENTER")) and def.contains("35%"), "defensivo: " + def)


func test_hud_hover_finds_ult_next_and_behavior() -> void:
	var g := new_game()
	var h = g.hud
	h.update_hover(h.ult_center(1))
	check(h.tip.get("kind") == "ult" and h.tip.get("i") == 1, "mouse na ultimate da Ártemis")
	h.update_hover(h.next_rect().get_center())
	check(h.tip.get("kind") == "next", "mouse na próxima carta")
	h.update_hover(h.beh_rect(2).get_center())
	check(h.tip.get("kind") == "beh" and h.tip.get("i") == 2, "mouse no botão Defensivo")
	h.update_hover(h.base_card_rect(0).get_center())
	check(h.hover == 0 and h.tip.is_empty(), "mouse na carta usa a dica da carta")
	g.paused = true
	h.update_hover(h.ult_center(0))
	check(h.tip.is_empty(), "sem dicas com o jogo pausado")
	done(g)


func _tip_draw_test(kind: String, i: int, ult := 0.0) -> void:
	after_draw(func():
		scene = new_game()
		var h = scene.hud
		h.set_process(false)
		h.tip = {"kind": kind, "i": i}
		if ult > 0.0:
			hero(scene, 0, "talos").ult = ult
		h.queue_redraw(),
	func():
		# Erros de desenho aparecem como SCRIPT ERROR e reprovam o run_tests.
		check(scene.hud.tip.get("kind") == kind, "dica %s desenhada" % kind)
		done(scene)
		scene = null)


func test_hud_tip_draw_ult() -> void:
	_tip_draw_test("ult", 0, 100.0)


func test_hud_tip_draw_next() -> void:
	_tip_draw_test("next", 0)


func test_hud_tip_draw_behavior() -> void:
	_tip_draw_test("beh", 0)


func test_pause_menu_flow() -> void:
	var g := new_game()
	var h = g.hud
	var reqs: Array = []
	g.request.connect(func(a): reqs.append(a))
	h._input(_key(KEY_ESCAPE))
	check(g.paused and h.pause_view == "main", "ESC pausa")
	h._input(_key(KEY_ESCAPE))
	check(not g.paused, "ESC de novo retoma")
	h._input(_key(KEY_P))
	check(g.paused, "P pausa")
	h.pause_click(h.pause_button("help").get_center())
	check(h.pause_view == "help", "Como jogar abre a ajuda")
	h._input(_key(KEY_ESCAPE))
	check(g.paused and h.pause_view == "main", "ESC na ajuda volta à pausa")
	h.pause_click(h.pause_button("quit").get_center())
	check(h.pause_view == "confirm" and reqs.is_empty(), "Voltar ao menu pede confirmação")
	h.pause_click(h.confirm_button(1).get_center())
	check(h.pause_view == "main" and reqs.is_empty(), "Cancelar volta à pausa")
	var lr: Rect2 = h.pause_lang_rect()
	h.pause_click(Vector2(lr.end.x - 5, lr.get_center().y))
	check(T.lang() == "en", "botão EN na pausa troca o idioma")
	h.pause_click(Vector2(lr.position.x + 5, lr.get_center().y))
	check(T.lang() == "pt", "botão PT na pausa volta")
	h.pause_click(h.pause_button("continue").get_center())
	check(not g.paused, "Continuar retoma")
	h.set_paused(true)
	h.pause_click(h.pause_button("quit").get_center())
	h.pause_click(h.confirm_button(0).get_center())
	check(reqs == ["menu"], "confirmar volta ao menu principal")
	done(g)


func test_pause_on_focus_loss() -> void:
	var g := new_game()
	g.hud._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(g.paused and g.hud.auto_paused, "perder o foco pausa sozinho")
	g.hud._input(_key(KEY_ESCAPE))
	check(not g.paused, "ESC retoma")
	g.ended = true
	g.hud._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(not g.paused, "partida encerrada não pausa")
	done(g)


func test_pause_menu_draws() -> void:
	after_draw(func():
		scene = new_game()
		scene.hud.set_paused(true, true)
		scene.hud.pause_view = "confirm"
		scene.hud.queue_redraw(),
	func():
		check(scene.paused, "pausa desenhada")
		done(scene)
		scene = null)


func test_menu_language_button() -> void:
	var Menu = load("res://scripts/menu.gd")
	var m: Node2D = Menu.new()
	var lr: Rect2 = m.lang_rect()
	for r in [m.play_rect(), m.help_rect(), m.heroes_rect()]:
		check(not lr.intersects(r), "botão de idioma não cobre outros botões")
	check(lr.end.x <= 1280 and lr.position.y >= 0, "botão de idioma dentro da tela")
	check(UI_lang_at(lr, Vector2(lr.position.x + 2, lr.get_center().y)) == "pt" and UI_lang_at(lr, Vector2(lr.end.x - 2, lr.get_center().y)) == "en", "metades PT e EN")
	m.free()


func UI_lang_at(r: Rect2, p: Vector2) -> String:
	return load("res://scripts/ui.gd").lang_at(r, p)


func test_art_every_map_image_is_used() -> void:
	# Com textura em todos os caminhos map/, a partida desenha as 5 imagens do mapa.
	after_draw(func():
		var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
		img.fill(Color.WHITE)
		var tx := ImageTexture.create_from_image(img)
		Art.clear_cache()
		for p in _all_art_paths():
			Art.set_texture(p, tx)
		Art.drawn_names.clear()
		scene = _art_scene(),
	func():
		for name in Art.MAP_IMAGES.keys():
			check(Art.drawn_names.has("map/" + name), "a imagem map/%s.png nunca é desenhada" % name)
		done(scene)
		scene = null
		Art.clear_cache())


func test_art_map_sizes() -> void:
	# Colunas grandes (raio 34/28) e pequenas (22/20); tamanhos na tela.
	check(Art.pillar_name(34.0) == "pillar_large" and Art.pillar_name(28.0) == "pillar_large", "raio 34 e 28 usam a coluna grande")
	check(Art.pillar_name(22.0) == "pillar_small" and Art.pillar_name(20.0) == "pillar_small", "raio 22 e 20 usam a coluna pequena")
	check(absf(Art.map_size("pillar_large", 34.0) - 80.0) < 0.1, "coluna de raio 34 desenhada com 80 px")
	check(absf(Art.map_size("control_point", 95.0) - 211.1) < 0.2, "ponto desenhado com ~211 px")
	var readme := FileAccess.get_file_as_string("res://assets/README.md")
	for name in Art.MAP_IMAGES.keys():
		check(readme.contains(name + ".png"), "assets/README.md deveria listar map/%s.png" % name)


func test_music_pauses_with_game() -> void:
	var a := new_audio()
	var old = AudioScript.instance
	AudioScript.instance = a
	a.music_on = true
	while not a.generate_music_step(1000.0):
		pass
	a.apply_settings()
	check(a._music_player.playing, "música tocando antes da pausa")
	var g := new_game()
	g.hud.set_paused(true)
	check(a.music_paused and a._music_player.stream_paused, "pausa do menu para a música")
	g.hud.set_paused(false)
	check(not a.music_paused and not a._music_player.stream_paused, "continuar volta a música")
	g.hud._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(a._music_player.stream_paused, "pausa automática para a música")
	g.hud.pause_click(g.hud.pause_button("quit").get_center())
	g.hud.pause_click(g.hud.confirm_button(0).get_center())
	check(not a._music_player.stream_paused, "voltar ao menu solta a música")
	a.toggle_music()
	a.toggle_music()
	check(a.music_on, "opção de música intacta")
	done(g)
	AudioScript.instance = old
	a.free()


func test_readability_names_above_bodies_and_soft_areas() -> void:
	# Nome numa camada acima dos corpos (heróis empilhados na base não escondem
	# o nome do vizinho) e áreas grandes translúcidas o bastante para ler os heróis.
	var g := new_game()
	for h in g.heroes:
		check(h.name_tag != null and h.name_tag.z_index > 0 and h.name_tag.get_parent() == h, "nome de %s numa camada acima do corpo" % h.hid)
	check(Art.AREA_ALPHA >= 0.35 and Art.AREA_ALPHA <= 0.65, "área grande nem invisível nem opaca (%.2f)" % Art.AREA_ALPHA)
	check(Art.RAIN_ALPHA >= 0.3 and Art.RAIN_ALPHA <= 0.6, "Chuva de Prata translúcida (%.2f)" % Art.RAIN_ALPHA)
	done(g)


func test_ability_popups_do_not_overlap() -> void:
	# Quatro habilidades ao mesmo tempo no mesmo grupo: os selos não se sobrepõem.
	var g := new_game()
	var t = hero(g, 0, "talos")
	var a = hero(g, 0, "artemis")
	var s = hero(g, 0, "asclepio")
	pin(t, Vector2(600, 300)); pin(a, Vector2(612, 296)); pin(s, Vector2(590, 310))
	g.cast(t, "valvula", t.position)
	g.cast(s, "sopro", s.position)
	g.cast(a, "salto", a.position)
	g.cast(t, "furia", t.position)
	var lay: Array = g.popup_layout()
	check(lay.size() == 4, "quatro selos (veio %d)" % lay.size())
	for i in lay.size():
		for j in range(i + 1, lay.size()):
			var d: float = lay[i]["pos"].distance_to(lay[j]["pos"])
			check(d >= lay[i]["r"] + lay[j]["r"], "selos %d e %d sobrepostos (%.0f px)" % [i, j, d])
	done(g)
