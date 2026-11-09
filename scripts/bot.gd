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

	# As habilidades são armadas apenas quando o herói já vê um bom momento.
	for hid in game.teams[team]:
		if cmd.can_ult(hid) == "":
			var h = game.get_hero(team, hid)
			if h.decide(Data.HEROES[hid]["ult"], false) != null:
				cmd.use_ult(hid)
				return

	# Cartas com bom momento agora, mesmo as que ainda não dá para pagar.
	var good: Array = []
	for i in cmd.HAND_SIZE:
		var card: String = cmd.hand[i]
		if card == "":
			continue
		var reason: String = cmd.can_play(i)
		if reason != "" and reason != "icor":
			continue
		var hero = cmd.card_hero(card)
		if hero.has_armed(card):
			continue
		if hero.decide(card, false) != null:
			good.append(i)
	# Prefere a carta mais cara; se ela está quase paga, guarda Ícor para ela.
	good.sort_custom(func(x, y): return Data.ABILITIES[cmd.hand[x]]["cost"] > Data.ABILITIES[cmd.hand[y]]["cost"])
	for i in good:
		var cost: float = Data.ABILITIES[cmd.hand[i]]["cost"]
		if cmd.ichor >= cost:
			cmd.play(i)
			return
		if cmd.ichor >= cost - 1.5 and difficulty != "easy":
			return
	if cmd.ichor >= Data.ICHOR_MAX - 0.3:
		for i in cmd.HAND_SIZE:
			if cmd.can_play(i) == "":
				cmd.play(i)
				return


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
