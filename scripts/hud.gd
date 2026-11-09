extends Node2D
## Interface do jogador: cartas, Ícor, ultimates, comportamento e placar.

const Data = preload("res://scripts/data.gd")
const UI = preload("res://scripts/ui.gd")

const PANEL := Rect2(0, 560, 1280, 160)
const ICHOR_BAR := Rect2(350, 700, 504, 14)
const NEXT_RECT := Rect2(872, 604, 78, 90)

var game
var cmd
var selected := -1
var selected_ult := ""
var press_slot := -1
var press_pos := Vector2.ZERO
var dragging := false
var msg := ""
var msg_t := 0.0
var hover := -1


func setup(g) -> void:
	game = g
	cmd = g.commanders[g.player_team]


func card_rect(i: int) -> Rect2:
	var r := Rect2(350 + i * 128, 576, 120, 118)
	if i == selected or i == hover:
		r.position.y -= 8
	return r


func base_card_rect(i: int) -> Rect2:
	return Rect2(350 + i * 128, 576, 120, 118)


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
	var m := get_global_mouse_position()
	hover = -1
	if not game.ended:
		for i in 4:
			if base_card_rect(i).has_point(m):
				hover = i
	queue_redraw()


func _input(event: InputEvent) -> void:
	var m := get_global_mouse_position()
	if game.ended:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if end_button(0).has_point(m):
				game.request.emit("restart")
			elif end_button(1).has_point(m):
				game.request.emit("menu")
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_P:
			game.paused = not game.paused
			return
	if game.paused or not _player_controls():
		return

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_press(m)
			else:
				_on_release(m)
	elif event is InputEventMouseMotion:
		if press_slot >= 0 and not dragging and m.distance_to(press_pos) > 12.0:
			if cmd.can_play(press_slot) == "":
				dragging = true
				selected = press_slot
				selected_ult = ""
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1: _click_card(0)
			KEY_2: _click_card(1)
			KEY_3: _click_card(2)
			KEY_4: _click_card(3)
			KEY_Q: _try_ult(Data.HERO_ORDER[0])
			KEY_W: _try_ult(Data.HERO_ORDER[1])
			KEY_E: _try_ult(Data.HERO_ORDER[2])
			KEY_Z: _try_behavior(Data.BEHAVIORS[0])
			KEY_X: _try_behavior(Data.BEHAVIORS[1])
			KEY_C: _try_behavior(Data.BEHAVIORS[2])
			KEY_ESCAPE: _cancel()


func _on_press(m: Vector2) -> void:
	for i in 4:
		if base_card_rect(i).has_point(m):
			press_slot = i
			press_pos = m
			dragging = false
			return
	for j in 3:
		if m.distance_to(ult_center(j)) <= 30.0:
			_try_ult(Data.HERO_ORDER[j])
			return
	for k in 3:
		if beh_rect(k).has_point(m):
			_try_behavior(Data.BEHAVIORS[k])
			return
	if game.in_arena(m):
		if selected >= 0:
			_cast_card(selected, m)
		elif selected_ult != "":
			_cast_ult(m)


func _on_release(m: Vector2) -> void:
	if press_slot < 0:
		return
	var slot := press_slot
	press_slot = -1
	if dragging:
		dragging = false
		if game.in_arena(m):
			_cast_card(slot, m)
		else:
			selected = -1
	else:
		_click_card(slot)


func _cancel() -> void:
	selected = -1
	selected_ult = ""
	press_slot = -1
	dragging = false


func _flash(reason: String) -> void:
	var texts := {"icor": "Ícor insuficiente", "morto": "Herói abatido", "atordoado": "Herói atordoado",
		"carga": "Ultimate ainda carregando", "vazio": "Sem carta neste espaço", "cd": "Aguarde para trocar o comportamento"}
	msg = texts.get(reason, reason)
	msg_t = 1.4


func _click_card(i: int) -> void:
	if selected == i:
		_cancel()
		return
	var reason: String = cmd.can_play(i)
	if reason != "":
		_flash(reason)
		return
	var ab: Dictionary = Data.ABILITIES[cmd.hand[i]]
	if ab["target"] == "self":
		var h = cmd.card_hero(cmd.hand[i])
		cmd.play(i, h.position)
		_cancel()
	else:
		selected = i
		selected_ult = ""


func _cast_card(i: int, m: Vector2) -> void:
	var reason: String = cmd.can_play(i)
	if reason != "":
		_flash(reason)
		_cancel()
		return
	cmd.play(i, m)
	_cancel()


func _try_ult(hid: String) -> void:
	var reason: String = cmd.can_ult(hid)
	if reason != "":
		_flash(reason)
		return
	var ab: Dictionary = Data.ABILITIES[Data.HEROES[hid]["ult"]]
	if ab["target"] == "self":
		var h = game.get_hero(cmd.team, hid)
		cmd.use_ult(hid, h.position)
		_cancel()
	else:
		selected_ult = hid
		selected = -1


func _cast_ult(m: Vector2) -> void:
	cmd.use_ult(selected_ult, m)
	selected_ult = ""


func _try_behavior(b: String) -> void:
	if b == cmd.behavior:
		return
	if not cmd.set_behavior(b):
		_flash("cd")


# ---------------------------------------------------------------------------
# Desenho
func _draw() -> void:
	game.draw_overlay(self)
	_draw_targeting()
	_draw_top()
	_draw_panel()
	if msg_t > 0.0:
		UI.text_c(self, Vector2(640, 548), msg, 18, Color(1, 0.5, 0.4, clampf(msg_t, 0.0, 1.0)), 4)
	if dragging and selected >= 0 and cmd.hand[selected] != "":
		var m := get_global_mouse_position()
		if not game.in_arena(m):
			_draw_card(Rect2(m - Vector2(60, 59), Vector2(120, 118)), cmd.hand[selected], true, 0.8)
	if game.paused and not game.ended:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.55))
		UI.text_c(self, Vector2(640, 330), "PAUSADO", 44, Data.GOLD, 6)
		UI.text_c(self, Vector2(640, 370), "Pressione P para continuar", 18, Color.WHITE, 3)
	if game.ended:
		_draw_end()


func _caster():
	if selected >= 0 and cmd.hand[selected] != "":
		return cmd.card_hero(cmd.hand[selected])
	if selected_ult != "":
		return game.get_hero(cmd.team, selected_ult)
	return null


func _draw_targeting() -> void:
	var h = _caster()
	if h == null or not h.alive:
		return
	var ab_id: String = cmd.hand[selected] if selected >= 0 else Data.HEROES[selected_ult]["ult"]
	var ab: Dictionary = Data.ABILITIES[ab_id]
	var m := get_global_mouse_position()
	var tc: Color = Data.TEAM_COLORS[cmd.team]
	UI.ring(self, h.position, h.radius + 12.0, Color(Data.GOLD, 0.9), 3.0)
	if not game.in_arena(m):
		return
	var target := m
	if ab["range"] > 0.0:
		UI.ring(self, h.position, ab["range"], Color(tc, 0.35), 2.0)
		var v: Vector2 = m - h.position
		if v.length() > ab["range"]:
			target = h.position + v.normalized() * ab["range"]
	match ab_id:
		"muralha", "disparo", "veneno", "investida":
			var dir: Vector2 = (m - h.position).normalized()
			var length := 260.0 if ab_id == "investida" else 420.0
			if ab_id == "muralha":
				length = 70.0
			draw_line(h.position, h.position + dir * length, Color(Data.GOLD, 0.7), 4.0, true)
			draw_circle(h.position + dir * length, 6.0, Color(Data.GOLD, 0.9))
		"engrenagem":
			var best = null
			var bd := INF
			for a in game.alive_heroes(cmd.team):
				var d: float = a.position.distance_to(m)
				if d < bd:
					bd = d
					best = a
			if best != null:
				UI.ring(self, best.position, best.radius + 10.0, Color(0.6, 1.0, 0.8, 0.9), 3.0)
		_:
			pass
	if ab["radius"] > 0.0 and ab["target"] == "point":
		draw_circle(target, ab["radius"], Color(tc, 0.18))
		UI.ring(self, target, ab["radius"], Color(Data.GOLD, 0.8), 2.0)
	UI.text_c(self, m + Vector2(0, -22), ab["name"], 13, Color.WHITE, 3)


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
		var hc: Color = h.def["color"]
		UI.text_c(self, Vector2(c.x, 582), h.def["name"], 13, Color.WHITE)
		UI.text_c(self, Vector2(c.x, 596), h.def["role"], 10, Color(1, 1, 1, 0.55))
		var hb := Rect2(c.x - 40, 602, 80, 6)
		draw_rect(hb, Color(0, 0, 0, 0.7))
		draw_rect(Rect2(hb.position, Vector2(hb.size.x * (h.hp / h.max_hp if h.alive else 0.0), hb.size.y)), Data.TEAM_COLORS[cmd.team])
		draw_circle(c, 30.0, Color(0.05, 0.04, 0.03))
		draw_circle(c, 25.0, Color(hc, 0.25))
		var ready: bool = h.ult >= 100.0 and h.alive
		draw_arc(c, 28.0, -PI * 0.5, -PI * 0.5 + TAU * h.ult / 100.0, 40, Data.GOLD if ready else Color(Data.GOLD, 0.6), 4.0, true)
		if ready:
			var pulse := 0.5 + 0.5 * sin(game.time * 6.0)
			draw_circle(c, 25.0, Color(Data.GOLD, 0.25 + 0.3 * pulse))
		UI.text_c(self, c + Vector2(0, 5), h.ability_ready_text() if h.alive else "—", 12 if ready else 13, Color.WHITE, 3)
		UI.text_c(self, c + Vector2(0, -12), Data.ULT_KEYS[i], 10, Color(1, 1, 1, 0.6))
		var ult_name: String = Data.ABILITIES[h.def["ult"]]["name"]
		UI.text_c(self, Vector2(c.x, 712), ult_name, 10, Color(Data.GOLD, 0.8))
		if not h.alive:
			draw_circle(c, 30.0, Color(0, 0, 0, 0.6))
			UI.text_c(self, c + Vector2(0, 5), "%d s" % int(ceil(h.respawn_t)), 15, Color(1, 0.5, 0.4), 3)

	# Cartas
	for i in 4:
		var card: String = cmd.hand[i]
		var r := card_rect(i)
		if card == "":
			draw_rect(base_card_rect(i), Color(1, 1, 1, 0.04))
			draw_rect(base_card_rect(i), Color(1, 1, 1, 0.15), false, 1.0)
			UI.text_c(self, base_card_rect(i).get_center() + Vector2(0, 5), "—", 14, Color(1, 1, 1, 0.3))
			continue
		_draw_card(r, card, i == selected, 1.0)
		UI.text_r(self, r.end + Vector2(-5, -5), str(i + 1), 10, Color(1, 1, 1, 0.5))
		var reason: String = cmd.can_play(i)
		if reason == "icor":
			var cost: float = Data.ABILITIES[card]["cost"]
			var f := clampf(cmd.ichor / cost, 0.0, 1.0)
			draw_rect(Rect2(r.position, Vector2(r.size.x, r.size.y * (1.0 - f))), Color(0, 0, 0, 0.6))
		elif reason == "atordoado":
			draw_rect(r, Color(0, 0, 0, 0.6))
			UI.text_c(self, r.get_center(), "ATORDOADO", 11, Color(1, 0.9, 0.3), 3)

	# Próxima carta
	UI.text_c(self, Vector2(NEXT_RECT.get_center().x, 596), "Próxima", 10, Color(1, 1, 1, 0.6))
	var nxt: String = cmd.next_card()
	if nxt != "":
		var ab: Dictionary = Data.ABILITIES[nxt]
		var hc2: Color = Data.HEROES[ab["hero"]]["color"]
		UI.panel(self, NEXT_RECT, hc2.darkened(0.7), Color(hc2, 0.6), 1.5)
		_gem(NEXT_RECT.position + Vector2(NEXT_RECT.size.x * 0.5, 14), ab["cost"], 9.0)
		UI.text_box(self, Rect2(NEXT_RECT.position.x + 4, NEXT_RECT.position.y + 28, NEXT_RECT.size.x - 8, 58), ab["name"], 11, Color.WHITE)
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
	UI.text_c(self, Vector2(1128, 702), "P pausa · botão direito cancela", 10, Color(1, 1, 1, 0.4))


func _gem(c: Vector2, cost: int, r: float) -> void:
	var pts := PackedVector2Array([c + Vector2(0, -r), c + Vector2(r, 0), c + Vector2(0, r), c + Vector2(-r, 0)])
	draw_colored_polygon(pts, Data.GOLD)
	UI.text_c(self, c + Vector2(0, r * 0.45), str(cost), int(r * 1.3), Color(0.15, 0.08, 0.02))


func _draw_card(r: Rect2, card: String, sel: bool, alpha: float) -> void:
	var ab: Dictionary = Data.ABILITIES[card]
	var hd: Dictionary = Data.HEROES[ab["hero"]]
	var hc: Color = hd["color"]
	draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.4 * alpha))
	UI.panel(self, r, Color(hc.darkened(0.72), alpha), Color(Data.GOLD, alpha) if sel else Color(hc, 0.7 * alpha), 3.0 if sel else 2.0)
	draw_rect(Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, 26)), Color(hc, 0.25 * alpha))
	UI.text_c(self, Vector2(r.get_center().x + 8, r.position.y + 15), hd["name"].to_upper(), 9, Color(hc.lightened(0.3), alpha))
	UI.text_box(self, Rect2(r.position.x + 6, r.position.y + 28, r.size.x - 12, 34), ab["name"], 12, Color(1, 1, 1, alpha))
	UI.text_box(self, Rect2(r.position.x + 6, r.position.y + 62, r.size.x - 12, 54), ab["desc"], 9, Color(1, 1, 1, 0.75 * alpha))
	_gem(r.position + Vector2(13, 14), ab["cost"], 11.0)


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
