extends RefCounted
## Roda do Destino de um time (claude/sistema-engrenar.md). Guarda a engrenagem
## engatada, o tempo que ainda resta e quantos elos seguidos a Cadência tem.
## Conta o momento em que o efeito da carta acontece (game.cast), não o clique.

const Data = preload("res://scripts/data.gd")

## Engrenagem engatada (índice em Data.GEARS) ou -1.
var gear := -1
## Segundos que a engrenagem ainda fica engatada.
var t := 0.0
## Elos seguidos na Cadência atual (0 = só a primeira carta).
var links := 0
## Estatísticas da partida (simulação e testes).
var stats := {"links": 0, "cadence": 0, "full": 0, "breaks": 0}


func update(dt: float) -> void:
	if gear < 0:
		return
	t -= dt
	if t <= 0.0:
		reset()


func reset() -> void:
	gear = -1
	t = 0.0
	links = 0


## Engrenagem que continuaria a Cadência (-1 se nada está engatado).
func next_gear() -> int:
	return -1 if gear < 0 else (gear + 1) % Data.GEARS.size()


## Uma carta da engrenagem `g` aconteceu. Retorna o resultado:
##   linked   engrenou (era a próxima da roda): a carta ganha o bônus de `g`
##   links    elos seguidos agora
##   cadence  este elo devolve Ícor (Data.CADENCE_FROM em diante)
##   full     fechou uma volta completa
func on_cast(g: int) -> Dictionary:
	var linked := gear >= 0 and g == next_gear()
	if linked:
		links += 1
		stats["links"] += 1
	else:
		if gear >= 0 and links > 0:
			stats["breaks"] += 1
		links = 0
	gear = g
	t = Data.GEAR_WINDOW
	var cadence := linked and links >= Data.CADENCE_FROM
	var full := linked and links % Data.FULL_TURN_LINKS == 0
	if cadence:
		stats["cadence"] += 1
	if full:
		stats["full"] += 1
	return {"linked": linked, "links": links, "cadence": cadence, "full": full, "gear": g}
