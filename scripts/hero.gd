extends Node2D
## Herói autônomo: atributos, estados, IA e desenho.

const Data = preload("res://scripts/data.gd")
const UI = preload("res://scripts/ui.gd")

var game
var team := 0
var hid := ""
var def := {}
var hp := 100.0
var max_hp := 100.0
var radius := 16.0
var speed := 80.0
var alive := true
var respawn_t := 0.0
var attack_cd := 0.0
var target = null
var facing := Vector2.RIGHT
var retreating := false
var slot_index := 0

# Estados
var stun_t := 0.0
var root_t := 0.0
var slow_t := 0.0
var slow_amt := 0.0
var dr_t := 0.0
var dr_amt := 0.0
var dr_src = null
var haste_t := 0.0
var haste_amt := 0.0
var shield_hp := 0.0
var shield_t := 0.0
var shield_src = null
var undying_t := 0.0
var poison_t := 0.0
var poison_dps := 0.0
var poison_src = null
var heal_red_t := 0.0
var dash_t := 0.0
var dash_vel := Vector2.ZERO
var dash_damage := false
var dash_hit := []
var knock_vel := Vector2.ZERO
var knock_t := 0.0
var wall_t := 0.0
var wall_hp := 0.0

var ult := 0.0
var hit_flash := 0.0
var heal_target = null
var heal_cd := 0.0
var heal_beam_t := 0.0
var swing_t := 0.0
var strafe_phase := 0.0
var stats := {"kills": 0, "deaths": 0, "damage": 0.0, "healing": 0.0, "mitigated": 0.0}


func setup(g, t: int, id: String, idx: int) -> void:
	game = g
	team = t
	hid = id
	slot_index = idx
	def = Data.HEROES[id]
	max_hp = def["hp"]
	hp = max_hp
	radius = def["radius"]
	speed = def["speed"]
	strafe_phase = randf() * TAU
	facing = Vector2.RIGHT if team == 0 else Vector2.LEFT


func clear_status() -> void:
	stun_t = 0.0; root_t = 0.0; slow_t = 0.0; slow_amt = 0.0
	dr_t = 0.0; dr_amt = 0.0; dr_src = null
	haste_t = 0.0; haste_amt = 0.0
	shield_hp = 0.0; shield_t = 0.0; shield_src = null
	undying_t = 0.0; poison_t = 0.0; poison_dps = 0.0; poison_src = null
	heal_red_t = 0.0; dash_t = 0.0; knock_t = 0.0
	wall_t = 0.0; wall_hp = 0.0
	target = null; heal_target = null; retreating = false


func add_charge(v: float) -> void:
	if alive:
		ult = minf(100.0, ult + v)


func ability_ready_text() -> String:
	return "PRONTO" if ult >= 100.0 else str(int(ult)) + "%"


# --------------------------------------------------------------------------
func tick(dt: float) -> void:
	if not alive:
		respawn_t -= dt
		if respawn_t <= 0.0:
			game.respawn(self)
		return

	attack_cd -= dt
	stun_t -= dt
	root_t -= dt
	slow_t -= dt
	dr_t -= dt
	haste_t -= dt
	shield_t -= dt
	undying_t -= dt
	heal_red_t -= dt
	hit_flash -= dt
	heal_beam_t -= dt
	swing_t -= dt
	wall_t -= dt
	if shield_t <= 0.0:
		shield_hp = 0.0
	if wall_hp <= 0.0:
		wall_t = 0.0
	if slow_t <= 0.0:
		slow_amt = 0.0

	if poison_t > 0.0:
		poison_t -= dt
		game.deal_damage(poison_src, self, poison_dps * dt, false)
		if not alive:
			return

	add_charge(Data.ULT_PASSIVE * dt)
	if game.point_unlocked() and game.in_point(position):
		add_charge(Data.ULT_POINT * dt)
	if position.distance_to(game.spawn_pos(team)) < game.SPAWN_R:
		hp = minf(max_hp, hp + Data.SPAWN_REGEN * dt)

	if dash_t > 0.0:
		dash_t -= dt
		position += dash_vel * dt
		if dash_damage:
			game.dash_hits(self)
	elif knock_t > 0.0:
		knock_t -= dt
		position += knock_vel * dt
	elif stun_t <= 0.0:
		var move := _think(dt)
		if root_t > 0.0:
			move = Vector2.ZERO
		var spd := speed * (1.0 - slow_amt)
		position += move * spd * dt
	game.resolve_collisions(self)
	queue_redraw()


# --------------------------------------------------------------------------
# IA
func _think(dt: float) -> Vector2:
	var beh: String = game.commanders[team].behavior
	var side := -1.0 if team == 0 else 1.0
	var forward := -side
	var enemies: Array = game.alive_heroes(1 - team)
	var hpf := hp / max_hp
	var th: float = {"aggressive": 0.15, "balanced": 0.3, "defensive": 0.35}[beh]
	if hpf < th and undying_t <= 0.0:
		retreating = true
	if retreating and hpf > 0.8:
		retreating = false

	if hid == "asclepio":
		_support_heal(dt)

	target = _pick_target(enemies, beh)
	if target != null:
		var to: Vector2 = target.position - position
		if to.length() > 0.1:
			facing = to.normalized()
	_try_attack()

	if retreating:
		var dest: Vector2 = game.spawn_pos(team)
		if hid != "asclepio":
			var sup = game.get_hero(team, "asclepio")
			if sup != null and sup.alive and not sup.retreating:
				dest = sup.position + Vector2(side * 50.0, 0.0)
		if target != null and position.distance_to(target.position) < 120.0:
			return _kite(target.position)
		return _go(dest, 25.0)

	if not game.point_unlocked():
		var stage: Vector2 = game.CENTER + Vector2(side * (game.POINT_R + 70.0 + slot_index * 35.0), (slot_index - 1) * 60.0)
		return _go(stage, 10.0)

	if hid == "asclepio":
		var ht = heal_target
		if ht == null or ht == self:
			var tank = game.get_hero(team, "talos")
			if tank != null and tank.alive:
				ht = tank
		if target != null and position.distance_to(target.position) < 110.0:
			return _kite(target.position)
		if ht != null and ht != self:
			var d: float = ht.position.distance_to(position)
			if d > 150.0:
				return _steer(ht.position - Vector2(forward * 60.0, 0.0))
			return _strafe() * 0.4
		return _go(_anchor(beh, forward), 12.0)

	if target != null:
		var d: float = position.distance_to(target.position)
		var desired: float = def["range"] * 0.85
		if hid == "talos":
			desired = def["range"] * 0.6
		if hid == "artemis" and d < 150.0:
			return _kite(target.position)
		if d > desired:
			return _steer(target.position)
		return _strafe() * 0.5

	return _go(_anchor(beh, forward), 12.0)


func _anchor(beh: String, forward: float) -> Vector2:
	var c: Vector2 = game.CENTER
	match hid:
		"talos":
			var dx: float = {"aggressive": 150.0, "balanced": 20.0, "defensive": 0.0}[beh]
			return c + Vector2(forward * dx, 0.0)
		"artemis":
			var dx2: float = {"aggressive": 70.0, "balanced": -95.0, "defensive": -55.0}[beh]
			return c + Vector2(forward * dx2, -45.0)
		_:
			var tank = game.get_hero(team, "talos")
			if tank != null and tank.alive:
				return tank.position + Vector2(-forward * 85.0, 40.0)
			return c + Vector2(-forward * 120.0, 40.0)


func _pick_target(enemies: Array, beh: String):
	var aggro: float = {"aggressive": 560.0, "balanced": 400.0, "defensive": 320.0}[beh]
	var leash: float = {"aggressive": 99999.0, "balanced": game.POINT_R + 380.0, "defensive": game.POINT_R + 220.0}[beh]
	var best = null
	var best_score := INF
	for e in enemies:
		var d: float = position.distance_to(e.position)
		var in_range: bool = d <= def["range"] + e.radius
		if d > aggro and not in_range:
			continue
		if e.position.distance_to(game.CENTER) > leash and not in_range:
			continue
		if e.position.distance_to(game.spawn_pos(e.team)) < game.SPAWN_R + 10.0 and not in_range:
			continue
		var score := d
		if hid == "artemis":
			score = d + e.hp * 0.6
		if score < best_score:
			best_score = score
			best = e
	return best


func _try_attack() -> void:
	if target == null or attack_cd > 0.0 or stun_t > 0.0 or dash_t > 0.0:
		return
	if hid == "asclepio" and heal_target != null and heal_target.position.distance_to(position) <= def["heal_range"]:
		return
	var d: float = position.distance_to(target.position) - target.radius
	if d > def["range"]:
		return
	attack_cd = def["cd"] / (1.0 + (haste_amt if haste_t > 0.0 else 0.0))
	if hid == "talos":
		swing_t = 0.18
		game.deal_damage(self, target, def["dmg"])
		for e in game.alive_heroes(1 - team):
			if e != target and e.position.distance_to(target.position) < 45.0:
				game.deal_damage(self, e, def["dmg"] * 0.5)
	else:
		var dir: Vector2 = (target.position - position).normalized()
		var col: Color = Color(0.85, 0.9, 1.0) if hid == "artemis" else Color(0.5, 1.0, 0.65)
		game.spawn_projectile(self, position + dir * (radius + 4.0), dir * def["proj_speed"], def["dmg"], 5.0, "basic", col)


func _support_heal(dt: float) -> void:
	heal_cd -= dt
	var best = null
	var best_f := 0.97
	for a in game.alive_heroes(team):
		if a.position.distance_to(position) > 600.0:
			continue
		var f: float = a.hp / a.max_hp
		if a == self:
			f += 0.15
		if f < best_f:
			best_f = f
			best = a
	heal_target = best
	if best != null and heal_cd <= 0.0 and best.position.distance_to(position) <= def["heal_range"]:
		heal_cd = 0.5
		heal_beam_t = 0.3
		game.heal(self, best, def["heal"])


## Recua do inimigo puxando para a própria base, para não ficar preso nos cantos.
func _kite(from: Vector2) -> Vector2:
	var away := (position - from).normalized()
	var home: Vector2 = (game.spawn_pos(team) - position).normalized()
	var dir := (away + home * 0.8).normalized()
	return _steer(position + dir * 90.0)


func _strafe() -> Vector2:
	return Vector2(0.0, sin(game.time * 1.3 + strafe_phase))


func _go(dest: Vector2, tol: float) -> Vector2:
	var d := position.distance_to(dest)
	if d < tol:
		return Vector2.ZERO
	return _steer(dest) * minf(1.0, d / 40.0)


func _steer(dest: Vector2) -> Vector2:
	var to_dest := dest - position
	if to_dest.length() < 0.5:
		return Vector2.ZERO
	var dir := to_dest.normalized()
	var steer := Vector2.ZERO
	for o in game.OBSTACLES:
		var c := Vector2(o.x, o.y)
		var r: float = o.z
		var to := c - position
		var dist := to.length()
		var margin := r + radius + 45.0
		if dist < margin and dir.dot(to) > 0.0:
			var perp := Vector2(-to.y, to.x).normalized()
			if perp.dot(to_dest) < 0.0:
				perp = -perp
			steer += perp * (1.0 - (dist - r - radius) / 45.0) * 1.4
	return (dir + steer).normalized()


# --------------------------------------------------------------------------
# Desenho
func _draw() -> void:
	if not alive:
		return
	var tc: Color = Data.TEAM_COLORS[team]
	var hc: Color = def["color"]
	if hit_flash > 0.0:
		hc = hc.lerp(Color.WHITE, 0.6)

	# Rastro de investida/salto
	if dash_t > 0.0:
		draw_line(Vector2.ZERO, -dash_vel.normalized() * 40.0, Color(1, 1, 1, 0.35), radius * 1.4)

	# Feixe de cura
	if heal_beam_t > 0.0 and heal_target != null and is_instance_valid(heal_target) and heal_target.alive and heal_target != self:
		var tp: Vector2 = heal_target.position - position
		draw_line(Vector2.ZERO, tp, Color(0.45, 1.0, 0.6, 0.7), 4.0, true)
		draw_line(Vector2.ZERO, tp, Color(1, 1, 1, 0.6), 1.5, true)

	# Sombra e corpo
	draw_circle(Vector2(0, 5), radius + 2.0, Color(0, 0, 0, 0.35))
	if undying_t > 0.0:
		draw_circle(Vector2.ZERO, radius + 10.0, Color(1.0, 0.85, 0.3, 0.35))
	if ult >= 100.0:
		var pulse := 0.5 + 0.5 * sin(game.time * 6.0)
		UI.ring(self, Vector2.ZERO, radius + 7.0, Color(Data.GOLD, 0.4 + 0.5 * pulse), 2.0)
	draw_circle(Vector2.ZERO, radius + 3.0, tc)
	draw_circle(Vector2.ZERO, radius, hc)
	_draw_glyph()

	# Indicador de direção
	var tip := facing * (radius + 9.0)
	var side := Vector2(-facing.y, facing.x) * 5.0
	draw_colored_polygon(PackedVector2Array([tip, facing * (radius + 2.0) + side, facing * (radius + 2.0) - side]), tc)

	# Golpe corpo a corpo
	if swing_t > 0.0:
		var a := facing.angle()
		draw_arc(Vector2.ZERO, radius + 18.0, a - 0.9, a + 0.9, 12, Color(1, 0.9, 0.6, 0.8), 4.0, true)

	# Muralha
	if wall_t > 0.0:
		var a2 := facing.angle()
		var alpha := clampf(wall_hp / 450.0, 0.25, 1.0)
		draw_arc(Vector2.ZERO, 44.0, a2 - 1.0, a2 + 1.0, 18, Color(0.95, 0.7, 0.3, alpha), 7.0, true)
		draw_arc(Vector2.ZERO, 44.0, a2 - 1.0, a2 + 1.0, 18, Color(1, 1, 0.8, alpha * 0.7), 2.0, true)

	# Estados
	if dr_t > 0.0:
		UI.ring(self, Vector2.ZERO, radius + 5.0, Color(0.85, 0.65, 0.35, 0.9), 2.0)
	if shield_hp > 0.0:
		UI.ring(self, Vector2.ZERO, radius + 8.0, Color(0.6, 1.0, 0.8, 0.9), 3.0)
	if root_t > 0.0:
		UI.ring(self, Vector2(0, 4), radius + 4.0, Color(0.55, 0.4, 0.2, 1.0), 4.0)
	if slow_t > 0.0:
		UI.ring(self, Vector2.ZERO, radius + 1.0, Color(0.5, 0.7, 1.0, 0.7), 2.0)
	if poison_t > 0.0:
		for i in 3:
			var ang: float = game.time * 2.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(ang), sin(ang)) * (radius - 4.0), 2.5, Color(0.5, 1.0, 0.3))
	if stun_t > 0.0:
		for i in 3:
			var ang2: float = game.time * 5.0 + i * TAU / 3.0
			draw_circle(Vector2(cos(ang2) * 12.0, -radius - 18.0 + sin(ang2) * 4.0), 3.0, Color(1, 0.95, 0.3))

	# Barra de vida
	var bw := 46.0
	var by := -radius - 13.0
	draw_rect(Rect2(-bw * 0.5 - 1, by - 1, bw + 2, 7), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(-bw * 0.5, by, bw * clampf(hp / max_hp, 0.0, 1.0), 5), tc.lerp(Color.WHITE, 0.15))
	if shield_hp > 0.0:
		draw_rect(Rect2(-bw * 0.5, by - 4, bw * clampf(shield_hp / max_hp, 0.0, 1.0), 3), Color(0.7, 1.0, 0.85))
	UI.text_c(self, Vector2(0, radius + 16.0), def["name"], 11, Color(1, 1, 1, 0.85), 3)


func _draw_glyph() -> void:
	var dark := Color(0.12, 0.09, 0.07, 0.9)
	match hid:
		"talos":
			var s := radius * 0.5
			draw_colored_polygon(PackedVector2Array([
				Vector2(-s, -s), Vector2(s, -s), Vector2(s, s * 0.3), Vector2(0, s * 1.2), Vector2(-s, s * 0.3)]), dark)
		"artemis":
			var s2 := radius * 0.6
			draw_line(Vector2(-s2, s2), Vector2(s2, -s2), dark, 3.0)
			draw_colored_polygon(PackedVector2Array([Vector2(s2 + 2, -s2 - 2), Vector2(s2 - 6, -s2), Vector2(s2, -s2 + 6)]), dark)
		_:
			var s3 := radius * 0.55
			draw_rect(Rect2(-s3 * 0.3, -s3, s3 * 0.6, s3 * 2.0), dark)
			draw_rect(Rect2(-s3, -s3 * 0.3, s3 * 2.0, s3 * 0.6), dark)
