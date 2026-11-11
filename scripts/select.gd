extends Node2D
## Seleção de personagens (aberta pelo botão Jogar da tela inicial).
## O jogador monta o time com calma: clica nos heróis para pôr ou tirar
## (3 heróis, no máximo 2 da mesma função, sem repetir), escolhe a dificuldade
## do bot e o comportamento inicial, e confirma. ESC volta à tela inicial.
## Os cartões são os mesmos da Galeria (scripts/hero_cards.gd).

const Data = preload("res://scripts/data.gd")
const UI = preload("res://scripts/ui.gd")
const T = preload("res://scripts/i18n.gd")
const Art = preload("res://scripts/art.gd")
const AudioScript = preload("res://scripts/audio.gd")
const Cards = preload("res://scripts/hero_cards.gd")
const Gallery = preload("res://scripts/gallery.gd")

signal start(opts: Dictionary)
signal back

const DIFFS := ["easy", "normal", "hard"]
const LIST_RECT := Rect2(24, 96, 560, 600)
const CARD_SIZE := Vector2(120, 148)
const CARD_GAP := 10.0
const COLS := 4
const PANEL := Rect2(604, 96, 652, 600)
const X := 626.0
const XR := 1236.0

var heroes: Array = []
var team: Array = Data.DEFAULT_TEAM.duplicate()
var difficulty := "normal"
var behavior := "balanced"
## Herói mostrado na ficha (o último clicado; o mouse por cima tem prioridade).
var focus := ""
## Aviso curto depois de um clique que não pôde pôr o herói no time.
var flash_text := ""
var flash_t := 0.0
var t := 0.0


func _ready() -> void:
	heroes = Data.heroes_by_role()
	focus = heroes[0]


func open() -> void:
	if heroes.is_empty():
		_ready()
	visible = true
	flash_t = 0.0
	queue_redraw()


# ---------------------------------------------------------------------------
# Layout

func card_rect(i: int) -> Rect2:
	return Cards.layout(heroes, LIST_RECT, COLS, CARD_SIZE, CARD_GAP)["cards"][i]


func back_rect() -> Rect2:
	return Rect2(24, 22, 120, 38)


func slot_rect(i: int) -> Rect2:
	return Rect2(X + i * 204, 432, 196, 80)


func diff_rect(i: int) -> Rect2:
	return Rect2(X + i * 98, 578, 92, 30)


func beh_rect(i: int) -> Rect2:
	return Rect2(940 + i * 98, 578, 92, 30)


func confirm_rect() -> Rect2:
	return Rect2(1000, 634, 236, 50)


# ---------------------------------------------------------------------------
# Regras do time

func ready_to_start() -> bool:
	return Data.valid_team(team)


func start_opts() -> Dictionary:
	return {"difficulty": difficulty, "behavior": behavior, "team": Data.sort_team(team)}


## Põe ou tira o herói do time. Retorna "" (mudou) ou o motivo do bloqueio.
func toggle(hid: String) -> String:
	focus = hid
	if team.has(hid):
		team.erase(hid)
		return ""
	var why := Data.team_add_block(team, hid)
	if why == "":
		team.append(hid)
		team = Data.sort_team(team)
	return why


## Texto do aviso de engrenagens que faltam ("" se o time tem todas).
func gear_warning() -> String:
	if team.size() < Data.TEAM_SIZE:
		return ""
	var miss := Data.missing_gears(team)
	if miss.is_empty():
		return ""
	var names: Array = []
	for g in miss:
		names.append(T.t("GEAR_" + String(Data.GEARS[g]).to_upper()))
	var txt: String = names[0]
	if names.size() > 1:
		txt = ", ".join(names.slice(0, names.size() - 1)) + T.t("SEL_AND") + names[-1]
	return T.tf("SEL_WARN_GEAR", [txt])


# ---------------------------------------------------------------------------
# Entrada

func _process(delta: float) -> void:
	if visible:
		t += delta
		flash_t = maxf(0.0, flash_t - delta)
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if handle(event):
		get_viewport().set_input_as_handled()


func handle(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m: Vector2 = event.position
		if back_rect().has_point(m):
			_sound("click")
			close()
			return true
		for i in heroes.size():
			if card_rect(i).has_point(m):
				var why := toggle(heroes[i])
				if why == "":
					_sound("click")
				else:
					flash_text = T.t("SEL_BLOCK_ROLE" if why == "role" else "SEL_BLOCK_FULL")
					flash_t = 2.0
				return true
		for i in team.size():
			if slot_rect(i).has_point(m):
				focus = team[i]
				team.remove_at(i)
				_sound("click")
				return true
		for i in 3:
			if diff_rect(i).has_point(m):
				difficulty = DIFFS[i]
				_sound("click")
				return true
			if beh_rect(i).has_point(m):
				behavior = Data.BEHAVIORS[i]
				_sound("click")
				return true
		if confirm_rect().has_point(m):
			confirm()
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_BACKSPACE:
				_sound("click")
				close()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
				confirm()
			_:
				return false
		return true
	return false


func confirm() -> void:
	if not ready_to_start():
		return
	_sound("card")
	visible = false
	start.emit(start_opts())


func close() -> void:
	visible = false
	back.emit()


func _sound(n: String) -> void:
	var a = AudioScript.instance
	if a != null:
		a.play(n)


# ---------------------------------------------------------------------------
# Desenho

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.07, 0.055, 0.045))
	UI.gear(self, Vector2(1180, 640), 90.0, 11, Color(Data.BRONZE, 0.06), t * 0.2)
	var m := get_global_mouse_position()
	UI.text_c(self, Vector2(640, 52), T.t("SEL_TITLE"), 30, Data.GOLD, 5)
	UI.text_c(self, Vector2(640, 80), T.t("SEL_HINT"), 13, Color(1, 1, 1, 0.6))
	var br := back_rect()
	UI.panel(self, br, Color(Data.BRONZE, 0.35) if br.has_point(m) else Color(0, 0, 0, 0.4), Color(Data.BRONZE, 0.7), 1.5)
	UI.text_c(self, br.get_center() + Vector2(0, 5), T.t("GAL_BACK"), 14, Color.WHITE)

	# Lista agrupada por função
	UI.panel(self, LIST_RECT, Color(0, 0, 0, 0.3), Color(Data.BRONZE, 0.4), 1.5)
	var lay := Cards.layout(heroes, LIST_RECT, COLS, CARD_SIZE, CARD_GAP)
	for hd in lay["headers"]:
		Cards.draw_header(self, hd[1], hd[0])
	var hover := ""
	for i in heroes.size():
		var hid: String = heroes[i]
		var r: Rect2 = lay["cards"][i]
		var hov := r.has_point(m)
		if hov:
			hover = hid
		var in_team := team.has(hid)
		var dim := not in_team and Data.team_add_block(team, hid) != ""
		Cards.draw_card(self, r, hid, in_team, hov, dim, T.t("SEL_IN_TEAM") if in_team else "")

	UI.panel(self, PANEL, Color(0, 0, 0, 0.3), Color(Data.BRONZE, 0.4), 1.5)
	_draw_info(hover if hover != "" else focus)
	_draw_team(m)
	_draw_options(m)


func _draw_info(hid: String) -> void:
	var h: Dictionary = Data.HEROES[hid]
	var rc: Color = Data.ROLE_COLORS[h["role"]]
	var f := UI.font()
	Cards.portrait(self, hid, Vector2(X + 40, 150), 38.0, rc)
	UI.text_l(self, Vector2(X + 94, 140), T.hero_name(hid), 28, Data.GOLD, 4)
	var role := T.role_name(h["role"])
	var rw := f.get_string_size(role, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 20.0
	var chip := Rect2(X + 94, 152, rw, 22)
	UI.panel(self, chip, Color(rc, 0.3), rc, 2.0)
	UI.text_c(self, chip.get_center() + Vector2(0, 5), role, 13, Color.WHITE)
	UI.text_l(self, Vector2(chip.end.x + 12, 169), T.hero_text(hid, "epithet"), 14, Data.BRONZE.lightened(0.35))
	# Atributos (os mesmos da Galeria)
	var stats := [["GAL_HP", "hp"], ["GAL_SPEED", "speed"], ["GAL_RANGE", "range"]]
	for i in stats.size():
		var y := 204.0 + i * 22.0
		UI.text_l(self, Vector2(X, y + 10), T.t(stats[i][0]), 13, Color(1, 1, 1, 0.8))
		var bar := Rect2(X + 100, y, XR - X - 190, 11)
		draw_rect(bar, Color(0, 0, 0, 0.55))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * Gallery.stat_fraction(hid, stats[i][1]), bar.size.y)), rc)
		draw_rect(bar, Color(Data.BRONZE, 0.6), false, 1.0)
		UI.text_r(self, Vector2(XR, y + 10), Gallery.stat_text(hid, stats[i][1]), 13, Color.WHITE)
	# Habilidades: 3 cartas e a ultimate, com o tipo
	var abs: Array = h["cards"].duplicate()
	abs.append(h["ult"])
	for i in abs.size():
		var ab: Dictionary = Data.ABILITIES[abs[i]]
		var is_ult: bool = ab.get("ult", false)
		var y2 := 286.0 + i * 30.0
		UI.badge(self, Vector2(X + 12, y2 + 10), 11.0, ab, rc, 1.0, is_ult)
		UI.text_l(self, Vector2(X + 32, y2 + 15), T.ab_name(abs[i]), 14, Color.WHITE)
		var sub := T.t("GAL_ULT") if is_ult else T.tf("GAL_COST", [ab["cost"]]) + " · " + T.effect_name(ab["effect"])
		UI.text_r(self, Vector2(XR, y2 + 15), sub, 12, Data.GOLD if is_ult else Color(1, 1, 1, 0.65))


func _draw_team(m: Vector2) -> void:
	UI.text_l(self, Vector2(X, 420), T.t("SEL_TEAM"), 14, Data.BRONZE.lightened(0.3))
	for i in Data.TEAM_SIZE:
		var r := slot_rect(i)
		if i < team.size():
			var hid: String = team[i]
			var rc: Color = Data.ROLE_COLORS[Data.HEROES[hid]["role"]]
			var hov := r.has_point(m)
			UI.panel(self, r, Color(rc, 0.22), rc if not hov else Data.GOLD, 2.0)
			Cards.portrait(self, hid, r.position + Vector2(40, 40), 28.0, rc)
			UI.text_l(self, r.position + Vector2(78, 36), T.hero_name(hid), 16, Color.WHITE, 2)
			UI.text_l(self, r.position + Vector2(78, 54), T.role_name(Data.HEROES[hid]["role"]), 12, rc.lightened(0.25))
			if hov:
				UI.text_l(self, r.position + Vector2(78, 70), T.t("SEL_REMOVE"), 10, Color(1, 1, 1, 0.55))
		else:
			UI.panel(self, r, Color(0, 0, 0, 0.35), Color(Data.BRONZE, 0.35), 1.5)
			UI.text_c(self, r.get_center() + Vector2(0, 5), T.t("SEL_EMPTY"), 13, Color(1, 1, 1, 0.35))
	# Aviso: clique bloqueado (2 s) ou engrenagem da Roda que falta.
	var warn := flash_text if flash_t > 0.0 else gear_warning()
	if warn != "":
		UI.text_l(self, Vector2(X, 540), "⚠ " + warn if UI.font().has_char(0x26A0) else "! " + warn, 14, Color(1.0, 0.75, 0.35))


func _draw_options(m: Vector2) -> void:
	UI.text_l(self, Vector2(X, 570), T.t("MENU_DIFFICULTY"), 12, Color(1, 1, 1, 0.75))
	UI.text_l(self, Vector2(940, 570), T.t("MENU_BEHAVIOR"), 12, Color(1, 1, 1, 0.75))
	for i in 3:
		var r := diff_rect(i)
		var on: bool = DIFFS[i] == difficulty
		UI.panel(self, r, Color(Data.BRONZE, 0.6) if on else Color(0, 0, 0, 0.55), Data.GOLD if on else Color(Data.BRONZE, 0.6), 2.0)
		UI.text_c(self, r.get_center() + Vector2(0, 5), T.t("DIFF_" + String(DIFFS[i]).to_upper()), 13, Color.WHITE)
		var r2 := beh_rect(i)
		var on2: bool = Data.BEHAVIORS[i] == behavior
		UI.panel(self, r2, Color(Data.BRONZE, 0.6) if on2 else Color(0, 0, 0, 0.55), Data.GOLD if on2 else Color(Data.BRONZE, 0.6), 2.0)
		UI.text_c(self, r2.get_center() + Vector2(0, 5), T.behavior_name(Data.BEHAVIORS[i]), 13, Color.WHITE)
	var cr := confirm_rect()
	var ok := ready_to_start()
	var hov := cr.has_point(m) and ok
	UI.panel(self, cr, Color(Data.GOLD, (0.55 if hov else 0.4) if ok else 0.08), Data.GOLD if ok else Color(Data.BRONZE, 0.4), 3.0 if ok else 1.5)
	UI.text_c(self, cr.get_center() + Vector2(0, 7), T.t("SEL_CONFIRM"), 18, Color.WHITE if ok else Color(1, 1, 1, 0.35), 3)
	if not ok:
		UI.text_r(self, Vector2(cr.position.x - 14, cr.get_center().y + 5), T.tf("SEL_NEED", [Data.TEAM_SIZE - team.size()]), 14, Color(1, 1, 1, 0.6))

