extends RefCounted
## Comandante controlado pelo computador.

const Data = preload("res://scripts/data.gd")

var game
var team := 0
var cmd
var difficulty := "normal"
var think_t := 1.5
var interval := 1.0
var mistake := 0.1
var lead := 0.0


func setup(g, t: int, c, diff: String) -> void:
	game = g
	team = t
	cmd = c
	difficulty = diff
	match diff:
		"easy":
			interval = 1.7; mistake = 0.35; lead = 0.0
		"hard":
			interval = 0.5; mistake = 0.0; lead = 0.25
		_:
			interval = 1.0; mistake = 0.12; lead = 0.1


func think(dt: float) -> void:
	think_t -= dt
	if think_t > 0.0:
		return
	think_t = interval * randf_range(0.7, 1.3)
	_maybe_behavior()
	if randf() < mistake:
		return

	for hid in Data.HERO_ORDER:
		if cmd.can_ult(hid) == "":
			var tp = _ult_target(hid)
			if tp != null:
				cmd.use_ult(hid, tp)
				return

	var best := -1
	var best_score := 0.0
	var best_t := Vector2.ZERO
	for i in cmd.HAND_SIZE:
		if cmd.can_play(i) != "":
			continue
		var r: Array = _eval(cmd.hand[i])
		if r[0] > best_score:
			best_score = r[0]
			best = i
			best_t = r[1]
	var threshold := 4.0
	if cmd.ichor >= Data.ICHOR_MAX - 0.5:
		threshold = 2.5
	if best >= 0 and best_score >= threshold:
		cmd.play(best, best_t)


func _maybe_behavior() -> void:
	var mine: float = game.progress[team]
	var theirs: float = game.progress[1 - team]
	var want := "balanced"
	if difficulty == "hard":
		if game.point_owner == team and mine > theirs + 10.0:
			want = "defensive"
		elif theirs > mine + 15.0:
			want = "aggressive"
	elif difficulty == "normal":
		if theirs > mine + 25.0:
			want = "aggressive"
	if want != cmd.behavior:
		cmd.set_behavior(want)


func _enemies() -> Array:
	return game.alive_heroes(1 - team)


func _allies() -> Array:
	return game.alive_heroes(team)


func _nearest(from: Vector2, list: Array, max_d: float):
	var best = null
	var bd := max_d
	for e in list:
		var d: float = from.distance_to(e.position)
		if d < bd:
			bd = d
			best = e
	return best


func _aim(e) -> Vector2:
	var p: Vector2 = e.position
	if lead > 0.0 and e.facing != null:
		p += e.facing * e.speed * lead
	return p


func _eval(card: String) -> Array:
	var h = cmd.card_hero(card)
	if h == null:
		return [0.0, Vector2.ZERO]
	var enemies := _enemies()
	var allies := _allies()
	var hp: Vector2 = h.position
	match card:
		"muralha":
			for e in enemies:
				if e.hid != "talos" and hp.distance_to(e.position) < 450.0:
					return [6.0, e.position]
			var n = _nearest(hp, enemies, 300.0)
			if n != null:
				return [3.0, n.position]
		"investida":
			var n2 = _nearest(hp, enemies, 240.0)
			if n2 != null:
				var s := 6.0
				if n2.hp / n2.max_hp < 0.4:
					s += 2.0
				return [s, _aim(n2)]
		"valvula":
			var count := 0
			for a in allies:
				if a.position.distance_to(hp) < 190.0:
					count += 1
			if count >= 2 and _nearest(hp, enemies, 350.0) != null:
				return [4.0 + count, hp]
		"disparo":
			var n3 = _nearest(hp, enemies, 750.0)
			if n3 != null:
				var dir: Vector2 = (n3.position - hp).normalized()
				var in_line := 0
				for e in enemies:
					var v: Vector2 = e.position - hp
					var along := v.dot(dir)
					if along > 0.0 and absf(v.cross(dir)) < 30.0:
						in_line += 1
				return [3.0 + 2.0 * in_line, _aim(n3)]
		"armadilha":
			var n4 = _nearest(hp, enemies, 320.0)
			if n4 != null:
				return [4.0, _aim(n4)]
			if game.point_unlocked() and game.count_traps(team) == 0:
				var side := -1.0 if team == 0 else 1.0
				return [3.0, game.CENTER + Vector2(side * 30.0, randf_range(-40.0, 40.0))]
		"salto":
			var n5 = _nearest(hp, enemies, 150.0)
			if n5 != null or (h.hp / h.max_hp < 0.45 and _nearest(hp, enemies, 300.0) != null):
				return [7.0, hp]
		"sopro":
			var missing := 0.0
			for a in allies:
				if a.position.distance_to(hp) < 210.0:
					missing += a.max_hp - a.hp
			if missing >= 140.0:
				return [4.0 + missing / 60.0, hp]
		"veneno":
			var n6 = _nearest(hp, enemies, 520.0)
			if n6 != null:
				var s2 := 4.0
				if n6.hid == "talos" or n6.hid == "asclepio":
					s2 += 1.5
				return [s2, _aim(n6)]
		"engrenagem":
			var low = null
			var lf := 0.55
			for a in allies:
				var f: float = a.hp / a.max_hp
				if f < lf and _nearest(a.position, enemies, 450.0) != null:
					lf = f
					low = a
			if low != null:
				return [7.0, low.position]
	return [0.0, Vector2.ZERO]


func _ult_target(hid: String):
	var h = game.get_hero(team, hid)
	var enemies := _enemies()
	match hid:
		"talos":
			var c := 0
			for e in enemies:
				if e.position.distance_to(h.position) < 200.0:
					c += 1
			if c >= 2 or (c >= 1 and difficulty == "easy"):
				return h.position
		"artemis":
			var best = null
			var bc := 1
			for e in enemies:
				if e.position.distance_to(h.position) > 650.0:
					continue
				var c2 := 0
				var sum := Vector2.ZERO
				for o in enemies:
					if o.position.distance_to(e.position) < 160.0:
						c2 += 1
						sum += o.position
				if c2 > bc:
					bc = c2
					best = sum / float(c2)
			if best != null:
				return best
			if difficulty != "easy":
				for e in enemies:
					if game.in_point(e.position) and e.position.distance_to(h.position) < 650.0:
						return e.position
		"asclepio":
			for a in _allies():
				if a.position.distance_to(h.position) < 240.0 and a.hp / a.max_hp < 0.3:
					if _nearest(a.position, enemies, 400.0) != null:
						return h.position
	return null
