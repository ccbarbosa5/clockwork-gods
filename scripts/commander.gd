extends RefCounted
## Comandante de um time: deck, mão, Ícor, ultimates e comportamento da IA.
## Usado tanto pelo jogador quanto pelo bot.

const Data = preload("res://scripts/data.gd")

const HAND_SIZE := 4

var game
var team := 0
var ichor := Data.ICHOR_START
var queue: Array = []
var hand: Array = ["", "", "", ""]
var behavior := "balanced"
var behavior_cd := 0.0
var cards_played := 0
var ults_used := 0


func setup(g, t: int, hero_ids: Array) -> void:
	game = g
	team = t
	var deck: Array = []
	for h in hero_ids:
		for c in Data.HEROES[h]["cards"]:
			deck.append(c)
	deck.shuffle()
	queue = deck
	hand = ["", "", "", ""]
	refill()


func update(dt: float) -> void:
	ichor = minf(Data.ICHOR_MAX, ichor + dt / Data.ICHOR_INTERVAL)
	behavior_cd = maxf(0.0, behavior_cd - dt)


func add_ichor(v: float) -> void:
	ichor = minf(Data.ICHOR_MAX, ichor + v)


func card_hero(card: String):
	return game.get_hero(team, Data.ABILITIES[card]["hero"])


func _hero_alive(card: String) -> bool:
	var h = card_hero(card)
	return h != null and h.alive


## Preenche espaços vazios da mão com a próxima carta de um herói vivo.
func refill() -> void:
	for i in HAND_SIZE:
		if hand[i] == "":
			hand[i] = _take_next()


func _take_next() -> String:
	for j in queue.size():
		var c: String = queue[j]
		if _hero_alive(c):
			queue.remove_at(j)
			return c
	return ""


func next_card() -> String:
	for c in queue:
		if _hero_alive(c):
			return c
	return ""


## Quando um herói morre, as cartas dele voltam para o deck.
func on_hero_died(hid: String) -> void:
	for i in HAND_SIZE:
		var c: String = hand[i]
		if c != "" and Data.ABILITIES[c]["hero"] == hid:
			queue.append(c)
			hand[i] = ""
	refill()


## Retorna "" se a carta pode ser jogada, ou o motivo.
func can_play(slot: int) -> String:
	var card: String = hand[slot]
	if card == "":
		return "vazio"
	var h = card_hero(card)
	if h == null or not h.alive:
		return "morto"
	if h.stun_t > 0.0:
		return "atordoado"
	if ichor < Data.ABILITIES[card]["cost"]:
		return "icor"
	return ""


func play(slot: int, tpos: Vector2) -> bool:
	if can_play(slot) != "":
		return false
	var card: String = hand[slot]
	var h = card_hero(card)
	if not game.cast(h, card, tpos):
		return false
	ichor -= Data.ABILITIES[card]["cost"]
	hand[slot] = ""
	queue.append(card)
	refill()
	cards_played += 1
	return true


func can_ult(hid: String) -> String:
	var h = game.get_hero(team, hid)
	if h == null or not h.alive:
		return "morto"
	if h.ult < 100.0:
		return "carga"
	if h.stun_t > 0.0:
		return "atordoado"
	return ""


func use_ult(hid: String, tpos: Vector2) -> bool:
	if can_ult(hid) != "":
		return false
	var h = game.get_hero(team, hid)
	if game.cast(h, Data.HEROES[hid]["ult"], tpos):
		h.ult = 0.0
		ults_used += 1
		return true
	return false


func set_behavior(b: String) -> bool:
	if b == behavior or behavior_cd > 0.0:
		return false
	behavior = b
	behavior_cd = Data.BEHAVIOR_CD
	return true
