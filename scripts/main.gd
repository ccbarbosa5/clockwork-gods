extends Node2D
## Ponto de entrada: alterna entre menu e partida.
## Argumentos de linha de comando (após "--"):
##   --autotest           partida bot contra bot acelerada, imprime o resultado e sai
##   --shot=caminho.png   salva uma captura de tela (requer renderização)
##   --shot-at=segundos   momento da captura (padrão 40)
##   --shot-menu          captura o menu em vez da partida
##   --shot-gallery=heroi captura a Galeria de heróis aberta nesse herói

const GameScript = preload("res://scripts/game.gd")
const MenuScript = preload("res://scripts/menu.gd")
const AudioScript = preload("res://scripts/audio.gd")
const GalleryScript = preload("res://scripts/gallery.gd")
const T = preload("res://scripts/i18n.gd")

var game: Node2D = null
var menu: Node2D = null
var gallery: Node2D = null
var last_opts := {}
var autotest := false
var shot_path := ""
var shot_at := 40.0
var shot_menu := false
var shot_gallery := ""
var _shot_done := false
var _frames := 0


func _ready() -> void:
	randomize()
	T.init()
	for a in OS.get_cmdline_user_args():
		if a == "--autotest":
			autotest = true
		elif a.begins_with("--shot="):
			shot_path = a.substr(7)
		elif a.begins_with("--shot-at="):
			shot_at = a.substr(10).to_float()
		elif a == "--shot-menu":
			shot_menu = true
		elif a.begins_with("--shot-gallery="):
			shot_menu = true
			shot_gallery = a.substr(15)
	var audio := Node.new()
	audio.set_script(AudioScript)
	add_child(audio)
	menu = Node2D.new()
	menu.set_script(MenuScript)
	add_child(menu)
	menu.start.connect(_on_start)
	gallery = Node2D.new()
	gallery.set_script(GalleryScript)
	gallery.visible = false
	add_child(gallery)
	menu.open_gallery.connect(_open_gallery)
	gallery.back.connect(_close_gallery)
	if shot_gallery != "":
		_open_gallery()
		gallery.open(shot_gallery)
	if autotest:
		Engine.time_scale = 20.0
		_on_start({"difficulty": "hard", "autotest": true})
	elif shot_path != "" and not shot_menu:
		Engine.time_scale = 4.0
		_on_start({"difficulty": "normal", "autotest": true})


func _open_gallery() -> void:
	menu.visible = false
	gallery.open()


func _close_gallery() -> void:
	gallery.visible = false
	menu.visible = true


func _on_start(opts: Dictionary) -> void:
	last_opts = opts
	if game != null:
		game.queue_free()
	menu.visible = false
	game = Node2D.new()
	game.set_script(GameScript)
	add_child(game)
	game.setup(opts)
	game.request.connect(_on_request)


func _on_request(action: String) -> void:
	if action == "restart":
		_on_start(last_opts)
	elif action == "menu":
		if game != null:
			game.queue_free()
			game = null
		menu.visible = true


func _process(_delta: float) -> void:
	_frames += 1
	if shot_path != "" and not _shot_done:
		var ready := false
		if shot_menu:
			ready = _frames > 10
		elif game != null and game.time >= shot_at:
			Engine.time_scale = 0.0
			ready = true
		if ready:
			_shot_done = true
			await RenderingServer.frame_post_draw
			var img := get_viewport().get_texture().get_image()
			img.save_png(shot_path)
			print("SHOT_SAVED ", shot_path)
			get_tree().quit(0)
	if autotest and game != null:
		if _frames % 600 == 0:
			print("t=%.0f progresso=%.1f/%.1f dono=%d icor=%.1f/%.1f" % [game.time, game.progress[0], game.progress[1], game.point_owner, game.commanders[0].ichor, game.commanders[1].ichor])
		if game.ended or game.time > 400.0:
			print("RESULTADO vencedor=%d tempo=%.1f progresso=%.1f/%.1f" % [game.result, game.time, game.progress[0], game.progress[1]])
			for h in game.heroes:
				print("  time%d %s %s" % [h.team, h.hid, str(h.stats)])
			for c in game.commanders:
				print("  cmd%d cartas=%d ults=%d" % [c.team, c.cards_played, c.ults_used])
			get_tree().quit(0)
