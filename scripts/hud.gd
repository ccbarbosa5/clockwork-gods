extends Node2D
## Interface do jogador: cartas, Ícor, ultimates, comportamento e placar.
## Clicar numa carta basta: o herói usa a habilidade sozinho no melhor momento.

const Data = preload("res://scripts/data.gd")
const UI = preload("res://scripts/ui.gd")

const PANEL := Rect2(0, 560, 1280, 160)
const ICHOR_BAR := Rect2(350, 700, 504, 14)
const NEXT_RECT := Rect2(872, 604, 78, 90)

var game
var cmd
var msg := ""
var msg_t := 0.0
var hover := -1
var pressed := -1
var press_t := 0.0


func setup(g) -> void:
	game = g
	cmd = g.commanders[g.player_team]


func base_card_rect(i: int) -> Rect2:
	return Rect2(350 + i * 128, 576, 120, 118)


func card_rect(i: int) -> Rect2:
	var r := base_card_rect(i)
	if i == hover:
		r.position.y -= 8
	if i == pressed and press_t > 0.0:
		r.position.y += 3
	return r


func ult_center(i: int) -> Vector2:
	return Vector2(58 + i * 98, 668)


func beh_rect(i: int) -> Rect2:
	return Rect2(984 + i * 96, 614, 90, 40)


func end_button(i: int) -> Rect2:
	return Rect2(470 + i * 180, 560, 160, 44)


func _player_controls() -> bool:
	return game.bots[game.player_team] == null


# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	msg_t -= delta
	press_t -= delta
	var m := get_global_mouse_position()
	hover = -1
	if not game.ended:
		for i in 4:
			if base_card_rect(i).has_point(m) and cmd.hand[i] != "":
				hover = i
	queue_redraw()


func _input(event: InputEvent) -> void:
	var m := get_global_mouse_position()
	if event is InputEventMouse:
		m = (make_input_local(event) as InputEventMouse).position
	if game.ended:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if end_button(0).has_point(m):
				game.request.emit("restart")
			elif end_button(1).has_point(m):
				game.request.emit("menu")
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_P:
		game.paused = not game.paused
		return
	if game.paused or not _player_controls():
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in 4:
			if base_card_rect(i).has_point(m):
				_play(i)
				return
		for j in 3:
			if m.distance_to(ult_center(j)) <= 30.0:
				_ult(Data.HERO_ORDER[j])
				return
		for k in 3:
			if beh_rect(k).has_point(m):
				_behavior(Data.BEHAVIORS[k])
				return
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _play(0)
			KEY_2: _play(1)
			KEY_3: _play(2)
			KEY_4: _play(3)
			KEY_Q: _ult(Data.HERO_ORDER[0])
			KEY_W: _ult(Data.HERO_ORDER[1])
			KEY_E: _ult(Data.HERO_ORDER[2])
			KEY_Z: _behavior(Data.BEHAVIORS[0])
			KEY_X: _behavior(Data.BEHAVIORS[1])
			KEY_C: _behavior(Data.BEHAVIORS[2])


func _flash(reason: String) -> void:
	var texts := {"icor": "Ícor insuficiente", "morto": "Herói abatido", "armada": "Ultimate já armada",
		"carga": "Ultimate ainda carregando", "vazio": "Sem carta neste espaço", "cd": "Aguarde para trocar o comportamento"}
	msg = texts.get(reason, reason)
	msg_t = 1.4


func _play(i: int) -> void:
	var reason: String = cmd.can_play(i)
	if reason != "":
		_flash(reason)
		return
	pressed = i
	press_t = 0.12
	cmd.play(i)


func _ult(hid: String) -> void:
	var reason: String = cmd.can_ult(hid)
	if reason != "":
		_flash(reason)
		return
	cmd.use_ult(hid)


func _behavior(b: String) -> void:
	if b == cmd.behavior:
		return
	if not cmd.set_behavior(b):
		_flash("cd")


# ---------------------------------------------------------------------------
# Desenho
func _draw() -> void:
	game.draw_overlay(self)
	_draw_top()
	_draw_panel()
	if hover >= 0:
		_draw_tooltip(hover)
	if msg_t > 0.0:
		UI.text_c(self, Vector2(640, 548), msg, 18, Color(1, 0.5, 0.4, clampf(msg_t, 0.0, 1.0)), 4)
	if game.paused and not game.ended:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.55))
		UI.text_c(self, Vector2(640, 330), "PAUSADO", 44, Data.GOLD, 6)
		UI.text_c(self, Vector2(640, 370), "Pressione P para continuar", 18, Color.WHITE, 3)
	if game.ended:
		_draw_end()


func _draw_top() -> void:
	draw_rect(Rect2(0, 0, 1280, 40), Color(0.08, 0.06, 0.05))
	draw_line(Vector2(0, 40), Vector2(1280, 40), Color(Data.BRONZE, 0.8), 2.0)
	for t in 2:
		var tc: Color = Data.TEAM_COLORS[t]
		var r := Rect2(20, 13, 470, 14) if t == 0 else Rect2(790, 13, 470, 14)
		draw_rect(r, Color(0, 0, 0, 0.6))
		var w: float = r.size.x * game.progress[t] / 100.0
		if t == 0:
			draw_rect(Rect2(r.position, Vector2(w, r.size.y)), tc)
		else:
			draw_rect(Rect2(r.end.x - w, r.position.y, w, r.size.y), tc)
		draw_rect(r, Color(Data.BRONZE, 0.8), false, 1.5)
		var label := "%s  %d%%" % ["VOCÊ" if t == game.player_team else "BOT", int(game.progress[t])]
		if t == 0:
			UI.text_l(self, Vector2(24, 25), label, 12, Color.WHITE, 3)
		else:
			UI.text_r(self, Vector2(1256, 25), label, 12, Color.WHITE, 3)
	var tl: float = game.time_left()
	var clock := "%d:%02d" % [int(tl) / 60, int(tl) % 60]
	if game.overtime:
		clock = "PRORROGAÇÃO"
	UI.text_c(self, Vector2(640, 20), clock, 18, Data.GOLD, 3)
	var status := ""
	if not game.point_unlocked():
		status = "Ponto libera em %d s" % int(ceil(Data.UNLOCK_TIME - game.time))
	elif game.contested:
		status = "Ponto disputado"
	elif game.point_owner >= 0:
		status = "Ponto: time %s" % Data.TEAM_NAMES[game.point_owner]
	else:
		status = "Ponto neutro"
	UI.text_c(self, Vector2(640, 35), status, 11, Color(1, 1, 1, 0.75))


func _draw_panel() -> void:
	draw_rect(PANEL, Color(0.1, 0.08, 0.06))
	draw_line(PANEL.position, Vector2(PANEL.end.x, PANEL.position.y), Data.BRONZE, 3.0)
	draw_line(Vector2(330, 568), Vector2(330, 712), Color(Data.BRONZE, 0.3), 1.0)
	draw_line(Vector2(966, 568), Vector2(966, 712), Color(Data.BRONZE, 0.3), 1.0)

	# Heróis e ultimates
	for i in 3:
		var hid: String = Data.HERO_ORDER[i]
		var h = game.get_hero(cmd.team, hid)
		var c := ult_center(i)
		var rc: Color = h.role_color()
		UI.hero_glyph(self, hid, Vector2(c.x - 34, 578), 5.0, rc)
		UI.text_c(self, Vector2(c.x + 4, 583), h.def["name"], 13, Color.WHITE)
		UI.text_c(self, Vector2(c.x, 597), h.def["role"], 10, rc)
		var hb := Rect2(c.x - 40, 602, 80, 6)
		draw_rect(hb, Color(0, 0, 0, 0.7))
		draw_rect(Rect2(hb.position, Vector2(hb.size.x * (h.hp / h.max_hp if h.alive else 0.0), hb.size.y)), Data.TEAM_COLORS[cmd.team])
		# Habilidades armadas deste herói
		var n: int = h.armed.size()
		for k in n:
			var ab: Dictionary = Data.ABILITIES[h.armed[k]["ab"]]
			UI.badge(self, Vector2(c.x + 30 - k * 16, 624), 6.5, ab, rc, 0.95, h.armed[k]["ult"])
		draw_circle(c, 30.0, Color(0.05, 0.04, 0.03))
		draw_circle(c, 25.0, Color(rc, 0.22))
		var ready: bool = h.ult >= 100.0 and h.alive
		draw_arc(c, 28.0, -PI * 0.5, -PI * 0.5 + TAU * h.ult / 100.0, 40, Data.GOLD if ready else Color(Data.GOLD, 0.6), 4.0, true)
		if ready:
			var pulse := 0.5 + 0.5 * sin(game.time * 6.0)
			draw_circle(c, 25.0, Color(Data.GOLD, 0.25 + 0.3 * pulse))
		var ult_ab: Dictionary = Data.ABILITIES[h.def["ult"]]
		UI.effect_icon(self, ult_ab["effect"], c + Vector2(0, -4), 9.0, Color(1, 1, 1, 0.35 if not ready else 0.9))
		UI.text_c(self, c + Vector2(0, 17), h.ability_ready_text() if h.alive else "—", 10 if ready else 11, Color.WHITE, 3)
		UI.text_c(self, c + Vector2(-20, -18), Data.ULT_KEYS[i], 10, Color(1, 1, 1, 0.6), 2)
		UI.text_c(self, Vector2(c.x, 712), ult_ab["name"], 10, Color(Data.GOLD, 0.8))
		if not h.alive:
			draw_circle(c, 30.0, Color(0, 0, 0, 0.65))
			UI.text_c(self, c + Vector2(0, 5), "%d s" % int(ceil(h.respawn_t)), 15, Color(1, 0.5, 0.4), 3)

	# Cartas
	for i in 4:
		var card: String = cmd.hand[i]
		if card == "":
			var br := base_card_rect(i)
			draw_rect(br, Color(1, 1, 1, 0.04))
			draw_rect(br, Color(1, 1, 1, 0.15), false, 1.0)
			UI.text_c(self, br.get_center() + Vector2(0, 5), "—", 14, Color(1, 1, 1, 0.3))
			continue
		var r := card_rect(i)
		_draw_card(r, card, i == hover)
		UI.text_r(self, r.end + Vector2(-5, -5), str(i + 1), 10, Color(1, 1, 1, 0.55))
		if cmd.can_play(i) == "icor":
			var cost: float = Data.ABILITIES[card]["cost"]
			var f := clampf(cmd.ichor / cost, 0.0, 1.0)
			draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * (1.0 - f))), Color(0, 0, 0, 0.6))

	# Próxima carta
	UI.text_c(self, Vector2(NEXT_RECT.get_center().x, 596), "Próxima", 10, Color(1, 1, 1, 0.6))
	var nxt: String = cmd.next_card()
	if nxt != "":
		_draw_card_mini(NEXT_RECT, nxt)
	else:
		draw_rect(NEXT_RECT, Color(1, 1, 1, 0.12), false, 1.0)

	# Barra de Ícor
	var bar := ICHOR_BAR
	draw_rect(bar, Color(0, 0, 0, 0.7))
	var seg := bar.size.x / Data.ICHOR_MAX
	var full := int(floor(cmd.ichor))
	for s in int(Data.ICHOR_MAX):
		var sr := Rect2(bar.position.x + s * seg + 1, bar.position.y + 1, seg - 2, bar.size.y - 2)
		if s < full:
			draw_rect(sr, Data.GOLD)
		elif s == full:
			draw_rect(Rect2(sr.position, Vector2(sr.size.x * (cmd.ichor - full), sr.size.y)), Color(Data.GOLD, 0.5))
	UI.text_l(self, Vector2(bar.end.x + 8, bar.end.y), "%d Ícor" % full, 13, Data.GOLD, 3)

	# Comportamento
	UI.text_c(self, Vector2(1128, 594), "Comportamento da IA", 13, Color.WHITE)
	for k in 3:
		var b: String = Data.BEHAVIORS[k]
		var r2 := beh_rect(k)
		var active: bool = cmd.behavior == b
		UI.panel(self, r2, Color(Data.BRONZE, 0.45) if active else Color(0, 0, 0, 0.4), Data.GOLD if active else Color(Data.BRONZE, 0.5), 2.0 if active else 1.0)
		UI.text_c(self, r2.get_center() + Vector2(0, 2), Data.BEHAVIOR_NAMES[b], 12, Color.WHITE)
		UI.text_c(self, r2.get_center() + Vector2(0, 15), Data.BEHAVIOR_KEYS[k], 9, Color(1, 1, 1, 0.5))
	if cmd.behavior_cd > 0.0:
		UI.text_c(self, Vector2(1128, 676), "Nova troca em %d s" % int(ceil(cmd.behavior_cd)), 11, Color(1, 1, 1, 0.6))
	UI.text_c(self, Vector2(1128, 702), "Clique na carta: o herói usa no melhor momento", 10, Color(1, 1, 1, 0.4))


func _gem(c: Vector2, cost: int, r: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	draw_colored_polygon(pts, Data.GOLD)
	draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), Color(0.3, 0.18, 0.05), 1.5)
	UI.text_c(self, c + Vector2(0, r * 0.45), str(cost), int(r * 1.3), Color(0.15, 0.08, 0.02))


## Carta: faixa e moldura na cor da função, emblema do herói, ícone grande do efeito.
func _draw_card(r: Rect2, card: String, hov: bool) -> void:
	var ab: Dictionary = Data.ABILITIES[card]
	var hd: Dictionary = Data.HEROES[ab["hero"]]
	var rc: Color = Data.ROLE_COLORS[hd["role"]]
	draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.4))
	draw_rect(r, rc.darkened(0.78))
	# Faixa superior com o herói
	var head := Rect2(r.position, Vector2(r.size.x, 24))
	draw_rect(head, rc.darkened(0.15))
	UI.hero_glyph(self, ab["hero"], head.position + Vector2(r.size.x - 14, 12), 5.5, Color(0.1, 0.06, 0.03))
	UI.text_c(self, Vector2(r.get_center().x + 4, head.position.y + 16), hd["name"].to_upper(), 10, Color(0.1, 0.06, 0.03))
	# Ícone do efeito
	var ic := Vector2(r.get_center().x, r.position.y + 54)
	draw_circle(ic, 20.0, rc.darkened(0.45))
	UI.ring(self, ic, 20.0, Color(rc, 0.9), 2.0)
	UI.effect_icon(self, ab["effect"], ic, 12.0, Color.WHITE)
	# Nome e resumo
	UI.text_box(self, Rect2(r.position.x + 4, r.position.y + 76, r.size.x - 8, 30), ab["name"], 11, Color.WHITE)
	UI.text_c(self, Vector2(r.get_center().x, r.end.y - 6), ab["short"], 9, Color(rc.lightened(0.35), 0.95))
	draw_rect(r, Data.GOLD if hov else Color(rc, 0.9), false, 3.0 if hov else 2.0)
	_gem(r.position + Vector2(13, 13), ab["cost"], 11.0)


func _draw_card_mini(r: Rect2, card: String) -> void:
	var ab: Dictionary = Data.ABILITIES[card]
	var rc: Color = Data.ROLE_COLORS[Data.HEROES[ab["hero"]]["role"]]
	draw_rect(r, rc.darkened(0.78))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 8)), rc.darkened(0.15))
	var ic := Vector2(r.get_center().x, r.position.y + 36)
	draw_circle(ic, 15.0, rc.darkened(0.45))
	UI.effect_icon(self, ab["effect"], ic, 9.0, Color.WHITE)
	UI.text_box(self, Rect2(r.position.x + 3, r.position.y + 54, r.size.x - 6, 34), ab["name"], 9, Color(1, 1, 1, 0.85))
	draw_rect(r, Color(rc, 0.7), false, 1.5)
	_gem(r.position + Vector2(10, 12), ab["cost"], 8.0)


func _draw_tooltip(i: int) -> void:
	var card: String = cmd.hand[i]
	if card == "":
		return
	var ab: Dictionary = Data.ABILITIES[card]
	var hd: Dictionary = Data.HEROES[ab["hero"]]
	var rc: Color = Data.ROLE_COLORS[hd["role"]]
	var br := base_card_rect(i)
	var r := Rect2(br.get_center().x - 120, br.position.y - 104, 240, 92)
	UI.panel(self, r, Color(0.08, 0.06, 0.05, 0.96), rc, 2.0)
	UI.text_l(self, r.position + Vector2(10, 20), ab["name"], 14, Color.WHITE)
	UI.text_l(self, r.position + Vector2(10, 37), "%s · %s · %s" % [hd["name"], hd["role"], Data.EFFECT_NAMES[ab["effect"]]], 11, rc.lightened(0.3))
	UI.text_box(self, Rect2(r.position.x + 8, r.position.y + 42, r.size.x - 16, 46), ab["desc"], 11, Color(1, 1, 1, 0.85))


func _draw_end() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.72))
	var title := "EMPATE"
	var col := Color.WHITE
	if game.result == game.player_team:
		title = "VITÓRIA"
		col = Data.GOLD
	elif game.result >= 0:
		title = "DERROTA"
		col = Color(1, 0.4, 0.35)
	UI.text_c(self, Vector2(640, 150), title, 64, col, 8)
	UI.text_c(self, Vector2(640, 190), "Progresso  %d%%  x  %d%%   ·   Tempo %d:%02d" % [int(game.progress[0]), int(game.progress[1]), int(game.time) / 60, int(game.time) % 60], 16, Color.WHITE, 3)
	var cols := [380.0, 540.0, 640.0, 740.0, 840.0]
	var heads := ["Herói", "Abates/Mortes", "Dano", "Cura", "Mitigado"]
	var y := 240.0
	for t in 2:
		UI.text_l(self, Vector2(300, y), "Seu time" if t == game.player_team else "Bot", 15, Data.TEAM_COLORS[t], 3)
		y += 22.0
		for i in heads.size():
			UI.text_c(self, Vector2(cols[i], y), heads[i], 11, Color(1, 1, 1, 0.5))
		y += 20.0
		for hid in Data.HERO_ORDER:
			var h = game.get_hero(t, hid)
			var st: Dictionary = h.stats
			var vals := [h.def["name"], "%d / %d" % [st["kills"], st["deaths"]], str(int(st["damage"])), str(int(st["healing"])), str(int(st["mitigated"]))]
			for i in vals.size():
				UI.text_c(self, Vector2(cols[i], y), vals[i], 13, Color.WHITE)
			y += 20.0
		y += 14.0
	for i in 2:
		var r := end_button(i)
		var hov := r.has_point(get_global_mouse_position())
		UI.panel(self, r, Color(Data.BRONZE, 0.6 if hov else 0.35), Data.GOLD, 2.0)
		UI.text_c(self, r.get_center() + Vector2(0, 6), ["Jogar novamente", "Menu"][i], 16, Color.WHITE, 2)
