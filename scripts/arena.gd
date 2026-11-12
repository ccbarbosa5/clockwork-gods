extends RefCounted
## Arena descrita em dados (arenas/<id>.json), para criar outras arenas sem
## mexer no código (item 51). A partida (game.gd) carrega a arena pelo id.
##
## Formato (coordenadas da tela, arena 1280 × 520 em y 40..560):
##   "obstaculos": lista de
##     {"tipo": "coluna" | "caldeira" | "estatua", "c": [x, y], "r": raio}
##     {"tipo": "parede" | "mureta", "ret": [x, y, larg, alt]}
##     {"tipo": "parede_l", "rets": [[x, y, larg, alt], [x, y, larg, alt]]}
##   "frascos": [[x, y], ...]           Frascos de Ambrosia
##   "rotas": {"centro"|"alto"|"baixo": [[x, y], ...]}  pontos de passagem (time azul)
##   "gargalos": [[x1, y1, x2, y2], ...]  vão de cada gargalo (só para a prévia)
##   "espelhar": true                    tudo fora do eixo x = 640 ganha a cópia do outro lado
##                                        (false: a lista já traz os dois lados)
## Tipos: todos bloqueiam movimento; só a mureta deixa passar tiros e habilidades.

const MID := 640.0
const DEFAULT := "tres_corredores"

static var _cache := {}


## Arena pronta para a partida (lida uma vez por id): {"def", "obs", "packs"}.
static func get_arena(id: String) -> Dictionary:
	if not _cache.has(id):
		var def := load_def("res://arenas/%s.json" % id)
		if def.is_empty():
			def = load_def("res://arenas/%s.json" % DEFAULT)
		_cache[id] = {"def": def, "obs": obstacles(def), "packs": packs(def)}
	return _cache[id]


static func load_def(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}


static func _mx(x: float) -> float:
	return 2.0 * MID - x


static func _rect(a: Array) -> Rect2:
	return Rect2(a[0], a[1], a[2], a[3])


static func _mrect(r: Rect2) -> Rect2:
	return Rect2(_mx(r.end.x), r.position.y, r.size.x, r.size.y)


## Obstáculos completos (com o lado espelhado). Cada um:
##   {"tipo", "circulo": true, "c": Vector2, "r": float, "tiro": bool}
##   {"tipo", "circulo": false, "ret": Rect2, "tiro": bool}
## "tiro" = bloqueia tiros. Uma parede em L vira 2 retângulos.
static func obstacles(def: Dictionary) -> Array:
	var out: Array = []
	var mirror: bool = def.get("espelhar", true)
	for o in def.get("obstaculos", []):
		var tipo: String = o["tipo"]
		var shot := tipo != "mureta"
		var parts: Array = []
		if o.has("c"):
			var c := Vector2(o["c"][0], o["c"][1])
			parts.append({"tipo": tipo, "circulo": true, "c": c, "r": float(o["r"]), "tiro": shot})
			if mirror and absf(c.x - MID) > 0.5:
				parts.append({"tipo": tipo, "circulo": true, "c": Vector2(_mx(c.x), c.y), "r": float(o["r"]), "tiro": shot})
		else:
			var rs: Array = o["rets"] if o.has("rets") else [o["ret"]]
			for a in rs:
				var r := _rect(a)
				parts.append({"tipo": tipo, "circulo": false, "ret": r, "tiro": shot})
				if mirror and absf(r.get_center().x - MID) > 0.5:
					parts.append({"tipo": tipo, "circulo": false, "ret": _mrect(r), "tiro": shot})
		out.append_array(parts)
	return out


static func packs(def: Dictionary) -> Array:
	var out: Array = []
	for p in def.get("frascos", []):
		var v := Vector2(p[0], p[1])
		out.append(v)
		if def.get("espelhar", true) and absf(v.x - MID) > 0.5:
			out.append(Vector2(_mx(v.x), v.y))
	return out


static func chokes(def: Dictionary) -> Array:
	var out: Array = []
	for g in def.get("gargalos", []):
		var a := Vector2(g[0], g[1])
		var b := Vector2(g[2], g[3])
		out.append([a, b])
		if def.get("espelhar", true) and absf((a.x + b.x) * 0.5 - MID) > 0.5:
			out.append([Vector2(_mx(a.x), a.y), Vector2(_mx(b.x), b.y)])
	return out


## Distância do ponto p até o obstáculo (negativa = dentro).
static func distance(o: Dictionary, p: Vector2) -> float:
	if o["circulo"]:
		return p.distance_to(o["c"]) - o["r"]
	var r: Rect2 = o["ret"]
	var q := Vector2(clampf(p.x, r.position.x, r.end.x), clampf(p.y, r.position.y, r.end.y))
	if r.has_point(p):
		return -minf(minf(p.x - r.position.x, r.end.x - p.x), minf(p.y - r.position.y, r.end.y - p.y))
	return p.distance_to(q)


## Um herói de raio `radius` cabe em p?
static func free_at(obs: Array, p: Vector2, radius: float) -> bool:
	for o in obs:
		if distance(o, p) < radius:
			return false
	return true


## O segmento a-b passa livre (para tiros: ignora muretas)?
static func line_clear(obs: Array, a: Vector2, b: Vector2, for_shot := true) -> bool:
	for o in obs:
		if for_shot and not o["tiro"]:
			continue
		if o["circulo"]:
			if Geometry2D.get_closest_point_to_segment(o["c"], a, b).distance_to(o["c"]) < o["r"]:
				return false
		else:
			var r: Rect2 = o["ret"]
			if r.has_point(a) or r.has_point(b):
				return false
			var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
			for k in 4:
				if Geometry2D.segment_intersects_segment(a, b, c[k], c[(k + 1) % 4]) != null:
					return false
	return true
