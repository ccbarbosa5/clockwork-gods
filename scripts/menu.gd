extends Node2D
## Tela inicial.

const Data = preload("res://scripts/data.gd")
const UI = preload("res://scripts/ui.gd")

signal start(opts: Dictionary)

const DIFFS := ["easy", "normal", "hard"]
const DIFF_NAMES := {"easy": "Fácil", "normal": "Normal", "hard": "Difícil"}

var difficulty := "normal"
var behavior := "balanced"
var show_help := false
var t := 0.0


func play_rect() -> Rect2:
	return Rect2(520, 470, 240, 54)


func help_rect() -> Rect2:
	return Rect2(560, 540, 160, 38)


func diff_rect(i: int) -> Rect2:
	return Rect2(450 + i * 130, 330, 120, 38)


func beh_rect(i: int) -> Rect2:
	return Rect2(450 + i * 130, 410, 120, 38)


func _process(delta: float) -> void:
	t += delta
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var m := get_global_mouse_position()
		if show_help:
			show_help = false
			return
		if play_rect().has_point(m):
			start.emit({"difficulty": difficulty, "behavior": behavior})
		elif help_rect().has_point(m):
			show_help = true
		for i in 3:
			if diff_rect(i).has_point(m):
				difficulty = DIFFS[i]
			if beh_rect(i).has_point(m):
				behavior = Data.BEHAVIORS[i]
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			if show_help:
				show_help = false
			else:
				start.emit({"difficulty": difficulty, "behavior": behavior})
		elif event.keycode == KEY_ESCAPE:
			show_help = false


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.07, 0.055, 0.045))
	# Engrenagens decorativas
	UI.gear(self, Vector2(160, 600), 150.0, 14, Color(Data.BRONZE, 0.08), t * 0.15)
	UI.gear(self, Vector2(1130, 130), 120.0, 12, Color(Data.BRONZE, 0.08), -t * 0.2)
	UI.gear(self, Vector2(1180, 640), 70.0, 9, Color(Data.GOLD, 0.06), t * 0.3)
	UI.gear(self, Vector2(640, 110), 130.0, 16, Color(Data.GOLD, 0.05), t * 0.12)

	UI.text_c(self, Vector2(640, 150), "ICHOR", 96, Data.GOLD, 10)
	UI.text_c(self, Vector2(640, 200), "CLOCKWORK GODS", 26, Data.BRONZE.lightened(0.2), 4)
	UI.text_c(self, Vector2(640, 250), "Seus heróis lutam sozinhos. Você decide o destino com cartas de habilidade.", 16, Color(1, 1, 1, 0.75), 2)

	UI.text_c(self, Vector2(640, 318), "Dificuldade do bot", 14, Color(1, 1, 1, 0.6))
	for i in 3:
		var r := diff_rect(i)
		var on: bool = DIFFS[i] == difficulty
		UI.panel(self, r, Color(Data.BRONZE, 0.5) if on else Color(0, 0, 0, 0.4), Data.GOLD if on else Color(Data.BRONZE, 0.5), 2.0)
		UI.text_c(self, r.get_center() + Vector2(0, 6), DIFF_NAMES[DIFFS[i]], 15, Color.WHITE)

	UI.text_c(self, Vector2(640, 398), "Comportamento inicial do seu time", 14, Color(1, 1, 1, 0.6))
	for i in 3:
		var r2 := beh_rect(i)
		var on2: bool = Data.BEHAVIORS[i] == behavior
		UI.panel(self, r2, Color(Data.BRONZE, 0.5) if on2 else Color(0, 0, 0, 0.4), Data.GOLD if on2 else Color(Data.BRONZE, 0.5), 2.0)
		UI.text_c(self, r2.get_center() + Vector2(0, 6), Data.BEHAVIOR_NAMES[Data.BEHAVIORS[i]], 15, Color.WHITE)

	var pr := play_rect()
	var hov := pr.has_point(get_global_mouse_position())
	UI.panel(self, pr, Color(Data.GOLD, 0.45 if hov else 0.3), Data.GOLD, 3.0)
	UI.text_c(self, pr.get_center() + Vector2(0, 8), "JOGAR CONTRA BOT", 20, Color.WHITE, 3)
	var hr := help_rect()
	UI.panel(self, hr, Color(0, 0, 0, 0.4), Color(Data.BRONZE, 0.6), 1.5)
	UI.text_c(self, hr.get_center() + Vector2(0, 5), "Como jogar", 14, Color.WHITE)

	UI.text_c(self, Vector2(640, 700), "Protótipo v0.1  ·  Talos · Ártemis · Asclépio", 12, Color(1, 1, 1, 0.35))

	if show_help:
		_draw_help()


func _draw_help() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0, 0, 0, 0.8))
	var r := Rect2(240, 80, 800, 560)
	UI.panel(self, r, Color(0.1, 0.08, 0.06), Data.BRONZE, 3.0)
	UI.text_c(self, Vector2(640, 125), "Como jogar", 30, Data.GOLD, 4)
	var lines := [
		"Objetivo: controle o ponto central até chegar a 100% de progresso.",
		"Seus 3 heróis (Talos, Ártemis e Asclépio) andam e atacam sozinhos.",
		"",
		"Cartas: clique numa carta (ou tecla 1-4) gastando Ícor (barra dourada).",
		"   O herói guarda a habilidade e usa sozinho no melhor momento,",
		"   escolhendo o alvo (em até 5 s). Se ele morrer antes, o Ícor volta.",
		"   Cor da carta = função (laranja Tanque, roxo Dano, verde Suporte).",
		"Ícor: recarrega com o tempo e ao abater inimigos.",
		"   Abater um herói do time que está na frente rende Ícor extra.",
		"",
		"Ultimates: botões redondos (Q, W, E), também usadas no melhor momento.",
		"   Carregam com dano, cura, mitigação e tempo no ponto. Sem custo de Ícor.",
		"Comportamento da IA (Z, X, C): Agressivo, Equilibrado ou Defensivo.",
		"Herói abatido renasce em 6 s; as cartas dele voltam ao deck.",
		"",
		"P pausa a partida.",
	]
	var y := 175.0
	for l in lines:
		UI.text_l(self, Vector2(290, y), l, 15, Color(1, 1, 1, 0.85))
		y += 26.0
	UI.text_c(self, Vector2(640, 625), "Clique para voltar", 13, Color(1, 1, 1, 0.5))
