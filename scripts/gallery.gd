extends Node2D
## Galeria de heróis: lista à esquerda, ilustração de corpo inteiro no centro
## e ficha à direita (textos, atributos e as 4 habilidades).
## Aberta pelo botão "Heróis" do menu; volta com "Voltar" ou ESC.
## A lista aceita qualquer número de heróis (grade de 2 colunas com rolagem),
## porque esta tela vai virar a seleção de time.

const Data = preload("res://scripts/data.gd")
const UI = preload("res://scripts/ui.gd")
const Art = preload("res://scripts/art.gd")
const AudioScript = preload("res://scripts/audio.gd")

signal back

## Tamanho da ilustração de corpo inteiro na tela (fonte 512×768).
const FULL_SIZE := Vector2(340, 510)
const FULL_CENTER := Vector2(484, 400)
## Lista de heróis (grade).
const LIST_RECT := Rect2(24, 84, 262, 612)
const CARD_SIZE := Vector2(120, 148)
const CARD_GAP := 10.0
const COLS := 2
## Ficha à direita.
const INFO_X := 700.0
const INFO_R := 1250.0

const LABELS := {
	"title": {"pt": "Heróis", "en": "Heroes"},
	"back": {"pt": "Voltar", "en": "Back"},
	"attrs": {"pt": "Atributos", "en": "Attributes"},
	"abilities": {"pt": "Habilidades", "en": "Abilities"},
	"hp": {"pt": "Vida", "en": "Health"},
	"speed": {"pt": "Velocidade", "en": "Speed"},
	"range": {"pt": "Alcance", "en": "Range"},
	"ichor": {"pt": "Ícor", "en": "Ichor"},
	"ult": {"pt": "Ultimate", "en": "Ultimate"},
}

var heroes: Array = []
var selected := 0
var scroll := 0.0
var t := 0.0
## Se o último desenho usou a ilustração de corpo inteiro (testes).
var used_full := false


func _ready() -> void:
	heroes = Data.HERO_ORDER.duplicate()


## Abre a galeria (opcionalmente num herói).
func open(hid := "") -> void:
	if heroes.is_empty():
		heroes = Data.HERO_ORDER.duplicate()
	visible = true
	if hid != "" and heroes.has(hid):
		select(heroes.find(hid))
	queue_redraw()


func close() -> void:
	visible = false
	back.emit()


func selected_id() -> String:
	return heroes[selected]


func select(i: int) -> void:
	selected = clampi(i, 0, heroes.size() - 1)
	_scroll_to(selected)
	queue_redraw()


static func label(key: String) -> String:
	var d: Dictionary = LABELS[key]
	return d.get(Data.lang, d["pt"])


# ---------------------------------------------------------------------------
# Layout da lista

func rows() -> int:
	return int(ceil(float(heroes.size()) / COLS))


func max_scroll() -> float:
	var content := rows() * (CARD_SIZE.y + CARD_GAP) - CARD_GAP
	return maxf(0.0, content - (LIST_RECT.size.y - 12.0))


## Retângulo do cartão `i` na tela (já com a rolagem).
func card_rect(i: int) -> Rect2:
	var col := i % COLS
	var row := i / COLS
	var x0 := LIST_RECT.position.x + (LIST_RECT.size.x - (COLS * CARD_SIZE.x + (COLS - 1) * CARD_GAP)) * 0.5
	var p := Vector2(x0 + col * (CARD_SIZE.x + CARD_GAP), LIST_RECT.position.y + 6.0 + row * (CARD_SIZE.y + CARD_GAP) - scroll)
	return Rect2(p, CARD_SIZE)


func card_visible(i: int) -> bool:
	return LIST_RECT.intersects(card_rect(i))


func _scroll_to(i: int) -> void:
	var r := card_rect(i)
	if r.position.y < LIST_RECT.position.y:
		scroll -= LIST_RECT.position.y + 6.0 - r.position.y
	elif r.end.y > LIST_RECT.end.y:
		scroll += r.end.y - LIST_RECT.end.y + 6.0
	scroll = clampf(scroll, 0.0, max_scroll())


func back_rect() -> Rect2:
	return Rect2(24, 22, 120, 38)


# ---------------------------------------------------------------------------
# Entrada

func _process(delta: float) -> void:
	if visible:
		t += delta
		queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if handle(event):
		get_viewport().set_input_as_handled()


## Trata um evento; retorna true se usou. Separado de _input para os testes.
func handle(event: InputEvent) -> bool:
	if event is InputEventMouseButton and event.pressed:
		var m: Vector2 = event.position
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN or event.button_index == MOUSE_BUTTON_WHEEL_UP:
			if LIST_RECT.has_point(m):
				var dir := 1.0 if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -1.0
				scroll = clampf(scroll + dir * 40.0, 0.0, max_scroll())
				return true
			return false
		if event.button_index != MOUSE_BUTTON_LEFT:
			return false
		if back_rect().has_point(m):
			_sound("click")
			close()
			return true
		if LIST_RECT.has_point(m):
			for i in heroes.size():
				if card_rect(i).has_point(m):
					if i != selected:
						_sound("click")
					select(i)
					return true
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_ESCAPE, KEY_BACKSPACE:
				_sound("click")
				close()
			KEY_RIGHT:
				select(selected + 1)
			KEY_LEFT:
				select(selected - 1)
			KEY_DOWN:
				select(mini(selected + COLS, heroes.size() - 1))
			KEY_UP:
				select(maxi(selected - COLS, 0))
			_:
				return false
		return true
	return false


func _sound(n: String) -> void:
	var a = AudioScript.instance
	if a != null:
		a.play(n)


# ---------------------------------------------------------------------------
# Desenho

## Texto em itálico: a fonte do jogo não tem itálico, então o texto é
## inclinado (o topo da letra vai para a direita) a partir da linha de base.
func italic_text(pos: Vector2, s: String, size: int, col: Color, width := -1.0, max_lines := 1) -> void:
	draw_set_transform_matrix(Transform2D(Vector2(1, 0), Vector2(-0.22, 1), pos))
	draw_multiline_string(UI.font(), Vector2.ZERO, s, HORIZONTAL_ALIGNMENT_LEFT, width, size, max_lines, col)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.07, 0.055, 0.045))
	UI.gear(self, Vector2(1180, 640), 90.0, 11, Color(Data.BRONZE, 0.06), t * 0.2)
	UI.gear(self, Vector2(100, 700), 120.0, 14, Color(Data.GOLD, 0.04), -t * 0.12)
	var hid := selected_id()
	_draw_header()
	_draw_list()
	_draw_full(hid)
	_draw_info(hid)


func _draw_header() -> void:
	UI.text_c(self, Vector2(640, 52), label("title").to_upper(), 30, Data.GOLD, 5)
	var br := back_rect()
	var hov := br.has_point(get_global_mouse_position())
	UI.panel(self, br, Color(Data.BRONZE, 0.35) if hov else Color(0, 0, 0, 0.4), Color(Data.BRONZE, 0.7), 1.5)
	UI.text_c(self, br.get_center() + Vector2(0, 5), "‹ " + label("back") + "  (ESC)", 14, Color.WHITE)


func _draw_list() -> void:
	UI.panel(self, LIST_RECT, Color(0, 0, 0, 0.3), Color(Data.BRONZE, 0.4), 1.5)
	var m := get_global_mouse_position()
	for i in heroes.size():
		if not card_visible(i):
			continue
		var r := card_rect(i)
		var hid: String = heroes[i]
		var role_col: Color = Data.ROLE_COLORS[Data.HEROES[hid]["role"]]
		var on := i == selected
		var hov := r.has_point(m) and LIST_RECT.has_point(m)
		var bg := Color(role_col, 0.28) if on else Color(0.12, 0.09, 0.07, 0.95)
		var border := role_col if on else (Color(Data.GOLD, 0.7) if hov else Color(Data.BRONZE, 0.5))
		UI.panel(self, r, bg, border, 3.0 if on else 1.5)
		var c := r.position + Vector2(r.size.x * 0.5, 58)
		_portrait(hid, c, 44.0, role_col)
		UI.text_c(self, Vector2(c.x, r.position.y + 126), Data.hero_text(hid, "name"), 15, Color.WHITE, 2)
		UI.text_c(self, Vector2(c.x, r.position.y + 141), Data.role_name(hid), 11, role_col.lightened(0.2))
	# Barra de rolagem (só quando a lista não cabe).
	var ms := max_scroll()
	if ms > 0.0:
		var track := Rect2(LIST_RECT.end.x - 6, LIST_RECT.position.y + 4, 3, LIST_RECT.size.y - 8)
		draw_rect(track, Color(1, 1, 1, 0.1))
		var h := track.size.y * track.size.y / (track.size.y + ms)
		draw_rect(Rect2(track.position.x, track.position.y + (track.size.y - h) * scroll / ms, 3, h), Color(Data.GOLD, 0.7))


## Retrato redondo; sem a imagem, emblema do herói num círculo da cor da função.
func _portrait(hid: String, c: Vector2, r: float, role_col: Color) -> void:
	draw_circle(c, r + 3.0, Color(0, 0, 0, 0.6))
	var p := Art.hero_portrait(hid)
	if p != null:
		Art.draw_circle_tex(self, p, c, r)
	else:
		draw_circle(c, r, role_col.darkened(0.45))
		UI.hero_glyph(self, hid, c, r * 0.45, role_col.lightened(0.3))
	UI.ring(self, c, r + 1.0, role_col, 2.5)


func _draw_full(hid: String) -> void:
	var role_col: Color = Data.ROLE_COLORS[Data.HEROES[hid]["role"]]
	# Pedestal: engrenagem girando atrás e sombra no chão.
	UI.gear(self, FULL_CENTER + Vector2(0, -20), 190.0, 18, Color(role_col, 0.07), t * 0.1)
	UI.ring(self, FULL_CENTER + Vector2(0, -20), 150.0, Color(Data.BRONZE, 0.15), 2.0)
	var full := Art.hero_full(hid)
	used_full = full != null
	var foot := FULL_CENTER + Vector2(0, FULL_SIZE.y * 0.5 - 14) if full != null else FULL_CENTER + Vector2(0, 150)
	draw_set_transform(foot, 0.0, Vector2(1.0, 0.22))
	draw_circle(Vector2.ZERO, 140.0, Color(0, 0, 0, 0.45))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if full != null:
		Art.draw_centered(self, full, FULL_CENTER, FULL_SIZE)
		return
	# Reserva: retrato ampliado (ou o emblema, se nem o retrato existir).
	_portrait(hid, FULL_CENTER + Vector2(0, -30), 150.0, role_col)


func _draw_info(hid: String) -> void:
	var h: Dictionary = Data.HEROES[hid]
	var role_col: Color = Data.ROLE_COLORS[h["role"]]
	var x := INFO_X
	var w := INFO_R - INFO_X
	var f := UI.font()
	# Nome e epíteto
	UI.text_l(self, Vector2(x, 128), Data.hero_text(hid, "name"), 42, Data.GOLD, 6)
	italic_text(Vector2(x, 160), Data.hero_text(hid, "epithet"), 19, Data.BRONZE.lightened(0.35))
	# Função (com a cor) e origem
	var role := Data.role_name(hid)
	var rw := f.get_string_size(role, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 24.0
	var chip := Rect2(x, 174, rw, 26)
	UI.panel(self, chip, Color(role_col, 0.3), role_col, 2.0)
	UI.text_c(self, chip.get_center() + Vector2(0, 5), role, 14, Color.WHITE)
	UI.text_l(self, Vector2(chip.end.x + 14, 193), Data.origin_name(hid), 15, Color(1, 1, 1, 0.75))
	# Biografia (até 3 linhas) e frase marcante
	draw_multiline_string(f, Vector2(x, 228), Data.hero_text(hid, "bio"), HORIZONTAL_ALIGNMENT_LEFT, w, 15, 3, Color(1, 1, 1, 0.85))
	italic_text(Vector2(x + 4, 300), "“" + Data.hero_text(hid, "quote") + "”", 16, Color(Data.GOLD, 0.9), w - 10, 2)
	# Atributos
	_section(Vector2(x, 362), label("attrs"))
	var stats := [["hp", "hp", ""], ["speed", "speed", " px/s"], ["range", "range", " px"]]
	for i in stats.size():
		var key: String = stats[i][0]
		var y := 378.0 + i * 24.0
		UI.text_l(self, Vector2(x, y + 11), label(key), 14, Color(1, 1, 1, 0.8))
		var bar := Rect2(x + 110, y, w - 200, 12)
		draw_rect(bar, Color(0, 0, 0, 0.55))
		var frac := stat_fraction(hid, stats[i][1])
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * frac, bar.size.y)), role_col)
		draw_rect(bar, Color(Data.BRONZE, 0.6), false, 1.0)
		UI.text_r(self, Vector2(INFO_R, y + 11), "%d%s" % [int(h[stats[i][1]]), stats[i][2]], 14, Color.WHITE)
	# Habilidades: 3 cartas e a ultimate
	_section(Vector2(x, 468), label("abilities"))
	var abs: Array = h["cards"].duplicate()
	abs.append(h["ult"])
	for i in abs.size():
		var ab: Dictionary = Data.ABILITIES[abs[i]]
		var is_ult: bool = ab.get("ult", false)
		var y2 := 478.0 + i * 55.0
		UI.badge(self, Vector2(x + 20, y2 + 24), 19.0, ab, role_col, 1.0, is_ult)
		UI.text_l(self, Vector2(x + 50, y2 + 18), ab["name"], 16, Color.WHITE, 2)
		var cost := label("ult") if is_ult else "%d %s" % [ab["cost"], label("ichor")]
		UI.text_r(self, Vector2(INFO_R, y2 + 18), cost, 14, Data.GOLD)
		if not is_ult:
			draw_circle(Vector2(INFO_R - f.get_string_size(cost, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x - 12, y2 + 13), 5.0, Data.GOLD)
		UI.text_l(self, Vector2(x + 50, y2 + 40), ab["desc"], 13, Color(1, 1, 1, 0.7))


func _section(p: Vector2, s: String) -> void:
	UI.text_l(self, p, s.to_upper(), 13, Data.BRONZE.lightened(0.3))
	draw_line(p + Vector2(UI.font().get_string_size(s.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x + 10, -5), Vector2(INFO_R, p.y - 5), Color(Data.BRONZE, 0.35), 1.0)


## Atributo do herói como fração do maior valor entre todos os heróis (0..1).
static func stat_fraction(hid: String, key: String) -> float:
	var top := 0.0
	for k in Data.HERO_ORDER:
		top = maxf(top, float(Data.HEROES[k][key]))
	return float(Data.HEROES[hid][key]) / top if top > 0.0 else 0.0
