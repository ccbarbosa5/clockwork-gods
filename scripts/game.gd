extends Node2D
## Partida: mapa, ponto de controle, combate, habilidades e regras.

const Data = preload("res://scripts/data.gd")
const T = preload("res://scripts/i18n.gd")
const UI = preload("res://scripts/ui.gd")
const Art = preload("res://scripts/art.gd")
const HeroScript = preload("res://scripts/hero.gd")
const Commander = preload("res://scripts/commander.gd")
const Bot = preload("res://scripts/bot.gd")
const Wheel = preload("res://scripts/wheel.gd")
const Arena = preload("res://scripts/arena.gd")
const HUD = preload("res://scripts/hud.gd")
const AudioScript = preload("res://scripts/audio.gd")

signal request(action: String)

const ARENA := Rect2(0, 40, 1280, 520)
const CENTER := Vector2(640, 300)
const POINT_R := Data.POINT_R
const SPAWN_R := 75.0
const SPAWNS := [Vector2(62, 300), Vector2(1218, 300)]
const STEP := 1.0 / 60.0

## Arena em uso (arenas/<id>.json; scripts/arena.gd). `arena_obs` tem todos os
## obstáculos (círculos e retângulos; "tiro" = bloqueia tiros); `obstacles` só
## os redondos como Vector3(x, y, raio), para o desenho das colunas.
var arena_id := Arena.DEFAULT
var arena_def: Dictionary = {}
var arena_obs: Array = []
var shot_obs: Array = []
var obstacles: Array = []
var heroes: Array = []
## Pacotes de vida (Data.HEALTH_PACKS): {pos, t}; t > 0 = reaparece em t s.
var packs: Array = []
## Como a partida acabou: "points" (alguém chegou a 100%) ou "time" (tempo esgotado).
var end_reason := ""
var commanders: Array = [null, null]
var bots: Array = [null, null]
var projectiles: Array = []
var traps: Array = []
var rains: Array = []
var fx: Array = []
## Nuvem de Tempestade: aviso de 1 s e depois o raio. {pos, r, t, team, src}
var clouds: Array = []
## Fúria do Olimpo: raios aleatórios em volta do Zeus. {src, team, life, tick, left}
var storms: Array = []
## Égide: cúpula que bloqueia projéteis vindos de fora. {pos, r, life, hp, team, src}
var domes: Array = []
## Falange de Atenas: zona fixa. {pos, r, life, team, src, got_shield: []}
var phalanxes: Array = []
## Roda do Destino de cada time (scripts/wheel.gd) e se o sistema está ligado.
var wheels: Array = []
var wheel_on := true
## Ordem em que as cartas foram armadas (para a roda prever a próxima engrenagem).
var arm_seq := 0
## Só para a simulação: [time, engrenagem] cujo bônus não vale (ver tests/simulate.gd).
var wheel_nobonus: Array = []
## Composição de cada time: [tanque, dano, suporte].
var teams: Array = [Data.DEFAULT_TEAM.duplicate(), Data.DEFAULT_TEAM.duplicate()]
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
## Linha menor abaixo do aviso (volta completa da roda).
var announce_sub := ""

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
	wheel_on = opts.get("wheel", true)
	wheel_nobonus = opts.get("wheel_nobonus", [])
	wheels = [Wheel.new(), Wheel.new()]
	var opt_teams: Array = opts.get("teams", [])
	for t in 2:
		if opt_teams.size() > t and Data.valid_team(opt_teams[t], opts.get("free", false)):
			teams[t] = Data.sort_team(opt_teams[t])
	load_arena(opts.get("arena", Arena.DEFAULT))
	for t in 2:
		for i in teams[t].size():
			var h := Node2D.new()
			h.set_script(HeroScript)
			add_child(h)
			h.setup(self, t, teams[t][i], i)
			h.position = _spawn_slot(t, i)
			heroes.append(h)
	for t in 2:
		var c = Commander.new()
		c.setup(self, t, teams[t])
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


func load_arena(id: String) -> void:
	var a := Arena.get_arena(id)
	arena_id = id
	arena_def = a["def"]
	arena_obs = a["obs"]
	shot_obs = []
	obstacles = []
	for o in arena_obs:
		if o["tiro"]:
			shot_obs.append(o)
		if o["circulo"]:
			obstacles.append(Vector3(o["c"].x, o["c"].y, o["r"]))
	packs.clear()
	for pp in a["packs"]:
		packs.append({"pos": pp, "t": 0.0})


## Linha de tiro livre entre a e b (muretas não bloqueiam).
func has_los(a: Vector2, b: Vector2) -> bool:
	return Arena.line_clear(shot_obs, a, b, true)


## Anda de `from` até `to` sem atravessar obstáculo (raio r). Devolve o último
## ponto livre e se bateu. Usado em avanços e empurrões rápidos.
func sweep(from: Vector2, to: Vector2, r: float) -> Array:
	var d := from.distance_to(to)
	var n := int(ceil(d / 4.0))
	var last := from
	for k in range(1, n + 1):
		var p := from.lerp(to, float(k) / n)
		if not Arena.free_at(arena_obs, p, r - 1.0):
			return [last, true]
		last = p
	return [to, false]


func _spawn_slot(t: int, i: int) -> Vector2:
	return SPAWNS[t] + Vector2(0, (i - 1) * 40.0)


# ---------------------------------------------------------------------------
# Consultas
## Herói do time na posição i (ordem de Data.sort_team: Tanque, Dano, Suporte).
func team_hero(t: int, i: int):
	return get_hero(t, teams[t][i])


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
	for w in wheels:
		w.update(dt)
	for b in bots:
		if b != null:
			b.think(dt)
	for h in heroes:
		h.tick(dt)
	_separate()
	_update_projectiles(dt)
	_update_traps(dt)
	_update_rains(dt)
	_update_zeus_zones(dt)
	_update_atena_zones(dt)
	_update_point(dt)
	_update_packs(dt)
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
		for o in arena_obs:
			h.position = _push_out(o, h.position, h.radius)
		var enemy_spawn: Vector2 = SPAWNS[1 - h.team]
		var ve: Vector2 = h.position - enemy_spawn
		var de := ve.length()
		if de < SPAWN_R + h.radius:
			h.position = enemy_spawn + ve / maxf(de, 0.01) * (SPAWN_R + h.radius)
		h.position.x = clampf(h.position.x, ARENA.position.x + h.radius, ARENA.end.x - h.radius)
		h.position.y = clampf(h.position.y, ARENA.position.y + h.radius, ARENA.end.y - h.radius)
	# Se ainda sobrepõe (vão entre obstáculo e borda menor que o herói), sai pela lateral.
	for o in arena_obs:
		if not o["circulo"]:
			continue
		var c2: Vector2 = o["c"]
		var minimum2: float = o["r"] + h.radius
		if h.position.distance_to(c2) < minimum2 - 0.5:
			var dy: float = h.position.y - c2.y
			var dx: float = sqrt(maxf(0.0, minimum2 * minimum2 - dy * dy))
			var sx := 1.0 if h.position.x >= c2.x else -1.0
			h.position.x = c2.x + sx * (dx + 0.5)
	# Garantia final: se ainda sobrepõe algo (ex.: caiu do Salto de Nemeia num
	# vão apertado), vai para o ponto livre mais próximo, em espiral.
	if not spot_free(h.position, h.radius, h.team):
		var base_pos: Vector2 = h.position
		for ring in range(1, 40):
			var found := false
			for k in 16:
				var ang := k * TAU / 16.0
				var p: Vector2 = base_pos + Vector2(cos(ang), sin(ang)) * ring * 4.0
				if spot_free(p, h.radius, h.team):
					h.position = p
					found = true
					break
			if found:
				break


## Empurra p para fora do obstáculo o (círculo ou retângulo), com folga r.
static func _push_out(o: Dictionary, p: Vector2, r: float) -> Vector2:
	if o["circulo"]:
		var c: Vector2 = o["c"]
		var v: Vector2 = p - c
		var d := v.length()
		var minimum: float = o["r"] + r
		if d < minimum:
			if d < 0.01:
				v = Vector2(0, 1)
				d = 1.0
			return c + v / d * minimum
		return p
	var rr: Rect2 = o["ret"]
	if rr.has_point(p):
		# Dentro: sai pelo lado mais perto.
		var dl := p.x - rr.position.x
		var dr := rr.end.x - p.x
		var dt := p.y - rr.position.y
		var db := rr.end.y - p.y
		var m := minf(minf(dl, dr), minf(dt, db))
		if m == dl:
			return Vector2(rr.position.x - r, p.y)
		if m == dr:
			return Vector2(rr.end.x + r, p.y)
		if m == dt:
			return Vector2(p.x, rr.position.y - r)
		return Vector2(p.x, rr.end.y + r)
	var q := Vector2(clampf(p.x, rr.position.x, rr.end.x), clampf(p.y, rr.position.y, rr.end.y))
	var v2 := p - q
	var d2 := v2.length()
	if d2 < r:
		return q + v2 / maxf(d2, 0.001) * r
	return p


## Posição livre para um herói de raio r do time `team`: dentro da arena, fora
## dos obstáculos e fora da base inimiga.
func spot_free(p: Vector2, r: float, team: int) -> bool:
	if p.x < ARENA.position.x + r or p.x > ARENA.end.x - r or p.y < ARENA.position.y + r or p.y > ARENA.end.y - r:
		return false
	if not Arena.free_at(arena_obs, p, r - 0.5):
		return false
	return p.distance_to(SPAWNS[1 - team]) >= SPAWN_R + r - 0.5


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
			end_reason = "points"
			_end(t)
			return
	if time >= Data.MATCH_TIME:
		end_reason = "time"
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
	victim.calm_t = 0.0  # interrompe a regeneração passiva
	var amt := amount
	if src != null and is_instance_valid(src) and src.buff_t > 0.0:
		amt *= 1.2  # Comando de Guerra
	if victim.mark_t > 0.0:
		amt *= 1.2  # Olhar da Coruja
	if victim.hide_t > 0.0:
		var mh: float = amt * victim.hide_amt  # Pele do Leão
		amt -= mh
		credit_mitigation(victim, mh)
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
		add_text(victim.position + Vector2(randf_range(-10, 10), -victim.radius - 18), str(int(round(amount * (1.2 if victim.mark_t > 0.0 else 1.0)))), Color(1, 0.92, 0.75))
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


# ---------------------------------------------------------------------------
# Pacotes de vida
func _update_packs(dt: float) -> void:
	for pk in packs:
		if pk["t"] > 0.0:
			pk["t"] = maxf(0.0, pk["t"] - dt)
			continue
		for h in heroes:
			if not h.alive or h.hp >= h.max_hp or h.leaping:
				continue
			if h.position.distance_to(pk["pos"]) <= Data.PACK_PICK_R + h.radius:
				var before: float = h.hp
				heal(null, h, Data.PACK_HEAL)
				h.stats["pack"] += h.hp - before
				pk["t"] = Data.PACK_RESPAWN
				_burst(pk["pos"], 30.0, Color(0.5, 1.0, 0.6), 0.45)
				if h.team == player_team:
					sfx("sopro", -8.0)
				break


## Pacote disponível mais perto de `p` (a até `max_d` px), ou null.
func nearest_pack(p: Vector2, max_d: float):
	var best = null
	var bd := max_d
	for pk in packs:
		if pk["t"] > 0.0:
			continue
		var d: float = p.distance_to(pk["pos"])
		if d < bd:
			bd = d
			best = pk
	return best


func _draw_packs() -> void:
	for pk in packs:
		var pos: Vector2 = pk["pos"]
		if pk["t"] > 0.0:
			# Base vazia, com o tempo para voltar.
			UI.ring(self, pos, 12.0, Color(0.5, 1.0, 0.6, 0.18), 2.0)
			var frac: float = 1.0 - pk["t"] / Data.PACK_RESPAWN
			draw_arc(pos, 12.0, -PI * 0.5, -PI * 0.5 + TAU * frac, 20, Color(0.5, 1.0, 0.6, 0.45), 2.0, true)
			continue
		var bob := sin(time * 3.0 + pos.x * 0.01) * 2.0
		draw_circle(pos + Vector2(0, 6), 12.0, Color(0, 0, 0, 0.3))
		if Art.draw_map(self, "health_pack", pos + Vector2(0, bob), Data.PACK_PICK_R):
			continue
		var c := pos + Vector2(0, bob)
		draw_circle(c, 15.0, Color(0.5, 1.0, 0.6, 0.18 + 0.08 * sin(time * 4.0)))
		draw_circle(c, 11.0, Color(0.1, 0.08, 0.06))
		UI.ring(self, c, 11.0, Data.BRONZE, 2.0)
		draw_rect(Rect2(c + Vector2(-2.5, -7), Vector2(5, 14)), Color(0.45, 1.0, 0.55))
		draw_rect(Rect2(c + Vector2(-7, -2.5), Vector2(14, 5)), Color(0.45, 1.0, 0.55))


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
			# Égide: bloqueia projéteis inimigos que entram na cúpula vindos de fora.
			var prev: Vector2 = p["pos"] - p["vel"] * dt
			for d in domes:
				if d["team"] == p["team"]:
					continue
				if prev.distance_to(d["pos"]) > d["r"] and p["pos"].distance_to(d["pos"]) <= d["r"]:
					d["hp"] -= p["dmg"]
					credit_mitigation(d["src"] if is_instance_valid(d["src"]) else null, p["dmg"])
					_burst(p["pos"], 14.0, Color(0.85, 0.9, 0.95), 0.25)
					alive = false
					break
		if alive:
			# Paredes, colunas, caldeiras e estátuas param o tiro; muretas não.
			if not Arena.line_clear(shot_obs, p["pos"] - p["vel"] * dt, p["pos"], true):
				alive = false
				_burst(p["pos"], 10.0, Color(1, 0.85, 0.5), 0.2)
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
	if p["kind"] == "chain" and h.alive and src != null:
		# Corrente de Cérbero: puxa até 150 px em direção ao Hércules e atordoa 0,4 s.
		var v: Vector2 = src.position - h.position
		var dist: float = clampf(v.length() - (src.radius + h.radius + 6.0), 0.0, 150.0)
		if dist > 1.0:
			h.apply_knock(v.normalized() * dist / 0.25, 0.25, 0.4 * p.get("ctrl", 1.0), "pull")
		else:
			h.apply_stun(0.4 * p.get("ctrl", 1.0))
		_burst(h.position, 22.0, Color(0.85, 0.6, 0.3), 0.3)
	if p["kind"] == "spear" and src != null and src.alive:
		pallas_shield(src)
	if p["kind"] == "poison" and h.alive:
		h.poison_t = 5.0
		h.poison_dps = 12.0 * p.get("dmg_k", 1.0)
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
					h.apply_root(1.8 * tr.get("ctrl", 1.0))
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
					h.apply_slow(0.3, 0.4)
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
				e.apply_stun(0.6)
				e.apply_knock(h.dash_vel.normalized() * 380.0, 0.3)


# ---------------------------------------------------------------------------
# Habilidades
func cast(h, ab: String, tpos: Vector2) -> bool:
	if h == null or not h.alive:
		return false
	var allies := alive_heroes(h.team)
	var enemies := alive_heroes(1 - h.team)
	var dir: Vector2 = tpos - h.position
	dir = dir.normalized() if dir.length() > 1.0 else h.facing
	# Roda do Destino: se a carta engrenou, ganha o bônus da sua engrenagem.
	var gear_res := _wheel_cast(h, ab)
	var bonus: int = gear_res["gear"] if gear_res.get("linked", false) else -1
	if wheel_nobonus.size() == 2 and wheel_nobonus[0] == h.team and wheel_nobonus[1] == bonus:
		bonus = -1
	var ctrl_k := 1.0 + Data.GEAR_CTRL_BONUS if bonus == 1 else 1.0
	var dmg_k := 1.0 + Data.GEAR_DMG_BONUS if bonus == 2 else 1.0
	var def_k := 1.0 + Data.GEAR_DEF_BONUS if bonus == 3 else 1.0
	if bonus == 0:
		_gear_move_shield(h)
	match ab:
		"muralha":
			h.facing = dir
			h.wall_t = 4.0
			h.wall_hp = 450.0 * def_k
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
					a.dr_amt = 0.4 * def_k
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
						e.apply_stun(1.6)
			_burst(h.position, 210.0, Color(1.0, 0.6, 0.2), 0.7, "furia_area")
			fx.append({"type": "cracks", "img": "furia_area", "pos": h.position, "r": 210.0, "col": Color(1.0, 0.55, 0.15), "t": 0.9, "max": 0.9, "seed": randf() * TAU})
		"disparo":
			h.facing = dir
			spawn_projectile(h, h.position + dir * 20.0, dir * 1100.0, 90.0 * dmg_k, 8.0, "pierce", Color(0.85, 0.95, 1.0), true, 0.85)
		"armadilha":
			var p := _clamp_range(h.position, tpos, 380.0)
			if count_traps(h.team) >= 2:
				for i in traps.size():
					if traps[i]["team"] == h.team:
						traps.remove_at(i)
						break
			traps.append({"pos": p, "team": h.team, "arm": 0.6, "life": 20.0, "src": h, "ctrl": ctrl_k})
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
					heal(h, a, 120.0 * def_k)
			_burst(h.position, 210.0, Color(0.5, 1.0, 0.6), 0.6, "sopro_area")
			for k in 10:
				var ang2 := randf() * TAU
				fx.append({"type": "plus", "pos": h.position + Vector2(cos(ang2), sin(ang2)) * randf_range(10.0, 190.0), "r": 7.0, "col": Color(0.55, 1.0, 0.6), "t": 0.9, "max": 0.9})
		"veneno":
			h.facing = dir
			spawn_projectile(h, h.position + dir * 18.0, dir * 750.0, 15.0 * dmg_k, 7.0, "poison", Color(0.55, 1.0, 0.3), false, 1.0)
			projectiles[-1]["dmg_k"] = dmg_k
		"engrenagem":
			var best = h
			var bd := INF
			for a in allies:
				var d2: float = a.position.distance_to(tpos)
				if d2 < bd:
					bd = d2
					best = a
			best.shield_hp = 150.0 * def_k
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
		# --- Hércules ---
		"nemeia":
			var lp := _clamp_range(h.position, tpos, 300.0)
			var eb: Vector2 = SPAWNS[1 - h.team]
			if lp.distance_to(eb) < SPAWN_R + h.radius:
				lp = eb + (lp - eb).normalized() * (SPAWN_R + h.radius + 2.0)
			h.facing = dir
			h.leaping = true
			h.leap_target = lp
			h.dash_vel = (lp - h.position) / 0.45
			h.dash_t = 0.45
			h.dash_damage = false
			fx.append({"type": "leap_mark", "pos": lp, "r": 75.0, "col": Color(0, 0, 0), "t": 0.45, "max": 0.45})
		"pele":
			h.hide_t = 3.0
			h.hide_amt = 0.5 * def_k
			h.stun_t = 0.0
			h.root_t = 0.0
			_burst(h.position, h.radius + 20.0, Color(1.0, 0.75, 0.3), 0.4)
		"corrente":
			h.facing = dir
			spawn_projectile(h, h.position + dir * 20.0, dir * 900.0, 25.0, 8.0, "chain", Color(0.8, 0.55, 0.25), false, 330.0 / 900.0)
			projectiles[-1]["ctrl"] = ctrl_k
		"trabalho":
			var grab = null
			var gd := INF
			for e in enemies:
				var d3: float = e.position.distance_to(h.position) - e.radius
				if d3 <= 90.0 and d3 < gd:
					gd = d3
					grab = e
			if grab != null:
				deal_damage(h, grab, 90.0)
				if grab.alive:
					var home: Vector2 = (SPAWNS[h.team] - grab.position).normalized()
					grab.apply_knock(home * 240.0 / 0.4, 0.4, 1.2, "throw")
				_burst(grab.position, 30.0, Color(1.0, 0.6, 0.25), 0.4)
		# --- Zeus ---
		"raios":
			var first = null
			var fd := INF
			for e in enemies:
				if e.position.distance_to(h.position) - e.radius > 280.0:
					continue
				var d4: float = e.position.distance_to(tpos)
				if d4 < fd:
					fd = d4
					first = e
			if first != null:
				h.facing = (first.position - h.position).normalized()
				var cdm: Array = []
				for v in h.def.get("chain_cast", [60.0, 45.0, 34.0, 25.0]):
					cdm.append(v * dmg_k)
				chain_lightning(h, first, cdm, 150.0, 5.0)
		"nuvem":
			var cp := _clamp_range(h.position, tpos, 450.0)
			clouds.append({"pos": cp, "r": 100.0, "t": 1.0, "max": 1.0, "team": h.team, "src": h, "ctrl": ctrl_k})
		"aguia":
			var ap := _clamp_range(h.position, tpos, 200.0)
			var av: Vector2 = ap - h.position
			if av.length() > 1.0:
				h.facing = av.normalized()
			h.dash_vel = av / 0.2
			h.dash_t = 0.2
			h.dash_damage = false
			h.empower_t = 3.0
			for k in 6:
				fx.append({"type": "feather", "pos": h.position + Vector2(randf_range(-12, 12), randf_range(-12, 12)), "r": 6.0, "col": Data.GOLD, "t": 0.6, "max": 0.6, "seed": randf() * TAU})
		"olimpo":
			storms.append({"src": h, "team": h.team, "life": 4.0, "tick": 0.0, "left": 8})
		# --- Atena ---
		"egide":
			var ep := _clamp_range(h.position, tpos, 300.0)
			domes.append({"pos": ep, "r": 100.0, "life": 3.0, "hp": 400.0 * def_k, "team": h.team, "src": h})
			_burst(ep, 100.0, Color(0.85, 0.9, 0.95), 0.4)
		"comando":
			for a in allies:
				if a.position.distance_to(h.position) <= 200.0:
					a.buff_t = 4.0
			_burst(h.position, 200.0, Color(0.6, 0.75, 0.35), 0.5, "comando_area")
		"coruja":
			var mk = null
			var md := INF
			for e in enemies:
				if e.position.distance_to(h.position) > 400.0 + e.radius or not has_los(h.position, e.position):
					continue
				var d5: float = e.position.distance_to(tpos)
				if d5 < md:
					md = d5
					mk = e
			if mk != null:
				mk.mark_t = 4.0 * ctrl_k
				mk.apply_slow(0.2, 4.0 * ctrl_k)
				fx.append({"type": "owl", "pos": h.position, "to": mk.position, "r": 8.0, "col": Data.GOLD, "t": 0.35, "max": 0.35})
		"falange":
			phalanxes.append({"pos": h.position, "r": 180.0, "life": 5.0, "team": h.team, "src": h, "got": []})
			_burst(h.position, 180.0, Color(0.75, 0.85, 0.6), 0.5)
		_:
			return false
	h.last_cast = ab
	h.last_cast_t = time
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


## Hércules caiu do Salto de Nemeia: 40 de dano e 30% de lentidão por 1,5 s
## num raio de 75 px. Se caiu em cima de uma coluna, é empurrado para fora.
func leap_land(h) -> void:
	resolve_collisions(h)
	for e in alive_heroes(1 - h.team):
		if e.position.distance_to(h.position) <= 75.0 + e.radius * 0.5:
			deal_damage(h, e, 40.0)
			if e.alive:
				e.apply_slow(0.3, 1.5)
	_burst(h.position, 75.0, Color(0.95, 0.65, 0.3), 0.5, "nemeia_queda")
	for k in 8:
		var ang := randf() * TAU
		add_puff(h.position + Vector2(cos(ang), sin(ang)) * randf_range(20.0, 70.0), Color(0.9, 0.8, 0.65))
	sfx("melee", -4.0)


## Alvo do Décimo Terceiro Trabalho caiu.
func on_throw_land(h) -> void:
	fx.append({"type": "img", "img": "trabalho_impacto", "pos": h.position, "r": 30.0, "col": Color(1.0, 0.6, 0.25), "t": 0.5, "max": 0.5})


## Raio em cadeia (não é projétil: Muralha e Égide não bloqueiam; obstáculos que
## bloqueiam tiro cortam o salto). Atinge `first` com dmgs[0]
## e salta para o inimigo mais próximo ainda não atingido a até `jump` px,
## com os danos seguintes. Desenha os raios entre os alvos.
func chain_lightning(src, first, dmgs: Array, jump: float, width := 3.0) -> void:
	var pts := PackedVector2Array([src.position])
	var hit: Array = []
	var cur = first
	for i in dmgs.size():
		if cur == null:
			break
		hit.append(cur)
		pts.append(cur.position)
		deal_damage(src, cur, dmgs[i])
		var nxt = null
		var nd := jump
		for e in alive_heroes(1 - src.team):
			if hit.has(e):
				continue
			var d: float = e.position.distance_to(cur.position)
			if d <= nd and has_los(cur.position, e.position):
				nd = d
				nxt = e
		cur = nxt
	fx.append({"type": "bolt", "pts": pts, "pos": pts[pts.size() - 1], "r": width, "col": Data.GOLD, "t": 0.18, "max": 0.18, "seed": randf() * 100.0})


## Ataque básico do Zeus: raio instantâneo de 14 que salta para 1 inimigo a até
## 90 px (7). Fortalecido pelo Voo da Águia: +30 no alvo e salta para 2.
func zeus_basic(h, target) -> void:
	var dmg: float = h.def["dmg"]
	var jumps := 1
	if h.empower_t > 0.0:
		h.empower_t = 0.0
		dmg += 30.0
		jumps = 2
	var dmgs: Array = [dmg]
	for k in jumps:
		dmgs.append(h.def["chain_dmg"])
	chain_lightning(h, target, dmgs, h.def["chain_range"], 2.0 if jumps == 1 else 4.0)


## Passiva Escudo de Palas: 10 de escudo no aliado mais ferido a até 220 px
## da Atena (acumula até 60, dura 4 s).
func pallas_shield(src) -> void:
	var cfg: Dictionary = src.def.get("pallas", {})
	if cfg.is_empty():
		return
	var best = null
	var bf := 2.0
	for a in alive_heroes(src.team):
		if a.position.distance_to(src.position) > cfg["range"]:
			continue
		var f: float = a.hp / a.max_hp
		if f < bf:
			bf = f
			best = a
	if best == null or best.shield_hp >= cfg["max"]:
		return
	if best.shield_hp <= 0.0:
		best.shield_src = src
	best.shield_hp = minf(cfg["max"], best.shield_hp + cfg["amount"])
	best.shield_t = maxf(best.shield_t, cfg["time"])


func _update_zeus_zones(dt: float) -> void:
	var keep: Array = []
	for c in clouds:
		c["t"] -= dt
		if c["t"] > 0.0:
			keep.append(c)
			continue
		var src = c["src"] if is_instance_valid(c["src"]) else null
		for e in alive_heroes(1 - c["team"]):
			if e.position.distance_to(c["pos"]) <= c["r"] + e.radius * 0.5:
				deal_damage(src, e, 50.0)
				if e.alive:
					e.apply_stun(0.8 * c.get("ctrl", 1.0))
		fx.append({"type": "strike", "pos": c["pos"], "r": 12.0, "col": Data.GOLD, "t": 0.3, "max": 0.3, "seed": randf() * 100.0})
		_burst(c["pos"], c["r"], Color(1.0, 0.85, 0.35), 0.35)
		sfx("melee", -6.0)
	clouds = keep
	var keep2: Array = []
	for s in storms:
		var z = s["src"]
		if not is_instance_valid(z) or not z.alive:
			continue
		s["life"] -= dt
		s["tick"] -= dt
		if s["tick"] <= 0.0 and s["left"] > 0:
			s["tick"] = 0.5
			s["left"] -= 1
			var near: Array = []
			for e in alive_heroes(1 - s["team"]):
				if e.position.distance_to(z.position) <= 350.0:
					near.append(e)
			if not near.is_empty():
				var e2 = near[randi() % near.size()]
				deal_damage(z, e2, 30.0)
				if e2.alive:
					e2.apply_slow(0.2, 0.5)
				fx.append({"type": "strike", "pos": e2.position, "r": 8.0, "col": Data.GOLD, "t": 0.25, "max": 0.25, "seed": randf() * 100.0})
		if s["life"] > 0.0 and s["left"] > 0:
			keep2.append(s)
	storms = keep2


func _update_atena_zones(dt: float) -> void:
	var keep: Array = []
	for d in domes:
		d["life"] -= dt
		if d["life"] > 0.0 and d["hp"] > 0.0:
			keep.append(d)
	domes = keep
	var keep2: Array = []
	for z in phalanxes:
		z["life"] -= dt
		var src = z["src"] if is_instance_valid(z["src"]) else null
		for a in alive_heroes(z["team"]):
			if a.position.distance_to(z["pos"]) > z["r"]:
				continue
			a.phalanx_t = 0.15
			if not z["got"].has(a):
				z["got"].append(a)
				a.shield_hp += 100.0
				a.shield_t = maxf(a.shield_t, z["life"])
				a.shield_src = src
		for e in alive_heroes(1 - z["team"]):
			if e.position.distance_to(z["pos"]) <= z["r"]:
				e.apply_slow(0.3, 0.2)
		if z["life"] > 0.0:
			keep2.append(z)
	phalanxes = keep2


# ---------------------------------------------------------------------------
# Roda do Destino
## Registra a carta na roda do time (ultimates ficam fora) e dá as recompensas
## de Cadência e volta completa. Retorna o resultado de Wheel.on_cast (vazio se
## a carta não conta).
func _wheel_cast(h, ab: String) -> Dictionary:
	var g := Data.gear_of(ab)
	if not wheel_on or g < 0:
		return {}
	var res: Dictionary = wheels[h.team].on_cast(g)
	if not res["linked"]:
		return res
	var mine: bool = h.team == player_team
	add_text(h.position + Vector2(0, -h.radius - 34), T.t("WHEEL_IN_GEAR"), Data.GOLD, 1.1, 15)
	fx.append({"type": "gear_spark", "pos": h.position, "r": h.radius + 16.0, "col": Data.GOLD, "t": 0.6, "max": 0.6, "seed": randf() * TAU})
	if res["cadence"]:
		commanders[h.team].add_ichor(Data.CADENCE_REFUND)
		add_text(h.position + Vector2(0, -h.radius - 52), T.tf("WHEEL_CADENCE", [res["links"]]), Data.GOLD.lightened(0.3), 1.3, 13)
	if res["full"]:
		for a in alive_heroes(h.team):
			a.add_charge(Data.FULL_TURN_ULT)
		fx.append({"type": "gear_spark", "pos": h.position, "r": 90.0, "col": Data.GOLD, "t": 0.9, "max": 0.9, "seed": randf() * TAU})
		if mine:
			announce(T.t("WHEEL_FULL_TURN"), Data.GOLD, 2.2)
			announce_sub = T.tf("WHEEL_FULL_TURN_SUB", [int(Data.FULL_TURN_ULT)])
			flash_t = 0.4
			flash_col = Data.GOLD
	if mine:
		sfx("gear", -4.0)
	return res


## Defesa → Movimento: o herói que se desloca chega com escudo.
func _gear_move_shield(h) -> void:
	if h.shield_hp <= 0.0:
		h.shield_src = h
	h.shield_hp += Data.GEAR_MOVE_SHIELD
	h.shield_t = maxf(h.shield_t, Data.GEAR_MOVE_SHIELD_T)


## Engrenagem que a próxima carta do time precisa ter para engrenar, contando
## as cartas já armadas que ainda não aconteceram (-1 = nada engatado).
func wheel_next_gear(t: int) -> int:
	if not wheel_on or wheels.is_empty():
		return -1
	var last := -1
	var seq := -1
	for h in heroes:
		if h.team != t or not h.alive:
			continue
		for a in h.armed:
			if not a["ult"] and a.get("seq", 0) > seq:
				seq = a.get("seq", 0)
				last = Data.gear_of(a["ab"])
	if last >= 0:
		return (last + 1) % Data.GEARS.size()
	return wheels[t].next_gear()


## Uma carta foi jogada e a habilidade está armada no herói.
func on_armed(h, _ab: String) -> void:
	arm_seq += 1
	if not h.armed.is_empty():
		h.armed[-1]["seq"] = arm_seq
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
	announce_sub = ""
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
	for o in obstacles:
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
		if not Art.draw_fx(self, "chuva_area", r["pos"], rain_size, 1.0, Art.RAIN_ALPHA, time * 0.3):
			draw_circle(r["pos"], r["r"], Color(rc, 0.12))
			UI.ring(self, r["pos"], r["r"], Color(0.85, 0.9, 1.0, 0.6), 2.0)
		else:
			UI.ring(self, r["pos"], r["r"], Color(rc, 0.8), 3.0)  # cor do time continua visível
		for k in 14:
			var sd: float = float(k) * 12.9898 + floor(time * 8.0) * 3.7
			var ox: float = sin(sd) * r["r"] * 0.9
			var oy: float = cos(sd * 1.3) * r["r"] * 0.9
			var p: Vector2 = r["pos"] + Vector2(ox, oy)
			if p.distance_to(r["pos"]) < r["r"]:
				if not Art.draw_fx(self, "chuva_flecha", p + Vector2(-2, -6), Art.FX_EFFECTS["chuva_flecha"], 1.0, 0.95, Vector2(4, 12).angle()):
					draw_line(p + Vector2(-4, -12), p, Color(0.9, 0.95, 1.0, 0.85), 2.0)

	_draw_packs()
	_draw_new_zones()

	# Projéteis
	for p2 in projectiles:
		var v: Vector2 = p2["vel"].normalized()
		if p2["kind"] == "chain" and is_instance_valid(p2["src"]):
			# Corrente de Cérbero: elos do Hércules até o gancho.
			if not Art.draw_beam(self, "corrente_elo", p2["src"].position, p2["pos"], 8.0):
				var a0: Vector2 = p2["src"].position
				var seg: float = a0.distance_to(p2["pos"])
				var n := int(seg / 9.0)
				for k in n:
					var pk: Vector2 = a0.lerp(p2["pos"], (k + 0.5) / maxf(1.0, n))
					draw_arc(pk, 3.5, 0.0, TAU, 8, Color(0.75, 0.52, 0.25), 2.0)
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
			"chain":
				for k in 3:
					var ang := v.angle() + (k - 1) * 0.6
					draw_line(p2["pos"], p2["pos"] + Vector2(cos(ang), sin(ang)) * 9.0, Color(0.85, 0.6, 0.3), 3.0, true)
				draw_circle(p2["pos"], 4.0, Color(0.6, 0.4, 0.2))
			"spear":
				draw_line(p2["pos"] - v * 30.0, p2["pos"] - v * 8.0, Color(0.6, 0.72, 0.4, 0.5), 5.0, true)
				draw_line(p2["pos"] - v * 26.0, p2["pos"], Color(0.88, 0.9, 0.95), 2.5, true)
				draw_colored_polygon(PackedVector2Array([p2["pos"] + v * 4.0, p2["pos"] - v * 4.0 + v.orthogonal() * 3.0, p2["pos"] - v * 4.0 - v.orthogonal() * 3.0]), Color(0.95, 0.97, 1.0))
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
			"bolt":
				_draw_bolt(f["pts"], f["r"], f["seed"], 1.0 - k2)
			"strike":
				# Raio vertical caindo do céu + clarão no chão.
				var top: Vector2 = f["pos"] + Vector2(0, -140.0)
				if not Art.draw_fx(self, "raio_queda", f["pos"] + Vector2(0, -70.0), Art.FX_EFFECTS["raio_queda"], 1.0, 1.0 - k2):
					_draw_bolt(PackedVector2Array([top, f["pos"]]), 4.0, f["seed"], 1.0 - k2)
				draw_circle(f["pos"], 18.0 * (0.6 + k2), Color(1.0, 0.9, 0.5, 0.45 * (1.0 - k2)))
			"gear_spark":
				# Roda do Destino engrenou: engrenagem dourada girando e faíscas.
				var gr: float = f["r"] * (0.7 + 0.4 * k2)
				UI.gear(self, f["pos"], gr, 12, Color(fc, 0.35 * (1.0 - k2)), f["seed"] + k2 * 2.0)
				UI.ring(self, f["pos"], gr * 0.8, Color(fc, 0.8 * (1.0 - k2)), 2.0)
				for j in 8:
					var ga: float = f["seed"] + j * TAU / 8.0
					var gv := Vector2(cos(ga), sin(ga))
					draw_line(f["pos"] + gv * gr * (0.9 + 0.3 * k2), f["pos"] + gv * gr * (1.1 + 0.5 * k2), Color(1.0, 0.95, 0.7, 1.0 - k2), 2.0, true)
			"leap_mark":
				# Sombra que cresce onde o Hércules vai cair.
				draw_circle(f["pos"], f["r"] * (0.3 + 0.7 * k2), Color(0, 0, 0, 0.25 + 0.15 * k2))
				if not Art.draw_fx(self, "nemeia_alvo", f["pos"], Art.FX_EFFECTS["nemeia_alvo"] * (f["r"] / 75.0), 1.0, 0.5 + 0.5 * k2):
					UI.ring(self, f["pos"], f["r"], Color(0.95, 0.65, 0.3, 0.5), 2.0)
			"feather":
				var fp: Vector2 = f["pos"] + Vector2(sin(f["seed"] + k2 * 4.0) * 8.0, 14.0 * k2)
				if not Art.draw_fx(self, "aguia_pena", fp, Art.FX_EFFECTS["aguia_pena"], 1.0, 1.0 - k2, f["seed"] + k2 * 3.0):
					draw_line(fp - Vector2(4, 2), fp + Vector2(4, 2), Color(Data.GOLD, 1.0 - k2), 3.0, true)
			"owl":
				var op: Vector2 = f["pos"].lerp(f["to"], k2) + Vector2(0, -30.0 * sin(k2 * PI))
				if not Art.draw_fx(self, "coruja_voo", op, Art.FX_EFFECTS["coruja_voo"], 1.0, 1.0, (f["to"] - f["pos"]).angle()):
					draw_circle(op, 6.0, Color(0.72, 0.55, 0.3))
					draw_circle(op + Vector2(-2, -1), 1.8, Data.GOLD)
					draw_circle(op + Vector2(2, -1), 1.8, Data.GOLD)
			"img":
				if not Art.draw_fx(self, f["img"], f["pos"], Art.FX_EFFECTS.get(f["img"], Vector2(44, 44)), 1.0, 1.0 - k2):
					UI.ring(self, f["pos"], f["r"] * (0.3 + 0.7 * k2), Color(fc, 1.0 - k2), 4.0)
			_:
				if f.has("img") and Art.draw_fx(self, f["img"], f["pos"], Vector2(f["r"], f["r"]) * 2.0, 0.3 + 0.7 * k2, Art.AREA_ALPHA * (1.0 - k2), k2 * 0.5):
					continue
				UI.ring(self, f["pos"], f["r"] * (0.3 + 0.7 * k2), Color(fc, 1.0 - k2), 4.0)

	# Renascimento
	for h in heroes:
		if not h.alive:
			var sp: Vector2 = _spawn_slot(h.team, h.slot_index)
			UI.text_c(self, sp + Vector2(0, 5), "%s %d" % [T.hero_name(h.hid).substr(0, 1), int(ceil(h.respawn_t))], 12, Color(Data.TEAM_COLORS[h.team], 0.8), 3)


## Selos das habilidades recém-usadas, acima dos heróis. Só o ícone: o nome
## fica no registro do canto e, nas ultimates, no anúncio do topo. Selos que
## se encostariam são afastados lado a lado, para não se empilharem.
const POPUP_R := 11.0
const POPUP_ULT_R := 14.0
const POPUP_GAP := 3.0


func popup_layout() -> Array:
	var out: Array = []
	for pp in popups:
		var hero = pp["hero"]
		if is_instance_valid(hero) and hero.alive:
			pp["pos"] = hero.position
		var k: float = 1.0 - pp["t"] / pp["max"]
		var big: bool = pp["ult"]
		var r := POPUP_ULT_R if big else POPUP_R
		var abd: Dictionary = Data.ABILITIES[pp["ab"]]
		var c: Vector2 = pp["pos"] + Vector2(0, -52.0 - 10.0 * k)
		# Procura uma posição livre alternando direita/esquerda.
		var base := c
		var step := 0
		while true:
			var free := true
			for o in out:
				if c.distance_to(o["pos"]) < r + o["r"] + POPUP_GAP:
					free = false
					break
			if free or step > 12:
				break
			step += 1
			var side := 1.0 if step % 2 == 1 else -1.0
			c = base + Vector2(side * ceil(step / 2.0) * (r * 2.0 + POPUP_GAP), 0)
		out.append({"pos": c, "r": r, "ab": pp["ab"], "ult": big,
			"col": Data.ROLE_COLORS[Data.HEROES[abd["hero"]]["role"]],
			"a": clampf(pp["t"] / pp["max"] * 2.5, 0.0, 1.0)})
	return out


## Raio em zigue-zague passando por `pts` (dourado, com núcleo claro).
func _draw_bolt(pts: PackedVector2Array, w: float, sd: float, a: float) -> void:
	for i in pts.size() - 1:
		var p0: Vector2 = pts[i]
		var p1: Vector2 = pts[i + 1]
		var line := PackedVector2Array([p0])
		var n := maxi(2, int(p0.distance_to(p1) / 18.0))
		var perp := (p1 - p0).orthogonal().normalized()
		for k in range(1, n):
			var off := sin(sd + k * 7.7 + i * 3.1) * 7.0
			line.append(p0.lerp(p1, float(k) / n) + perp * off)
		line.append(p1)
		# Com imagem (fx/raio_cadeia.png), a faixa segue o mesmo zigue-zague.
		if Art.fx("raio_cadeia") != null:
			for k in line.size() - 1:
				# 2 px a mais em cada ponta para não abrir fresta nas dobras.
				var dk: Vector2 = (line[k + 1] - line[k]).normalized() * 2.0
				Art.draw_beam(self, "raio_cadeia", line[k] - dk, line[k + 1] + dk, w * 3.0, Color(1, 1, 1, a))
			continue
		draw_polyline(line, Color(Data.GOLD, 0.55 * a), w + 3.0, true)
		draw_polyline(line, Color(1.0, 0.97, 0.8, a), maxf(1.0, w * 0.6), true)


## Zonas do Zeus e da Atena (Nuvem, Fúria do Olimpo, Égide, Falange).
func _draw_new_zones() -> void:
	for c in clouds:
		var k: float = 1.0 - c["t"] / c["max"]
		var tc: Color = Data.TEAM_COLORS[c["team"]]
		if not Art.draw_fx(self, "nuvem_area", c["pos"], Art.FX_EFFECTS["nuvem_area"] * (c["r"] / 100.0), 1.0, Art.AREA_ALPHA + 0.2, time * 0.4):
			draw_circle(c["pos"], c["r"], Color(0.75, 0.75, 0.78, 0.22))
			for j in 6:
				var ang := time * 0.4 + j * TAU / 6.0
				draw_circle(c["pos"] + Vector2(cos(ang), sin(ang)) * c["r"] * 0.55, c["r"] * 0.3, Color(0.82, 0.82, 0.86, 0.18))
		UI.ring(self, c["pos"], c["r"], Color(tc, 0.85), 3.0)
		# Aviso: arco dourado enche em 1 s até o raio cair.
		draw_arc(c["pos"], c["r"] - 6.0, -PI * 0.5, -PI * 0.5 + TAU * k, 40, Color(Data.GOLD, 0.9), 4.0, true)
	for s in storms:
		var z = s["src"]
		if is_instance_valid(z) and z.alive:
			if not Art.draw_fx(self, "olimpo_area", z.position, Art.FX_EFFECTS["olimpo_area"], 1.0, 0.35, time * 0.2):
				draw_circle(z.position, 350.0, Color(0.05, 0.05, 0.12, 0.16))
			UI.ring(self, z.position, 350.0, Color(Data.TEAM_COLORS[s["team"]], 0.6), 2.0)
	for d in domes:
		var tc2: Color = Data.TEAM_COLORS[d["team"]]
		var a2: float = clampf(d["hp"] / 400.0, 0.35, 1.0) * clampf(d["life"] * 2.0, 0.0, 1.0)
		if not Art.draw_fx(self, "egide_cupula", d["pos"], Art.FX_EFFECTS["egide_cupula"], 1.0, a2 * 0.8):
			draw_circle(d["pos"], d["r"], Color(0.85, 0.9, 0.95, 0.12 * a2))
			draw_arc(d["pos"], d["r"] * 0.55, PI * 1.1, PI * 1.9, 16, Color(1, 1, 1, 0.25 * a2), 3.0, true)
		UI.ring(self, d["pos"], d["r"], Color(0.9, 0.93, 1.0, 0.8 * a2), 3.0)
		UI.ring(self, d["pos"], d["r"] + 3.0, Color(tc2, 0.7 * a2), 2.0)
	for z2 in phalanxes:
		var tc3: Color = Data.TEAM_COLORS[z2["team"]]
		var a3: float = clampf(z2["life"] * 2.0, 0.0, 1.0)
		if not Art.draw_fx(self, "falange_area", z2["pos"], Art.FX_EFFECTS["falange_area"], 1.0, Art.FALANGE_ALPHA * a3):
			draw_circle(z2["pos"], z2["r"], Color(0.55, 0.65, 0.35, 0.12 * a3))
			for j in 14:
				var ang2 := j * TAU / 14.0
				var sp: Vector2 = z2["pos"] + Vector2(cos(ang2), sin(ang2)) * z2["r"]
				draw_circle(sp, 8.0, Color(0.78, 0.82, 0.86, 0.8 * a3))
				draw_circle(sp, 4.0, Color(0.55, 0.65, 0.35, 0.9 * a3))
			draw_line(z2["pos"] + Vector2(0, 10), z2["pos"] + Vector2(0, -34), Color(0.9, 0.92, 0.95, a3), 3.0, true)
			draw_colored_polygon(PackedVector2Array([z2["pos"] + Vector2(0, -44), z2["pos"] + Vector2(-5, -32), z2["pos"] + Vector2(5, -32)]), Color(0.95, 0.97, 1.0, a3))
		UI.ring(self, z2["pos"], z2["r"], Color(tc3, 0.8 * a3), 3.0)


func draw_overlay(ci: CanvasItem) -> void:
	# Chamado pelo HUD para desenhar acima dos heróis.
	if flash_t > 0.0:
		ci.draw_rect(ARENA.grow(-4), Color(flash_col, clampf(flash_t, 0.0, 0.6)), false, 10.0)
	for b in popup_layout():
		UI.badge(ci, b["pos"], b["r"], Data.ABILITIES[b["ab"]], b["col"], b["a"], b["ult"])
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
		if announce_sub != "":
			UI.text_c(ci, Vector2(640, 134), announce_sub, 15, Color(1, 1, 1, a3), 4)
