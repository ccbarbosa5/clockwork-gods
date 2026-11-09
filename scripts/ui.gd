extends RefCounted
## Utilitários de desenho compartilhados.

const Art = preload("res://scripts/art.gd")
const T = preload("res://scripts/i18n.gd")
const Data = preload("res://scripts/data.gd")

## Linhas da ajuda "Como jogar" (chaves de i18n; "" = linha em branco).
const HELP_LINES := ["HELP_01", "HELP_02", "", "HELP_03", "HELP_04", "HELP_05", "HELP_06", "HELP_07", "HELP_08", "",
	"HELP_09", "HELP_10", "HELP_11", "HELP_12", "", "HELP_13", "HELP_14"]

static func font() -> Font:
	return ThemeDB.fallback_font


## Texto centralizado horizontalmente em `center.x`; `center.y` é a linha de base.
static func text_c(ci: CanvasItem, center: Vector2, s: String, size: int, col: Color, outline := 0) -> void:
	var f := font()
	var w := 1200.0
	var p := Vector2(center.x - w * 0.5, center.y)
	if outline > 0:
		ci.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_CENTER, w, size, outline, Color(0, 0, 0, 0.85))
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)


static func text_l(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, outline := 0) -> void:
	var f := font()
	if outline > 0:
		ci.draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline, Color(0, 0, 0, 0.85))
	ci.draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func text_r(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, outline := 0) -> void:
	var f := font()
	var w := 600.0
	var p := Vector2(pos.x - w, pos.y)
	if outline > 0:
		ci.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_RIGHT, w, size, outline, Color(0, 0, 0, 0.85))
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_RIGHT, w, size, col)


static func text_box(ci: CanvasItem, rect: Rect2, s: String, size: int, col: Color) -> void:
	var f := font()
	ci.draw_multiline_string(f, Vector2(rect.position.x, rect.position.y + size), s,
		HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, size, int(rect.size.y / (size + 2)), col)


static func ring(ci: CanvasItem, c: Vector2, r: float, col: Color, w := 2.0) -> void:
	ci.draw_arc(c, r, 0.0, TAU, maxi(24, int(r * 0.6)), col, w, true)


static func panel(ci: CanvasItem, rect: Rect2, bg: Color, border: Color, bw := 2.0) -> void:
	ci.draw_rect(rect, bg, true)
	ci.draw_rect(rect, border, false, bw)


static func gear(ci: CanvasItem, c: Vector2, r: float, teeth: int, col: Color, rot := 0.0) -> void:
	var pts := PackedVector2Array()
	var n := teeth * 4
	for i in n:
		var a := rot + TAU * float(i) / float(n)
		var rr := r if (i % 4) < 2 else r * 0.78
		pts.append(c + Vector2(cos(a), sin(a)) * rr)
	ci.draw_colored_polygon(pts, col)


## Emblema do herói (o mesmo desenhado no corpo dele no mapa).
static func hero_glyph(ci: CanvasItem, hid: String, c: Vector2, s: float, col: Color) -> void:
	match hid:
		"talos":
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s, -s), c + Vector2(s, -s), c + Vector2(s, s * 0.3),
				c + Vector2(0, s * 1.2), c + Vector2(-s, s * 0.3)]), col)
		"artemis":
			ci.draw_arc(c + Vector2(-s * 0.3, 0), s * 1.0, -1.2, 1.2, 12, col, maxf(2.0, s * 0.22), true)
			ci.draw_line(c + Vector2(-s * 0.9, 0), c + Vector2(s * 0.9, 0), col, maxf(1.5, s * 0.15), true)
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(s * 1.15, 0), c + Vector2(s * 0.6, -s * 0.35), c + Vector2(s * 0.6, s * 0.35)]), col)
		_:
			ci.draw_rect(Rect2(c + Vector2(-s * 0.3, -s), Vector2(s * 0.6, s * 2.0)), col)
			ci.draw_rect(Rect2(c + Vector2(-s, -s * 0.3), Vector2(s * 2.0, s * 0.6)), col)


## Ícone do tipo de efeito: dano, cura, escudo, controle, mobilidade.
static func effect_icon(ci: CanvasItem, effect: String, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(2.0, s * 0.22)
	match effect:
		"dano":
			ci.draw_line(c + Vector2(-s * 0.7, s * 0.7), c + Vector2(s * 0.75, -s * 0.75), col, w * 1.3, true)
			ci.draw_line(c + Vector2(-s * 0.55, s * 0.05), c + Vector2(-s * 0.05, s * 0.55), col, w, true)
			ci.draw_line(c + Vector2(-s * 0.9, s * 0.9), c + Vector2(-s * 0.55, s * 0.55), col, w * 1.4, true)
		"cura":
			ci.draw_circle(c + Vector2(-s * 0.38, -s * 0.2), s * 0.42, col)
			ci.draw_circle(c + Vector2(s * 0.38, -s * 0.2), s * 0.42, col)
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(-s * 0.78, -s * 0.05), c + Vector2(s * 0.78, -s * 0.05), c + Vector2(0, s * 0.85)]), col)
		"escudo":
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -s * 0.95), c + Vector2(s * 0.8, -s * 0.6), c + Vector2(s * 0.65, s * 0.3),
				c + Vector2(0, s * 0.95), c + Vector2(-s * 0.65, s * 0.3), c + Vector2(-s * 0.8, -s * 0.6)]), col)
		"controle":
			ci.draw_colored_polygon(PackedVector2Array([
				c + Vector2(s * 0.2, -s), c + Vector2(-s * 0.55, s * 0.15), c + Vector2(-s * 0.05, s * 0.15),
				c + Vector2(-s * 0.25, s), c + Vector2(s * 0.55, -s * 0.15), c + Vector2(s * 0.05, -s * 0.15)]), col)
		"mobilidade":
			for k in 2:
				var ox := (k - 0.5) * s * 0.75
				ci.draw_polyline(PackedVector2Array([
					c + Vector2(ox - s * 0.35, -s * 0.7), c + Vector2(ox + s * 0.35, 0), c + Vector2(ox - s * 0.35, s * 0.7)]), col, w * 1.2, true)


## Ícone da habilidade: usa assets/icons/<habilidade>.png no mesmo tamanho do
## ícone por código (lado 2·s); sem a imagem, desenha o ícone do tipo de efeito.
static func ability_icon(ci: CanvasItem, ab: Dictionary, c: Vector2, s: float, col: Color) -> void:
	var t := Art.icon(Art.ability_id(ab))
	if t == null:
		effect_icon(ci, ab["effect"], c, s, col)
		return
	Art.draw_centered(ci, t, c, Vector2(s, s) * 2.0, 0.0, Color(1, 1, 1, col.a))


## Selo de habilidade: círculo na cor da função com o ícone da habilidade.
static func badge(ci: CanvasItem, c: Vector2, r: float, ab: Dictionary, role_col: Color, alpha := 1.0, ult := false) -> void:
	ci.draw_circle(c, r + 2.0, Color(0, 0, 0, 0.7 * alpha))
	ci.draw_circle(c, r, Color(role_col.darkened(0.35), alpha))
	if ult:
		ci.draw_arc(c, r + 3.0, 0.0, TAU, 32, Color(0.95, 0.76, 0.31, alpha), 2.5, true)
	ability_icon(ci, ab, c, r * 0.6, Color(1, 1, 1, alpha))


## Botão padrão da interface (painel de bronze, texto centralizado).
static func button(ci: CanvasItem, r: Rect2, label: String, hov: bool, active := false, size := 14) -> void:
	var bg := Color(Data.BRONZE, 0.5) if active else (Color(Data.BRONZE, 0.3) if hov else Color(0, 0, 0, 0.45))
	panel(ci, r, bg, Data.GOLD if active or hov else Color(Data.BRONZE, 0.6), 2.0 if active else 1.5)
	text_c(ci, r.get_center() + Vector2(0, size * 0.36), label, size, Color.WHITE)


## Botão de idioma: metade PT, metade EN; a metade do idioma atual fica acesa.
static func lang_toggle(ci: CanvasItem, r: Rect2, mouse: Vector2) -> void:
	for i in 2:
		var l: String = T.LANGS[i]
		var half := Rect2(r.position + Vector2(r.size.x * 0.5 * i, 0), Vector2(r.size.x * 0.5, r.size.y))
		button(ci, half, T.t("LANG_" + l.to_upper()), half.has_point(mouse), T.lang() == l, 13)


## Idioma da metade clicada do botão de idioma ("" se fora dele).
static func lang_at(r: Rect2, p: Vector2) -> String:
	if not r.has_point(p):
		return ""
	return T.LANGS[0] if p.x < r.get_center().x else T.LANGS[1]


## Tela "Como jogar" (menu e pausa).
static func draw_help(ci: CanvasItem) -> void:
	ci.draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.8))
	var r := Rect2(220, 70, 840, 580)
	panel(ci, r, Color(0.1, 0.08, 0.06), Data.BRONZE, 3.0)
	text_c(ci, Vector2(640, 115), T.t("HELP_TITLE"), 30, Data.GOLD, 4)
	var y := 160.0
	for key in HELP_LINES:
		if key != "":
			text_l(ci, Vector2(260, y), T.t(key), 15, Color(1, 1, 1, 0.85))
		y += 25.0
	text_c(ci, Vector2(640, 636), T.t("HELP_BACK"), 13, Color(1, 1, 1, 0.5))
