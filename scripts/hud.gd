extends Node2D
## Interface do jogador: cartas, Ícor, ultimates, comportamento e placar.
## Clicar numa carta basta: o herói usa a habilidade sozinho no melhor momento.

const Data = preload("res://scripts/data.gd")
const UI = preload("res://scripts/ui.gd")
const T = preload("res://scripts/i18n.gd")
const Art = preload("res://scripts/art.gd")
const AudioScript = preload("res://scripts/audio.gd")

const PANEL := Rect2(0, 560, 1280, 160)
const ICHOR_BAR := Rect2(350, 700, 504, 14)
const NEXT_RECT := Rect2(872, 604, 78, 90)
## Roda do Destino: entre as ultimates e as cartas, ao lado do medidor de Ícor.
const WHEEL_C := Vector2(302, 664)
const WHEEL_R := 17.0
const WHEEL_NODE_R := 7.0

var game
var cmd
var msg := ""
var msg_t := 0.0
var hover := -1
var pressed := -1
var press_t := 0.0
## Dica do mouse fora das cartas: {"kind": "ult"|"next"|"beh", "i": índice}.
var tip := {}
## Só para capturas de tela (main.gd --shot-tip): dica sempre aberta.
var force_tip := {}
## Menu de pausa: "main", "help" ou "confirm" (sair para o menu).
var pause_view := "main"
## Pausa causada pela janela/aba perder o foco.
var auto_paused := false


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


## Largura máxima do nome da ultimate embaixo do medidor (passo de 94 px).
const ULT_LABEL_W := 92.0


## Maior tamanho de fonte (de `big` até `small`) em que o texto cabe em `w`.
static func fit_size(s: String, w: float, big: int, small: int) -> int:
	var size := big
	while size > small and UI.font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > w:
		size -= 1
	return size


func ult_center(i: int) -> Vector2:
	return Vector2(50 + i * 94, 668)


## Centro de cada engrenagem na roda: Movimento em cima e o resto em sentido horário.
static func wheel_node(g: int) -> Vector2:
	var a := -PI * 0.5 + g * TAU / Data.GEARS.size()
	return WHEEL_C + Vector2(cos(a), sin(a)) * WHEEL_R


static func wheel_rect() -> Rect2:
	var e := WHEEL_R + WHEEL_NODE_R + 3.0
	return Rect2(WHEEL_C - Vector2(e, e), Vector2(e, e) * 2.0)


func beh_rect(i: int) -> Rect2:
	return Rect2(984 + i * 96, 614, 90, 40)


func end_button(i: int) -> Rect2:
	return Rect2(470 + i * 180, 560, 160, 44)


# --- Menu de pausa ----------------------------------------------------------
const PAUSE_PANEL := Rect2(430, 120, 420, 470)
const PAUSE_BUTTONS := ["continue", "help", "quit"]


func pause_button(id: String) -> Rect2:
	match id:
		"continue": return Rect2(490, 210, 300, 44)
		"help": return Rect2(490, 266, 300, 44)
		"quit": return Rect2(490, 470, 300, 44)
	return Rect2()


## Som: diminuir, aumentar, mudo. Idioma: botão PT/EN.
func pause_sound_rect(i: int) -> Rect2:
	return [Rect2(560, 342, 30, 30), Rect2(720, 342, 30, 30), Rect2(560, 380, 190, 30)][i]


func pause_lang_rect() -> Rect2:
	return Rect2(560, 424, 110, 32)


func confirm_button(i: int) -> Rect2:
	return Rect2(470 + i * 180, 380, 160, 44)


func next_rect() -> Rect2:
	return NEXT_RECT


func ult_rect(i: int) -> Rect2:
	return Rect2(ult_center(i) - Vector2(30, 30), Vector2(60, 60))


func _player_controls() -> bool:
	return game.bots[game.player_team] == null


# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	msg_t -= delta
	press_t -= delta
	var m := get_global_mouse_position()
	update_hover(m)
	queue_redraw()


## Carta, ultimate, próxima carta ou comportamento sob o mouse.
func update_hover(m: Vector2) -> void:
	hover = -1
	tip = force_tip.duplicate()
	if not force_tip.is_empty():
		return
	if game.ended or game.paused:
		return
	for i in 4:
		if base_card_rect(i).has_point(m) and cmd.hand[i] != "":
			hover = i
			return
	for j in 3:
		if m.distance_to(ult_center(j)) <= 30.0:
			tip = {"kind": "ult", "i": j}
			return
	if NEXT_RECT.has_point(m) and cmd.next_card() != "":
		tip = {"kind": "next", "i": 0}
		return
	if game.wheel_on and wheel_rect().has_point(m):
		tip = {"kind": "wheel", "i": 0}
		return
	for k in 3:
		if beh_rect(k).has_point(m):
			tip = {"kind": "beh", "i": k}
			return


func set_paused(on: bool, auto := false) -> void:
	if game.ended:
		return
	game.paused = on
	auto_paused = on and auto
	pause_view = "main"
	if AudioScript.instance != null:
		AudioScript.instance.pause_music(on)


func _notification(what: int) -> void:
	# Pausa sozinho quando a janela (ou a aba, na versão web) perde o foco.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		if game != null and not game.ended and not game.paused and _player_controls():
			set_paused(true, true)


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
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_P or event.keycode == KEY_ESCAPE):
		if not game.paused:
			set_paused(true)
		elif pause_view != "main":
			pause_view = "main"
		else:
			set_paused(false)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_M:
		if AudioScript.instance != null:
			AudioScript.instance.toggle_mute()
		return
	if game.paused:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			pause_click(m)
		return
	if not _player_controls():
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in 4:
			if base_card_rect(i).has_point(m):
				_play(i)
				return
		for j in 3:
			if m.distance_to(ult_center(j)) <= 30.0:
				_ult(game.teams[cmd.team][j])
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
			KEY_Q: _ult(game.teams[cmd.team][0])
			KEY_W: _ult(game.teams[cmd.team][1])
			KEY_E: _ult(game.teams[cmd.team][2])
			KEY_Z: _behavior(Data.BEHAVIORS[0])
			KEY_X: _behavior(Data.BEHAVIORS[1])
			KEY_C: _behavior(Data.BEHAVIORS[2])


## Clique no menu de pausa (separado de _input para os testes).
func pause_click(m: Vector2) -> void:
	var a = AudioScript.instance
	match pause_view:
		"help":
			pause_view = "main"
		"confirm":
			if confirm_button(0).has_point(m):
				set_paused(false)
				game.request.emit("menu")
			elif confirm_button(1).has_point(m):
				pause_view = "main"
		_:
			if pause_button("continue").has_point(m):
				set_paused(false)
			elif pause_button("help").has_point(m):
				pause_view = "help"
			elif pause_button("quit").has_point(m):
				pause_view = "confirm"
			elif a != null and pause_sound_rect(0).has_point(m):
				a.set_volume(snappedf(a.volume - 0.1, 0.1))
			elif a != null and pause_sound_rect(1).has_point(m):
				a.set_volume(snappedf(a.volume + 0.1, 0.1))
			elif a != null and pause_sound_rect(2).has_point(m):
				a.toggle_mute()
			else:
				var l := UI.lang_at(pause_lang_rect(), m)
				if l != "":
					T.set_lang(l)
				return
	if a != null:
		a.play("click")


func _flash(reason: String) -> void:
	msg = T.t("FLASH_" + reason.to_upper())
	msg_t = 1.4
	game.sfx("no_ichor" if reason == "icor" else "click")


func _play(i: int) -> void:
	var reason: String = cmd.can_play(i)
	if reason != "":
		_flash(reason)
		return
	pressed = i
	press_t = 0.12
	cmd.play(i)
	game.sfx("card")


func _ult(hid: String) -> void:
	var reason: String = cmd.can_ult(hid)
	if reason != "":
		_flash(reason)
		return
	cmd.use_ult(hid)
	game.sfx("card")


func _behavior(b: String) -> void:
	if b == cmd.behavior:
		return
	if not cmd.set_behavior(b):
		_flash("cd")
	else:
		game.sfx("click")


# ---------------------------------------------------------------------------
# Desenho
func _draw() -> void:
	game.draw_overlay(self)
	_draw_top()
	_draw_panel()
	if hover >= 0:
		_draw_tooltip(hover)
	elif not tip.is_empty():
		match tip["kind"]:
			"ult": _draw_ult_tip(tip["i"])
			"next": _draw_next_tip()
			"beh": _draw_beh_tip(tip["i"])
			"wheel": _draw_wheel_tip()
	if msg_t > 0.0:
		UI.text_c(self, Vector2(640, 548), msg, 18, Color(1, 0.5, 0.4, clampf(msg_t, 0.0, 1.0)), 4)
	if game.paused and not game.ended:
		_draw_pause()
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
		var label := "%s  %d%%" % [T.t("HUD_YOU") if t == game.player_team else T.t("HUD_BOT"), int(game.progress[t])]
		if t == 0:
			UI.text_l(self, Vector2(24, 25), label, 12, Color.WHITE, 3)
		else:
			UI.text_r(self, Vector2(1256, 25), label, 12, Color.WHITE, 3)
	var tl: float = game.time_left()
	var clock := "%d:%02d" % [int(tl) / 60, int(tl) % 60]
	if game.overtime:
		clock = T.t("HUD_OVERTIME")
	UI.text_c(self, Vector2(640, 20), clock, 18, Data.GOLD, 3)
	var status := ""
	if not game.point_unlocked():
		status = T.tf("HUD_POINT_UNLOCK", [int(ceil(Data.UNLOCK_TIME - game.time))])
	elif game.contested:
		status = T.t("HUD_POINT_CONTESTED")
	elif game.point_owner >= 0:
		status = T.tf("HUD_POINT_OWNER", [T.team_name(game.point_owner)])
	else:
		status = T.t("HUD_POINT_NEUTRAL")
	UI.text_c(self, Vector2(640, 35), status, 11, Color(1, 1, 1, 0.75))
	if AudioScript.instance != null and AudioScript.instance.muted:
		UI.text_r(self, Vector2(760, 35), T.t("HUD_MUTED"), 10, Color(1, 0.6, 0.5, 0.9))


func _draw_panel() -> void:
	draw_rect(PANEL, Color(0.1, 0.08, 0.06))
	draw_line(PANEL.position, Vector2(PANEL.end.x, PANEL.position.y), Data.BRONZE, 3.0)
	draw_line(Vector2(330, 568), Vector2(330, 712), Color(Data.BRONZE, 0.3), 1.0)
	draw_line(Vector2(966, 568), Vector2(966, 712), Color(Data.BRONZE, 0.3), 1.0)

	# Heróis e ultimates
	for i in 3:
		var hid: String = game.teams[cmd.team][i]
		var h = game.get_hero(cmd.team, hid)
		var c := ult_center(i)
		var rc: Color = h.role_color()
		UI.hero_glyph(self, hid, Vector2(c.x - 34, 578), 5.0, rc)
		UI.text_c(self, Vector2(c.x + 4, 583), T.hero_name(hid), 13, Color.WHITE)
		UI.text_c(self, Vector2(c.x, 597), T.role_name(h.def["role"]), 10, rc)
		var hb := Rect2(c.x - 40, 602, 80, 6)
		draw_rect(hb, Color(0, 0, 0, 0.7))
		draw_rect(Rect2(hb.position, Vector2(hb.size.x * (h.hp / h.max_hp if h.alive else 0.0), hb.size.y)), Data.TEAM_COLORS[cmd.team])
		# Habilidades armadas deste herói
		var n: int = h.armed.size()
		for k in n:
			var ab: Dictionary = Data.ABILITIES[h.armed[k]["ab"]]
			UI.badge(self, Vector2(c.x + 30 - k * 16, 624), 6.5, ab, rc, 0.95, h.armed[k]["ult"])
		var portrait := Art.hero_portrait(hid)
		draw_circle(c, 30.0, Color(0.05, 0.04, 0.03))
		if portrait != null:
			Art.draw_circle_tex(self, portrait, c, 25.0)
		else:
			draw_circle(c, 25.0, Color(rc, 0.22))
		var ready: bool = h.ult >= 100.0 and h.alive
		draw_arc(c, 28.0, -PI * 0.5, -PI * 0.5 + TAU * h.ult / 100.0, 40, Data.GOLD if ready else Color(Data.GOLD, 0.6), 4.0, true)
		if ready:
			var pulse := 0.5 + 0.5 * sin(game.time * 6.0)
			draw_circle(c, 25.0, Color(Data.GOLD, 0.25 + 0.3 * pulse))
		var ult_ab: Dictionary = Data.ABILITIES[h.def["ult"]]
		if portrait != null:
			# Com retrato: a ultimate vira um selo no canto inferior direito do medidor
			# e a porcentagem fica sobre a base do retrato.
			UI.badge(self, c + Vector2(21, 21), 9.0, ult_ab, rc, 1.0 if ready else 0.75, ready)
			UI.text_c(self, c + Vector2(0, 21), h.ability_ready_text() if h.alive else "—", 11, Color.WHITE, 3)
		else:
			UI.ability_icon(self, ult_ab, c + Vector2(0, -4), 9.0, Color(1, 1, 1, 0.35 if not ready else 0.9))
			UI.text_c(self, c + Vector2(0, 17), h.ability_ready_text() if h.alive else "—", 10 if ready else 11, Color.WHITE, 3)
		UI.text_c(self, c + Vector2(-20, -18), Data.ULT_KEYS[i], 10, Color(1, 1, 1, 0.6), 2)
		var uname := T.ab_name(h.def["ult"])
		UI.text_c(self, Vector2(c.x, 712), uname, fit_size(uname, ULT_LABEL_W, 10, 7), Color(Data.GOLD, 0.8))
		if not h.alive:
			draw_circle(c, 30.0, Color(0, 0, 0, 0.65))
			UI.text_c(self, c + Vector2(0, 5), T.tf("HUD_RESPAWN", [int(ceil(h.respawn_t))]), 15, Color(1, 0.5, 0.4), 3)

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
		# Selo depois do escurecimento: a carta que engrena aparece mesmo sem Ícor.
		if continues_chain(card):
			_draw_gear_seal(r)

	# Roda do Destino
	if game.wheel_on:
		_draw_wheel()

	# Próxima carta
	UI.text_c(self, Vector2(NEXT_RECT.get_center().x, 596), T.t("HUD_NEXT"), 10, Color(1, 1, 1, 0.6))
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
	UI.text_l(self, Vector2(bar.end.x + 8, bar.end.y), T.tf("HUD_ICHOR", [full]), 13, Data.GOLD, 3)

	# Comportamento
	UI.text_c(self, Vector2(1128, 594), T.t("HUD_BEHAVIOR"), 13, Color.WHITE)
	for k in 3:
		var b: String = Data.BEHAVIORS[k]
		var r2 := beh_rect(k)
		var active: bool = cmd.behavior == b
		UI.panel(self, r2, Color(Data.BRONZE, 0.45) if active else Color(0, 0, 0, 0.4), Data.GOLD if active else Color(Data.BRONZE, 0.5), 2.0 if active else 1.0)
		UI.text_c(self, r2.get_center() + Vector2(0, 2), T.behavior_name(b), 12, Color.WHITE)
		UI.text_c(self, r2.get_center() + Vector2(0, 15), Data.BEHAVIOR_KEYS[k], 9, Color(1, 1, 1, 0.5))
	if cmd.behavior_cd > 0.0:
		UI.text_c(self, Vector2(1128, 676), T.tf("HUD_BEH_CD", [int(ceil(cmd.behavior_cd))]), 11, Color(1, 1, 1, 0.6))
	UI.text_c(self, Vector2(1128, 702), T.t("HUD_FOOTER"), 10, Color(1, 1, 1, 0.4))


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
	var frame := Art.card_frame(hd["role"])
	draw_rect(Rect2(r.position + Vector2(3, 4), r.size), Color(0, 0, 0, 0.4))
	var head := Rect2(r.position, Vector2(r.size.x, 24))
	if frame != null:
		# Moldura em imagem (240×236) no lugar do fundo, da faixa e da borda.
		Art.draw_centered(self, frame, r.get_center(), r.size)
	else:
		draw_rect(r, rc.darkened(0.78))
		# Faixa superior com o herói
		draw_rect(head, rc.darkened(0.15))
	UI.hero_glyph(self, ab["hero"], head.position + Vector2(r.size.x - 14, 12), 5.5, Color(0.1, 0.06, 0.03))
	UI.text_c(self, Vector2(r.get_center().x + 4, head.position.y + 16), T.hero_name(ab["hero"]).to_upper(), 10, Color(0.1, 0.06, 0.03))
	# Ícone do efeito
	var ic := Vector2(r.get_center().x, r.position.y + 54)
	if frame == null:
		draw_circle(ic, 20.0, rc.darkened(0.45))
		UI.ring(self, ic, 20.0, Color(rc, 0.9), 2.0)
	# Com moldura, o círculo e o anel do ícone já vêm na imagem.
	UI.ability_icon(self, ab, ic, 12.0, Color.WHITE)
	# Nome e resumo
	# Nome numa linha só (fonte diminui até 9); só quebra se ainda não couber.
	var nm := T.ab_name(card)
	var nw := r.size.x - 8
	var ns := fit_size(nm, nw, 11, 9)
	if UI.font().get_string_size(nm, HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x <= nw:
		UI.text_c(self, Vector2(r.get_center().x, r.position.y + 90), nm, ns, Color.WHITE)
	else:
		UI.text_box(self, Rect2(r.position.x + 4, r.position.y + 76, nw, 30), nm, 9, Color.WHITE)
	UI.text_c(self, Vector2(r.get_center().x, r.end.y - 6), T.ab_short(card), 9, Color(rc.lightened(0.35), 0.95))
	if frame == null or hov:
		draw_rect(r, Data.GOLD if hov else Color(rc, 0.9), false, 3.0 if hov else 2.0)
	_gem(r.position + Vector2(13, 13), ab["cost"], 11.0)


func _draw_card_mini(r: Rect2, card: String) -> void:
	var ab: Dictionary = Data.ABILITIES[card]
	var rc: Color = Data.ROLE_COLORS[Data.HEROES[ab["hero"]]["role"]]
	draw_rect(r, rc.darkened(0.78))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 8)), rc.darkened(0.15))
	var ic := Vector2(r.get_center().x, r.position.y + 36)
	draw_circle(ic, 15.0, rc.darkened(0.45))
	UI.ability_icon(self, ab, ic, 9.0, Color.WHITE)
	UI.text_box(self, Rect2(r.position.x + 3, r.position.y + 54, r.size.x - 6, 34), T.ab_name(card), 9, Color(1, 1, 1, 0.85))
	draw_rect(r, Color(rc, 0.7), false, 1.5)
	_gem(r.position + Vector2(10, 12), ab["cost"], 8.0)


## Caixa de dica acima de `anchor`: título, subtítulo e linhas de texto.
## `lines` aceita String ou [String, Color]. Usada por cartas, ultimates,
## próxima carta e comportamentos.
func _draw_tip(anchor: Rect2, col: Color, title: String, sub: String, lines: Array, width := 260.0) -> Rect2:
	var f := UI.font()
	var inner := width - 20.0
	var r := tip_rect(anchor, sub, lines, width)
	UI.panel(self, r, Color(0.08, 0.06, 0.05, 0.96), col, 2.0)
	UI.text_l(self, r.position + Vector2(10, 20), title, 14, Color.WHITE)
	UI.text_l(self, r.position + Vector2(10, 37), sub, 11, col.lightened(0.3))
	var y := r.position.y + (46.0 if sub != "" else 30.0)
	for l in lines:
		var s2: String = l if l is String else l[0]
		var c: Color = Color(1, 1, 1, 0.85) if l is String else l[1]
		draw_multiline_string(f, Vector2(r.position.x + 10, y + 11), s2, HORIZONTAL_ALIGNMENT_LEFT, inner, 11, -1, c)
		y += f.get_multiline_string_size(s2, HORIZONTAL_ALIGNMENT_LEFT, inner, 11).y + 3.0
	return r


# ---------------------------------------------------------------------------
# Roda do Destino
## A carta da mão continuaria a Cadência (selo de engrenagem dourada).
func continues_chain(card: String) -> bool:
	if card == "" or not game.wheel_on:
		return false
	var want: int = game.wheel_next_gear(cmd.team)
	return want >= 0 and Data.gear_of(card) == want


## Linhas da dica da roda (7 linhas: título e 6), com os números de data.gd.
static func wheel_tip_lines() -> Array:
	return [
		T.tf("WHEEL_TIP_MOVE_CTRL", [int(round(Data.GEAR_CTRL_BONUS * 100.0))]),
		T.tf("WHEEL_TIP_CTRL_ATK", [int(round(Data.GEAR_DMG_BONUS * 100.0))]),
		T.tf("WHEEL_TIP_ATK_DEF", [int(round(Data.GEAR_DEF_BONUS * 100.0))]),
		T.tf("WHEEL_TIP_DEF_MOVE", [int(Data.GEAR_MOVE_SHIELD)]),
		T.tf("WHEEL_TIP_WINDOW", [T.num(Data.GEAR_WINDOW, 0), Data.CADENCE_FROM, int(Data.CADENCE_REFUND)]),
		T.tf("WHEEL_TIP_FULL", [int(Data.FULL_TURN_ULT)]),
	]


func _draw_wheel_tip() -> void:
	_draw_tip(wheel_rect(), Data.GOLD, T.t("WHEEL_TIP_TITLE"), "", wheel_tip_lines(), 260.0)


func _draw_wheel() -> void:
	var w = game.wheels[cmd.team]
	var n: int = Data.GEARS.size()
	draw_circle(WHEEL_C, WHEEL_R + WHEEL_NODE_R + 2.0, Color(0, 0, 0, 0.35))
	# Elos: arcos entre engrenagens vizinhas; os da Cadência atual ficam acesos.
	for g in n:
		var a0 := -PI * 0.5 + g * TAU / n + 0.42
		var a1 := -PI * 0.5 + (g + 1) * TAU / n - 0.42
		var lit := false
		if w.gear >= 0 and w.links > 0:
			# elo que chega na engrenagem k: (k-1 → k); acesos os `links` últimos até a engatada
			for j in mini(w.links, n):
				if (w.gear - j - 1 + n * 4) % n == g:
					lit = true
		draw_arc(WHEEL_C, WHEEL_R, a0, a1, 10, Data.GOLD if lit else Color(Data.BRONZE, 0.45), 3.0 if lit else 1.5, true)
	var nxt: int = game.wheel_next_gear(cmd.team)
	for g in n:
		var c := wheel_node(g)
		var on: bool = w.gear == g
		var col := Data.GOLD if on else Color(Data.BRONZE, 0.85)
		if on:
			var pulse := 0.5 + 0.5 * sin(game.time * 8.0)
			draw_circle(c, WHEEL_NODE_R + 4.0, Color(Data.GOLD, 0.25 + 0.2 * pulse))
		UI.gear(self, c, WHEEL_NODE_R, 8, Color(0.12, 0.09, 0.06) if not on else Color(0.35, 0.25, 0.08), game.time * (1.5 if on else 0.0))
		UI.ring(self, c, WHEEL_NODE_R - 1.0, col, 1.5)
		UI.effect_icon(self, Data.GEAR_ICON[g], c, 3.6, Color(1, 1, 1, 0.95 if on else 0.6))
		if on:
			# Tempo que ainda resta engatada
			draw_arc(c, WHEEL_NODE_R + 2.5, -PI * 0.5, -PI * 0.5 + TAU * clampf(w.t / Data.GEAR_WINDOW, 0.0, 1.0), 24, Color(1.0, 0.95, 0.7), 2.0, true)
		elif g == nxt:
			UI.ring(self, c, WHEEL_NODE_R + 2.5, Color(Data.GOLD, 0.35 + 0.25 * sin(game.time * 5.0)), 1.0)


## Selo de engrenagem dourada no canto da carta que continuaria a Cadência.
func _draw_gear_seal(r: Rect2) -> void:
	var pulse := 0.5 + 0.5 * sin(game.time * 5.0)
	draw_rect(r.grow(1.0), Color(Data.GOLD, 0.35 + 0.35 * pulse), false, 2.0)
	var c := r.position + Vector2(r.size.x - 16.0, 40.0)
	draw_circle(c, 11.0, Color(0, 0, 0, 0.6))
	UI.gear(self, c, 10.0, 8, Data.GOLD, game.time * 1.2)
	draw_circle(c, 4.0, Color(0.3, 0.2, 0.05))


## Retângulo da caixa de dica (o mesmo que _draw_tip desenha).
static func tip_rect(anchor: Rect2, sub: String, lines: Array, width := 260.0) -> Rect2:
	var f := UI.font()
	var inner := width - 20.0
	var h := 50.0 if sub != "" else 34.0
	for l in lines:
		var s: String = l if l is String else l[0]
		h += f.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, inner, 11).y + 3.0
	var x := clampf(anchor.get_center().x - width * 0.5, 6.0, 1274.0 - width)
	return Rect2(x, anchor.position.y - h - 10.0, width, h)


func _card_sub(card: String) -> String:
	var ab: Dictionary = Data.ABILITIES[card]
	var hd: Dictionary = Data.HEROES[ab["hero"]]
	return "%s · %s · %s" % [T.hero_name(ab["hero"]), T.role_name(hd["role"]), T.effect_name(ab["effect"])]


func _draw_tooltip(i: int) -> void:
	var card: String = cmd.hand[i]
	if card == "":
		return
	var ab: Dictionary = Data.ABILITIES[card]
	var rc: Color = Data.ROLE_COLORS[Data.HEROES[ab["hero"]]["role"]]
	_draw_tip(base_card_rect(i), rc, T.ab_name(card), _card_sub(card),
		[T.ab_desc(card), [T.tf("TIP_CARD_KEY", [i + 1, ab["cost"]]), Color(Data.GOLD, 0.9)]], 240.0)


func _draw_next_tip() -> void:
	var card: String = cmd.next_card()
	if card == "":
		return
	var ab: Dictionary = Data.ABILITIES[card]
	var rc: Color = Data.ROLE_COLORS[Data.HEROES[ab["hero"]]["role"]]
	_draw_tip(NEXT_RECT, rc, T.ab_name(card), _card_sub(card),
		[T.ab_desc(card), [T.t("TIP_NEXT"), Color(1, 1, 1, 0.6)]], 250.0)


func _draw_ult_tip(i: int) -> void:
	var hid: String = game.teams[cmd.team][i]
	var h = game.get_hero(cmd.team, hid)
	var ult: String = h.def["ult"]
	var ab: Dictionary = Data.ABILITIES[ult]
	var rc: Color = Data.ROLE_COLORS[h.def["role"]]
	var state: Array
	if not h.alive:
		state = [T.tf("TIP_ULT_DEAD", [int(ceil(h.respawn_t))]), Color(1, 0.55, 0.45)]
	elif h.ult >= 100.0:
		state = [T.t("TIP_ULT_READY"), Data.GOLD]
	else:
		state = [T.tf("TIP_ULT_CHARGE", [int(h.ult)]), Color(Data.GOLD, 0.85)]
	_draw_tip(ult_rect(i), Data.GOLD, T.ab_name(ult),
		"%s · %s" % [T.tf("TIP_ULT_OF", [T.hero_name(hid)]), T.effect_name(ab["effect"])],
		[T.ab_desc(ult), state, [T.tf("TIP_ULT_KEY", [Data.ULT_KEYS[i]]), Color(1, 1, 1, 0.7)], [T.t("TIP_ULT_HOW"), Color(1, 1, 1, 0.6)]], 270.0)


## Linhas da dica de um comportamento, com os números reais da IA (em metros).
static func behavior_lines(b: String) -> Array:
	var p: Dictionary = Data.BEHAVIOR_PARAMS[b]
	var lines: Array = []
	lines.append(T.t("TIP_BEH_FRONT_CENTER") if p["front"] <= 0.0 else T.tf("TIP_BEH_FRONT", [T.meters(p["front"])]))
	lines.append(T.tf("TIP_BEH_WAIT", [T.meters(Data.WAIT_GROUP_DIST)]) if p["wait_group"] else T.t("TIP_BEH_NO_WAIT"))
	lines.append(T.tf("TIP_BEH_DPS", [T.meters(p["dps_back"])]))
	if p["leash"] < 0.0:
		lines.append(T.tf("TIP_BEH_CHASE_FREE", [T.meters(p["aggro"])]))
	else:
		lines.append(T.tf("TIP_BEH_CHASE", [T.meters(p["aggro"]), T.meters(p["leash"] + Data.POINT_R)]))
	lines.append(T.tf("TIP_BEH_RETREAT", [int(round(p["retreat"] * 100.0)), int(round(Data.RETREAT_BACK * 100.0))]))
	return lines


func _draw_beh_tip(k: int) -> void:
	var b: String = Data.BEHAVIORS[k]
	var lines := behavior_lines(b)
	lines.append([T.tf("TIP_BEH_KEY", [Data.BEHAVIOR_KEYS[k], int(Data.BEHAVIOR_CD)]), Color(1, 1, 1, 0.6)])
	_draw_tip(beh_rect(k), Data.GOLD, T.behavior_name(b), T.t("BEH_%s_DESC" % b.to_upper()), lines, 300.0)


func _draw_pause() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.6))
	if pause_view == "help":
		UI.draw_help(self)
		return
	var m := get_global_mouse_position()
	UI.panel(self, PAUSE_PANEL, Color(0.1, 0.08, 0.06, 0.97), Data.BRONZE, 3.0)
	UI.text_c(self, Vector2(640, 172), T.t("PAUSE_TITLE"), 36, Data.GOLD, 5)
	if auto_paused:
		UI.text_c(self, Vector2(640, 196), T.t("PAUSE_AUTO"), 12, Color(1, 1, 1, 0.6))
	var confirm := pause_view == "confirm"
	UI.button(self, pause_button("continue"), T.t("PAUSE_CONTINUE"), not confirm and pause_button("continue").has_point(m), true, 16)
	UI.button(self, pause_button("help"), T.t("PAUSE_HELP"), not confirm and pause_button("help").has_point(m))
	# Som
	var a = AudioScript.instance
	UI.text_l(self, Vector2(490, 363), T.t("PAUSE_SOUND"), 14, Color(1, 1, 1, 0.8))
	for i in 3:
		var label: String = ["-", "+", T.t("MUTE_ON") if a != null and a.muted else T.t("MUTE_OFF")][i]
		UI.button(self, pause_sound_rect(i), label, not confirm and pause_sound_rect(i).has_point(m), i == 2 and a != null and a.muted, 13)
	var bar := Rect2(596, 352, 118, 10)
	draw_rect(bar, Color(0, 0, 0, 0.6))
	if a != null:
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * a.volume, bar.size.y)), Data.GOLD if not a.muted else Color(0.5, 0.5, 0.5))
	# Idioma
	UI.text_l(self, Vector2(490, 446), T.t("LANG_LABEL"), 14, Color(1, 1, 1, 0.8))
	UI.lang_toggle(self, pause_lang_rect(), m if not confirm else Vector2(-1, -1))
	UI.button(self, pause_button("quit"), T.t("PAUSE_QUIT"), not confirm and pause_button("quit").has_point(m))
	UI.text_c(self, Vector2(640, 560), T.t("PAUSE_HINT"), 12, Color(1, 1, 1, 0.5))
	if confirm:
		draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.5))
		var r := Rect2(400, 270, 480, 180)
		UI.panel(self, r, Color(0.1, 0.08, 0.06), Data.GOLD, 3.0)
		draw_multiline_string(UI.font(), Vector2(r.position.x + 30, r.position.y + 44), T.t("PAUSE_CONFIRM"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 60, 17, 3, Color.WHITE)
		UI.button(self, confirm_button(0), T.t("CONFIRM_YES"), confirm_button(0).has_point(m), false, 16)
		UI.button(self, confirm_button(1), T.t("CONFIRM_NO"), confirm_button(1).has_point(m), false, 16)


func _draw_end() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.72))
	var title := T.t("END_DRAW")
	var col := Color.WHITE
	if game.result == game.player_team:
		title = T.t("END_WIN")
		col = Data.GOLD
	elif game.result >= 0:
		title = T.t("END_LOSS")
		col = Color(1, 0.4, 0.35)
	UI.text_c(self, Vector2(640, 150), title, 64, col, 8)
	UI.text_c(self, Vector2(640, 190), T.tf("END_SUMMARY", [int(game.progress[0]), int(game.progress[1]), int(game.time) / 60, int(game.time) % 60]), 16, Color.WHITE, 3)
	var cols := [380.0, 540.0, 640.0, 740.0, 840.0]
	var heads := [T.t("END_COL_HERO"), T.t("END_COL_KD"), T.t("END_COL_DMG"), T.t("END_COL_HEAL"), T.t("END_COL_MIT")]
	var y := 240.0
	for t in 2:
		UI.text_l(self, Vector2(300, y), T.t("END_YOUR_TEAM") if t == game.player_team else T.t("END_BOT"), 15, Data.TEAM_COLORS[t], 3)
		y += 22.0
		for i in heads.size():
			UI.text_c(self, Vector2(cols[i], y), heads[i], 11, Color(1, 1, 1, 0.5))
		y += 20.0
		for hid in game.teams[t]:
			var h = game.get_hero(t, hid)
			var st: Dictionary = h.stats
			var vals := [T.hero_name(hid), "%d / %d" % [st["kills"], st["deaths"]], str(int(st["damage"])), str(int(st["healing"])), str(int(st["mitigated"]))]
			for i in vals.size():
				UI.text_c(self, Vector2(cols[i], y), vals[i], 13, Color.WHITE)
			y += 20.0
		y += 14.0
	for i in 2:
		var r := end_button(i)
		var hov := r.has_point(get_global_mouse_position())
		UI.panel(self, r, Color(Data.BRONZE, 0.6 if hov else 0.35), Data.GOLD, 2.0)
		UI.text_c(self, r.get_center() + Vector2(0, 6), [T.t("END_AGAIN"), T.t("END_MENU")][i], 16, Color.WHITE, 2)
