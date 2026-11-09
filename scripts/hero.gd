extends Node2D
## Herói autônomo: atributos, estados, IA de formação, cartas armadas e desenho.

const Data = preload("res://scripts/data.gd")
const UI = preload("res://scripts/ui.gd")
const Art = preload("res://scripts/art.gd")

var game
var team := 0
var hid := ""
var def := {}
var style := "frontline"
var hp := 100.0
var max_hp := 100.0
var radius := 16.0
var speed := 80.0
var alive := true
var respawn_t := 0.0
var attack_cd := 0.0
var target = null
var facing := Vector2.RIGHT
## Ângulo do sprite: segue `facing` girando no máximo Art.HERO_TURN_DEG por segundo.
var sprite_angle := 0.0
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

## Habilidades armadas aguardando o melhor momento: [{ab, t, ult}]
var armed: Array = []
var cast_gap := 0.0
var puff_t := 0.0

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
	style = def.get("style", "frontline")
	max_hp = def["hp"]
	hp = max_hp
	radius = def["radius"]
	speed = def["speed"]
	strafe_phase = randf() * TAU
	facing = Vector2.RIGHT if team == 0 else Vector2.LEFT
	sprite_angle = facing.angle()


func clear_status() -> void:
	stun_t = 0.0; root_t = 0.0; slow_t = 0.0; slow_amt = 0.0
	dr_t = 0.0; dr_amt = 0.0; dr_src = null
	haste_t = 0.0; haste_amt = 0.0
	shield_hp = 0.0; shield_t = 0.0; shield_src = null
	undying_t = 0.0; poison_t = 0.0; poison_dps = 0.0; poison_src = null
	heal_red_t = 0.0; dash_t = 0.0; knock_t = 0.0
	wall_t = 0.0; wall_hp = 0.0
	target = null; heal_target = null; retreating = false
	armed = []


func add_charge(v: float) -> void:
	if alive:
		ult = minf(100.0, ult + v)


func ability_ready_text() -> String:
	return "PRONTO" if ult >= 100.0 else str(int(ult)) + "%"


func role_color() -> Color:
	return Data.ROLE_COLORS[def["role"]]


func is_backline() -> bool:
	return style == "backline_dps" or style == "backline_support" or style == "flank"


func is_healer() -> bool:
	return def.has("heal")


## Arma uma habilidade: o herói a usa sozinho no melhor momento.
func arm(ab: String, is_ult: bool) -> void:
	armed.append({"ab": ab, "t": Data.ARM_TIME, "ult": is_ult})


func has_armed(ab: String) -> bool:
	for a in armed:
		if a["ab"] == ab:
			return true
	return false


# --------------------------------------------------------------------------
func tick(dt: float) -> void:
	if not alive:
		respawn_t -= dt
		sprite_angle = facing.angle()
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
	cast_gap -= dt
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

	for a in armed:
		a["t"] -= dt

	if dash_t > 0.0:
		dash_t -= dt
		position += dash_vel * dt
		puff_t -= dt
		if puff_t <= 0.0:
			puff_t = 0.03
			game.add_puff(position, Color(1, 0.95, 0.85) if dash_damage else role_color().lightened(0.3))
		if dash_damage:
			game.dash_hits(self)
	elif knock_t > 0.0:
		knock_t -= dt
		position += knock_vel * dt
	elif stun_t <= 0.0:
		_update_armed()
		var move := _think(dt)
		if root_t > 0.0:
			move = Vector2.ZERO
		# Contestando: dentro do ponto, não sai dele perseguindo ninguém.
		if not retreating and game.contest_need(team) and game.in_point(position):
			var out: Vector2 = position - game.CENTER
			if out.length() > game.POINT_R * 0.7:
				var n := out.normalized()
				var outward := move.dot(n)
				if outward > 0.0:
					move -= n * outward
				if move.length() < 0.15:
					# Sem congelar: circula dentro do ponto (BUG-016).
					move = Vector2(-n.y, n.x) * 0.4 * sin(game.time * 1.1 + strafe_phase) - n * 0.2
		var spd := speed * (1.0 - slow_amt)
		position += move * spd * dt
	game.resolve_collisions(self)
	sprite_angle = rotate_toward(sprite_angle, facing.angle(), deg_to_rad(Art.HERO_TURN_DEG) * dt)
	queue_redraw()


# --------------------------------------------------------------------------
# Cartas armadas: escolher momento e alvo
func _update_armed() -> void:
	if armed.is_empty() or cast_gap > 0.0 or dash_t > 0.0:
		return
	for i in armed.size():
		var a: Dictionary = armed[i]
		var tp = decide(a["ab"], a["t"] <= 0.0)
		if tp != null:
			armed.remove_at(i)
			game.cast(self, a["ab"], tp)
			cast_gap = 0.3
			return


func _forward() -> float:
	return 1.0 if team == 0 else -1.0


func _ahead(dist: float) -> Vector2:
	return position + Vector2(_forward() * dist, 0.0)


func _nearest(from: Vector2, list: Array, max_d: float):
	var best = null
	var bd := max_d
	for e in list:
		var d: float = from.distance_to(e.position)
		if d < bd:
			bd = d
			best = e
	return best


func _lead(e) -> Vector2:
	return e.position + e.facing * e.speed * 0.15


## Decide se é um bom momento para a habilidade e onde mirar.
## Retorna a posição-alvo ou null para esperar. Com `forced`, sempre retorna.
func decide(ab: String, forced: bool):
	var enemies: Array = game.alive_heroes(1 - team)
	var allies: Array = game.alive_heroes(team)
	var near = _nearest(position, enemies, 99999.0)
	var fallback: Vector2 = near.position if near != null else _ahead(150.0)
	match ab:
		"muralha":
			for e in enemies:
				if e.def["range"] > 150.0 and position.distance_to(e.position) < 450.0:
					return e.position
			if near != null and position.distance_to(near.position) < 250.0:
				return near.position
		"investida":
			var best = null
			var bs := INF
			for e in enemies:
				var d: float = position.distance_to(e.position)
				if d < 300.0:
					var sc: float = d + e.hp * 0.3
					if sc < bs:
						bs = sc
						best = e
			if best != null:
				return _lead(best)
		"valvula":
			var c := 0
			for a in allies:
				if a.position.distance_to(position) <= 190.0:
					c += 1
			var threat = _nearest(position, enemies, 350.0)
			if threat != null and (c >= 2 or hp / max_hp < 0.6):
				return position
			if forced:
				return position
		"furia":
			var n := 0
			var weak := false
			for e in enemies:
				if e.position.distance_to(position) < 200.0:
					n += 1
					if e.hp / e.max_hp < 0.35:
						weak = true
			if n >= 2 or (n >= 1 and weak):
				return position
			if forced:
				return position
		"disparo":
			var best2 = null
			var bc := 0
			for e in enemies:
				if position.distance_to(e.position) > 700.0:
					continue
				var dir: Vector2 = (e.position - position).normalized()
				var c2 := 0
				for o in enemies:
					var v: Vector2 = o.position - position
					if v.dot(dir) > 0.0 and absf(v.cross(dir)) < 32.0:
						c2 += 1
				if c2 > bc:
					bc = c2
					best2 = e
			if best2 != null:
				return _lead(best2)
		"armadilha":
			var n2 = _nearest(position, enemies, 320.0)
			if n2 != null:
				return _lead(n2)
			if forced:
				return game.CENTER + Vector2(-_forward() * 20.0, randf_range(-40.0, 40.0))
		"salto":
			var close = _nearest(position, enemies, 160.0)
			if close != null or (hp / max_hp < 0.5 and _nearest(position, enemies, 300.0) != null):
				return position
			if forced:
				return position
		"chuva":
			var bestc = null
			var cc := 1
			for e in enemies:
				if e.position.distance_to(position) > 650.0:
					continue
				var c3 := 0
				var sum := Vector2.ZERO
				for o in enemies:
					if o.position.distance_to(e.position) < 160.0:
						c3 += 1
						sum += o.position
				if c3 > cc:
					cc = c3
					bestc = sum / float(c3)
			if bestc != null:
				return bestc
			for e in enemies:
				if e.position.distance_to(position) < 600.0 and (game.in_point(e.position) or e.hp / e.max_hp < 0.4):
					return e.position
			if forced:
				return fallback if near != null and position.distance_to(near.position) < 650.0 else game.CENTER
		"sopro":
			var missing := 0.0
			for a in allies:
				if a.position.distance_to(position) <= 210.0:
					missing += a.max_hp - a.hp
			if missing >= 90.0 or forced:
				return position
		"veneno":
			var n3 = _nearest(position, enemies, 500.0)
			if n3 != null:
				return _lead(n3)
		"engrenagem":
			var low = null
			var lf := 0.85
			for a in allies:
				var f: float = a.hp / a.max_hp
				if f < lf and _nearest(a.position, enemies, 450.0) != null:
					lf = f
					low = a
			if low != null:
				return low.position
			if forced:
				var tank = game.get_hero(team, "talos")
				return tank.position if tank != null and tank.alive else position
		"segunda":
			for a in allies:
				if a.position.distance_to(position) < 240.0 and a.hp / a.max_hp < 0.35:
					return position
			if forced:
				return position
	if forced:
		return fallback
	return null


# --------------------------------------------------------------------------
# IA de movimento e formação
func _think(dt: float) -> Vector2:
	var beh: String = game.commanders[team].behavior
	var forward := _forward()
	var enemies: Array = game.alive_heroes(1 - team)
	var hpf := hp / max_hp
	var th: float = {"aggressive": 0.15, "balanced": 0.3, "defensive": 0.35}[beh]
	if game.desperate(team):
		th = 0.0
		retreating = false
	if hpf < th and undying_t <= 0.0:
		retreating = true
	if retreating and hpf > 0.8:
		retreating = false

	if is_healer():
		_support_heal(dt)

	target = _pick_target(enemies, beh)
	if target != null:
		var to: Vector2 = target.position - position
		if to.length() > 0.1:
			facing = to.normalized()
	elif not retreating:
		facing = facing.lerp(Vector2(forward, 0.0), 0.05).normalized()
	_try_attack()

	if retreating:
		if target != null and position.distance_to(target.position) < 120.0:
			return _kite(target.position)
		if not is_healer():
			var sup = _team_healer()
			if sup != null and not sup.retreating:
				# Fica a 60 px do curandeiro, do lado em que está: sem atravessá-lo
				# nem empurrá-lo (BUG-014) e sem congelar (BUG-011).
				var side_dir: Vector2 = position - sup.position
				side_dir = side_dir.normalized() if side_dir.length() > 1.0 else Vector2(-forward, 0.0)
				return _hold(sup.position + side_dir * 60.0)
		return _go(game.spawn_pos(team), 25.0)

	# Objetivo primeiro: com o ponto do inimigo (ou neutro), vai para o ponto.
	if game.contest_need(team) and position.distance_to(game.CENTER) > game.POINT_R * 0.75:
		return _steer(_contest_spot(forward))

	var form := _formation_pos(beh, forward)

	# Suporte: acompanha quem precisa de cura, sem passar à frente do tanque.
	if style == "backline_support":
		if target != null and position.distance_to(target.position) < 110.0:
			return _kite(target.position)
		var ht = heal_target
		if ht != null and ht != self and ht.position.distance_to(position) > 160.0:
			return _steer(_clamp_behind_front(ht.position - Vector2(forward * 60.0, 0.0), beh))
		return _hold(form)

	if target != null:
		var d: float = position.distance_to(target.position)
		match style:
			"frontline", "dive":
				# Já no alcance: para de empurrar o alvo (BUG-010: tanques travavam
				# se empurrando um contra o outro).
				if d - target.radius > def["range"] * 0.8:
					return _steer(target.position)
				return _strafe() * 0.5
			"battle_support":
				if d > def["range"] * 0.7:
					return _steer(_clamp_behind_front(target.position, beh))
				return _strafe() * 0.5
			"flank":
				if d < 150.0:
					return _kite(target.position)
				if d > def["range"] * 0.85:
					var lane := -150.0 if position.y < game.CENTER.y else 150.0
					var wp: Vector2 = target.position + Vector2(0.0, lane)
					if position.distance_to(wp) > 80.0 and d > def["range"] * 1.2:
						return _steer(wp)
					return _steer(target.position)
				return _strafe() * 0.5
			_:
				# backline_dps: atira de trás, recua se encostarem.
				if d < 150.0:
					return _kite(target.position)
				if d > def["range"] * 0.85:
					var chase := _clamp_behind_front(target.position, beh)
					if chase.distance_to(position) < 12.0:
						return _strafe() * 0.5
					return _steer(chase)
				return _strafe() * 0.5

	return _hold(form)


## Lugar dentro do ponto para contestar, mantendo a formação.
func _contest_spot(forward: float) -> Vector2:
	var c: Vector2 = game.CENTER
	match style:
		"frontline", "dive":
			return c + Vector2(forward * 25.0, 0.0)
		"backline_dps", "flank":
			return c + Vector2(-forward * 40.0, -35.0)
		"backline_support", "battle_support":
			return c + Vector2(-forward * 50.0, 35.0)
	return c


## Posição na formação, conforme o estilo do herói.
func _formation_pos(beh: String, forward: float) -> Vector2:
	var c: Vector2 = game.CENTER
	var front: Vector2
	if not game.point_unlocked():
		front = c - Vector2(forward * (game.POINT_R + 45.0), 0.0)
	else:
		var dx: float = {"aggressive": 150.0, "balanced": 20.0, "defensive": 0.0}[beh]
		front = c + Vector2(forward * dx, 0.0)
	if style == "frontline" or style == "dive":
		# Não avança sozinho: espera o grupo se ele ficou muito atrás.
		var others: Array = []
		for a in game.alive_heroes(team):
			if a != self and not a.retreating:
				others.append(a)
		if not others.is_empty():
			var nearest_d := INF
			for a in others:
				nearest_d = minf(nearest_d, a.position.distance_to(position))
			var ahead_of_group := true
			for a in others:
				if (a.position.x - position.x) * forward > 0.0:
					ahead_of_group = false
			if nearest_d > 280.0 and ahead_of_group and beh != "aggressive":
				return position
		return front
	var lead = _team_front()
	var lead_pos: Vector2 = lead.position if lead != null else front
	match style:
		"backline_dps":
			var back := 40.0 if beh == "aggressive" else 90.0
			return lead_pos - Vector2(forward * back, 55.0)
		"backline_support":
			return lead_pos - Vector2(forward * 120.0, -50.0)
		"battle_support":
			return lead_pos - Vector2(forward * 50.0, -35.0)
		"flank":
			var lane := -170.0 if slot_index % 2 == 0 else 170.0
			return Vector2(c.x + forward * 40.0, c.y + lane)
	return front


## Impede heróis de trás de passarem à frente do tanque.
func _clamp_behind_front(p: Vector2, beh: String) -> Vector2:
	if not is_backline() or style == "flank":
		return p
	var forward := _forward()
	var lead = _team_front()
	var limit_x: float
	if lead != null:
		limit_x = lead.position.x + forward * 30.0
	elif beh == "aggressive":
		return p
	else:
		limit_x = game.CENTER.x + forward * 60.0
	if (p.x - limit_x) * forward > 0.0:
		p.x = limit_x
	return p


func _team_front():
	for a in game.alive_heroes(team):
		if a != self and (a.style == "frontline" or a.style == "dive") and not a.retreating:
			return a
	return null


func _team_healer():
	for a in game.alive_heroes(team):
		if a != self and a.is_healer():
			return a
	return null


func _pick_target(enemies: Array, beh: String):
	var aggro: float = {"aggressive": 560.0, "balanced": 400.0, "defensive": 320.0}[beh]
	if not game.point_unlocked():
		aggro = 300.0
	if style == "dive":
		aggro += 150.0
	var leash: float = {"aggressive": 99999.0, "balanced": game.POINT_R + 380.0, "defensive": game.POINT_R + 220.0}[beh]
	if game.contest_need(team):
		leash = minf(leash, game.POINT_R + 110.0)
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
		match style:
			"backline_dps", "flank":
				score = d + e.hp * 0.6
			"dive":
				score = d * 0.5 + e.hp + (400.0 if e.style == "frontline" else 0.0)
		if score < best_score:
			best_score = score
			best = e
	return best


func _try_attack() -> void:
	if target == null or attack_cd > 0.0 or stun_t > 0.0 or dash_t > 0.0:
		return
	if style == "backline_support" and heal_target != null and heal_target.position.distance_to(position) <= def["heal_range"]:
		return
	var d: float = position.distance_to(target.position) - target.radius
	if d > def["range"]:
		return
	attack_cd = def["cd"] / (1.0 + (haste_amt if haste_t > 0.0 else 0.0))
	if def["range"] < 100.0:
		swing_t = 0.18
		game.sfx("melee", -10.0)
		game.deal_damage(self, target, def["dmg"])
		for e in game.alive_heroes(1 - team):
			if e != target and e.position.distance_to(target.position) < 45.0:
				game.deal_damage(self, e, def["dmg"] * 0.5)
	else:
		var dir: Vector2 = (target.position - position).normalized()
		var col: Color = role_color().lightened(0.45)
		game.sfx("shot" if not is_healer() else "shot_support", -14.0)
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


## Movimento lateral em combate: perpendicular ao alvo e longe das bordas
## (BUG-008: antes era sempre vertical e prendia o herói na parede).
func _strafe() -> Vector2:
	var perp := Vector2(-facing.y, facing.x)
	var v := perp * sin(game.time * 1.3 + strafe_phase)
	var safe: Rect2 = game.ARENA.grow(-(radius + 30.0))
	if not safe.has_point(position + v * 40.0):
		v = -v
		if not safe.has_point(position + v * 40.0):
			v = (game.CENTER - position).normalized()
	return v


## Vai até a posição e, ao chegar, continua se movimentando levemente.
func _hold(dest: Vector2) -> Vector2:
	var d := position.distance_to(dest)
	if d < 14.0:
		var t: float = game.time
		return Vector2(0.3 * sin(t * 0.9 + strafe_phase), 0.55 * sin(t * 1.4 + strafe_phase * 1.7))
	return _steer(dest) * minf(1.0, d / 40.0)


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
	var rc := role_color()
	var t: float = game.time
	if hit_flash > 0.0:
		hc = hc.lerp(Color.WHITE, 0.6)

	# Rastro de investida/salto
	if dash_t > 0.0:
		var back := -dash_vel.normalized()
		var spr := Art.hero_sprite(hid)
		for k in 3:
			if spr != null:
				# Com sprite: rastro de cópias translúcidas do próprio herói.
				var px0: float = Art.HERO_SPRITE_PX.get(hid, (radius + 3.0) * 2.0 / 0.8)
				Art.draw_centered(self, spr, back * (14.0 + k * 14.0), Vector2(px0, px0) * (0.95 - k * 0.1), sprite_angle, Color(1, 1, 1, 0.3 - k * 0.08))
			else:
				draw_circle(back * (14.0 + k * 14.0), radius * (0.9 - k * 0.2), Color(hc, 0.3 - k * 0.08))
	if haste_t > 0.0:
		var a0 := facing.angle() + PI
		draw_arc(Vector2.ZERO, radius + 12.0, a0 - 0.8, a0 + 0.8, 14, Color(rc.lightened(0.4), 0.7), 3.0, true)
		draw_arc(Vector2.ZERO, radius + 18.0, a0 - 0.6, a0 + 0.6, 12, Color(rc.lightened(0.4), 0.4), 2.0, true)

	# Feixe de cura
	if heal_beam_t > 0.0 and heal_target != null and is_instance_valid(heal_target) and heal_target.alive and heal_target != self:
		var tp: Vector2 = heal_target.position - position
		if not Art.draw_beam(self, "feixe_cura", Vector2.ZERO, tp, 6.0):
			draw_line(Vector2.ZERO, tp, Color(0.45, 1.0, 0.6, 0.7), 4.0, true)
			draw_line(Vector2.ZERO, tp, Color(1, 1, 1, 0.6), 1.5, true)

	# Sombra e corpo
	draw_circle(Vector2(0, 5), radius + 2.0, Color(0, 0, 0, 0.35))
	var aura_k := radius / 22.0  # auras são feitas no tamanho do Talos (raio 22)
	if undying_t > 0.0 and Art.draw_fx(self, "aura_segunda", Vector2.ZERO, Art.FX_EFFECTS["aura_segunda"], aura_k, 0.9, t * 1.5):
		pass
	elif undying_t > 0.0:
		draw_circle(Vector2.ZERO, radius + 12.0, Color(1.0, 0.85, 0.3, 0.3))
		for k in 8:
			var ang := t * 1.5 + k * TAU / 8.0
			draw_line(Vector2(cos(ang), sin(ang)) * (radius + 6.0), Vector2(cos(ang), sin(ang)) * (radius + 16.0), Color(1, 0.9, 0.4, 0.8), 2.0, true)
	if ult >= 100.0:
		var pulse := 0.5 + 0.5 * sin(t * 6.0)
		UI.ring(self, Vector2.ZERO, radius + 7.0, Color(Data.GOLD, 0.4 + 0.5 * pulse), 2.0)
	var sprite := Art.hero_sprite(hid)
	if sprite != null:
		# Com sprite: só a imagem gira com o herói; o anel do time fica fixo e por
		# cima dela, para a cor do time sempre aparecer. Sem triângulo de direção
		# e sem emblema (a imagem já mostra os dois).
		var px: float = Art.HERO_SPRITE_PX.get(hid, (radius + 3.0) * 2.0 / 0.8)
		var mod := Color(1.8, 1.8, 1.8) if hit_flash > 0.0 else Color.WHITE
		Art.draw_centered(self, sprite, Vector2.ZERO, Vector2(px, px), sprite_angle, mod)
		UI.ring(self, Vector2.ZERO, radius + 1.5, tc, 3.0)
	else:
		draw_circle(Vector2.ZERO, radius + 3.0, tc)
		draw_circle(Vector2.ZERO, radius, hc)
		UI.hero_glyph(self, hid, Vector2.ZERO, radius * 0.5, Color(0.1, 0.07, 0.05, 0.9))

		# Indicador de direção
		var tip := facing * (radius + 9.0)
		var side := Vector2(-facing.y, facing.x) * 5.0
		draw_colored_polygon(PackedVector2Array([tip, facing * (radius + 2.0) + side, facing * (radius + 2.0) - side]), tc)

	# Golpe corpo a corpo
	if swing_t > 0.0:
		var a := facing.angle()
		var sk := (radius + 18.0) / 40.0
		if not Art.draw_fx(self, "soco_arco", facing * (radius + 12.0), Art.FX_EFFECTS["soco_arco"], sk, swing_t / 0.18, a):
			draw_arc(Vector2.ZERO, radius + 18.0, a - 0.9, a + 0.9, 12, Color(1, 0.9, 0.6, 0.8), 4.0, true)

	# Muralha de Bronze
	if wall_t > 0.0:
		var a2 := facing.angle()
		var alpha := clampf(wall_hp / 450.0, 0.3, 1.0)
		if Art.draw_fx(self, "muralha_arco", facing * 44.0, Art.FX_EFFECTS["muralha_arco"], 1.0, alpha, a2):
			pass
		else:
			_draw_wall_code(a2, alpha)

	# Estados
	if dr_t > 0.0 and Art.draw_fx(self, "aura_valvula", Vector2.ZERO, Art.FX_EFFECTS["aura_valvula"], aura_k, 0.85, t * 1.0):
		pass
	elif dr_t > 0.0:
		# Válvula de Pressão: vapor girando
		for k in 4:
			var ang3 := t * 2.2 + k * TAU / 4.0
			draw_circle(Vector2(cos(ang3), sin(ang3)) * (radius + 6.0), 4.0, Color(1, 1, 1, 0.35))
		UI.ring(self, Vector2.ZERO, radius + 5.0, Color(1.0, 0.65, 0.3, 0.8), 2.0)
	if shield_hp > 0.0 and Art.draw_fx(self, "aura_engrenagem", Vector2.ZERO, Art.FX_EFFECTS["aura_engrenagem"], aura_k, 0.95, -t * 1.8):
		pass
	elif shield_hp > 0.0:
		# Engrenagem Vital: engrenagens orbitando
		UI.ring(self, Vector2.ZERO, radius + 8.0, Color(0.6, 1.0, 0.8, 0.8), 2.5)
		for k in 3:
			var ang4 := -t * 1.8 + k * TAU / 3.0
			UI.gear(self, Vector2(cos(ang4), sin(ang4)) * (radius + 9.0), 5.0, 6, Color(0.7, 1.0, 0.85), t * 4.0)
	if root_t > 0.0 and Art.draw_fx(self, "aura_raiz", Vector2(0, 4), Art.FX_EFFECTS["aura_raiz"], aura_k):
		pass
	elif root_t > 0.0:
		UI.ring(self, Vector2(0, 4), radius + 4.0, Color(0.55, 0.4, 0.2, 1.0), 4.0)
		for k in 4:
			var ang5 := k * TAU / 4.0 + 0.4
			draw_line(Vector2(cos(ang5), sin(ang5)) * (radius + 1.0), Vector2(cos(ang5), sin(ang5)) * (radius + 10.0), Color(0.6, 0.45, 0.25), 3.0)
	if slow_t > 0.0:
		UI.ring(self, Vector2.ZERO, radius + 1.0, Color(0.5, 0.7, 1.0, 0.7), 2.0)
	if poison_t > 0.0:
		for i in 4:
			var ph := fmod(t * 1.2 + i * 0.25, 1.0)
			var bp := Vector2(sin(i * 2.1) * radius * 0.7, -ph * (radius + 10.0))
			if not Art.draw_fx(self, "veneno_bolha", bp, Art.FX_EFFECTS["veneno_bolha"], 1.6 - ph, 1.0 - ph):
				draw_circle(bp, 2.5 * (1.0 - ph) + 1.0, Color(0.5, 1.0, 0.3, 1.0 - ph))
	if stun_t > 0.0:
		for i in 3:
			var ang2: float = t * 5.0 + i * TAU / 3.0
			var sp := Vector2(cos(ang2) * 12.0, -radius - 20.0 + sin(ang2) * 4.0)
			if not Art.draw_fx(self, "atordoado_estrela", sp, Art.FX_EFFECTS["atordoado_estrela"], 1.0, 1.0, t * 4.0):
				draw_circle(sp, 3.0, Color(1, 0.95, 0.3))

	# Barra de vida
	var bw := 46.0
	var by := -radius - 13.0
	draw_rect(Rect2(-bw * 0.5 - 1, by - 1, bw + 2, 7), Color(0, 0, 0, 0.75))
	draw_rect(Rect2(-bw * 0.5, by, bw * clampf(hp / max_hp, 0.0, 1.0), 5), tc.lerp(Color.WHITE, 0.15))
	if shield_hp > 0.0:
		draw_rect(Rect2(-bw * 0.5, by - 4, bw * clampf(shield_hp / max_hp, 0.0, 1.0), 3), Color(0.7, 1.0, 0.85))

	# Habilidades armadas (aguardando o momento)
	var n := armed.size()
	for i in n:
		var a3: Dictionary = armed[i]
		var c := Vector2((i - (n - 1) * 0.5) * 22.0, by - 16.0)
		var ab: Dictionary = Data.ABILITIES[a3["ab"]]
		var pulse2 := 0.75 + 0.25 * sin(t * 8.0)
		UI.badge(self, c, 9.0, ab, rc, pulse2, a3["ult"])
		var frac := clampf(a3["t"] / Data.ARM_TIME, 0.0, 1.0)
		draw_arc(c, 12.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 20, Color(1, 1, 1, 0.8), 2.0, true)

	UI.text_c(self, Vector2(0, radius + 16.0), def["name"], 11, Color(1, 1, 1, 0.85), 3)


## Muralha de Bronze desenhada por código (sem imagem).
func _draw_wall_code(a2: float, alpha: float) -> void:
	draw_arc(Vector2.ZERO, 44.0, a2 - 1.0, a2 + 1.0, 18, Color(1.0, 0.6, 0.2, alpha * 0.35), 16.0, true)
	draw_arc(Vector2.ZERO, 44.0, a2 - 1.0, a2 + 1.0, 18, Color(0.95, 0.65, 0.25, alpha), 7.0, true)
	draw_arc(Vector2.ZERO, 44.0, a2 - 1.0, a2 + 1.0, 18, Color(1, 1, 0.8, alpha * 0.8), 2.0, true)
	for k in 5:
		var ra := a2 - 0.8 + k * 0.4
		draw_circle(Vector2(cos(ra), sin(ra)) * 44.0, 2.0, Color(0.4, 0.25, 0.1, alpha))
