extends RefCounted
## Cartões de herói agrupados por função (Tanque, Dano, Suporte), usados pela
## Galeria de heróis e pela tela de seleção de personagens: cada função tem uma
## faixa com o nome na cor dela e, abaixo, os cartões dos heróis da função
## (os originais primeiro: ordem de Data.heroes_by_role()).

const Data = preload("res://scripts/data.gd")
const UI = preload("res://scripts/ui.gd")
const T = preload("res://scripts/i18n.gd")
const Art = preload("res://scripts/art.gd")

const HEADER_H := 24.0


## Posições (sem rolagem) dentro de `area`, para a lista `heroes` na ordem dada.
## Uma faixa nova começa sempre que a função muda.
## Retorna {"cards": [Rect2 por índice], "headers": [[função, Rect2]], "height": px}.
static func layout(heroes: Array, area: Rect2, cols: int, card: Vector2, gap: float) -> Dictionary:
	var cards: Array = []
	var headers: Array = []
	var x0 := area.position.x + (area.size.x - (cols * card.x + (cols - 1) * gap)) * 0.5
	var y := area.position.y + 6.0
	var col := cols
	var role := ""
	for i in heroes.size():
		var r: String = Data.HEROES[heroes[i]]["role"]
		if r != role:
			if role != "":
				y += card.y + gap
			role = r
			headers.append([r, Rect2(area.position.x + 6.0, y, area.size.x - 12.0, HEADER_H)])
			y += HEADER_H + 6.0
			col = 0
		elif col >= cols:
			y += card.y + gap
			col = 0
		cards.append(Rect2(Vector2(x0 + col * (card.x + gap), y), card))
		col += 1
	if not heroes.is_empty():
		y += card.y
	return {"cards": cards, "headers": headers, "height": y - area.position.y}


## Faixa da função: fundo na cor da função, nome em maiúsculas e o ícone.
static func draw_header(ci: CanvasItem, r: Rect2, role: String) -> void:
	var col: Color = Data.ROLE_COLORS[role]
	ci.draw_rect(r, Color(col, 0.22))
	ci.draw_rect(Rect2(r.position, Vector2(5, r.size.y)), col)
	ci.draw_line(Vector2(r.position.x, r.end.y), r.end, Color(col, 0.8), 2.0)
	UI.text_l(ci, r.position + Vector2(14, r.size.y * 0.5 + 5), T.role_name(role).to_upper(), 14, col.lightened(0.35), 2)


## Retrato redondo; sem a imagem, emblema do herói num círculo da cor da função.
static func portrait(ci: CanvasItem, hid: String, c: Vector2, r: float, role_col: Color, mod := Color.WHITE) -> void:
	ci.draw_circle(c, r + 3.0, Color(0, 0, 0, 0.6))
	var p := Art.hero_portrait(hid)
	if p != null:
		Art.draw_circle_tex(ci, p, c, r, mod)
	else:
		ci.draw_circle(c, r, role_col.darkened(0.45))
		UI.hero_glyph(ci, hid, c, r * 0.45, role_col.lightened(0.3))
	UI.ring(ci, c, r + 1.0, role_col, 2.5)


## Cartão de herói: retrato, nome e função.
##   on    selecionado (borda e fundo na cor da função)
##   hov   mouse por cima
##   dim   indisponível (escurecido)
##   tag   faixa no topo (ex.: "NO TIME"); "" para nenhuma
static func draw_card(ci: CanvasItem, r: Rect2, hid: String, on: bool, hov: bool, dim := false, tag := "") -> void:
	var role_col: Color = Data.ROLE_COLORS[Data.HEROES[hid]["role"]]
	var bg := Color(role_col, 0.28) if on else Color(0.12, 0.09, 0.07, 0.95)
	var border := role_col if on else (Color(Data.GOLD, 0.7) if hov else Color(Data.BRONZE, 0.5))
	UI.panel(ci, r, bg, border, 3.0 if on else 1.5)
	var pr := minf(44.0, r.size.y * 0.3)
	var c := r.position + Vector2(r.size.x * 0.5, 14.0 + pr)
	portrait(ci, hid, c, pr, role_col, Color(0.45, 0.45, 0.45) if dim else Color.WHITE)
	UI.text_c(ci, Vector2(c.x, r.end.y - 22.0), T.hero_name(hid), 15, Color.WHITE if not dim else Color(1, 1, 1, 0.45), 2)
	UI.text_c(ci, Vector2(c.x, r.end.y - 7.0), T.role_name(Data.HEROES[hid]["role"]), 11, role_col.lightened(0.2))
	if dim:
		ci.draw_rect(r, Color(0, 0, 0, 0.35))
	if tag != "":
		var tr := Rect2(r.position + Vector2(6, 6), Vector2(r.size.x - 12, 18))
		UI.panel(ci, tr, Color(role_col, 0.85), role_col.lightened(0.3), 1.0)
		UI.text_c(ci, tr.get_center() + Vector2(0, 4), tag, 11, Color(0.08, 0.06, 0.05))
