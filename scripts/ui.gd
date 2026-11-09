extends RefCounted
## Utilitários de desenho compartilhados.

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
