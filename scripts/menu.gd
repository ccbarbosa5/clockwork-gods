extends Node2D
## Tela inicial.

const Data = preload("res://scripts/data.gd")
const UI = preload("res://scripts/ui.gd")
const T = preload("res://scripts/i18n.gd")
const Art = preload("res://scripts/art.gd")
const AudioScript = preload("res://scripts/audio.gd")

signal start(opts: Dictionary)
signal open_gallery

const DIFFS := ["easy", "normal", "hard"]

var difficulty := "normal"
var behavior := "balanced"
## Seu time: um herói por função (Tanque, Dano, Suporte).
var team: Array = Data.DEFAULT_TEAM.duplicate()
var show_help := false
var t := 0.0


## Versão lida do projeto (BUG-013: o menu mostrava uma versão fixa e antiga).
static func version_label() -> String:
	return T.tf("MENU_VERSION", [ProjectSettings.get_setting("application/config/version", "?"), Data.HERO_ORDER.size()])


## Nome do jogo (marca: igual em todos os idiomas), lido do projeto.
static func game_title() -> String:
	return String(ProjectSettings.get_setting("application/config/name", "")).to_upper()


func lang_rect() -> Rect2:
	return Rect2(1160, 20, 96, 32)


func vol_rect(i: int) -> Rect2:
	# 0 = diminuir, 1 = aumentar, 2 = música
	return [Rect2(970, 668, 30, 30), Rect2(1106, 668, 30, 30), Rect2(1150, 668, 110, 30)][i]


func _audio():
	return AudioScript.instance


func play_rect() -> Rect2:
	return Rect2(520, 552, 240, 48)


func help_rect() -> Rect2:
	return Rect2(356, 557, 150, 38)


func heroes_rect() -> Rect2:
	return Rect2(774, 557, 150, 38)


func diff_rect(i: int) -> Rect2:
	return Rect2(340 + i * 98, 628, 92, 30)


func beh_rect(i: int) -> Rect2:
	return Rect2(646 + i * 98, 628, 92, 30)


## Botão do herói da função i no seu time (clique troca pelo próximo da função).
func team_rect(i: int) -> Rect2:
	return Rect2(450 + i * 130, 676, 120, 34)


func cycle_team(i: int) -> void:
	var opts: Array = Data.heroes_of_role(Data.ROLE_ORDER[i])
	team[i] = opts[(opts.find(team[i]) + 1) % opts.size()]


func start_opts() -> Dictionary:
	return {"difficulty": difficulty, "behavior": behavior, "team": team.duplicate()}


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
		var a = _audio()
		var l := UI.lang_at(lang_rect(), m)
		if l != "":
			T.set_lang(l)
			if a != null: a.play("click")
			return
		if a != null:
			if vol_rect(0).has_point(m):
				a.set_volume(snappedf(a.volume - 0.1, 0.1)); a.play("click"); return
			if vol_rect(1).has_point(m):
				a.set_volume(snappedf(a.volume + 0.1, 0.1)); a.play("click"); return
			if vol_rect(2).has_point(m):
				a.toggle_music(); a.play("click"); return
		if play_rect().has_point(m):
			if a != null:
				a.play("card")
			start.emit(start_opts())
		elif help_rect().has_point(m):
			show_help = true
		elif heroes_rect().has_point(m):
			if a != null: a.play("click")
			open_gallery.emit()
			return
		for i in 3:
			if team_rect(i).has_point(m):
				cycle_team(i)
				if a != null: a.play("click")
			if diff_rect(i).has_point(m):
				difficulty = DIFFS[i]
				if a != null: a.play("click")
			if beh_rect(i).has_point(m):
				behavior = Data.BEHAVIORS[i]
				if a != null: a.play("click")
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			if show_help:
				show_help = false
			else:
				start.emit(start_opts())
		elif event.keycode == KEY_ESCAPE:
			show_help = false
		elif event.keycode == KEY_L:
			T.toggle()
		elif event.keycode == KEY_M and _audio() != null:
			_audio().toggle_mute()


func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.07, 0.055, 0.045))
	var bg := Art.tex(Art.TITLE_BG)
	if bg != null:
		Art.draw_cover(self, bg, Rect2(0, 0, 1280, 720))
		# Escurece o chão para os botões lerem bem.
		var band := PackedVector2Array([Vector2(0, 520), Vector2(1280, 520), Vector2(1280, 720), Vector2(0, 720)])
		draw_polygon(band, PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.6), Color(0, 0, 0, 0.6)]))
	else:
		# Engrenagens decorativas (sem imagem de fundo)
		UI.gear(self, Vector2(160, 600), 150.0, 14, Color(Data.BRONZE, 0.08), t * 0.15)
		UI.gear(self, Vector2(1130, 130), 120.0, 12, Color(Data.BRONZE, 0.08), -t * 0.2)
		UI.gear(self, Vector2(1180, 640), 70.0, 9, Color(Data.GOLD, 0.06), t * 0.3)
		UI.gear(self, Vector2(640, 110), 130.0, 16, Color(Data.GOLD, 0.05), t * 0.12)

	var logo := Art.tex(Art.LOGO)
	if logo != null:
		Art.draw_centered(self, logo, Vector2(640, Art.LOGO_TOP + Art.LOGO_SIZE.y * 0.5), Art.LOGO_SIZE)
	else:
		UI.text_c(self, Vector2(640, 135), game_title(), 80, Data.GOLD, 10)
	UI.text_c(self, Vector2(640, 232), T.t("MENU_TAGLINE"), 16, Color.WHITE, 4)
	var mouse := get_global_mouse_position()
	UI.lang_toggle(self, lang_rect(), mouse)

	var hr := help_rect()
	UI.panel(self, hr, Color(Data.BRONZE, 0.35) if hr.has_point(mouse) else Color(0, 0, 0, 0.55), Color(Data.BRONZE, 0.8), 1.5)
	UI.text_c(self, hr.get_center() + Vector2(0, 5), T.t("MENU_HELP"), 14, Color.WHITE)
	var pr := play_rect()
	UI.panel(self, pr, Color(Data.GOLD, 0.55 if pr.has_point(mouse) else 0.4), Data.GOLD, 3.0)
	UI.text_c(self, pr.get_center() + Vector2(0, 8), T.t("MENU_PLAY"), 20, Color.WHITE, 3)
	var gr := heroes_rect()
	UI.panel(self, gr, Color(Data.BRONZE, 0.35) if gr.has_point(mouse) else Color(0, 0, 0, 0.55), Color(Data.BRONZE, 0.8), 1.5)
	UI.text_c(self, gr.get_center() + Vector2(0, 5), T.t("MENU_HEROES"), 14, Color.WHITE)

	UI.text_c(self, diff_rect(1).get_center() + Vector2(0, -21), T.t("MENU_DIFFICULTY"), 12, Color(1, 1, 1, 0.75), 3)
	UI.text_c(self, beh_rect(1).get_center() + Vector2(0, -21), T.t("MENU_BEHAVIOR"), 12, Color(1, 1, 1, 0.75), 3)
	for i in 3:
		var r := diff_rect(i)
		var on: bool = DIFFS[i] == difficulty
		UI.panel(self, r, Color(Data.BRONZE, 0.6) if on else Color(0, 0, 0, 0.55), Data.GOLD if on else Color(Data.BRONZE, 0.6), 2.0)
		UI.text_c(self, r.get_center() + Vector2(0, 5), T.t("DIFF_" + String(DIFFS[i]).to_upper()), 13, Color.WHITE)
		var r2 := beh_rect(i)
		var on2: bool = Data.BEHAVIORS[i] == behavior
		UI.panel(self, r2, Color(Data.BRONZE, 0.6) if on2 else Color(0, 0, 0, 0.55), Data.GOLD if on2 else Color(Data.BRONZE, 0.6), 2.0)
		UI.text_c(self, r2.get_center() + Vector2(0, 5), T.behavior_name(Data.BEHAVIORS[i]), 13, Color.WHITE)

	UI.text_c(self, team_rect(1).get_center() + Vector2(0, -22), T.t("MENU_TEAM"), 12, Color(1, 1, 1, 0.75), 3)
	for i in 3:
		var tr := team_rect(i)
		var rc: Color = Data.ROLE_COLORS[Data.ROLE_ORDER[i]]
		UI.panel(self, tr, Color(0, 0, 0, 0.55).lerp(rc, 0.35 if tr.has_point(mouse) else 0.2), rc, 2.0)
		UI.text_c(self, tr.get_center() + Vector2(0, 2), T.hero_name(team[i]), 14, Color.WHITE, 2)
		UI.text_c(self, tr.get_center() + Vector2(0, 14), "‹ " + T.role_name(Data.ROLE_ORDER[i]) + " ›", 9, rc.lightened(0.3))
	UI.text_l(self, Vector2(24, 708), version_label(), 12, Color(1, 1, 1, 0.45))
	_draw_audio()

	if show_help:
		UI.draw_help(self)


func _draw_audio() -> void:
	var a = _audio()
	if a == null:
		return
	UI.text_l(self, Vector2(970, 660), T.t("SOUND_LABEL") + "  " + T.t("SOUND_MUTED_HINT" if a.muted else "SOUND_HINT"), 12, Color(1, 1, 1, 0.6))
	for i in 3:
		UI.panel(self, vol_rect(i), Color(0, 0, 0, 0.4), Color(Data.BRONZE, 0.6), 1.5)
	UI.text_c(self, vol_rect(0).get_center() + Vector2(0, 6), "-", 18, Color.WHITE)
	UI.text_c(self, vol_rect(1).get_center() + Vector2(0, 6), "+", 18, Color.WHITE)
	var bar := Rect2(1006, 678, 94, 10)
	draw_rect(bar, Color(0, 0, 0, 0.6))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * a.volume, bar.size.y)), Data.GOLD if not a.muted else Color(0.5, 0.5, 0.5))
	UI.text_c(self, vol_rect(2).get_center() + Vector2(0, 5), T.t("MUSIC_ON" if a.music_on else "MUSIC_OFF"), 12, Color.WHITE)
