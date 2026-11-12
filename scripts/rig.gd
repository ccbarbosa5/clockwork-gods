extends RefCounted
## Animação por peças (Pacote 7): herói montado em camadas, cada uma com um
## pivô, movidas por código conforme o estado (parado, andando, ataque,
## habilidade, dano). Equivale a um esqueleto 2D simples, sem cena nem
## AnimationPlayer: as poses são funções do estado, então rodam iguais no
## jogo, nos testes e na versão web.
##
## Camadas em assets/heroes/camadas/<arquivo>.png, todas 256 × 256 no mesmo
## enquadramento do sprite inteiro (heroes/<id>_top.png), virado para a direita.
## Se faltar qualquer camada, o herói usa o sprite inteiro (fallback).
## Pivôs e movimentos: claude/animacao-2d.md (Assets).

const Art = preload("res://scripts/art.gd")

const LAYER_PATH := "res://assets/heroes/camadas/%s.png"
const SIZE := 256.0

## Por herói: camadas de baixo para cima. "parts": recortes da imagem com o
## pivô de cada um (a camada das chaminés tem duas, uma em cada metade).
const RIGS := {
	"talos": [
		{"name": "corpo", "file": "talos_top_corpo", "parts": [[Rect2(0, 0, 256, 256), Vector2(128, 128)]]},
		{"name": "braco_escudo", "file": "talos_top_braco_escudo", "parts": [[Rect2(0, 0, 256, 256), Vector2(153, 72)]]},
		{"name": "braco_soco", "file": "talos_top_braco_soco", "parts": [[Rect2(0, 0, 256, 256), Vector2(150, 182)]]},
		{"name": "chamines", "file": "talos_top_chamines", "parts": [
			[Rect2(0, 0, 256, 128), Vector2(109, 76)],
			[Rect2(0, 128, 256, 128), Vector2(109, 176)]]},
	],
}


## O herói tem todas as camadas? (senão, sprite inteiro)
static func ready(hid: String) -> bool:
	if not RIGS.has(hid):
		return false
	for l in RIGS[hid]:
		if Art.tex(LAYER_PATH % l["file"]) == null:
			return false
	return true


## Estado de animação lido do herói (tudo de 0 a 1, menos "t" e "walk").
##   t      relógio da partida (s)
##   walk   fase do passo (rad); move: 0 parado .. 1 andando
##   attack avanço do soco (0 → 1 → 0); guard: Muralha de Bronze ativa
##   hurt   recuo ao levar dano; fury: ultimate em uso (chaminés soltam mais vapor)
static func state_of(h) -> Dictionary:
	return {"t": h.game.time if h.game != null else 0.0, "walk": h.anim_walk, "move": h.anim_move,
		"attack": h.anim_attack(), "guard": 1.0 if h.wall_t > 0.0 else 0.0,
		"hurt": h.anim_hurt(), "fury": 1.0 if h.ult_active() else 0.0}


## Pose de cada camada: {"off": Vector2 (px da imagem; +x = para a frente),
## "rot": rad, "scale": Vector2}. Uma entrada por parte.
static func pose(hid: String, layer: String, part: int, st: Dictionary) -> Dictionary:
	var t: float = st["t"]
	var m: float = st["move"]
	var w: float = st["walk"]
	var out := {"off": Vector2.ZERO, "rot": 0.0, "scale": Vector2.ONE}
	if hid != "talos":
		return out
	match layer:
		"corpo":
			# Respiração: 100% a 102%, mais calma quando anda.
			var br: float = 1.0 + 0.02 * (0.5 + 0.5 * sin(t * 2.2)) * (1.0 - 0.5 * m)
			out["scale"] = Vector2(br, br)
		"braco_escudo":
			# Andando: balança. Muralha: o escudo vai à frente (+25°). Dano: abre (−12°).
			var r: float = sin(w) * deg_to_rad(8.0) * m + sin(t * 2.2) * deg_to_rad(1.5)
			r = lerpf(r, deg_to_rad(25.0), st["guard"])
			r -= deg_to_rad(12.0) * st["hurt"]
			out["rot"] = r
			out["off"] = Vector2(6.0 * st["guard"], 0)
		"braco_soco":
			# Andando: o braço vai e volta, oposto ao escudo. Soco: avança até 14 px.
			var fx: float = -sin(w) * 4.0 * m + 14.0 * st["attack"] - 3.0 * st["hurt"]
			out["off"] = Vector2(fx, 0)
			out["rot"] = deg_to_rad(6.0) * st["hurt"]
		"chamines":
			# Vapor: cada chaminé pulsa 100% a 115%, defasadas; mais na ultimate.
			var ph := t * (6.0 if st["fury"] > 0.0 else 3.0) + part * PI
			var amp := 0.15 if st["fury"] > 0.0 else 0.07
			var s := 1.0 + amp * (0.5 + 0.5 * sin(ph))
			out["scale"] = Vector2(s, s)
	return out


## Desenha o herói em camadas em `ci`, por cima da transformação `parent`
## (a do corpo do herói), centrado em (0, 0) com lado `size_px` e girado em
## `angle`. Devolve false (sem desenhar nada) se faltar camada.
static func draw(ci: CanvasItem, hid: String, parent: Transform2D, size_px: float, angle: float, mod: Color, st: Dictionary) -> bool:
	if not ready(hid):
		return false
	var k := size_px / SIZE
	var base := parent * Transform2D(angle, Vector2.ZERO) * Transform2D().scaled(Vector2(k, k)) * Transform2D(0.0, Vector2(-SIZE * 0.5, -SIZE * 0.5))
	for l in RIGS[hid]:
		var tex := Art.tex(LAYER_PATH % l["file"])
		Art.drawn += 1
		Art.drawn_names["heroes/camadas/" + l["file"]] = true
		var i := 0
		for p in l["parts"]:
			var region: Rect2 = p[0]
			var pivot: Vector2 = p[1]
			var ps := pose(hid, l["name"], i, st)
			var off: Vector2 = ps["off"]
			var rot: float = ps["rot"]
			var sc: Vector2 = ps["scale"]
			var xf := base * Transform2D(0.0, pivot + off) * Transform2D(rot, Vector2.ZERO) \
				* Transform2D().scaled(sc) * Transform2D(0.0, -pivot)
			ci.draw_set_transform_matrix(xf)
			ci.draw_texture_rect_region(tex, region, region, mod)
			i += 1
	ci.draw_set_transform_matrix(parent)
	return true
