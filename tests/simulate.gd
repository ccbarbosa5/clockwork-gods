extends SceneTree
## Simulador de partidas: joga várias partidas bot contra bot, verifica
## invariantes a cada passo (anomalias = possíveis bugs) e mede o equilíbrio.
## Rodar:  godot --headless --path . --script res://tests/simulate.gd -- --matches=12
##         ... -- --balance   joga as 64 combinações de times (bots difíceis dos
##                            dois lados) e mostra a taxa de vitória de cada herói
## Sai com código 1 se encontrar anomalias ou métricas fora dos limites.

const Data = preload("res://scripts/data.gd")
const T = preload("res://scripts/i18n.gd")
const GameScript = preload("res://scripts/game.gd")

const STEP := 1.0 / 60.0
const MAX_TIME := 420.0

## Limites aceitáveis das métricas agregadas.
const LIMITS := {
	"duration_min": 100.0, "duration_max": 330.0,
	"kills_min": 5.0,
	"winrate_min": 0.15,            # cada lado vence pelo menos 15% (bots iguais)
	"formation_ok_min": 0.80,       # tempo com a linha de trás atrás do tanque
	"armed_wait_max": 4.0,          # espera média de uma carta armada (s)
	"uncontested_max": 15.0,        # s por partida com o ponto inimigo livre e o time de pé longe dele (BUG-015)
}

var matches := 12
var balance := false
## Parte das partidas (k/n) para rodar o balanceamento em paralelo.
var part_k := 0
var part_n := 1
## Soma às sementes (outra amostra das mesmas combinações).
var seed_offset := 0
## Roda do Destino: --wheel=off desliga; --nobonus=g tira do time 0 o bônus da
## engrenagem g (0 Movimento, 1 Controle, 2 Ataque, 3 Defesa) para ver se algum
## elo é obrigatório; --diffs=a,b troca os níveis dos bots no --balance.
var wheel_on := true
## --free: times do modo livre (até 2 da mesma função); padrão: 1 de cada função.
var free_mode := false
var nobonus := -1
var bal_diffs: Array = ["hard", "hard"]
var wheel_tot := {}
## Por composição de time (a,b,c): partidas e vitórias; como as partidas acabam;
## cura por herói (habilidades, pacotes e regeneração).
var comp_games := {}
var comp_wins := {}
var end_counts := {}
var heal_tot := {}
## As 8 composições possíveis (um herói por função).
var comps: Array = []
## Por herói: partidas e vitórias (sem contar espelhos, quando está nos dois times).
var hero_games := {}
var hero_wins := {}
var anomalies: Array = []
var anomaly_counts := {}
var _ran := false


func _process(_delta: float) -> bool:
	if not _ran:
		_ran = true
		_run()
	return false


func _run() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--matches="):
			matches = a.substr(10).to_int()
		elif a == "--balance":
			balance = true
		elif a == "--free":
			free_mode = true
		elif a == "--wheel=off":
			wheel_on = false
		elif a.begins_with("--nobonus="):
			nobonus = a.substr(10).to_int()
		elif a.begins_with("--diffs="):
			bal_diffs = Array(a.substr(8).split(","))
		elif a.begins_with("--seed="):
			seed_offset = a.substr(7).to_int()
		elif a.begins_with("--part="):
			var kn := a.substr(7).split("/")
			part_k = kn[0].to_int()
			part_n = kn[1].to_int()
	# Padrão: os 8 times de 1 por função (todos contra todos = 64 por semente).
	# --free: os 20 times do modo livre, 64 pares por semente que variam com ela.
	comps = Data.all_teams(free_mode)
	if balance:
		matches = 64
	var results: Array = []
	var casts := {}
	var t0 := Time.get_ticks_msec()
	for m in matches:
		seed(1000 + m + seed_offset)
		if m % part_n != part_k:
			continue
		var diffs: Array = [["hard", "hard"], ["normal", "normal"], ["hard", "easy"], ["easy", "hard"]][m % 4]
		var behaviors := ["balanced", "aggressive", "defensive"]
		var beh: String = behaviors[m % 3]
		# Times em rodízio: em 12 partidas todos os heróis jogam dos dois lados.
		var t0c: Array = comps[m % comps.size()]
		var t1c: Array = comps[(m * 3 + 5) % comps.size()]
		if balance:
			diffs = bal_diffs
			beh = "balanced"
			if free_mode:
				var off := seed_offset / 1000
				t0c = comps[(m + off * 7) % comps.size()]
				t1c = comps[(m * 7 + 3 + off * 3) % comps.size()]
			else:
				t0c = comps[m / comps.size()]
				t1c = comps[m % comps.size()]
		var r := _play_match(m, diffs[0], diffs[1], beh, casts, [t0c, t1c])
		if diffs[0] == diffs[1]:
			_count_heroes(r["winner"], t0c, t1c)
			_count_comp(r["winner"], t0c, t1c)
		end_counts[r["end"]] = end_counts.get(r["end"], 0) + 1
		results.append(r)
		print("partida %2d  %-6s x %-6s  %s x %s  vencedor=%2d  %5.1fs  progresso %5.1f/%5.1f  abates %2d  cartas %2d/%2d  ults %d/%d  formação %.0f%%  espera %.1fs  livre %.0fs" % [
			m + 1, diffs[0], diffs[1], "/".join(t0c), "/".join(t1c), r["winner"], r["duration"], r["p0"], r["p1"], r["kills"],
			r["cards0"], r["cards1"], r["ults0"], r["ults1"], r["formation"] * 100.0, r["armed_wait"], r["uncontested"]])

	print("")
	print("=== Métricas ===")
	var failed := false
	var same: Array = []
	for i in results.size():
		if i % 4 < 2:
			same.append(results[i])
	var avg_dur := _avg(results, "duration")
	var avg_kills := _avg(results, "kills")
	var avg_form := _avg(results, "formation")
	var avg_wait := _avg(results, "armed_wait")
	var avg_unc := _avg(results, "uncontested")
	var w0 := 0
	var w1 := 0
	for r in same:
		if r["winner"] == 0:
			w0 += 1
		elif r["winner"] == 1:
			w1 += 1
	var n_same: int = maxi(1, same.size())
	print("duração média      %.1f s   (limite %.0f a %.0f)" % [avg_dur, LIMITS["duration_min"], LIMITS["duration_max"]])
	print("abates por partida %.1f     (mínimo %.0f)" % [avg_kills, LIMITS["kills_min"]])
	print("vitórias (bots iguais)  azul %d · vermelho %d de %d" % [w0, w1, same.size()])
	print("formação respeitada %.0f%%  (mínimo %.0f%%)" % [avg_form * 100.0, LIMITS["formation_ok_min"] * 100.0])
	print("espera média carta armada %.2f s (máximo %.1f)" % [avg_wait, LIMITS["armed_wait_max"]])
	print("ponto inimigo sem contestação com time de pé longe dele %.1f s/partida (máximo %.0f)" % [avg_unc, LIMITS["uncontested_max"]])
	if avg_dur < LIMITS["duration_min"] or avg_dur > LIMITS["duration_max"]:
		failed = true; print("  !! duração média fora do limite")
	if avg_kills < LIMITS["kills_min"]:
		failed = true; print("  !! poucos abates")
	if float(w0) / n_same < LIMITS["winrate_min"] or float(w1) / n_same < LIMITS["winrate_min"]:
		# Amostras pequenas variam muito: só reprova com 10+ partidas entre bots iguais.
		if same.size() >= 10:
			failed = true; print("  !! um lado vence quase sempre com bots iguais")
		else:
			print("  aviso: vitórias desiguais, mas a amostra é pequena (%d partidas)" % same.size())
	if avg_form < LIMITS["formation_ok_min"]:
		failed = true; print("  !! linha de trás passa muito à frente do tanque")
	if avg_unc > LIMITS["uncontested_max"]:
		failed = true; print("  !! time deixa o inimigo pontuar enquanto luta longe do ponto")
	if avg_wait > LIMITS["armed_wait_max"]:
		failed = true; print("  !! heróis demoram demais para usar cartas armadas")

	print("")
	print("=== Taxa de vitória por herói (bots do mesmo nível; sem espelhos) ===")
	for hid in Data.HERO_ORDER:
		var gms: int = hero_games.get(hid, 0)
		var wns: float = hero_wins.get(hid, 0.0)
		print("%-9s %5.1f%%  (%d partidas)" % [hid, 100.0 * wns / maxf(1.0, gms), gms])
		print("BAL %s %d %.1f" % [hid, gms, wns])
	var side := [0.0, 0.0]
	for r in results:
		if r["winner"] == 0:
			side[0] += 1.0
		elif r["winner"] == 1:
			side[1] += 1.0
		else:
			side[0] += 0.5; side[1] += 0.5
	print("SIDE %d %.1f %.1f" % [results.size(), side[0], side[1]])
	for k in comp_games.keys():
		print("COMP %s %d %.1f" % [k, comp_games[k], comp_wins[k]])
	for k in end_counts.keys():
		print("END %s %d" % [k, end_counts[k]])
	print("DUR %d %.1f" % [results.size(), _avg(results, "duration") * results.size()])
	for k in heal_tot.keys():
		var a3: Array = heal_tot[k]
		print("HEAL %s %d %.0f %.0f %.0f" % [k, a3[0], a3[1], a3[2], a3[3]])
	print("")
	print("=== Roda do Destino (por time e partida) ===")
	for d in wheel_tot.keys():
		var acc: Dictionary = wheel_tot[d]
		var n: float = maxf(1.0, acc["n"])
		print("%-7s cartas %.1f  elos %.1f  cadência %.2f  voltas %.2f" % [d, acc["cards"] / n, acc["links"] / n, acc["cadence"] / n, acc["full"] / n])
		print("WHEEL %s %d %d %d %d %d" % [d, acc["n"], acc["cards"], acc["links"], acc["cadence"], acc["full"]])
	print("")
	print("=== Habilidades usadas (todas as partidas) ===")
	var line := ""
	for ab in Data.ABILITIES.keys():
		var n: int = casts.get(ab, 0)
		line += "%s %d · " % [T.ab_name(ab), n]
		if n == 0:
			failed = true
			_anomaly("habilidade nunca usada: " + ab, "")
	print(line)
	var total := 0.0
	for ab in Data.ABILITIES.keys():
		total += casts.get(ab, 0)
	var avg_cast := total / Data.ABILITIES.size()
	print("")
	print("=== Pontos de melhoria (não reprovam) ===")
	var any_warn := false
	for ab in Data.ABILITIES.keys():
		var n2: int = casts.get(ab, 0)
		if n2 > 0 and n2 < avg_cast * 0.25:
			any_warn = true
			print("carta pouco usada: %s (%d usos, média %.0f)" % [T.ab_name(ab), n2, avg_cast])
	if not any_warn:
		print("nenhum")

	print("")
	print("=== Anomalias ===")
	if anomalies.is_empty():
		print("nenhuma")
	else:
		failed = true
		for k in anomaly_counts.keys():
			print("%4dx  %s" % [anomaly_counts[k], k])
		print("primeiras ocorrências:")
		for i in mini(10, anomalies.size()):
			print("   ", anomalies[i])
	print("")
	print("tempo real %.1f s" % ((Time.get_ticks_msec() - t0) / 1000.0))
	print("RESULTADO_SIMULACAO ", "FALHOU" if failed else "OK")
	quit(1 if failed else 0)


func _avg(list: Array, key: String) -> float:
	if list.is_empty():
		return 0.0
	var s := 0.0
	for r in list:
		s += float(r[key])
	return s / list.size()


func _anomaly(kind: String, detail: String) -> void:
	anomaly_counts[kind] = anomaly_counts.get(kind, 0) + 1
	if anomaly_counts[kind] <= 3:
		anomalies.append(kind + "  " + detail)


## Conta a partida para a composição de cada lado (espelhos não contam).
func _count_comp(winner: int, t0c: Array, t1c: Array) -> void:
	if t0c == t1c:
		return
	for side in 2:
		var key: String = ",".join(t0c if side == 0 else t1c)
		comp_games[key] = comp_games.get(key, 0) + 1
		comp_wins[key] = comp_wins.get(key, 0.0) + (1.0 if winner == side else (0.5 if winner < 0 else 0.0))


## Conta a partida para os heróis de cada lado (empate vale meia vitória).
func _count_heroes(winner: int, t0c: Array, t1c: Array) -> void:
	for side in 2:
		var mine: Array = t0c if side == 0 else t1c
		var other: Array = t1c if side == 0 else t0c
		for hid in mine:
			if other.has(hid):
				continue
			hero_games[hid] = hero_games.get(hid, 0) + 1
			var w := 1.0 if winner == side else (0.5 if winner < 0 else 0.0)
			hero_wins[hid] = hero_wins.get(hid, 0.0) + w


func _play_match(idx: int, d0: String, d1: String, beh: String, casts: Dictionary, teams: Array) -> Dictionary:
	var g := Node2D.new()
	g.set_script(GameScript)
	root.add_child(g)
	var o := {"autotest": true, "difficulty": d1, "difficulty0": d0, "teams": teams, "wheel": wheel_on, "free": free_mode}
	if nobonus >= 0:
		o["wheel_nobonus"] = [0, nobonus]
	g.setup(o)
	g.set_process(false)
	g.hud.set_process(false)
	g.commanders[0].behavior = beh
	g.commanders[1].behavior = beh  # mesmo comportamento inicial nos dois lados

	# Contar habilidades usadas e tempo de espera das armadas.
	var waits: Array = []
	var still := {}
	var last_pos := {}
	for h in g.heroes:
		still[h] = 0.0
		last_pos[h] = h.position
	var uncontested := 0.0
	var prev_dist := {}
	var form_ok := 0
	var form_total := 0
	var prev_feed := 0

	while not g.ended and g.time < MAX_TIME:
		# Antes do passo: registrar cartas armadas para medir a espera.
		var armed_before := {}
		for h in g.heroes:
			for a in h.armed:
				armed_before[str(h.get_instance_id()) + a["ab"]] = a["t"]
		g._step(STEP)
		var tag := "partida %d t=%.1f" % [idx + 1, g.time]
		for h in g.heroes:
			var ids := {}
			for a in h.armed:
				ids[str(h.get_instance_id()) + a["ab"]] = true
			for k in armed_before.keys():
				if k.begins_with(str(h.get_instance_id())) and not ids.has(k) and h.alive:
					waits.append(Data.ARM_TIME - armed_before[k])
		_check_invariants(g, tag, still, last_pos)
		# BUG-015: inimigo dono do ponto, ninguém do time contestando, mas 2+ heróis
		# de pé, fora da base e sem estar indo para o ponto (lutando longe do objetivo).
		if g.point_unlocked() and not g.contested:
			for t in 2:
				if g.point_owner != 1 - t:
					continue
				var out := 0
				var on := 0
				for h in g.heroes:
					if h.team != t or not h.alive:
						continue
					if g.in_point(h.position):
						on += 1
					elif not h.retreating and h.position.distance_to(g.spawn_pos(t)) > g.SPAWN_R + 40.0:
						var dnow: float = h.position.distance_to(g.CENTER)
						if dnow >= prev_dist.get(h, INF) - 0.05:
							out += 1
				if on == 0 and out >= 2:
					uncontested += STEP
		for h in g.heroes:
			prev_dist[h] = h.position.distance_to(g.CENTER)
		# Formação: herói de trás não passa muito do tanque vivo.
		if g.point_unlocked() and int(g.time * 60.0) % 15 == 0:
			for t in 2:
				var tank = null
				for h2 in g.heroes:
					if h2.team == t and (h2.style == "frontline" or h2.style == "dive"):
						tank = h2
						break
				if tank == null or not tank.alive or tank.retreating:
					continue
				var fwd := 1.0 if t == 0 else -1.0
				for b in g.heroes:
					if b.team != t or b.style == "frontline" or b.style == "dive":
						continue
					# Flanco (Zeus) contorna pelas laterais de propósito.
					if b.style != "flank" and b.alive and not b.retreating:
						form_total += 1
						if (b.position.x - tank.position.x) * fwd <= 60.0:
							form_ok += 1

	for ab in g.cast_counts.keys():
		casts[ab] = casts.get(ab, 0) + g.cast_counts[ab]
	for t in 2:
		var d: String = [d0, d1][t]
		var ws: Dictionary = g.wheels[t].stats
		var acc: Dictionary = wheel_tot.get(d, {"n": 0, "cards": 0, "links": 0, "cadence": 0, "full": 0})
		acc["n"] += 1
		acc["cards"] += g.commanders[t].cards_played
		for k in ["links", "cadence", "full"]:
			acc[k] += ws[k]
		wheel_tot[d] = acc
	if not g.ended:
		_anomaly("partida não terminou", "partida %d" % (idx + 1))
	for h in g.heroes:
		var acc2: Array = heal_tot.get(h.hid, [0, 0.0, 0.0, 0.0])
		acc2[0] += 1
		acc2[1] += h.stats["healing"]
		acc2[2] += h.stats["pack"]
		acc2[3] += h.stats["regen"]
		heal_tot[h.hid] = acc2
	var kills := 0
	for h in g.heroes:
		kills += h.stats["kills"]
	var r := {"winner": g.result, "duration": g.time, "p0": g.progress[0], "p1": g.progress[1],
		"kills": kills, "cards0": g.commanders[0].cards_played, "cards1": g.commanders[1].cards_played,
		"ults0": g.commanders[0].ults_used, "ults1": g.commanders[1].ults_used,
		"formation": float(form_ok) / maxf(1.0, float(form_total)),
		"armed_wait": _mean(waits), "uncontested": uncontested,
		"end": g.end_reason if g.end_reason != "" else "none"}
	g.free()
	return r


func _mean(a: Array) -> float:
	if a.is_empty():
		return 0.0
	var s := 0.0
	for x in a:
		s += x
	return s / a.size()


func _check_invariants(g, tag: String, still: Dictionary, last_pos: Dictionary) -> void:
	for h in g.heroes:
		var name: String = "%s(t%d)" % [h.hid, h.team]
		if not h.alive:
			if not h.armed.is_empty():
				_anomaly("herói morto com habilidade armada", tag + " " + name)
			last_pos[h] = h.position
			still[h] = 0.0
			continue
		var p: Vector2 = h.position
		if is_nan(p.x) or is_nan(p.y):
			_anomaly("posição NaN", tag + " " + name)
			continue
		if not g.ARENA.grow(1.0).has_point(p):
			_anomaly("herói fora da arena", tag + " " + name + " " + str(p))
		for o in g.OBSTACLES:
			if not h.leaping and p.distance_to(Vector2(o.x, o.y)) < o.z + h.radius - 1.5:
				_anomaly("herói dentro de obstáculo", tag + " " + name)
		if not h.leaping and p.distance_to(g.SPAWNS[1 - h.team]) < g.SPAWN_R + h.radius - 1.5:
			_anomaly("herói dentro da base inimiga", tag + " " + name)
		if h.hp > h.max_hp + 0.01 or h.hp <= 0.0:
			_anomaly("vida inválida", tag + " %s hp=%.1f" % [name, h.hp])
		for a in h.armed:
			if a["t"] < -2.0 and h.stun_t <= 0.0 and h.dash_t <= 0.0:
				_anomaly("carta armada travada (passou do prazo)", tag + " " + name + " " + a["ab"])
		# Herói totalmente parado por muito tempo fora da base (congelado)
		var moved: float = p.distance_to(last_pos[h])
		last_pos[h] = p
		var in_spawn: bool = p.distance_to(g.spawn_pos(h.team)) < g.SPAWN_R
		if moved < 0.01 and h.stun_t <= 0.0 and h.root_t <= 0.0 and not in_spawn:
			still[h] += STEP
			if still[h] > 3.0:
				_anomaly("herói congelado por mais de 3 s", tag + " " + name + " " + str(p))
				still[h] = -999.0
		elif moved >= 0.01:
			still[h] = 0.0
	for t in 2:
		var c = g.commanders[t]
		if c.ichor < -0.001 or c.ichor > Data.ICHOR_MAX + 0.001:
			_anomaly("Ícor fora do limite", tag + " %.2f" % c.ichor)
		var all: Array = []
		for x in c.hand:
			if x != "":
				all.append(x)
				var owner = c.card_hero(x)
				if not owner.alive:
					_anomaly("carta de herói morto na mão", tag + " " + x)
		all.append_array(c.queue)
		if all.size() != 9:
			_anomaly("deck com tamanho errado", tag + " %d cartas" % all.size())
		if c.hand.has("") and c.next_card() != "":
			_anomaly("espaço vazio na mão com carta disponível", tag)
	for t in 2:
		if g.progress[t] < 0.0 or g.progress[t] > 100.0:
			_anomaly("progresso fora do limite", tag)
