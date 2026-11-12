extends SceneTree
## Sequências de quadros para os gifs do Pacote 7 (docs/capturas/visual-2d/).
## Uso (precisa de tela; no servidor, com xvfb-run):
##   godot --path . --rendering-driver opengl3 --resolution 1280x720 --script res://tools/visual_capture.gd -- <pasta> luta|talos
##   luta   partida entre bots: pula até 40 s e grava 4 s (30 quadros/s)
##   talos  Talos sozinho, em sequência: parado, andando, soco, Muralha, levar dano,
##          habilidade (pulinho) e renascer. Com as camadas em assets/heroes/camadas/,
##          usa a animação por peças; sem elas, o sprite inteiro.
## Depois, o gif sai com Python (PIL), juntando os PNG da pasta.

const GameScript = preload("res://scripts/game.gd")
const Data = preload("res://scripts/data.gd")
const T = preload("res://scripts/i18n.gd")

const FPS := 30.0

var out := ""
var mode := "luta"
var g: Node2D = null
var frame := 0
var total := 0
var talos = null
var foe = null
## Na sequência do Talos, a partida fica dentro de um nó ampliado (câmera).
var cam: Node2D = null
const HOME := Vector2(200, 300)
const FOE_AT := Vector2(300, 300)
const ZOOM := 4.0


func _initialize() -> void:
	T.set_lang("pt", false)
	var args := OS.get_cmdline_user_args()
	out = args[0]
	mode = args[1] if args.size() > 1 else "luta"
	DirAccess.make_dir_recursive_absolute(out)
	seed(7)
	# A partida só anda pelos passos deste script (o _process dela fica parado).
	Engine.time_scale = 0.0
	g = Node2D.new()
	g.set_script(GameScript)
	cam = Node2D.new()
	root.add_child(cam)
	cam.add_child(g)
	if mode == "luta":
		g.setup({"autotest": true, "difficulty0": "hard", "difficulty": "hard"})
		g.set_process(false)
		for i in int(40.0 * 60.0):
			g._step(1.0 / 60.0)
		total = int(4.0 * FPS)
	else:
		g.setup({"bots": false, "teams": [["talos", "artemis", "asclepio"], ["hercules", "zeus", "atena"]]})
		g.set_process(false)
		g.time = 30.0
		g._announced_unlock = true
		talos = g.get_hero(0, "talos")
		foe = g.get_hero(1, "zeus")
		for h in g.heroes:
			if h != talos and h != foe:
				h.position = g.spawn_pos(h.team)
				h.visible = false
		talos.position = HOME
		talos.facing = Vector2.RIGHT
		talos.sprite_angle = 0.0
		foe.position = FOE_AT
		g.hud.visible = false
		cam.scale = Vector2(ZOOM, ZOOM)
		cam.position = Vector2(560, 380) - HOME * ZOOM
		foe.facing = Vector2.LEFT
		foe.sprite_angle = PI
		total = int(7.0 * FPS)


func _process(_d: float) -> bool:
	if frame > 0:
		var img := root.get_viewport().get_texture().get_image()
		img.save_png(out.path_join("f_%04d.png" % (frame - 1)))
	if frame >= total:
		quit()
		return false
	var dt := 1.0 / FPS
	if mode == "luta":
		g._step(dt * 0.5)
		g._step(dt * 0.5)
	else:
		_script_talos(frame * dt, dt)
		g.time += dt
	g._update_visuals(dt)
	for h in g.heroes:
		h.queue_redraw()
	g.queue_redraw()
	g.hud.queue_redraw()
	frame += 1
	return false


## Roteiro do Talos (segundos): 0–1 parado, 1–2,4 andando, 2,4–3,2 socos,
## 3,2–4,4 Muralha, 4,4–5,2 leva dano, 5,2–5,8 habilidade, 5,8–7 renasce.
func _script_talos(t: float, dt: float) -> void:
	# Sem os passos da partida, os tempos curtos do herói descem aqui.
	for h in [talos, foe]:
		h.hit_flash = maxf(0.0, h.hit_flash - dt)
		h.swing_t = maxf(0.0, h.swing_t - dt)
	talos.hp = talos.max_hp
	foe.hp = foe.max_hp
	foe.position = FOE_AT
	if t >= 1.0 and t < 2.4:
		talos.position += Vector2(70.0, 0).rotated(sin((t - 1.0) * 2.0) * 0.6) * dt * (1.0 if t < 1.7 else -1.0)
		talos.facing = Vector2.RIGHT if t < 1.7 else Vector2.LEFT
		talos.sprite_angle = talos.facing.angle()
	elif t >= 2.4 and t < 2.45:
		talos.facing = Vector2.RIGHT
		talos.sprite_angle = 0.0
	if t >= 2.4 and t < 3.2 and fmod(t - 2.4, 0.4) < dt:
		talos.lunge_t = talos.LUNGE_T
		talos.swing_t = 0.18
		g.deal_damage(talos, foe, 26.0)
	if t >= 3.2 and t < 3.2 + dt:
		g.cast(talos, "muralha", talos.position + Vector2(100, 0))
	if t >= 4.4 and t < 4.4 + dt:
		talos.wall_t = 0.0
	if t >= 4.5 and t < 5.2 and fmod(t - 4.5, 0.25) < dt:
		g.deal_damage(foe, talos, 18.0)
	if t >= 5.3 and t < 5.3 + dt:
		g.cast(talos, "valvula", talos.position)
	if t >= 5.9 and t < 5.9 + dt:
		g.respawn(talos)
		talos.position = HOME
		talos.anim_prev = talos.position
