extends SceneTree
## Gera as capturas das 8 abas de "Como jogar" (assets/help/howto_N_pt.jpg e
## howto_N_en.jpg, 800 × 450: o HUD aparece no idioma de quem lê),
## cada uma a partir de uma cena preparada da partida (ou da seleção, na aba 2).
## Uso (precisa de tela; no servidor, com xvfb-run):
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 --script res://tools/howto_shots.gd -- [aba] [--lang=pt|en]
## Sem número, gera as 8; sem --lang, os dois idiomas. As marcações (setas, contornos, legendas) são
## desenhadas por código na tela "Como jogar" (scripts/howto.gd), não na imagem.

const GameScript = preload("res://scripts/game.gd")
const SelectScript = preload("res://scripts/select.gd")
const Data = preload("res://scripts/data.gd")
const T = preload("res://scripts/i18n.gd")
const HowTo = preload("res://scripts/howto.gd")

const OUT := "res://assets/help/howto_%d_%s.jpg"
const SIZE := Vector2i(800, 450)

var tabs: Array = []
var langs: Array = ["pt", "en"]
var jobs: Array = []
var cur := -1
var node: Node = null
var frames := 0


func _initialize() -> void:
	tabs = [1, 2, 3, 4, 5, 6, 7, 8]
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			tabs = [a.to_int()]
		elif a.begins_with("--lang="):
			langs = [a.trim_prefix("--lang=")]
	for l in langs:
		for tb in tabs:
			jobs.append([tb, l])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/help"))
	_next()


func _next() -> void:
	Engine.time_scale = 1.0
	if node != null:
		node.free()
		node = null
	cur += 1
	if cur >= jobs.size():
		quit()
		return
	T.set_lang(jobs[cur][1], false)
	node = _scene(jobs[cur][0])
	Engine.time_scale = 0.0
	frames = 0


func _process(_d: float) -> bool:
	frames += 1
	if frames == 5:
		var img := root.get_viewport().get_texture().get_image()
		var tb: int = jobs[cur][0] - 1
		if HowTo.ZOOMS.has(tb):
			# Lupa: recorte em tamanho real (sem a redução para 800 × 450).
			var zr: Rect2 = HowTo.ZOOMS[tb]["src"]
			var crop := img.get_region(Rect2i(zr))
			if HowTo.ZOOMS[tb].get("circle", false):
				# Só a roda: fora do círculo fica transparente (borda suave de 1,5 px).
				crop.convert(Image.FORMAT_RGBA8)
				var c := Vector2(crop.get_width(), crop.get_height()) * 0.5
				var rad: float = c.x * HowTo.ZOOM_CIRCLE
				for y in crop.get_height():
					for x in crop.get_width():
						var d := Vector2(x + 0.5, y + 0.5).distance_to(c)
						var px := crop.get_pixel(x, y)
						px.a = clampf((rad - d) / 1.5 + 0.5, 0.0, 1.0)
						crop.set_pixel(x, y, px)
			var zp := ProjectSettings.globalize_path(HowTo.zoom_path(tb, jobs[cur][1]))
			crop.save_png(zp)
			print("SHOT ", zp)
		img.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_LANCZOS)
		var path := ProjectSettings.globalize_path(OUT % jobs[cur])
		img.save_jpg(path, 0.9)
		print("SHOT ", path)
		_next()
	return false


## Partida montada à mão: times padrão contra Hércules/Zeus/Atena, aos 1:48
## (relógio em 3:12), sem bots e sem efeitos na tela; cada aba ajusta o resto.
func _match() -> Node2D:
	seed(77)
	var g := Node2D.new()
	g.set_script(GameScript)
	root.add_child(g)
	g.setup({"bots": false, "difficulty": "normal",
		"teams": [Data.DEFAULT_TEAM.duplicate(), ["hercules", "zeus", "atena"]]})
	g.set_process(false)
	g.hud.set_process(false)
	g.time = 108.0
	g._announced_unlock = true
	g.announce_text = ""
	g.announce_t = 0.0
	g.progress = [22.0, 17.0]
	g.point_owner = 0
	g.hud.hover = -1
	var blue := [Vector2(610, 300), Vector2(560, 255), Vector2(545, 345)]
	var red := [Vector2(790, 290), Vector2(870, 250), Vector2(880, 350)]
	for i in 3:
		_place(g.team_hero(0, i), blue[i], 0.85 - 0.15 * i)
		_place(g.team_hero(1, i), red[i], 0.7 + 0.1 * i)
	cmd_defaults(g.commanders[0])
	return g


func _place(h, pos: Vector2, frac: float) -> void:
	h.position = pos
	h.alive = true
	h.visible = true
	h.retreating = false
	h.hp = h.max_hp * frac
	h.ult = 40.0


func cmd_defaults(c) -> void:
	c.ichor = 5.0
	c.hand = ["armadilha", "muralha", "valvula", "veneno"]


func _scene(tab: int) -> Node:
	if tab == 2:
		var s := Node2D.new()
		s.set_script(SelectScript)
		root.add_child(s)
		s.open()
		s.team = Data.DEFAULT_TEAM.duplicate()
		s.focus = "zeus"
		return s
	var g := _match()
	var cmd = g.commanders[0]
	match tab:
		1:
			g.point_owner = 0
			g.progress = [46.0, 31.0]
			g.capture_prog = 0.0
			g.capture_team = -1
			g.team_hero(1, 0).position = Vector2(905, 260)
			g.team_hero(1, 1).position = Vector2(960, 330)
			g.team_hero(1, 2).position = Vector2(1000, 280)
		3:
			cmd.ichor = 6.4
			cmd.hand = ["investida", "disparo", "sopro", "muralha"]
		4:
			cmd.ichor = 7.0
			cmd.hand = ["armadilha", "muralha", "salto", "veneno"]
			var w = g.wheels[0]
			w.gear = 0
			w.t = 3.3
			w.links = 2
		5:
			var hs: Array = []
			for i in 3:
				hs.append(g.team_hero(0, i))
			hs[0].ult = 100.0
			hs[1].ult = 62.0
			hs[2].ult = 35.0
		6:
			cmd.behavior = "balanced"
			g.hud.force_tip = {"kind": "beh", "i": 1}
			g.hud.tip = g.hud.force_tip.duplicate()
		7:
			var tl = g.get_hero(0, "talos")
			var ar = g.get_hero(0, "artemis")
			var asc = g.get_hero(0, "asclepio")
			# Altar-forja: Asclépio na base, curando.
			asc.position = g.spawn_pos(0) + Vector2(10, 0)
			asc.hp = asc.max_hp * 0.6
			# Centelha Viva: Ártemis ferida, longe do perigo.
			ar.position = HowTo.SCENE_SPARK
			ar.hp = ar.max_hp * 0.55
			ar.calm_t = 10.0
			ar.regenerating = true
			# Cobertura: Talos atrás da coluna (330, 300), do lado da própria base.
			tl.position = Vector2(280, 300)
			tl.hp = tl.max_hp * 0.45
			tl.covering = true
			tl.calm_t = 10.0
			tl.regenerating = true
			for h in [tl, ar, asc]:
				h.retreating = false
			for pk in g.packs:
				if pk["pos"].distance_to(HowTo.HOWTO_PACKS[1]) < 1.0:
					pk["t"] = 17.0    # vazio, volta em 17 s (o outro fica disponível)
			g.point_owner = -1
			g.team_hero(1, 0).position = Vector2(700, 280)
			g.team_hero(1, 1).position = Vector2(760, 230)
			g.team_hero(1, 2).position = Vector2(780, 340)
		8:
			g.hud.set_paused(true)
	for h in g.heroes:
		h.queue_redraw()
	g.queue_redraw()
	g.hud.queue_redraw()
	return g
