extends SceneTree
## Prévia das plantas da arena nova (Pacote 6, etapa 1; item 50).
## Para cada arenas/<id>.json: monta a partida com a planta, desenha paredes,
## muretas, caldeiras e estátuas por cima, as 3 rotas do time azul (caminho
## mais curto por A*, passando pelos pontos de passagem do arquivo) e os
## gargalos; mede o tempo de caminhada base › ponto e salva a captura.
## Uso (precisa de tela; no servidor, com xvfb-run):
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 --script res://tools/arena_preview.gd -- <saída> [id ...]

const GameScript = preload("res://scripts/game.gd")
const Arena = preload("res://scripts/arena.gd")
const Data = preload("res://scripts/data.gd")
const UI = preload("res://scripts/ui.gd")
const T = preload("res://scripts/i18n.gd")

const IDS := ["classica", "opcao_a", "opcao_b", "opcao_c"]
const CELL := 8
const HERO_R := 18.0
## Velocidade média do elenco (Talos 72, Hércules 80, Ártemis 92, Atena 88,
## Zeus 96, Asclépio 90) e a do mais lento.
const SPEED_AVG := 86.3
const SPEED_SLOW := 72.0
const ROUTE_COLORS := {"centro": Color(1.0, 0.82, 0.3), "alto": Color(0.35, 0.85, 1.0), "baixo": Color(0.95, 0.45, 0.85)}
const ROUTE_NAMES := {"centro": "Centro", "alto": "Flanco de cima", "baixo": "Flanco de baixo"}

var out_dir := ""
var ids: Array = []
var cur := -1
var game: Node2D = null
var overlay: Node2D = null
var frames := 0
var report: Array = []


func _initialize() -> void:
	T.set_lang("pt", false)
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "user://"
	ids = args.slice(1) if args.size() > 1 else IDS.duplicate()
	_next()


func _next() -> void:
	Engine.time_scale = 1.0
	if game != null:
		game.free()
		overlay.free()
	cur += 1
	if cur >= ids.size():
		for line in report:
			print(line)
		quit()
		return
	var def := Arena.load_def("res://arenas/%s.json" % ids[cur])
	var obs := Arena.obstacles(def)
	var info := measure(def, obs)
	report.append("%s: %s folga %s" % [ids[cur], JSON.stringify(info["times"]), info["clear"]])
	game = _game(def, obs)
	overlay = Node2D.new()
	overlay.set_script(Overlay)
	overlay.def = def
	overlay.obs = obs
	overlay.info = info
	root.add_child(overlay)
	Engine.time_scale = 0.0
	frames = 0


func _process(_d: float) -> bool:
	frames += 1
	if frames == 5:
		var img := root.get_viewport().get_texture().get_image()
		var path := out_dir.path_join("arena_%s.png" % ids[cur])
		img.save_png(path)
		print("SHOT ", path)
		_next()
	return false


func _game(def: Dictionary, obs: Array) -> Node2D:
	var g := Node2D.new()
	g.set_script(GameScript)
	root.add_child(g)
	g.setup({"bots": false, "difficulty": "normal",
		"teams": [Data.DEFAULT_TEAM.duplicate(), ["hercules", "zeus", "atena"]]})
	g.set_process(false)
	g.hud.visible = false
	g.time = 108.0
	g._announced_unlock = true
	g.announce_text = ""
	# Só as colunas ficam com o desenho do jogo; o resto a prévia desenha.
	var cols: Array = []
	for o in obs:
		if o["tipo"] == "coluna":
			cols.append(Vector3(o["c"].x, o["c"].y, o["r"]))
	g.obstacles = cols
	g.packs.clear()
	for p in Arena.packs(def):
		g.packs.append({"pos": p, "t": 0.0})
	for h in g.heroes:
		h.visible = false
	g.queue_redraw()
	return g


# --- Caminhos -----------------------------------------------------------------
var _astar: AStarGrid2D = null


func _grid(obs: Array) -> AStarGrid2D:
	var a := AStarGrid2D.new()
	a.region = Rect2i(0, 0, 1280 / CELL, 520 / CELL)
	a.cell_size = Vector2(CELL, CELL)
	a.offset = Vector2(CELL * 0.5, 40 + CELL * 0.5)
	a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	a.default_compute_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	a.default_estimate_heuristic = AStarGrid2D.HEURISTIC_EUCLIDEAN
	a.update()
	var enemy_base := Vector2(1218, 300)
	for x in a.region.size.x:
		for y in a.region.size.y:
			var p := a.offset + Vector2(x, y) * CELL
			var solid := not Arena.free_at(obs, p, HERO_R)
			solid = solid or p.x < HERO_R or p.x > 1280 - HERO_R or p.y < 40 + HERO_R or p.y > 560 - HERO_R
			solid = solid or p.distance_to(enemy_base) < 75.0 + HERO_R
			a.set_point_solid(Vector2i(x, y), solid)
	return a


func _cell(p: Vector2) -> Vector2i:
	var c := ((p - _astar.offset) / CELL).round()
	return Vector2i(clampi(int(c.x), 0, _astar.region.size.x - 1), clampi(int(c.y), 0, _astar.region.size.y - 1))


## Caminho mais curto (com atalhos em linha reta onde dá).
func _path(a: Vector2, b: Vector2, obs: Array) -> PackedVector2Array:
	var raw := _astar.get_point_path(_cell(a), _cell(b), true)
	if raw.is_empty():
		return raw
	raw[0] = a
	# Atalhos: liga cada ponto ao mais distante que ainda se vê sem raspar parede.
	var out := PackedVector2Array([raw[0]])
	var i := 0
	while i < raw.size() - 1:
		var j := raw.size() - 1
		while j > i + 1 and not _walkable(raw[i], raw[j], obs):
			j -= 1
		out.append(raw[j])
		i = j
	return out


func _walkable(a: Vector2, b: Vector2, obs: Array) -> bool:
	var n := int(a.distance_to(b) / 4.0) + 1
	for k in n + 1:
		if not Arena.free_at(obs, a.lerp(b, float(k) / n), HERO_R - 1.0):
			return false
	return true


## Mede as 3 rotas: da base (62, 300) até entrar no ponto (raio 95).
func measure(def: Dictionary, obs: Array) -> Dictionary:
	_astar = _grid(obs)
	var routes := {}
	var times := {}
	var center := Vector2(640, 300)
	for key in ["centro", "alto", "baixo"]:
		var wps: Array = def.get("rotas", {}).get(key, [])
		var pts := PackedVector2Array([Vector2(62, 300)])
		var stops: Array = []
		for w in wps:
			stops.append(Vector2(w[0], w[1]))
		stops.append(center)
		var full := PackedVector2Array([Vector2(62, 300)])
		var at := Vector2(62, 300)
		for s in stops:
			var seg := _path(at, s, obs)
			for k in range(1, seg.size()):
				full.append(seg[k])
			at = s
		# Corta no primeiro ponto dentro do círculo do ponto de controle.
		var cut := PackedVector2Array([full[0]])
		var length := 0.0
		for k in range(1, full.size()):
			var a2: Vector2 = full[k - 1]
			var b2: Vector2 = full[k]
			if b2.distance_to(center) <= Data.POINT_R:
				# entra no círculo neste trecho
				var lo := 0.0
				var hi := 1.0
				for it in 20:
					var mid := (lo + hi) * 0.5
					if a2.lerp(b2, mid).distance_to(center) <= Data.POINT_R:
						hi = mid
					else:
						lo = mid
				var e := a2.lerp(b2, hi)
				length += a2.distance_to(e)
				cut.append(e)
				break
			length += a2.distance_to(b2)
			cut.append(b2)
		routes[key] = cut
		times[key] = [snappedf(length, 1.0), snappedf(length / SPEED_AVG, 0.1), snappedf(length / SPEED_SLOW, 0.1)]
	# Folga em volta do ponto: distância do centro até o obstáculo mais perto.
	var clear := INF
	for o in obs:
		clear = minf(clear, Arena.distance(o, center))
	return {"routes": routes, "times": times, "clear": snappedf(clear, 1.0)}


# --- Desenho da planta -------------------------------------------------------
class Overlay extends Node2D:
	const Arena = preload("res://scripts/arena.gd")
	const UI = preload("res://scripts/ui.gd")
	const Data = preload("res://scripts/data.gd")
	var def: Dictionary
	var obs: Array
	var info: Dictionary

	func _draw() -> void:
		for o in obs:
			_draw_obstacle(o)
		# Rotas (time azul; o vermelho é o espelho).
		for key in ["alto", "baixo", "centro"]:
			var pts: PackedVector2Array = info["routes"][key]
			var col: Color = ROUTE_COLORS[key]
			if pts.size() < 2:
				continue
			for k in range(1, pts.size()):
				draw_line(pts[k - 1], pts[k], Color(0, 0, 0, 0.55), 9.0, true)
			for k in range(1, pts.size()):
				draw_line(pts[k - 1], pts[k], Color(col, 0.9), 5.0, true)
			# setas ao longo do caminho
			var total := 0.0
			for k in range(1, pts.size()):
				total += pts[k - 1].distance_to(pts[k])
			var marks := [0.3, 0.62, 1.0]
			for f in marks:
				var want: float = total * f
				var acc := 0.0
				for k in range(1, pts.size()):
					var seg: float = pts[k - 1].distance_to(pts[k])
					if acc + seg >= want - 0.01:
						var t := clampf((want - acc) / maxf(seg, 0.01), 0.0, 1.0)
						var p: Vector2 = pts[k - 1].lerp(pts[k], t)
						var d: Vector2 = (pts[k] - pts[k - 1]).normalized()
						var n := Vector2(-d.y, d.x)
						draw_colored_polygon(PackedVector2Array([p + d * 11, p - d * 7 + n * 9, p - d * 7 - n * 9]), Color(0, 0, 0, 0.6))
						draw_colored_polygon(PackedVector2Array([p + d * 9, p - d * 5 + n * 7, p - d * 5 - n * 7]), col)
						break
					acc += seg
		# Gargalos: faixa vermelha no vão, com as pontas marcadas.
		var n_g := 0
		for g in Arena.chokes(def):
			n_g += 1
			var a: Vector2 = g[0]
			var b: Vector2 = g[1]
			var dir := (b - a).normalized()
			var k := 0.0
			var L := a.distance_to(b)
			while k < L:
				draw_line(a + dir * k, a + dir * minf(k + 8.0, L), Color(1, 0.25, 0.2, 0.95), 4.0)
				k += 14.0
			var nn := Vector2(-dir.y, dir.x)
			for e in [a, b]:
				draw_line(e - nn * 9, e + nn * 9, Color(1, 0.25, 0.2), 4.0)
		_draw_legend()
		UI.text_c(self, Vector2(640, 28), "Planta proposta · arena 1280 × 520 · rotas do time azul", 15, Color(1, 1, 1, 0.75))

	func _draw_obstacle(o: Dictionary) -> void:
		var tipo: String = o["tipo"]
		if o["circulo"]:
			var c: Vector2 = o["c"]
			var r: float = o["r"]
			if tipo == "coluna":
				return  # o jogo já desenha
			draw_circle(c + Vector2(0, 6), r, Color(0, 0, 0, 0.4))
			if tipo == "caldeira":
				draw_circle(c, r, Color(0.45, 0.25, 0.12))
				draw_circle(c, r * 0.82, Color(0.68, 0.38, 0.18))
				UI.gear(self, c, r * 0.5, 8, Color(0.4, 0.2, 0.1), 0.0)
				draw_circle(c, r * 0.22, Color(1.0, 0.55, 0.15))
				UI.ring(self, c, r, Color(0.95, 0.65, 0.3), 3.0)
				for k in 8:
					var ang := TAU * k / 8.0
					draw_circle(c + Vector2(cos(ang), sin(ang)) * r * 0.9, 2.5, Color(0.95, 0.75, 0.4))
			else:  # estátua
				draw_circle(c, r, Color(0.42, 0.42, 0.45))
				draw_circle(c, r * 0.7, Color(0.62, 0.62, 0.66))
				draw_circle(c + Vector2(0, -r * 0.15), r * 0.32, Color(0.78, 0.78, 0.8))
				UI.ring(self, c, r, Color(0.85, 0.85, 0.9), 2.5)
			return
		var rr: Rect2 = o["ret"]
		draw_rect(Rect2(rr.position + Vector2(0, 6), rr.size), Color(0, 0, 0, 0.4))
		if tipo == "mureta":
			# Baixa: tiros passam por cima. Tom claro e borda tracejada.
			draw_rect(rr, Color(0.62, 0.5, 0.32, 0.9))
			var k := 0.0
			while k < rr.size.x:
				draw_line(Vector2(rr.position.x + k, rr.position.y), Vector2(rr.position.x + minf(k + 6, rr.size.x), rr.position.y), Color(1, 0.92, 0.7), 2.0)
				draw_line(Vector2(rr.position.x + k, rr.end.y), Vector2(rr.position.x + minf(k + 6, rr.size.x), rr.end.y), Color(1, 0.92, 0.7), 2.0)
				k += 10.0
			k = 0.0
			while k < rr.size.y:
				draw_line(Vector2(rr.position.x, rr.position.y + k), Vector2(rr.position.x, rr.position.y + minf(k + 6, rr.size.y)), Color(1, 0.92, 0.7), 2.0)
				draw_line(Vector2(rr.end.x, rr.position.y + k), Vector2(rr.end.x, rr.position.y + minf(k + 6, rr.size.y)), Color(1, 0.92, 0.7), 2.0)
				k += 10.0
		else:
			draw_rect(rr, Color(0.3, 0.2, 0.12))
			draw_rect(rr.grow(-4), Color(0.48, 0.32, 0.17))
			draw_rect(rr, Color(0.9, 0.65, 0.32), false, 2.5)
			# rebites
			var step := 18.0
			var x := rr.position.x + 8.0
			while x < rr.end.x - 4:
				var y := rr.position.y + 8.0
				while y < rr.end.y - 4:
					draw_circle(Vector2(x, y), 2.0, Color(0.95, 0.75, 0.4))
					y += step
				x += step

	func _draw_legend() -> void:
		var p := Rect2(0, 560, 1280, 160)
		draw_rect(p, Color(0.07, 0.055, 0.045))
		draw_line(Vector2(0, 561), Vector2(1280, 561), Color(Data.BRONZE, 0.8), 2.0)
		UI.text_l(self, Vector2(24, 594), def.get("nome", ""), 24, Data.GOLD, 3)
		# Rotas e tempos
		var y := 626.0
		var times: Dictionary = info["times"]
		UI.text_l(self, Vector2(24, y), "Base › ponto (vel. média 86 / Talos 72):", 14, Color(1, 1, 1, 0.7))
		y += 24.0
		for key in ["centro", "alto", "baixo"]:
			var col: Color = ROUTE_COLORS[key]
			draw_line(Vector2(24, y - 5), Vector2(60, y - 5), col, 5.0)
			var t: Array = times[key]
			UI.text_l(self, Vector2(70, y), "%s: %d px · %.1f s / %.1f s" % [ROUTE_NAMES[key], int(t[0]), t[1], t[2]], 15, Color.WHITE)
			y += 22.0
		# Tipos de obstáculo
		var lx := 560.0
		var ly := 600.0
		var items := [["parede", "Parede / parede em L (bloqueia tudo)"], ["mureta", "Mureta (bloqueia passagem; tiros passam)"],
			["caldeira", "Caldeira (peça grande)"], ["estatua", "Estátua (peça grande)"], ["coluna", "Coluna"]]
		for it in items:
			var c := Vector2(lx + 14, ly - 5)
			match it[0]:
				"parede":
					draw_rect(Rect2(c - Vector2(14, 7), Vector2(28, 14)), Color(0.48, 0.32, 0.17))
					draw_rect(Rect2(c - Vector2(14, 7), Vector2(28, 14)), Color(0.9, 0.65, 0.32), false, 2.0)
				"mureta":
					draw_rect(Rect2(c - Vector2(14, 5), Vector2(28, 10)), Color(0.62, 0.5, 0.32))
				"caldeira":
					draw_circle(c, 9, Color(0.68, 0.38, 0.18))
					UI.ring(self, c, 9, Color(0.95, 0.65, 0.3), 2.0)
				"estatua":
					draw_circle(c, 9, Color(0.62, 0.62, 0.66))
				"coluna":
					draw_circle(c, 9, Color(0.6, 0.43, 0.22))
					UI.ring(self, c, 9, Color(0.85, 0.62, 0.3), 2.0)
			UI.text_l(self, Vector2(lx + 36, ly), it[1], 14, Color(1, 1, 1, 0.85))
			ly += 22.0
		# Gargalo e frasco
		var gx := 960.0
		draw_line(Vector2(gx, 595), Vector2(gx + 28, 595), Color(1, 0.25, 0.2), 4.0)
		UI.text_l(self, Vector2(gx + 36, 600), "Gargalo (vão estreito)", 14, Color(1, 1, 1, 0.85))
		draw_circle(Vector2(gx + 14, 617), 7, Color(0.3, 0.85, 0.4))
		UI.text_l(self, Vector2(gx + 36, 622), "Frasco de Ambrosia (%d)" % Arena.packs(def).size(), 14, Color(1, 1, 1, 0.85))
		UI.text_l(self, Vector2(gx, 652), "Folga em volta do ponto: %d px do centro" % int(info["clear"]), 13, Color(1, 1, 1, 0.75))
		UI.text_l(self, Vector2(gx, 672), "Espelhada: o time vermelho tem", 13, Color(1, 1, 1, 0.6))
		UI.text_l(self, Vector2(gx, 690), "as mesmas rotas do outro lado.", 13, Color(1, 1, 1, 0.6))
