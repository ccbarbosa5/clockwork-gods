extends RefCounted
## Tela "Como jogar" (Pacote 5, etapa 2): 8 abas com captura real do jogo,
## marcações desenhadas por código (contornos, setas e legendas), título,
## frase de abertura e tópicos. A mesma tela abre pelo menu principal
## (scripts/menu.gd) e pelo menu de pausa (scripts/hud.gd).
##   Navegação: clique nas abas ou em ‹ ›, setas do teclado, teclas 1 a 8; ESC volta.
##   A última aba aberta fica salva em user://settings.cfg (geral/como_jogar_aba).
## Textos: chaves HOWTO_* do i18n/textos.csv (aprovados em claude/como-jogar.md);
## os números (%d) vêm de data.gd em `bullet_args()`.
## Capturas: assets/help/howto_N_<idioma>.jpg, geradas por tools/howto_shots.gd.

const Data = preload("res://scripts/data.gd")
const UI = preload("res://scripts/ui.gd")
const T = preload("res://scripts/i18n.gd")
const Art = preload("res://scripts/art.gd")

const TABS := 8
const SAVE_KEY := "como_jogar_aba"
const BULLETS := [5, 5, 5, 5, 4, 5, 5, 5]
const SHOT := "res://assets/help/howto_%d_%s.jpg"
## Lupa: recorte da captura em tamanho real (howto_N_zoom_<idioma>.png),
## mostrado ampliado em `dst` (coordenadas 1280 × 720 da captura).
## aba (0 a 7) → {"src": recorte, "dst": onde aparece}.
## "circle": recorte redondo (o resto fica transparente), para pegar só a roda.
const ZOOMS := {
	3: {"src": Rect2(266, 628, 72, 72), "dst": Rect2(245, 60, 240, 240), "circle": true},
	4: {"src": Rect2(12, 628, 264, 88), "dst": Rect2(150, 389, 449, 150)},
}
## Raio do recorte redondo, em fração da metade do lado.
const ZOOM_CIRCLE := 0.88
const ZOOM_PAD := 6.0
const MARK_FONT := 13
const ZOOM_SHOT := "res://assets/help/howto_%d_zoom_%s.png"

## Imagem: captura 1280 × 720 reduzida para 800 × 450 (escala 0,625).
const IMG := Rect2(24, 134, 800, 450)
const IMG_SCALE := 0.625
const TEXT := Rect2(840, 134, 416, 450)
const BACK := Rect2(24, 20, 150, 36)
const PREV := Rect2(24, 604, 190, 40)
const NEXT := Rect2(1066, 604, 190, 40)

## Geometria do HUD e da seleção usada nas marcações (conferida pelos testes
## contra hud.gd e select.gd: se o HUD mudar, o teste avisa).
const HUD_POINT := Vector2(640, 300)
const HUD_PROGRESS := [Rect2(20, 13, 470, 14), Rect2(790, 13, 470, 14)]
const HUD_CLOCK := Rect2(610, 3, 60, 22)
const HUD_STATUS := Rect2(560, 26, 160, 13)
const HUD_ICHOR := Rect2(350, 700, 504, 14)
## Barra de Ícor com o número ao lado ("5 Ícor").
const HUD_ICHOR_ALL := Rect2(350, 698, 560, 18)
const HUD_CARDS := Rect2(350, 576, 504, 118)
const HUD_CARD_W := 128.0
const HUD_NEXT := Rect2(872, 604, 78, 90)
const HUD_WHEEL := Vector2(302, 664)
const HUD_WHEEL_R := 17.0
const HUD_ULT := Vector2(50, 668)
const HUD_ULT_STEP := 94.0
## Letra da tecla da ultimate, em relação ao centro do botão.
const HUD_ULT_KEY := Vector2(-20, -18)
const HUD_BEH := Rect2(984, 614, 282, 40)
const HUD_BEH_W := 96.0
const HUD_PAUSE := Rect2(430, 120, 420, 470)
const HUD_PAUSE_LANG := Rect2(560, 424, 110, 32)
## Botões de idioma com a palavra "Idioma" à esquerda.
const HUD_PAUSE_LANG_ALL := Rect2(486, 422, 186, 36)
const SEL_LIST := Rect2(24, 96, 560, 600)
const SEL_SHEET := Rect2(612, 104, 636, 298)
const SEL_SLOTS := Rect2(626, 432, 604, 80)
const SEL_FREE := Rect2(626, 642, 300, 34)
const SEL_CONFIRM := Rect2(1000, 634, 236, 50)
## Cena da aba 7 (tools/howto_shots.gd): Ártemis regenerando e Talos na cobertura.
const SCENE_SPARK := Vector2(470, 260)
const SCENE_COVER := Vector2(222, 398)

var tab := 0
var hover := ""


# --- Estado ------------------------------------------------------------------
## Abre na última aba vista.
func open() -> void:
	tab = load_tab()


static func load_tab() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(T.settings_path) == OK:
		return clampi(int(cfg.get_value("geral", SAVE_KEY, 0)), 0, TABS - 1)
	return 0


func set_tab(i: int) -> void:
	tab = posmod(i, TABS)
	var cfg := ConfigFile.new()
	cfg.load(T.settings_path)  # mantém idioma e som
	cfg.set_value("geral", SAVE_KEY, tab)
	cfg.save(T.settings_path)


func tab_rect(i: int) -> Rect2:
	return Rect2(24 + i * 154, 82, 148, 38)


## Trata o evento; devolve "close" quando a tela deve fechar.
func handle(event: InputEvent, m: Vector2) -> String:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if BACK.has_point(m):
			return "close"
		for i in TABS:
			if tab_rect(i).has_point(m):
				set_tab(i)
				return ""
		if PREV.has_point(m):
			set_tab(tab - 1)
		elif NEXT.has_point(m):
			set_tab(tab + 1)
	elif event is InputEventKey and event.pressed and not event.echo:
		var k: int = event.keycode
		if k == KEY_ESCAPE:
			return "close"
		elif k == KEY_LEFT or k == KEY_UP:
			set_tab(tab - 1)
		elif k == KEY_RIGHT or k == KEY_DOWN:
			set_tab(tab + 1)
		elif k >= KEY_1 and k <= KEY_8:
			set_tab(k - KEY_1)
		elif k >= KEY_KP_1 and k <= KEY_KP_8:
			set_tab(k - KEY_KP_1)
	return ""


# --- Textos ------------------------------------------------------------------
## Números de cada tópico, lidos do jogo (chave → argumentos de %d).
static func bullet_args() -> Dictionary:
	return {
		"HOWTO_1_1": [int(Data.UNLOCK_TIME)],
		"HOWTO_1_2": [int(Data.CAPTURE_TIME)],
		"HOWTO_2_3": [Data.MAX_PER_ROLE],
		"HOWTO_3_2": [int(Data.ARM_TIME)],
		"HOWTO_3_4": [int(Data.ICHOR_MAX)],
		"HOWTO_4_2": [int(Data.GEAR_WINDOW)],
		"HOWTO_4_4": [Data.CADENCE_FROM, int(Data.CADENCE_REFUND)],
		"HOWTO_4_5": [int(Data.FULL_TURN_ULT)],
		"HOWTO_7_1": [int(Data.RESPAWN)],
		"HOWTO_7_3": [int(Data.PACK_HEAL), int(Data.PACK_RESPAWN)],
		"HOWTO_7_4": [int(Data.REGEN_DELAY)],
	}


static func bullet_keys(i: int) -> Array:
	var out: Array = []
	for k in BULLETS[i]:
		out.append("HOWTO_%d_%d" % [i + 1, k + 1])
	return out


static func bullet_text(key: String) -> String:
	var a := bullet_args()
	return T.tf(key, a[key]) if a.has(key) else T.t(key)


## Marcações de cada aba, em coordenadas da tela do jogo (1280 × 720):
## {"key": legenda, "at": centro da legenda, "shapes": [Rect2 ou [centro, raio]]}.
## Uma legenda pode ter várias setas (uma por forma). Raio 0 = só a seta.
## Regras (conferidas em tests/tests.gd): a legenda não cobre nenhum alvo da aba,
## nem outra legenda, nem a lupa; setas de legendas diferentes não se cruzam.
static func marks(i: int) -> Array:
	var ult := func(j: int) -> Vector2: return HUD_ULT + Vector2(j * HUD_ULT_STEP, 0)
	var card := func(j: int) -> Rect2: return Rect2(HUD_CARDS.position + Vector2(j * HUD_CARD_W, 0), Vector2(120, 118))
	var beh := func(j: int) -> Rect2: return Rect2(HUD_BEH.position + Vector2(j * HUD_BEH_W, 0), Vector2(90, 40))
	match i:
		0:
			return [
				{"key": "HOWTO_M_1_1", "at": Vector2(640, 452), "shapes": [[HUD_POINT, Data.POINT_R + 8.0]]},
				# Uma legenda, duas setas: para a ponta de fora de cada barra,
				# passando por baixo das legendas do tempo e do dono do ponto.
				{"key": "HOWTO_M_1_2", "at": Vector2(640, 135), "shapes": HUD_PROGRESS.duplicate(),
					"to": [Vector2(60, 29), Vector2(1220, 29)]},
				{"key": "HOWTO_M_1_3", "at": Vector2(420, 55), "shapes": [HUD_CLOCK]},
				{"key": "HOWTO_M_1_4", "at": Vector2(850, 55), "shapes": [HUD_STATUS]},
			]
		1:
			return [
				{"key": "HOWTO_M_2_1", "at": Vector2(304, 72), "shapes": [SEL_LIST]},
				{"key": "HOWTO_M_2_2", "at": Vector2(1100, 72), "shapes": [SEL_SHEET]},
				{"key": "HOWTO_M_2_3", "at": Vector2(900, 535), "shapes": [SEL_SLOTS]},
				{"key": "HOWTO_M_2_4", "at": Vector2(776, 700), "shapes": [SEL_FREE]},
				{"key": "HOWTO_M_2_5", "at": Vector2(1118, 535), "shapes": [SEL_CONFIRM]},
			]
		2:
			return [
				{"key": "HOWTO_M_3_1", "at": Vector2(1070, 704), "shapes": [HUD_ICHOR_ALL]},
				{"key": "HOWTO_M_3_2", "at": Vector2(600, 512), "shapes": [HUD_CARDS]},
				{"key": "HOWTO_M_3_3", "at": Vector2(380, 455), "shapes": [[card.call(1).position + Vector2(13, 13), 14.0]]},
				{"key": "HOWTO_M_3_4", "at": Vector2(800, 455), "shapes": [Rect2(card.call(2).position, Vector2(120, 26))]},
				{"key": "HOWTO_M_3_5", "at": Vector2(1010, 512), "shapes": [HUD_NEXT]},
			]
		3:
			# Na lupa da roda: engrenagem do Movimento engatada (2 elos acesos, 3,3 s de 5).
			var z := func(p: Vector2) -> Vector2: return zoom_point(3, p)
			var zs: float = zoom_scale(3)
			var node0 := HUD_WHEEL + Vector2(0, -HUD_WHEEL_R)
			var arc := node0 + Vector2(cos(PI / 6.0), sin(PI / 6.0)) * 9.5
			var link := HUD_WHEEL + Vector2(-1, -1).normalized() * HUD_WHEEL_R
			return [
				{"key": "HOWTO_M_4_1", "at": Vector2(420, 345), "shapes": [[z.call(HUD_WHEEL), (HUD_WHEEL_R + 11.0) * zs]]},
				{"key": "HOWTO_M_4_2", "at": Vector2(640, 95), "shapes": [[z.call(node0), 9.0 * zs]]},
				{"key": "HOWTO_M_4_3", "at": Vector2(640, 200), "shapes": [[z.call(arc), 0.0]]},
				{"key": "HOWTO_M_4_4", "at": Vector2(640, 525), "shapes": [card.call(0)]},
				{"key": "HOWTO_M_4_5", "at": Vector2(110, 110), "shapes": [[z.call(link), 0.0]]},
			]
		4:
			# Na lupa dos medidores: Talos pronta, Ártemis 62%, Asclépio 35%.
			var z := func(p: Vector2) -> Vector2: return zoom_point(4, p)
			var zs: float = zoom_scale(4)
			return [
				{"key": "HOWTO_M_5_1", "at": Vector2(180, 350), "shapes": [[z.call(ult.call(0)), 31.0 * zs]]},
				{"key": "HOWTO_M_5_2", "at": Vector2(440, 350), "shapes": [[z.call(ult.call(1)), 31.0 * zs]]},
				{"key": "HOWTO_M_5_3", "at": Vector2(760, 470), "shapes": [[z.call(ult.call(2)), 22.0 * zs]]},
				{"key": "HOWTO_M_5_4", "at": Vector2(70, 450), "shapes": [[z.call(ult.call(0) + HUD_ULT_KEY), 8.0 * zs]]},
			]
		5:
			return [
				{"key": "HOWTO_M_6_1", "at": Vector2(1125, 704), "shapes": [HUD_BEH]},
				{"key": "HOWTO_M_6_2", "at": Vector2(830, 560), "shapes": [beh.call(1)]},
				{"key": "HOWTO_M_6_3", "at": Vector2(820, 420), "shapes": [behavior_tip_rect()]},
			]
		6:
			return [
				{"key": "HOWTO_M_7_1", "at": Vector2(150, 150), "shapes": [[Vector2(62, 300), 80.0]]},
				{"key": "HOWTO_M_7_2", "at": Vector2(480, 95), "shapes": [[Data.HEALTH_PACKS[0], 24.0]]},
				{"key": "HOWTO_M_7_3", "at": Vector2(480, 520), "shapes": [[Data.HEALTH_PACKS[1], 24.0]]},
				{"key": "HOWTO_M_7_4", "at": Vector2(600, 190), "shapes": [[SCENE_SPARK, 30.0]]},
				{"key": "HOWTO_M_7_5", "at": Vector2(120, 520), "shapes": [[SCENE_COVER, 52.0]]},
			]
		7:
			return [
				{"key": "HOWTO_M_8_1", "at": Vector2(260, 540), "shapes": [HUD_CARDS]},
				{"key": "HOWTO_M_8_2", "at": Vector2(150, 597), "shapes": [Rect2(HUD_ULT - Vector2(32, 32), Vector2(64 + 2 * HUD_ULT_STEP, 64))]},
				{"key": "HOWTO_M_8_3", "at": Vector2(1125, 570), "shapes": [HUD_BEH]},
				{"key": "HOWTO_M_8_4", "at": Vector2(270, 165), "shapes": [Rect2(HUD_PAUSE.position + Vector2(60, 20), Vector2(300, 50))]},
				{"key": "HOWTO_M_8_5", "at": Vector2(300, 440), "shapes": [HUD_PAUSE_LANG_ALL]},
			]
	return []


## Ponto da captura (1280 × 720) dentro da lupa da aba `i`.
static func zoom_point(i: int, p: Vector2) -> Vector2:
	var zm: Dictionary = ZOOMS[i]
	return zm["dst"].position + (p - zm["src"].position) * zoom_scale(i)


static func zoom_scale(i: int) -> float:
	return ZOOMS[i]["dst"].size.x / ZOOMS[i]["src"].size.x


static func zoom_path(i: int, lang: String) -> String:
	return ZOOM_SHOT % [i + 1, lang]


## Moldura da lupa na tela (com a borda).
static func zoom_frame(i: int) -> Rect2:
	var d: Rect2 = ZOOMS[i]["dst"]
	return Rect2(to_screen(d.position), d.size * IMG_SCALE).grow(ZOOM_PAD + 3.0)


## Caixa da dica de comportamento (Equilibrado) na captura da aba 6.
static func behavior_tip_rect() -> Rect2:
	var hud = load("res://scripts/hud.gd")
	var b := "balanced"
	var lines: Array = hud.behavior_lines(b)
	lines.append([T.tf("TIP_BEH_KEY", [Data.BEHAVIOR_KEYS[1]]), Color.WHITE])
	return hud.tip_rect(Rect2(HUD_BEH.position + Vector2(HUD_BEH_W, 0), Vector2(90, 40)), T.t("BEH_BALANCED_DESC"), lines, 300.0)


## Ponto da captura (1280 × 720) na tela "Como jogar".
static func to_screen(p: Vector2) -> Vector2:
	return IMG.position + p * IMG_SCALE


## Geometria de uma marcação na tela: caixa da legenda, alvos (retângulos que
## os envolvem) e setas [de, até].
static func mark_layout(mk: Dictionary) -> Dictionary:
	var label := T.t(mk["key"])
	var tw := UI.font().get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, MARK_FONT).x
	var c := to_screen(mk["at"])
	var box := Rect2(c - Vector2(tw * 0.5 + 8, 11), Vector2(tw + 16, 22))
	# A legenda nunca sai da imagem.
	box.position.x = clampf(box.position.x, IMG.position.x + 4, IMG.end.x - box.size.x - 4)
	box.position.y = clampf(box.position.y, IMG.position.y + 4, IMG.end.y - box.size.y - 2)
	var targets: Array = []
	var arrows: Array = []
	var k := -1
	for s in mk["shapes"]:
		k += 1
		var target: Vector2
		if s is Rect2:
			var r := Rect2(to_screen(s.position), s.size * IMG_SCALE).grow(2)
			targets.append(r)
			# Ponto do alvo mais perto da legenda.
			target = Vector2(clampf(box.get_center().x, r.position.x, r.end.x), clampf(box.get_center().y, r.position.y, r.end.y))
		else:
			var cc := to_screen(s[0])
			var rr: float = s[1] * IMG_SCALE
			targets.append(Rect2(cc - Vector2(rr, rr), Vector2(rr, rr) * 2.0).grow(3.0 if rr <= 0.0 else 1.0))
			target = cc + (box.get_center() - cc).normalized() * rr
		if mk.has("to"):
			target = to_screen(mk["to"][k])
		var from := _rect_edge(box, target)
		if from.distance_to(target) > 6.0:
			arrows.append([from, target])
	return {"label": label, "box": box, "targets": targets, "arrows": arrows}


## Problemas de posição das legendas da aba `i` (vazio = tudo certo):
## legenda cobrindo um alvo, outra legenda ou a lupa; seta cruzando seta ou
## legenda de outra marcação. Usado pelos testes.
static func layout_problems(i: int) -> Array:
	var out: Array = []
	var ms := marks(i)
	var lays: Array = []
	for mk in ms:
		lays.append(mark_layout(mk))
	var frame := zoom_frame(i) if ZOOMS.has(i) else Rect2()
	for a in lays.size():
		var box: Rect2 = lays[a]["box"]
		var name: String = ms[a]["key"]
		if ZOOMS.has(i) and box.intersects(frame):
			out.append("%s cobre a lupa" % name)
		for b in lays.size():
			for t in lays[b]["targets"]:
				if box.intersects(t):
					out.append("%s cobre o alvo de %s" % [name, ms[b]["key"]])
			if b <= a:
				continue
			if box.intersects(lays[b]["box"]):
				out.append("%s cobre a legenda %s" % [name, ms[b]["key"]])
		for b in lays.size():
			if b == a:
				continue
			for ar in lays[a]["arrows"]:
				if _segment_hits_rect(ar[0], ar[1], lays[b]["box"].grow(-1)):
					out.append("seta de %s passa sobre a legenda %s" % [name, ms[b]["key"]])
				if b < a:
					continue
				for br in lays[b]["arrows"]:
					if Geometry2D.segment_intersects_segment(ar[0], ar[1], br[0], br[1]) != null:
						out.append("setas de %s e %s se cruzam" % [name, ms[b]["key"]])
	return out


static func _segment_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for k in 4:
		if Geometry2D.segment_intersects_segment(a, b, c[k], c[(k + 1) % 4]) != null:
			return true
	return false


# --- Desenho -----------------------------------------------------------------
func draw(ci: CanvasItem, m: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	ci.draw_rect(Rect2(0, 0, 1280, 720), Color(0.07, 0.055, 0.045))
	UI.gear(ci, Vector2(1180, 650), 110.0, 12, Color(Data.BRONZE, 0.05), now * 0.1)
	UI.gear(ci, Vector2(90, 60), 80.0, 10, Color(Data.GOLD, 0.04), -now * 0.12)
	UI.text_c(ci, Vector2(640, 50), T.t("HOWTO_TITLE"), 30, Data.GOLD, 4)
	UI.button(ci, BACK, T.t("HOWTO_BACK"), BACK.has_point(m))
	for i in TABS:
		_draw_tab(ci, i, m)
	_draw_image(ci, now)
	_draw_text(ci)
	_draw_footer(ci, m, now)


func _draw_tab(ci: CanvasItem, i: int, m: Vector2) -> void:
	var r := tab_rect(i)
	var on := i == tab
	var hov := r.has_point(m)
	var bg := Color(Data.GOLD, 0.32) if on else (Color(Data.BRONZE, 0.28) if hov else Color(0.12, 0.09, 0.07, 0.95))
	UI.panel(ci, r, bg, Data.GOLD if on else Color(Data.BRONZE, 0.7 if hov else 0.45), 2.5 if on else 1.5)
	if on:
		ci.draw_rect(Rect2(r.position.x, r.end.y - 4, r.size.x, 4), Data.GOLD)
	var num_c := Vector2(r.position.x + 15, r.get_center().y)
	ci.draw_circle(num_c, 9.0, Color(0, 0, 0, 0.5))
	UI.ring(ci, num_c, 9.0, Data.GOLD if on else Color(Data.BRONZE, 0.8), 1.5)
	UI.text_c(ci, num_c + Vector2(0, 4), str(i + 1), 11, Data.GOLD if on else Color(1, 1, 1, 0.75))
	var label := T.t("HOWTO_TAB_%d" % (i + 1))
	UI.text_c(ci, Vector2(r.position.x + TAB_TEXT_X + (r.size.x - TAB_TEXT_X - 4) * 0.5, r.get_center().y + 5), label, tab_font_size(), Color.WHITE if on else Color(1, 1, 1, 0.8))


## Início do nome dentro da aba (depois do número).
const TAB_TEXT_X := 28.0


## Mesmo tamanho de letra em todas as abas: o maior em que todos os nomes cabem.
static func tab_font_size() -> int:
	var size := 14
	for i in TABS:
		size = mini(size, _fit(T.t("HOWTO_TAB_%d" % (i + 1)), 148.0 - TAB_TEXT_X - 8.0, 14, 10))
	return size


static func shot_path(i: int, lang: String) -> String:
	return SHOT % [i + 1, lang]


func _draw_image(ci: CanvasItem, now: float) -> void:
	ci.draw_rect(IMG.grow(4), Color(0, 0, 0, 0.6))
	var tex := Art.tex(shot_path(tab, T.lang()))
	if tex == null:
		tex = Art.tex(shot_path(tab, "pt"))
	if tex != null:
		ci.draw_texture_rect(tex, IMG, false)
	else:
		ci.draw_rect(IMG, Color(0.12, 0.09, 0.07))
	ci.draw_rect(IMG.grow(2), Data.BRONZE, false, 2.0)
	if ZOOMS.has(tab):
		_draw_zoom(ci, tab)
	var pulse := 0.5 + 0.5 * sin(now * 4.0)
	for mk in marks(tab):
		_draw_mark(ci, mk, pulse)


func _draw_zoom(ci: CanvasItem, i: int) -> void:
	var zm: Dictionary = ZOOMS[i]
	var src: Rect2 = zm["src"]
	var dst := Rect2(to_screen(zm["dst"].position), zm["dst"].size * IMG_SCALE)
	var sr := Rect2(to_screen(src.position), src.size * IMG_SCALE)
	var round: bool = zm.get("circle", false)
	var tex := Art.tex(zoom_path(i, T.lang()))
	if tex == null:
		tex = Art.tex(zoom_path(i, "pt"))
	var col := Color(Data.BRONZE, 0.9)
	# Ligação entre o original e a lupa: contorno no original e um fio até a moldura.
	var frame := zoom_frame(i)
	if round:
		UI.ring(ci, sr.get_center(), sr.size.x * 0.5, col, 1.5)
	else:
		ci.draw_rect(sr.grow(1), col, false, 1.5)
	var a := Vector2(sr.get_center().x, sr.position.y)
	var b := Vector2(clampf(a.x, frame.position.x + 12, frame.end.x - 12), frame.end.y)
	ci.draw_line(a, b, col, 1.5, true)
	ci.draw_circle(b, 3.0, col)
	# Moldura: fundo escuro, borda limpa.
	UI.panel(ci, frame, Color(0.05, 0.04, 0.03, 0.97), Data.BRONZE, 2.5)
	ci.draw_rect(frame.grow(-4), Color(Data.GOLD, 0.25), false, 1.0)
	if tex != null:
		ci.draw_texture_rect(tex, dst, false)
	if round:
		UI.ring(ci, dst.get_center(), dst.size.x * 0.5 * ZOOM_CIRCLE, Color(Data.GOLD, 0.6), 1.5)


func _draw_mark(ci: CanvasItem, mk: Dictionary, pulse: float) -> void:
	var col := Color(Data.GOLD, 0.75 + 0.25 * pulse)
	var lay := mark_layout(mk)
	for s in mk["shapes"]:
		if s is Rect2:
			var r := Rect2(to_screen(s.position), s.size * IMG_SCALE).grow(2)
			ci.draw_rect(r, Color(0, 0, 0, 0.55), false, 4.0)
			ci.draw_rect(r, col, false, 2.0)
		else:
			var cc := to_screen(s[0])
			var rr: float = s[1] * IMG_SCALE
			if rr > 0.0:
				UI.ring(ci, cc, rr, Color(0, 0, 0, 0.55), 4.0)
				UI.ring(ci, cc, rr, col, 2.0)
			else:
				# Raio 0: só a seta, com um ponto no alvo.
				ci.draw_circle(cc, 3.5, Color(0, 0, 0, 0.6))
				ci.draw_circle(cc, 2.5, col)
	for ar in lay["arrows"]:
		_arrow(ci, ar[0], ar[1], col)
	var box: Rect2 = lay["box"]
	UI.panel(ci, box, Color(0.08, 0.06, 0.05, 0.92), Data.GOLD, 1.5)
	UI.text_c(ci, Vector2(box.get_center().x, box.end.y - 6), lay["label"], MARK_FONT, Color.WHITE)


## Ponto da borda do retângulo na direção de `toward` (a partir do centro).
static func _rect_edge(r: Rect2, toward: Vector2) -> Vector2:
	var c := r.get_center()
	var d := toward - c
	if d.length() < 0.01:
		return c
	var sx: float = INF if absf(d.x) < 0.001 else (r.size.x * 0.5) / absf(d.x)
	var sy: float = INF if absf(d.y) < 0.001 else (r.size.y * 0.5) / absf(d.y)
	return c + d * minf(minf(sx, sy), 1.0)


static func _arrow(ci: CanvasItem, a: Vector2, b: Vector2, col: Color) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x)
	ci.draw_line(a, b - d * 6.0, Color(0, 0, 0, 0.6), 4.0, true)
	ci.draw_line(a, b - d * 6.0, col, 2.0, true)
	ci.draw_colored_polygon(PackedVector2Array([b, b - d * 10.0 + n * 5.0, b - d * 10.0 - n * 5.0]), col)


func _draw_text(ci: CanvasItem) -> void:
	UI.panel(ci, TEXT, Color(0.1, 0.08, 0.06, 0.95), Color(Data.BRONZE, 0.7), 2.0)
	# Faixa com número e nome da aba (mesmo estilo das faixas da galeria).
	var band := Rect2(TEXT.position + Vector2(12, 12), Vector2(TEXT.size.x - 24, 32))
	ci.draw_rect(band, Color(Data.GOLD, 0.2))
	ci.draw_rect(Rect2(band.position, Vector2(5, band.size.y)), Data.GOLD)
	ci.draw_line(Vector2(band.position.x, band.end.y), band.end, Color(Data.GOLD, 0.8), 2.0)
	UI.text_l(ci, band.position + Vector2(16, 22), ("%d · %s" % [tab + 1, T.t("HOWTO_TAB_%d" % (tab + 1))]).to_upper(), 16, Data.GOLD.lightened(0.25), 2)
	var f := UI.font()
	var x := TEXT.position.x + 18
	var w := TEXT.size.x - 36
	var keys := bullet_keys(tab)
	# Diminui a letra se os textos não couberem no painel.
	var bs := 15
	while bs > 11 and _text_height(T.t("HOWTO_OPEN_%d" % (tab + 1)), keys, w, bs) > TEXT.size.y - 70:
		bs -= 1
	var y := band.end.y + 16
	var open := T.t("HOWTO_OPEN_%d" % (tab + 1))
	ci.draw_multiline_string(f, Vector2(x, y + bs + 1), open, HORIZONTAL_ALIGNMENT_LEFT, w, bs + 1, -1, Color(1.0, 0.88, 0.62))
	y += f.get_multiline_string_size(open, HORIZONTAL_ALIGNMENT_LEFT, w, bs + 1).y + 14
	ci.draw_line(Vector2(x, y - 6), Vector2(x + w, y - 6), Color(Data.BRONZE, 0.5), 1.0)
	for k in keys:
		var s := bullet_text(k)
		UI.gear(ci, Vector2(x + 6, y + bs * 0.62), 6.0, 6, Color(Data.GOLD, 0.85))
		ci.draw_circle(Vector2(x + 6, y + bs * 0.62), 2.0, Color(0.1, 0.08, 0.06))
		ci.draw_multiline_string(f, Vector2(x + 20, y + bs), s, HORIZONTAL_ALIGNMENT_LEFT, w - 20, bs, -1, Color(1, 1, 1, 0.9))
		y += f.get_multiline_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, w - 20, bs).y + 10


## Altura do texto (abertura e tópicos) com a letra `bs`.
static func _text_height(open: String, keys: Array, w: float, bs: int) -> float:
	var f := UI.font()
	var h := f.get_multiline_string_size(open, HORIZONTAL_ALIGNMENT_LEFT, w, bs + 1).y + 14
	for k in keys:
		h += f.get_multiline_string_size(bullet_text(k), HORIZONTAL_ALIGNMENT_LEFT, w - 20, bs).y + 10
	return h


func _draw_footer(ci: CanvasItem, m: Vector2, now: float) -> void:
	var pv := posmod(tab - 1, TABS)
	var nx := posmod(tab + 1, TABS)
	UI.button(ci, PREV, "‹ " + T.t("HOWTO_TAB_%d" % (pv + 1)), PREV.has_point(m), false, 13)
	UI.button(ci, NEXT, T.t("HOWTO_TAB_%d" % (nx + 1)) + " ›", NEXT.has_point(m), false, 13)
	if tab == 3:
		draw_wheel_anim(ci, now)
	else:
		for i in TABS:
			var c := Vector2(640 + (i - 3.5) * 22.0, 624)
			ci.draw_circle(c, 5.0 if i == tab else 3.5, Data.GOLD if i == tab else Color(Data.BRONZE, 0.6))
	UI.text_c(ci, Vector2(640, 708), T.t("HOWTO_KEYS"), 12, Color(1, 1, 1, 0.5))


## Bônus de cada elo (texto depois de ": " nas linhas da dica da roda).
static func link_bonus() -> Array:
	var keys := [["WHEEL_TIP_MOVE_CTRL", int(round(Data.GEAR_CTRL_BONUS * 100.0))],
		["WHEEL_TIP_CTRL_ATK", int(round(Data.GEAR_DMG_BONUS * 100.0))],
		["WHEEL_TIP_ATK_DEF", int(round(Data.GEAR_DEF_BONUS * 100.0))],
		["WHEEL_TIP_DEF_MOVE", int(Data.GEAR_MOVE_SHIELD)]]
	var out: Array = []
	for k in keys:
		var s := T.tf(k[0], [k[1]])
		var p := s.find(": ")
		out.append(s.substr(p + 2) if p >= 0 else s)
	return out


const GEAR_KEYS := ["GEAR_MOVE", "GEAR_CONTROL", "GEAR_ATTACK", "GEAR_DEFENSE"]
const ANIM_STEP := 0.9
const ANIM_HOLD := 1.8


## Quantas engrenagens estão acesas no instante `now` (1 a 5; 5 = volta completa).
static func anim_lit(now: float) -> int:
	var cyc := fmod(now, 5.0 * ANIM_STEP + ANIM_HOLD)
	return mini(5, int(cyc / ANIM_STEP) + 1)


## Faixa animada da aba Roda do Destino: Movimento › Controle › Ataque › Defesa
## › Movimento acendendo em sequência, com o bônus de cada elo.
func draw_wheel_anim(ci: CanvasItem, now: float) -> void:
	var lit := anim_lit(now)
	var bonus := link_bonus()
	var y := 638.0
	var xs: Array = []
	for k in 5:
		xs.append(300.0 + k * 170.0)
	for k in 5:
		var g: int = k % 4
		var on := k < lit
		var newest := k == lit - 1
		var c := Vector2(xs[k], y)
		if k > 0:
			# Elo entre a engrenagem anterior e esta, com o bônus.
			var a := Vector2(xs[k - 1] + 24, y)
			var b := Vector2(xs[k] - 24, y)
			ci.draw_line(a, b, Data.GOLD if on else Color(Data.BRONZE, 0.35), 3.0 if on else 1.5)
			UI.text_c(ci, (a + b) * 0.5 + Vector2(0, -6), "›", 16, Data.GOLD if on else Color(Data.BRONZE, 0.5))
			UI.text_c(ci, (a + b) * 0.5 + Vector2(0, 16), bonus[k - 1], 12, Color(1.0, 0.9, 0.6) if on else Color(1, 1, 1, 0.3))
		if newest:
			var p := 0.5 + 0.5 * sin(now * 10.0)
			ci.draw_circle(c, 26.0, Color(Data.GOLD, 0.2 + 0.2 * p))
		UI.gear(ci, c, 20.0, 9, Color(0.35, 0.25, 0.08) if on else Color(0.12, 0.09, 0.06), now * 1.5 if on else 0.0)
		UI.ring(ci, c, 19.0, Data.GOLD if on else Color(Data.BRONZE, 0.6), 2.0)
		UI.effect_icon(ci, Data.GEAR_ICON[g], c, 7.0, Color(1, 1, 1, 0.95 if on else 0.4))
		UI.text_c(ci, c + Vector2(0, 40), T.t(GEAR_KEYS[g]), 12, Data.GOLD if on else Color(1, 1, 1, 0.45))
	if lit >= 5:
		UI.text_c(ci, Vector2(640, 610), T.tf("WHEEL_TIP_FULL", [int(Data.FULL_TURN_ULT)]), 13, Data.GOLD, 3)


static func _fit(s: String, w: float, big: int, small: int) -> int:
	var size := big
	while size > small and UI.font().get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > w:
		size -= 1
	return size
