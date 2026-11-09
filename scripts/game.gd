extends Node2D
## Partida: mapa, ponto de controle, combate, habilidades e regras.

const Data = preload("res://scripts/data.gd")
const T = preload("res://scripts/i18n.gd")
const UI = preload("res://scripts/ui.gd")
const Art = preload("res://scripts/art.gd")
const HeroScript = preload("res://scripts/hero.gd")
const Commander = preload("res://scripts/commander.gd")
const Bot = preload("res://scripts/bot.gd")
const HUD = preload("res://scripts/hud.gd")
const AudioScript = preload("res://scripts/audio.gd")

signal request(action: String)

const ARENA := Rect2(0, 40, 1280, 520)
const CENTER := Vector2(640, 300)
const POINT_R := Data.POINT_R
const SPAWN_R := 75.0
const SPAWNS := [Vector2(62, 300), Vector2(1218, 300)]
const STEP := 1.0 / 60.0

## Obstáculos simétricos (x, y, raio): colunas e caldeiras.
const OBSTACLES := [
	Vector3(250, 215, 34), Vector3(250, 385, 34),
	Vector3(1030, 215, 34), Vector3(1030, 385, 34),
	Vector3(420, 150, 28), Vector3(420, 450, 28),
	Vector3(860, 150, 28), Vector3(860, 450, 28),
	Vector3(545, 122, 22), Vector3(545, 478, 22),
	Vector3(735, 122, 22), Vector3(735, 478, 22),
	Vector3(330, 300, 20), Vector3(950, 300, 20),
]

var heroes: Array = []
var commanders: Array = [null, null]
var bots: Array = [null, null]
var projectiles: Array = []
var traps: Array = []
var rains: Array = []
var fx: Array = []
var texts: Array = []
var killfeed: Array = []
var cast_feed: Array = []
var cast_counts := {}
var popups: Array = []
var flash_t := 0.0
var flash_col := Color.WHITE
var announce_text := ""
var announce_color := Color.WHITE
var announce_t := 0.0

var time := 0.0
var point_owner := -1
var capture_team := -1
var capture_prog := 0.0
var progress := [0.0, 0.0]
var contested := false
var overtime := false
var ended := false
var result := -2
var paused := false
var player_team := 0
var difficulty := "normal"
var autotest := false
var hud
var _acc := 0.0
var _announced_unlock := false


func setup(opts: Dictionary) -> void:
	difficulty = opts.get("difficulty", "normal")
	autotest = opts.get("autotest", false)
	for t in 2:
		for i in Data.HERO_ORDER.size():
			var h := Node2D.new()
			h.set_script(HeroScript)
			add_child(h)
			h.setup(self, t, Data.HERO_ORDER[i], i)
			h.position = _spawn_slot(t, i)
			heroes.append(h)
	for t in 2:
		var c = Commander.new()
		c.setup(self, t, Data.HERO_ORDER)
		commanders[t] = c
	commanders[0].behavior = opts.get("behavior", "balanced")
	if opts.get("bots", true):
		bots[1] = Bot.new()
		bots[1].setup(self, 1, commanders[1], difficulty)
	if autotest:
		bots[0] = Bot.new()
		bots[0].setup(self, 0, commanders[0], opts.get("difficulty0", "hard"))
	hud = Node2D.new()
	hud.set_script(HUD)
	hud.z_index = 10
	add_child(hud)
	hud.setup(self)
	announce(T.tf("ANN_UNLOCK", [int(Data.UNLOCK_TIME)]), Data.GOLD, 2.5)


func _spawn_slot(t: int, i: int) -> Vector2:
	return SPAWNS[t] + Vector2(0, (i - 1) * 40.0)


# ---------------------------------------------------------------------------
# Consultas
func get_hero(t: int, hid: String):
	for h in heroes:
		if h.team == t and h.hid == hid:
			return h
	return null


func alive_heroes(t: int) -> Array:
	var out: Array = []
	for h in heroes:
		if h.team == t and h.alive:
			out.append(h)
	return out


func spawn_pos(t: int) -> Vector2:
	return SPAWNS[t]


func point_unlocked() -> bool:
	return time >= Data.UNLOCK_TIME


func in_point(p: Vector2) -> bool:
	return p.distance_to(CENTER) <= POINT_R


func in_arena(p: Vector2) -> bool:
	return ARENA.has_point(p)


## O time precisa ir ao ponto: o inimigo controla, está capturando, ou ele está neutro.
## Nesses casos a IA prioriza pisar no ponto em vez de perseguir longe (BUG-015).
func contest_need(t: int) -> bool:
	if not point_unlocked():
		return false
	var e := 1 - t
	if point_owner == e:
		return true
	if capture_team == e and capture_prog > 0.0:
		return true
	return point_owner == -1


## Inimigo perto de vencer: o time luta no ponto até o fim, sem recuar.
func desperate(t: int) -> bool:
	return point_owner == 1 - t and progress[1 - t] >= 85.0


## Toca um efeito sonoro (se o áudio estiver ativo).
func sfx(name: String, db := 0.0) -> void:
	if AudioScript.instance != null and not autotest:
		AudioScript.instance.play(name, db)


func count_traps(t: int) -> int:
	var n := 0
	for tr in traps:
		if tr["team"] == t:
			n += 1
	return n


func time_left() -> float:
	return maxf(0.0, Data.MATCH_TIME - time)


# ---------------------------------------------------------------------------
# Loop
func _process(delta: float) -> void:
	if not paused and not ended:
		_acc += minf(delta, 0.5)
		while _acc >= STEP:
			_acc -= STEP
			_step(STEP)
			if ended:
				break
	_update_visuals(delta)
	queue_redraw()


func _step(dt: float) -> void:
	time += dt
	for c in commanders:
		c.update(dt)
	for b in bots:
		if b != null:
			b.think(dt)
	for h in heroes:
		h.tick(dt)
	_separate()
	_update_projectiles(dt)
	_update_traps(dt)
	_update_rains(dt)
	_update_point(dt)
	_check_end()


func _update_visuals(delta: float) -> void:
	var dt := 0.0 if paused else delta
	var nfx: Array = []
	for f in fx:
		f["t"] -= dt
		if f["t"] > 0.0:
			nfx.append(f)
	fx = nfx
	var nt: Array = []
	for t in texts:
		t["t"] -= dt
		t["pos"] += Vector2(0, -32.0 * dt)
		if t["t"] > 0.0:
			nt.append(t)
	texts = nt
	var nk: Array = []
	for k in killfeed:
		k["t"] -= dt
		if k["t"] > 0.0:
			nk.append(k)
	killfeed = nk
	announce_t -= dt
	flash_t -= dt
	var nc: Array = []
	for c in cast_feed:
		c["t"] -= dt
		if c["t"] > 0.0:
			nc.append(c)
	cast_feed = nc
	var npop: Array = []
	for pp in popups:
		pp["t"] -= dt
		if pp["t"] > 0.0:
			npop.append(pp)
	popups = npop


func _separate() -> void:
	var alive: Array = []
	for h in heroes:
		if h.alive:
			alive.append(h)
	for i in alive.size():
		for j in range(i + 1, alive.size()):
			var a = alive[i]
			var b = alive[j]
			var v: Vector2 = b.position - a.position
			var d := v.length()
			var minimum: float = a.radius + b.radius + 2.0
			if d < minimum:
				if d < 0.01:
					v = Vector2(randf() - 0.5, randf() - 0.5)
					d = v.length()
				var push := v / d * (minimum - d) * 0.5
				a.position -= push
				b.position += push
				resolve_collisions(a)
				resolve_collisions(b)


func resolve_collisions(h) -> void:
	# Várias passadas: empurrar para fora de obstáculos pode jogar o herói contra
	# a borda, e a borda pode devolvê-lo ao obstáculo (BUG-009).
	for it in 3:
		for o in OBSTACLES:
			var c := Vector2(o.x, o.y)
			var v: Vector2 = h.position - c
			var d := v.length()
			var minimum: float = o.z + h.radius
			if d < minimum:
				if d < 0.01:
					v = Vector2(0, 1)
					d = 1.0
				h.position = c + v / d * minimum
		var enemy_spawn: Vector2 = SPAWNS[1 - h.team]
		var ve: Vector2 = h.position - enemy_spawn
		var de := ve.length()
		if de < SPAWN_R + h.radius:
			h.position = enemy_spawn + ve / maxf(de, 0.01) * (SPAWN_R + h.radius)
		h.position.x = clampf(h.position.x, ARENA.position.x + h.radius, ARENA.end.x - h.radius)
		h.position.y = clampf(h.position.y, ARENA.position.y + h.radius, ARENA.end.y - h.radius)
	# Se ainda sobrepõe (vão entre obstáculo e borda menor que o herói), sai pela lateral.
	for o in OBSTACLES:
		var c2 := Vector2(o.x, o.y)
		var minimum2: float = o.z + h.radius
		if h.position.distance_to(c2) < minimum2 - 0.5:
			var dy: float = h.position.y - c2.y
			var dx: float = sqrt(maxf(0.0, minimum2 * minimum2 - dy * dy))
			var sx := 1.0 if h.position.x >= c2.x else -1.0
			h.position.x = c2.x + sx * (dx + 0.5)


# ---------------------------------------------------------------------------
# Ponto de controle
func _update_point(dt: float) -> void:
	if not point_unlocked():
		var left := Data.UNLOCK_TIME - time
		if left <= 3.0 and int(ceil(left)) != int(ceil(left + dt)):
			sfx("tick")
		return
	if not _announced_unlock:
		_announced_unlock = true
		announce(T.t("ANN_POINT_OPEN"), Data.GOLD, 2.0)
		sfx("unlock")
	var n := [0, 0]
	for h in heroes:
		if h.alive and in_point(h.position):
			n[h.team] += 1
	contested = n[0] > 0 and n[1] > 0
	if contested:
		pass
	elif n[0] > 0 or n[1] > 0:
		var t := 0 if n[0] > 0 else 1
		if point_owner == t and capture_prog > 0.0:
			capture_prog = maxf(0.0, capture_prog - dt / Data.CAPTURE_TIME * 2.0)
			if capture_prog <= 0.0:
				capture_team = -1
		elif point_owner != t:
			if capture_team != t and capture_prog > 0.0:
				capture_prog -= dt / Data.CAPTURE_TIME * 2.0
				if capture_prog <= 0.0:
					capture_prog = 0.0
					capture_team = t
			else:
				capture_team = t
				capture_prog += dt / Data.CAPTURE_TIME * (1.0 + 0.25 * (n[t] - 1))
				if capture_prog >= 1.0:
					point_owner = t
					capture_prog = 0.0
					capture_team = -1
					announce(T.tf("ANN_CAPTURED", [T.team_name(t)]), Data.TEAM_COLORS[t], 2.0)
					sfx("capture_us" if t == player_team else "capture_them")
					_burst(CENTER, POINT_R + 10.0, Data.TEAM_COLORS[t], 0.6)
	else:
		capture_prog = maxf(0.0, capture_prog - dt / Data.CAPTURE_TIME * 0.5)
		if capture_prog <= 0.0:
			capture_team = -1
	if point_owner >= 0:
		var rate := Data.PROGRESS_RATE
		if contested:
			# Disputado: só avança (a meia velocidade) se o dono tiver mais heróis no ponto.
			rate = Data.PROGRESS_RATE * Data.CONTESTED_RATE if n[point_owner] > n[1 - point_owner] else 0.0
		progress[point_owner] = minf(100.0, progress[point_owner] + rate * dt)


func _check_end() -> void:
	for t in 2:
		if progress[t] >= 100.0:
			_end(t)
			return
	if time >= Data.MATCH_TIME:
		if contested or (capture_team >= 0 and capture_team != point_owner and capture_prog > 0.0):
			if not overtime:
				overtime = true
				announce(T.t("ANN_OVERTIME"), Data.GOLD, 2.0)
				sfx("overtime")
			return
		if progress[0] > progress[1]:
			_end(0)
		elif progress[1] > progress[0]:
			_end(1)
		else:
			_end(-1)


func _end(winner: int) -> void:
	ended = true
	result = winner
	sfx("victory" if winner == player_team else "defeat")


# ---------------------------------------------------------------------------
# Combate
func deal_damage(src, victim, amount: float, show_text := true) -> void:
	if victim == null or not victim.alive or amount <= 0.0:
		return
	var amt := amount
	if victim.dr_t > 0.0:
		var m: float = amt * victim.dr_amt
		amt -= m
		credit_mitigation(victim.dr_src, m)
	if victim.shield_hp > 0.0:
		var a: float = minf(victim.shield_hp, amt)
		victim.shield_hp -= a
		amt -= a
		credit_mitigation(victim.shield_src, a)
	victim.hp -= amt
	if victim.undying_t > 0.0 and victim.hp < 1.0:
		victim.hp = 1.0
	victim.hit_flash = 0.1
	if src != null and is_instance_valid(src) and src.team != victim.team:
		src.stats["damage"] += amt
		src.add_charge(amt * Data.ULT_DMG)
	if show_text:
		add_text(victim.position + Vector2(randf_range(-10, 10), -victim.radius - 18), str(int(round(amount))), Color(1, 0.92, 0.75))
		sfx("hit", -8.0)
	if victim.hp <= 0.0:
		_kill(victim, src)


func credit_mitigation(h, m: float) -> void:
	if h != null and is_instance_valid(h) and m > 0.0:
		h.stats["mitigated"] += m
		h.add_charge(m * Data.ULT_MIT)


func heal(src, target, amount: float) -> void:
	if target == null or not target.alive:
		return
	var a := amount
	if target.heal_red_t > 0.0:
		a *= 0.5
	var actual: float = minf(target.max_hp - target.hp, a)
	if actual <= 0.0:
		return
	target.hp += actual
	if src != null:
		src.stats["healing"] += actual
		src.add_charge(actual * Data.ULT_HEAL)
	if actual >= 5.0:
		add_text(target.position + Vector2(randf_range(-10, 10), -target.radius - 18), "+" + str(int(round(actual))), Color(0.5, 1.0, 0.6))


func _kill(victim, killer) -> void:
	victim.alive = false
	victim.visible = false
	victim.respawn_t = Data.RESPAWN
	victim.stats["deaths"] += 1
	commanders[victim.team].refund(victim)
	victim.clear_status()
	_burst(victim.position, 40.0, Data.TEAM_COLORS[victim.team], 0.5)
	var killer_hid := ""  # vazio = "O destino"
	if killer != null and is_instance_valid(killer) and killer.team != victim.team:
		killer.stats["kills"] += 1
		killer_hid = killer.hid
		var reward := Data.KILL_REWARD
		if progress[victim.team] > progress[killer.team]:
			reward += Data.KILL_BONUS_LEADER
		commanders[killer.team].add_ichor(reward)
		add_text(victim.position + Vector2(0, -10), T.tf("TEXT_ICHOR_GAIN", [reward]), Data.GOLD, 1.4)
	sfx("death" if victim.team == player_team else "kill")
	killfeed.push_front({"t": 4.0, "a": killer_hid, "at": 1 - victim.team, "b": victim.hid, "bt": victim.team})
	if killfeed.size() > 4:
		killfeed.resize(4)
	commanders[victim.team].on_hero_died(victim.hid)


func respawn(h) -> void:
	h.alive = true
	h.visible = true
	h.hp = h.max_hp
	h.clear_status()
	h.position = _spawn_slot(h.team, h.slot_index)
	commanders[h.team].refill()
	if h.team == player_team:
		sfx("respawn", -6.0)


func spawn_projectile(src, pos: Vector2, vel: Vector2, dmg: float, r: float, kind: String, col: Color, pierce := false, life := 1.2) -> void:
	projectiles.append({"src": src, "team": src.team, "pos": pos, "vel": vel, "dmg": dmg, "r": r,
		"kind": kind, "col": col, "pierce": pierce, "hit": [], "life": life})


func _update_projectiles(dt: float) -> void:
	var keep: Array = []
	for p in projectiles:
		p["pos"] += p["vel"] * dt
		p["life"] -= dt
		var alive: bool = p["life"] > 0.0 and in_arena(p["pos"])
		if alive:
			for o in OBSTACLES:
				if p["pos"].distance_to(Vector2(o.x, o.y)) < o.z:
					alive = false
					_burst(p["pos"], 10.0, Color(1, 0.85, 0.5), 0.2)
					break
		if alive:
			for h in heroes:
				if h.team == p["team"] or not h.alive or h.wall_t <= 0.0:
					continue
				var v: Vector2 = p["pos"] - h.position
				var d := v.length()
				if d < 50.0 and d > 18.0 and v.normalized().dot(h.facing) > 0.52:
					h.wall_hp -= p["dmg"]
					credit_mitigation(h, p["dmg"])
					_burst(p["pos"], 12.0, Color(1, 0.8, 0.4), 0.2)
					alive = false
					break
		if alive:
			for h in heroes:
				if h.team == p["team"] or not h.alive or p["hit"].has(h):
					continue
				if p["pos"].distance_to(h.position) < p["r"] + h.radius:
					_projectile_hit(p, h)
					if p["pierce"]:
						p["hit"].append(h)
					else:
						alive = false
						break
		if alive:
			keep.append(p)
	projectiles = keep


func _projectile_hit(p: Dictionary, h) -> void:
	var src = p["src"] if is_instance_valid(p["src"]) else null
	deal_damage(src, h, p["dmg"])
	if p["kind"] == "poison" and h.alive:
		h.poison_t = 5.0
		h.poison_dps = 12.0
		h.poison_src = src
		h.heal_red_t = 5.0
		_burst(h.position, 24.0, Color(0.5, 1.0, 0.3), 0.3)


func _update_traps(dt: float) -> void:
	var keep: Array = []
	for tr in traps:
		tr["life"] -= dt
		tr["arm"] -= dt
		var used := false
		if tr["arm"] <= 0.0:
			for h in alive_heroes(1 - tr["team"]):
				if h.position.distance_to(tr["pos"]) < 30.0 + h.radius:
					h.root_t = 1.8
					var src = tr["src"] if is_instance_valid(tr["src"]) else null
					deal_damage(src, h, 30.0)
					_burst(tr["pos"], 36.0, Color(0.85, 0.65, 0.3), 0.4)
					fx.append({"type": "img", "img": "armadilha_fechada", "pos": tr["pos"], "r": 22.0, "col": Color.WHITE, "t": 0.6, "max": 0.6})
					used = true
					break
		if not used and tr["life"] > 0.0:
			keep.append(tr)
	traps = keep


func _update_rains(dt: float) -> void:
	var keep: Array = []
	for r in rains:
		r["life"] -= dt
		r["tick"] -= dt
		if r["tick"] <= 0.0:
			r["tick"] = 0.25
			var src = r["src"] if is_instance_valid(r["src"]) else null
			for h in alive_heroes(1 - r["team"]):
				if h.position.distance_to(r["pos"]) < r["r"] + h.radius * 0.5:
					deal_damage(src, h, 22.0, false)
					h.slow_t = 0.4
					h.slow_amt = 0.3
		if r["life"] > 0.0:
			keep.append(r)
	rains = keep


func dash_hits(h) -> void:
	for e in alive_heroes(1 - h.team):
		if h.dash_hit.has(e):
			continue
		if e.position.distance_to(h.position) < h.radius + e.radius + 6.0:
			h.dash_hit.append(e)
			deal_damage(h, e, 45.0)
			if e.alive:
				e.stun_t = maxf(e.stun_t, 0.6)
				e.knock_vel = h.dash_vel.normalized() * 380.0
				e.knock_t = 0.3


# ---------------------------------------------------------------------------
# Habilidades
func cast(h, ab: String, tpos: Vector2) -> bool:
	if h == null or not h.alive:
		return false
	var allies := alive_heroes(h.team)
	var enemies := alive_heroes(1 - h.team)
	var dir: Vector2 = tpos - h.position
	dir = dir.normalized() if dir.length() > 1.0 else h.facing
	match ab:
		"muralha":
			h.facing = dir
			h.wall_t = 4.0
			h.wall_hp = 450.0
			_burst(h.position + dir * 44.0, 40.0, Color(1.0, 0.7, 0.3), 0.4)
		"investida":
			h.facing = dir
			h.dash_vel = dir * (260.0 / 0.35)
			h.dash_t = 0.35
			h.dash_damage = true
			h.dash_hit = []
		"valvula":
			for a in allies:
				if a.position.distance_to(h.position) <= 190.0:
					a.dr_t = 4.0
					a.dr_amt = 0.4
					a.dr_src = h
			_burst(h.position, 190.0, Color(1.0, 0.65, 0.3), 0.5, "valvula_area")
			for k in 14:
				var ang := randf() * TAU
				add_puff(h.position + Vector2(cos(ang), sin(ang)) * randf_range(30.0, 170.0), Color(1, 1, 1))
		"furia":
			for e in enemies:
				if e.position.distance_to(h.position) <= 210.0:
					deal_damage(h, e, 60.0)
					if e.alive:
						e.stun_t = maxf(e.stun_t, 1.6)
			_burst(h.position, 210.0, Color(1.0, 0.6, 0.2), 0.7, "furia_area")
			fx.append({"type": "cracks", "img": "furia_area", "pos": h.position, "r": 210.0, "col": Color(1.0, 0.55, 0.15), "t": 0.9, "max": 0.9, "seed": randf() * TAU})
		"disparo":
			h.facing = dir
			spawn_projectile(h, h.position + dir * 20.0, dir * 1100.0, 90.0, 8.0, "pierce", Color(0.85, 0.95, 1.0), true, 0.85)
		"armadilha":
			var p := _clamp_range(h.position, tpos, 380.0)
			if count_traps(h.team) >= 2:
				for i in traps.size():
					if traps[i]["team"] == h.team:
						traps.remove_at(i)
						break
			traps.append({"pos": p, "team": h.team, "arm": 0.6, "life": 20.0, "src": h})
			_burst(p, 30.0, Color(0.85, 0.65, 0.3), 0.4)
		"salto":
			var away := Vector2.ZERO
			var closest = null
			var cd := INF
			for e in enemies:
				var d: float = e.position.distance_to(h.position)
				if d < cd:
					cd = d
					closest = e
			if closest != null and cd < 400.0:
				away = (h.position - closest.position).normalized()
			else:
				away = (SPAWNS[h.team] - h.position).normalized()
			h.dash_vel = away * (180.0 / 0.25)
			h.dash_t = 0.25
			h.dash_damage = false
			h.haste_t = 3.0
			h.haste_amt = 0.6
		"chuva":
			var p2 := _clamp_range(h.position, tpos, 650.0)
			rains.append({"pos": p2, "team": h.team, "r": 170.0, "life": 2.5, "tick": 0.0, "src": h})
		"sopro":
			for a in allies:
				if a.position.distance_to(h.position) <= 210.0:
					heal(h, a, 120.0)
			_burst(h.position, 210.0, Color(0.5, 1.0, 0.6), 0.6, "sopro_area")
			for k in 10:
				var ang2 := randf() * TAU
				fx.append({"type": "plus", "pos": h.position + Vector2(cos(ang2), sin(ang2)) * randf_range(10.0, 190.0), "r": 7.0, "col": Color(0.55, 1.0, 0.6), "t": 0.9, "max": 0.9})
		"veneno":
			h.facing = dir
			spawn_projectile(h, h.position + dir * 18.0, dir * 750.0, 15.0, 7.0, "poison", Color(0.55, 1.0, 0.3), false, 1.0)
		"engrenagem":
			var best = h
			var bd := INF
			for a in allies:
				var d2: float = a.position.distance_to(tpos)
				if d2 < bd:
					bd = d2
					best = a
			best.shield_hp = 150.0
			best.shield_t = 5.0
			best.shield_src = h
			_burst(best.position, 40.0, Color(0.6, 1.0, 0.8), 0.4)
		"segunda":
			for a in allies:
				if a.position.distance_to(h.position) <= 240.0:
					a.undying_t = 3.0
					heal(h, a, 40.0)
			_burst(h.position, 240.0, Color(1.0, 0.85, 0.3), 0.7, "segunda_area")
			fx.append({"type": "rays", "img": "segunda_area", "pos": h.position, "r": 240.0, "col": Color(1.0, 0.85, 0.3), "t": 1.0, "max": 1.0, "seed": randf() * TAU})
		_:
			return false
	var abd: Dictionary = Data.ABILITIES[ab]
	var is_ult: bool = abd.get("ult", false)
	cast_counts[ab] = cast_counts.get(ab, 0) + 1
	sfx(ab, 0.0 if h.team == player_team else -3.0)
	if is_ult and h.team != player_team:
		sfx("ult_warning", -2.0)
	popups.append({"hero": h, "pos": h.position, "ab": ab, "t": 1.6, "max": 1.6, "ult": is_ult})
	cast_feed.push_front({"t": 6.0, "team": h.team, "hid": h.hid, "ab": ab, "ult": is_ult})
	if cast_feed.size() > 6:
		cast_feed.resize(6)
	if is_ult:
		announce(T.tf("ANN_YOUR_ULT" if h.team == player_team else "ANN_ENEMY_ULT", [T.ab_name(ab)]), Data.TEAM_COLORS[h.team].lerp(Color.WHITE, 0.2), 1.8)
		flash_t = 0.6
		flash_col = Data.TEAM_COLORS[h.team]
	return true


## Uma carta foi jogada e a habilidade está armada no herói.
func on_armed(h, _ab: String) -> void:
	_burst(h.position, h.radius + 14.0, h.role_color(), 0.3)


func _clamp_range(from: Vector2, to: Vector2, r: float) -> Vector2:
	var v := to - from
	if v.length() > r:
		v = v.normalized() * r
	var p := from + v
	p.x = clampf(p.x, ARENA.position.x + 10, ARENA.end.x - 10)
	p.y = clampf(p.y, ARENA.position.y + 10, ARENA.end.y - 10)
	return p


# ---------------------------------------------------------------------------
# Efeitos visuais
## Anel que cresce e some. Com `img`, usa a imagem fx/<img>.png (se existir)
## no tamanho da área, crescendo, sumindo e girando devagar.
func _burst(pos: Vector2, r: float, col: Color, t: float, img := "") -> void:
	var f := {"type": "ring", "pos": pos, "r": r, "col": col, "t": t, "max": t}
	if img != "":
		f["img"] = img
	fx.append(f)


func add_puff(pos: Vector2, col: Color) -> void:
	fx.append({"type": "puff", "pos": pos + Vector2(randf_range(-6, 6), randf_range(-6, 6)), "r": randf_range(10.0, 16.0), "col": col, "t": 0.55, "max": 0.55})


func add_text(pos: Vector2, s: String, col: Color, t := 0.8, size := 14) -> void:
	texts.append({"pos": pos, "s": s, "col": col, "t": t, "max": t, "size": size})


func announce(s: String, col: Color, t := 2.0) -> void:
	announce_text = s
	announce_color = col
	announce_t = t


# ---------------------------------------------------------------------------
# Desenho do mapa
func _draw() -> void:
	# Piso (map/arena_floor.png; sem a imagem, grade e aqueduto por código)
	if not Art.draw_floor(self, ARENA):
		draw_rect(ARENA, Color(0.16, 0.13, 0.11))
		for i in 17:
			var x := 80.0 * i
			draw_line(Vector2(x, ARENA.position.y), Vector2(x, ARENA.end.y), Color(1, 0.85, 0.6, 0.04), 1.0)
		for j in 7:
			var y := ARENA.position.y + 80.0 * j
			draw_line(Vector2(0, y), Vector2(1280, y), Color(1, 0.85, 0.6, 0.04), 1.0)
		# Faixa central (aqueduto)
		draw_rect(Rect2(CENTER.x - 3, ARENA.position.y, 6, ARENA.size.y), Color(0.95, 0.76, 0.31, 0.06))
	draw_rect(ARENA, Color(0.78, 0.54, 0.23, 0.7), false, 3.0)

	# Bases
	for t in 2:
		var sc: Color = Data.TEAM_COLORS[t]
		if Art.draw_map(self, "spawn_base", SPAWNS[t], SPAWN_R):
			# Imagem neutra: o código tinge de leve e contorna com a cor do time.
			draw_circle(SPAWNS[t], SPAWN_R, Color(sc, 0.1))
			UI.ring(self, SPAWNS[t], SPAWN_R, Color(sc, 0.75), 3.0)
			continue
		draw_circle(SPAWNS[t], SPAWN_R, Color(sc, 0.12))
		UI.ring(self, SPAWNS[t], SPAWN_R, Color(sc, 0.6), 2.0)
		UI.gear(self, SPAWNS[t], 22.0, 8, Color(sc, 0.25), time * (0.4 if t == 0 else -0.4))

	# Ponto
	var pc := Color(0.85, 0.8, 0.7)
	if point_owner >= 0:
		pc = Data.TEAM_COLORS[point_owner]
	if not point_unlocked():
		pc = Color(0.5, 0.5, 0.5)
	if Art.draw_map(self, "control_point", CENTER, POINT_R, 0.0, Color(1, 1, 1) if point_unlocked() else Color(0.6, 0.6, 0.6)):
		# Imagem neutra: a cor do dono vem por cima, num véu e no anel.
		draw_circle(CENTER, POINT_R, Color(pc, 0.1 if point_owner >= 0 else 0.0))
	else:
		draw_circle(CENTER, POINT_R, Color(pc, 0.14))
		UI.gear(self, CENTER, 34.0, 10, Color(pc, 0.3), time * 0.25)
		draw_circle(CENTER, 16.0, Color(0.95, 0.76, 0.31, 0.6 if point_unlocked() else 0.2))
	UI.ring(self, CENTER, POINT_R, Color(pc, 0.8), 3.0)
	if contested:
		var pulse := 0.5 + 0.5 * sin(time * 10.0)
		UI.ring(self, CENTER, POINT_R + 5.0, Color(1, 1, 1, 0.3 + 0.5 * pulse), 2.0)
	if capture_team >= 0 and capture_prog > 0.0:
		draw_arc(CENTER, POINT_R + 9.0, -PI * 0.5, -PI * 0.5 + TAU * capture_prog, 48, Data.TEAM_COLORS[capture_team], 6.0, true)
	if not point_unlocked():
		UI.text_c(self, CENTER + Vector2(0, 6), str(int(ceil(Data.UNLOCK_TIME - time))), 22, Color(1, 1, 1, 0.8), 4)

	# Obstáculos
	for o in OBSTACLES:
		var c := Vector2(o.x, o.y)
		draw_circle(c + Vector2(0, 6), o.z, Color(0, 0, 0, 0.35))
		if Art.draw_map(self, Art.pillar_name(o.z), c, o.z):
			continue
		draw_circle(c, o.z, Color(0.42, 0.29, 0.15))
		draw_circle(c, o.z * 0.8, Color(0.6, 0.43, 0.22))
		UI.gear(self, c, o.z * 0.55, 6, Color(0.32, 0.22, 0.12), time * 0.3 + o.x)
		UI.ring(self, c, o.z, Color(0.85, 0.62, 0.3), 2.0)

	# Armadilhas
	for tr in traps:
		var tc: Color = Data.TEAM_COLORS[tr["team"]]
		var a := 0.35 if tr["arm"] > 0.0 else 0.8
		if Art.draw_fx(self, "armadilha_aberta", tr["pos"], Art.FX_EFFECTS["armadilha_aberta"], 1.0, a):
			UI.ring(self, tr["pos"], 23.0, Color(tc, a), 2.0)  # cor do time continua visível
			continue
		UI.ring(self, tr["pos"], 22.0, Color(tc, a), 2.0)
		for k in 6:
			var ang := TAU * k / 6.0
			draw_line(tr["pos"] + Vector2(cos(ang), sin(ang)) * 10.0, tr["pos"] + Vector2(cos(ang), sin(ang)) * 22.0, Color(0.8, 0.7, 0.5, a), 2.0)

	# Chuvas
	for r in rains:
		var rc: Color = Data.TEAM_COLORS[r["team"]]
		var rain_size := Vector2(r["r"], r["r"]) * 2.0
		if not Art.draw_fx(self, "chuva_area", r["pos"], rain_size, 1.0, 0.9, time * 0.3):
			draw_circle(r["pos"], r["r"], Color(rc, 0.12))
			UI.ring(self, r["pos"], r["r"], Color(0.85, 0.9, 1.0, 0.6), 2.0)
		else:
			UI.ring(self, r["pos"], r["r"], Color(rc, 0.5), 2.0)  # cor do time continua visível
		for k in 14:
			var sd: float = float(k) * 12.9898 + floor(time * 8.0) * 3.7
			var ox: float = sin(sd) * r["r"] * 0.9
			var oy: float = cos(sd * 1.3) * r["r"] * 0.9
			var p: Vector2 = r["pos"] + Vector2(ox, oy)
			if p.distance_to(r["pos"]) < r["r"]:
				if not Art.draw_fx(self, "chuva_flecha", p + Vector2(-2, -6), Art.FX_EFFECTS["chuva_flecha"], 1.0, 0.95, Vector2(4, 12).angle()):
					draw_line(p + Vector2(-4, -12), p, Color(0.9, 0.95, 1.0, 0.85), 2.0)

	# Projéteis
	for p2 in projectiles:
		var v: Vector2 = p2["vel"].normalized()
		# Com imagem: desenhada apontando para o voo. O tiro básico é tingido
		# com a cor do herói (a imagem deve ser clara/neutra).
		var tint: Color = p2["col"] if p2["kind"] == "basic" else Color.WHITE
		if Art.draw_projectile(self, p2["kind"], p2["pos"], v, tint):
			continue
		match p2["kind"]:
			"pierce":
				draw_line(p2["pos"] - v * 70.0, p2["pos"], Color(0.8, 0.6, 1.0, 0.35), 14.0, true)
				draw_line(p2["pos"] - v * 60.0, p2["pos"], Color(0.95, 0.9, 1.0, 0.9), 4.0, true)
				draw_circle(p2["pos"], 6.0, Color.WHITE)
			"poison":
				var perp := Vector2(-v.y, v.x)
				var pts := PackedVector2Array()
				for k in 8:
					var back := float(k) * 5.0
					pts.append(p2["pos"] - v * back + perp * sin(time * 30.0 + k * 0.9) * 5.0)
				draw_polyline(pts, Color(0.5, 1.0, 0.3, 0.9), 4.0, true)
				draw_circle(p2["pos"], 5.0, Color(0.7, 1.0, 0.4))
			_:
				draw_line(p2["pos"] - v * 8.0, p2["pos"], Color(p2["col"], 0.6), p2["r"], true)
				draw_circle(p2["pos"], p2["r"] * 0.7, p2["col"])

	# Efeitos
	for f in fx:
		var k2: float = 1.0 - f["t"] / f["max"]
		var fc: Color = f["col"]
		match f["type"]:
			"puff":
				if Art.draw_fx(self, "fumaca", f["pos"] + Vector2(0, -10.0 * k2), Vector2(f["r"], f["r"]) * 2.0, 0.5 + 0.8 * k2, 0.6 * (1.0 - k2), k2 * 1.5, fc):
					continue
				draw_circle(f["pos"] + Vector2(0, -10.0 * k2), f["r"] * (0.5 + 0.8 * k2), Color(fc, 0.45 * (1.0 - k2)))
			"plus":
				var pp: Vector2 = f["pos"] + Vector2(0, -26.0 * k2)
				if Art.draw_fx(self, "cura_mais", pp, Art.FX_EFFECTS["cura_mais"], 1.0, 1.0 - k2):
					continue
				var sz: float = f["r"]
				draw_rect(Rect2(pp - Vector2(sz * 0.3, sz), Vector2(sz * 0.6, sz * 2.0)), Color(fc, 1.0 - k2))
				draw_rect(Rect2(pp - Vector2(sz, sz * 0.3), Vector2(sz * 2.0, sz * 0.6)), Color(fc, 1.0 - k2))
			"cracks":
				if Art.fx(f["img"]) != null:
					continue  # a imagem da área já traz as rachaduras
				for k in 10:
					var ang: float = f["seed"] + k * TAU / 10.0
					var len: float = f["r"] * minf(1.0, k2 * 3.0) * (0.6 + 0.4 * sin(k * 7.3))
					var mid := Vector2(cos(ang + 0.15), sin(ang + 0.15)) * len * 0.5
					draw_polyline(PackedVector2Array([f["pos"], f["pos"] + mid, f["pos"] + Vector2(cos(ang), sin(ang)) * len]), Color(fc, 1.0 - k2), 3.0, true)
			"rays":
				if Art.fx(f["img"]) != null:
					continue  # a imagem da área já traz os raios
				for k in 16:
					var ang2: float = f["seed"] + k * TAU / 16.0
					var r0: float = f["r"] * 0.2
					var r1: float = f["r"] * (0.4 + 0.6 * minf(1.0, k2 * 2.0))
					draw_line(f["pos"] + Vector2(cos(ang2), sin(ang2)) * r0, f["pos"] + Vector2(cos(ang2), sin(ang2)) * r1, Color(fc, 0.8 * (1.0 - k2)), 3.0, true)
			"img":
				if not Art.draw_fx(self, f["img"], f["pos"], Art.FX_EFFECTS.get(f["img"], Vector2(44, 44)), 1.0, 1.0 - k2):
					UI.ring(self, f["pos"], f["r"] * (0.3 + 0.7 * k2), Color(fc, 1.0 - k2), 4.0)
			_:
				if f.has("img") and Art.draw_fx(self, f["img"], f["pos"], Vector2(f["r"], f["r"]) * 2.0, 0.3 + 0.7 * k2, 1.0 - k2, k2 * 0.5):
					continue
				UI.ring(self, f["pos"], f["r"] * (0.3 + 0.7 * k2), Color(fc, 1.0 - k2), 4.0)

	# Renascimento
	for h in heroes:
		if not h.alive:
			var sp: Vector2 = _spawn_slot(h.team, h.slot_index)
			UI.text_c(self, sp + Vector2(0, 5), "%s %d" % [T.hero_name(h.hid).substr(0, 1), int(ceil(h.respawn_t))], 12, Color(Data.TEAM_COLORS[h.team], 0.8), 3)


func draw_overlay(ci: CanvasItem) -> void:
	# Chamado pelo HUD para desenhar acima dos heróis.
	if flash_t > 0.0:
		ci.draw_rect(ARENA.grow(-4), Color(flash_col, clampf(flash_t, 0.0, 0.6)), false, 10.0)
	for pp in popups:
		var hero = pp["hero"]
		if is_instance_valid(hero) and hero.alive:
			pp["pos"] = hero.position
		var k: float = 1.0 - pp["t"] / pp["max"]
		var a: float = clampf(pp["t"] / pp["max"] * 2.5, 0.0, 1.0)
		var abd: Dictionary = Data.ABILITIES[pp["ab"]]
		var role_col: Color = Data.ROLE_COLORS[Data.HEROES[abd["hero"]]["role"]]
		var big: bool = pp["ult"]
		var c: Vector2 = pp["pos"] + Vector2(0, -48.0 - 14.0 * k)
		UI.badge(ci, c, 17.0 if big else 13.0, abd, role_col, a, big)
		var tc: Color = Data.TEAM_COLORS[hero.team if is_instance_valid(hero) else 0].lerp(Color.WHITE, 0.45)
		UI.text_c(ci, c + Vector2(0, (32.0 if big else 27.0)), T.ab_name(pp["ab"]), 14 if big else 12, Color(Data.GOLD if big else tc, a), 4)
	var fy := 62.0
	for cf in cast_feed:
		var fa: float = clampf(cf["t"], 0.0, 1.0)
		var abd2: Dictionary = Data.ABILITIES[cf["ab"]]
		var hd: Dictionary = Data.HEROES[cf["hid"]]
		var rcol: Color = Data.ROLE_COLORS[hd["role"]]
		UI.badge(ci, Vector2(22, fy - 5), 8.0, abd2, rcol, fa, cf["ult"])
		var txt: String = "%s · %s" % [T.hero_name(cf["hid"]), T.ab_name(cf["ab"])]
		var col: Color = Data.GOLD if cf["ult"] else Data.TEAM_COLORS[cf["team"]].lerp(Color.WHITE, 0.35)
		UI.text_l(ci, Vector2(38, fy), txt, 13, Color(col, fa), 3)
		fy += 20.0
	for t in texts:
		var a: float = clampf(t["t"] / t["max"] * 1.5, 0.0, 1.0)
		UI.text_c(ci, t["pos"], t["s"], t["size"], Color(t["col"], a), 3)
	var y := 64.0
	for k in killfeed:
		var a2: float = clampf(k["t"], 0.0, 1.0)
		var s: String = "%s  »  %s" % [T.hero_name(k["a"]) if k["a"] != "" else T.t("FEED_FATE"), T.hero_name(k["b"])]
		UI.text_r(ci, Vector2(1268, y), s, 13, Color(1, 1, 1, a2), 3)
		y += 18.0
	if announce_t > 0.0:
		var a3 := clampf(announce_t, 0.0, 1.0)
		UI.text_c(ci, Vector2(640, 110), announce_text, 28, Color(announce_color, a3), 6)
