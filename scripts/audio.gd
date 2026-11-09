extends Node
## Áudio sintetizado por código: efeitos e música, sem arquivos externos.
## Os sons são gerados uma vez ao iniciar; a música é gerada aos poucos,
## alguns milissegundos por quadro, para não travar o carregamento.

static var instance = null

const SR := 22050            # taxa dos efeitos
const MUSIC_SR := 16000      # taxa da música (menor = gera mais rápido)
const POOL := 14
const BPM := 100.0
const BARS := 8

## Intervalo mínimo entre repetições do mesmo som (evita metralhadora de áudio).
const MIN_GAP := {"hit": 0.06, "shot": 0.05, "shot_support": 0.07, "melee": 0.06, "tick": 0.2}

var sounds := {}
var volume := 0.8
var muted := false
var music_on := true
## Música parada pela pausa da partida (continua de onde parou).
var music_paused := false
var settings_path := "user://settings.cfg"

var _players: Array = []
var _last_play := {}
var _music_player: AudioStreamPlayer
var _music_buf := PackedFloat32Array()
var _music_pos := 0
var _music_total := 0
var music_ready := false
var sfx_ready := false
## Gera tudo de uma vez, sem esperar quadros (usado nos testes).
var instant := false
var _rng := RandomNumberGenerator.new()
var _slice_start := 0


func _ready() -> void:
	instance = self
	load_settings()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = -11.0
	add_child(_music_player)
	_rng.seed = 7
	_make_sfx()
	_music_total = int(BARS * 4.0 * 60.0 / BPM * MUSIC_SR)
	_music_buf.resize(_music_total)
	apply_settings()


func _exit_tree() -> void:
	if instance == self:
		instance = null


func _process(_delta: float) -> void:
	if sfx_ready and not music_ready:
		generate_music_step(6.0)
	if instant and not music_ready:
		while not generate_music_step(1000.0):
			pass


# ---------------------------------------------------------------------------
# Tocar
## Toca um efeito. Retorna false se o som não existe ou foi barrado pelo intervalo mínimo.
func play(name: String, db := 0.0) -> bool:
	if not sounds.has(name):
		return false
	var now := Time.get_ticks_msec() / 1000.0
	var gap: float = MIN_GAP.get(name, 0.02)
	if now - _last_play.get(name, -99.0) < gap:
		return false
	_last_play[name] = now
	var player: AudioStreamPlayer = null
	for p in _players:
		if not p.playing:
			player = p
			break
	if player == null:
		player = _players[0]
		_players.push_back(_players.pop_front())
	player.stream = sounds[name]
	player.volume_db = db
	player.play()
	return true


# ---------------------------------------------------------------------------
# Configurações
func set_volume(v: float) -> void:
	volume = clampf(v, 0.0, 1.0)
	apply_settings()
	save_settings()


func toggle_mute() -> void:
	muted = not muted
	apply_settings()
	save_settings()


## Pausa ou retoma a música junto com a partida (não muda a opção salva).
func pause_music(on: bool) -> void:
	music_paused = on
	if _music_player != null:
		_music_player.stream_paused = on
	apply_settings()


func toggle_music() -> void:
	music_on = not music_on
	apply_settings()
	save_settings()


func apply_settings() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(volume, 0.0001)))
	AudioServer.set_bus_mute(0, muted or volume <= 0.001)
	if _music_player == null:
		return
	if music_paused:
		return
	if music_on and music_ready and not _music_player.playing:
		_music_player.play()
	elif not music_on and _music_player.playing:
		_music_player.stop()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings_path)  # mantém as outras opções (idioma)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("audio", "muted", muted)
	cfg.set_value("audio", "music", music_on)
	cfg.save(settings_path)


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(settings_path) == OK:
		volume = float(cfg.get_value("audio", "volume", volume))
		muted = bool(cfg.get_value("audio", "muted", muted))
		music_on = bool(cfg.get_value("audio", "music", music_on))


# ---------------------------------------------------------------------------
# Síntese
func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * SR))
	return b


func _wave(kind: String, ph: float) -> float:
	match kind:
		"square":
			return 1.0 if fposmod(ph, TAU) < PI else -1.0
		"saw":
			return fposmod(ph, TAU) / PI - 1.0
		"tri":
			var x := fposmod(ph, TAU) / TAU
			return 4.0 * absf(x - 0.5) - 1.0
	return sin(ph)


## Tom com glissando de f0 a f1, ataque e decaimento exponencial.
func _tone(b: PackedFloat32Array, start: float, dur: float, f0: float, f1: float, amp: float,
		kind := "sine", decay := 6.0, attack := 0.005) -> void:
	var i0 := int(start * SR)
	var n := int(dur * SR)
	var ph := 0.0
	for k in n:
		var i := i0 + k
		if i >= b.size():
			break
		var t := float(k) / SR
		var f := lerpf(f0, f1, t / dur)
		ph += TAU * f / SR
		var env := minf(1.0, t / attack) * exp(-t * decay)
		b[i] += _wave(kind, ph) * amp * env


## Ruído com filtro passa-baixa simples (coef pequeno = grave, perto de 1 = agudo).
func _noise(b: PackedFloat32Array, start: float, dur: float, amp: float, decay := 8.0,
		coef := 0.5, attack := 0.002, coef_end := -1.0) -> void:
	var i0 := int(start * SR)
	var n := int(dur * SR)
	var lp := 0.0
	for k in n:
		var i := i0 + k
		if i >= b.size():
			break
		var t := float(k) / SR
		var c := coef if coef_end < 0.0 else lerpf(coef, coef_end, t / dur)
		lp += (_rng.randf() * 2.0 - 1.0 - lp) * c
		var env := minf(1.0, t / attack) * exp(-t * decay)
		b[i] += lp * amp * env


func _stream(b: PackedFloat32Array, rate := SR) -> AudioStreamWAV:
	var peak := 0.0
	for v in b:
		peak = maxf(peak, absf(v))
	var gain := 0.9 / peak if peak > 0.9 else 1.0
	var data := PackedByteArray()
	data.resize(b.size() * 2)
	for i in b.size():
		data.encode_s16(i * 2, int(clampf(b[i] * gain, -1.0, 1.0) * 32767.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = data
	return s


func _add(name: String, b: PackedFloat32Array) -> void:
	sounds[name] = _stream(b)


## Pausa a geração até o próximo quadro quando a fatia de tempo acabou,
## para o jogo não travar ao carregar (principalmente no navegador).
func _maybe_yield() -> void:
	if instant:
		return
	if Time.get_ticks_msec() - _slice_start > 8:
		await get_tree().process_frame
		_slice_start = Time.get_ticks_msec()


func _make_sfx() -> void:
	_slice_start = Time.get_ticks_msec()
	var b: PackedFloat32Array
	# --- Talos ---
	b = _buf(0.75)  # Muralha: clangor metálico
	_tone(b, 0, 0.75, 220, 220, 0.35, "sine", 4.0)
	_tone(b, 0, 0.6, 331, 331, 0.25, "sine", 5.0)
	_tone(b, 0, 0.5, 517, 517, 0.2, "sine", 7.0)
	_tone(b, 0, 0.3, 1180, 1180, 0.1, "sine", 12.0)
	_noise(b, 0, 0.04, 0.5, 60.0, 0.9)
	_add("muralha", b)
	await _maybe_yield()
	b = _buf(0.6)  # Investida: jato de vapor + baque
	_noise(b, 0, 0.45, 0.5, 3.0, 0.05, 0.03, 0.45)
	_tone(b, 0.3, 0.3, 95, 45, 0.7, "sine", 9.0)
	_add("investida", b)
	await _maybe_yield()
	b = _buf(0.95)  # Válvula: chiado de vapor
	_noise(b, 0, 0.95, 0.35, 2.6, 0.65, 0.05)
	_tone(b, 0, 0.6, 1250, 1180, 0.05, "sine", 4.0, 0.05)
	_add("valvula", b)
	await _maybe_yield()
	b = _buf(1.3)  # Fúria da Forja: estrondo
	_tone(b, 0, 1.3, 150, 35, 0.9, "sine", 2.4)
	_tone(b, 0, 0.6, 72, 60, 0.25, "square", 5.0)
	_noise(b, 0, 1.1, 0.6, 3.0, 0.15)
	_noise(b, 0, 0.06, 0.6, 50.0, 0.9)
	_add("furia", b)
	await _maybe_yield()
	# --- Ártemis ---
	b = _buf(0.22)  # Disparo Perfurante: zap
	_tone(b, 0, 0.2, 1700, 450, 0.35, "square", 11.0)
	_noise(b, 0, 0.03, 0.4, 80.0, 0.9)
	_add("disparo", b)
	await _maybe_yield()
	b = _buf(0.28)  # Armadilha: estalo metálico
	_noise(b, 0, 0.06, 0.6, 40.0, 0.85)
	_tone(b, 0, 0.25, 900, 880, 0.3, "sine", 18.0)
	_tone(b, 0, 0.2, 1350, 1320, 0.2, "sine", 22.0)
	_add("armadilha", b)
	await _maybe_yield()
	b = _buf(0.32)  # Salto Lunar: subida
	_tone(b, 0, 0.3, 350, 1150, 0.4, "sine", 4.0)
	_noise(b, 0, 0.28, 0.2, 6.0, 0.15, 0.02, 0.4)
	_add("salto", b)
	await _maybe_yield()
	b = _buf(1.4)  # Chuva de Prata: flechas caindo
	_noise(b, 0, 1.2, 0.22, 1.8, 0.3, 0.1)
	for k in 18:
		var st := _rng.randf_range(0.05, 1.15)
		_tone(b, st, 0.06, _rng.randf_range(2400, 3600), 1800, 0.22, "sine", 55.0)
		_noise(b, st, 0.02, 0.25, 90.0, 0.9)
	_add("chuva", b)
	await _maybe_yield()
	# --- Asclépio ---
	b = _buf(0.9)  # Sopro Restaurador: sinos suaves
	var notes := [1047.0, 1319.0, 1568.0]
	for k in 3:
		_tone(b, k * 0.08, 0.8, notes[k], notes[k], 0.28, "sine", 4.0)
		_tone(b, k * 0.08, 0.6, notes[k] * 0.5, notes[k] * 0.5, 0.12, "tri", 5.0)
	_add("sopro", b)
	await _maybe_yield()
	b = _buf(0.45)  # Veneno: sibilo + oscilação
	_noise(b, 0, 0.4, 0.3, 5.0, 0.5)
	_tone(b, 0, 0.4, 230, 140, 0.35, "tri", 5.0)
	_add("veneno", b)
	await _maybe_yield()
	b = _buf(0.9)  # Engrenagem Vital: catraca + sino
	for k in 7:
		_noise(b, k * 0.045, 0.012, 0.4, 120.0, 0.9)
		_tone(b, k * 0.045, 0.02, 2100, 2100, 0.15, "sine", 90.0)
	_tone(b, 0.32, 0.55, 880, 880, 0.25, "sine", 5.0)
	_tone(b, 0.32, 0.55, 1320, 1320, 0.18, "sine", 6.0)
	_add("engrenagem", b)
	await _maybe_yield()
	b = _buf(1.4)  # Segunda Chance: acorde celestial
	for f in [440.0, 554.4, 659.3, 880.0]:
		_tone(b, 0, 1.4, f, f * 1.01, 0.2, "sine", 1.8, 0.15)
	_tone(b, 0.1, 1.2, 1760, 1760, 0.07, "tri", 2.5, 0.2)
	_add("segunda", b)
	await _maybe_yield()
	# --- Hércules ---
	b = _buf(0.7)  # Salto de Nemeia: rugido curto + baque
	_tone(b, 0, 0.35, 180, 120, 0.35, "square", 6.0)
	_noise(b, 0, 0.3, 0.3, 6.0, 0.3)
	_tone(b, 0.42, 0.28, 90, 40, 0.7, "sine", 9.0)
	_noise(b, 0.42, 0.1, 0.5, 30.0, 0.8)
	_add("nemeia", b)
	await _maybe_yield()
	b = _buf(0.6)  # Pele do Leão: rosnado grave
	_tone(b, 0, 0.6, 110, 95, 0.4, "square", 3.0, 0.04)
	_tone(b, 0, 0.6, 220, 200, 0.12, "tri", 4.0)
	_add("pele", b)
	await _maybe_yield()
	b = _buf(0.4)  # Corrente de Cérbero: elos
	for k in 6:
		_noise(b, k * 0.04, 0.015, 0.4, 100.0, 0.9)
		_tone(b, k * 0.04, 0.03, 1500 - k * 90, 1400 - k * 90, 0.15, "sine", 70.0)
	_add("corrente", b)
	await _maybe_yield()
	b = _buf(1.0)  # Décimo Terceiro Trabalho: grito + impacto
	_tone(b, 0, 0.4, 260, 380, 0.3, "square", 4.0)
	_noise(b, 0.15, 0.4, 0.3, 4.0, 0.2, 0.01, 0.6)
	_tone(b, 0.55, 0.45, 120, 35, 0.8, "sine", 6.0)
	_noise(b, 0.55, 0.08, 0.6, 40.0, 0.9)
	_add("trabalho", b)
	await _maybe_yield()
	# --- Zeus ---
	b = _buf(0.45)  # Corrente de Raios: estalos elétricos
	for k in 4:
		_noise(b, k * 0.07, 0.06, 0.55, 35.0, 0.95)
		_tone(b, k * 0.07, 0.07, 2400, 900, 0.18, "square", 30.0)
	_add("raios", b)
	await _maybe_yield()
	b = _buf(1.3)  # Nuvem de Tempestade: rumor + trovão
	_noise(b, 0, 0.9, 0.25, 1.5, 0.08, 0.2)
	_noise(b, 1.0, 0.3, 0.7, 12.0, 0.6)
	_tone(b, 1.0, 0.3, 70, 40, 0.5, "sine", 8.0)
	_add("nuvem", b)
	await _maybe_yield()
	b = _buf(0.4)  # Voo da Águia: grito agudo + vento
	_tone(b, 0, 0.25, 1800, 2600, 0.25, "tri", 6.0)
	_noise(b, 0, 0.35, 0.2, 5.0, 0.4, 0.02, 0.15)
	_add("aguia", b)
	await _maybe_yield()
	b = _buf(1.6)  # Fúria do Olimpo: trovões
	for k in 4:
		_noise(b, k * 0.35, 0.3, 0.6, 9.0, 0.5)
		_tone(b, k * 0.35, 0.3, 90, 45, 0.4, "sine", 7.0)
	_add("olimpo", b)
	await _maybe_yield()
	# --- Atena ---
	b = _buf(0.9)  # Égide: escudo + brilho
	_tone(b, 0, 0.8, 330, 330, 0.3, "sine", 3.0)
	_tone(b, 0, 0.8, 495, 495, 0.2, "sine", 3.5)
	_tone(b, 0.05, 0.6, 1980, 1980, 0.08, "sine", 5.0)
	_add("egide", b)
	await _maybe_yield()
	b = _buf(0.8)  # Comando de Guerra: corneta
	for k in 3:
		_tone(b, k * 0.14, 0.3, [392.0, 523.3, 659.3][k], [392.0, 523.3, 659.3][k], 0.25, "square", 4.0, 0.02)
	_add("comando", b)
	await _maybe_yield()
	b = _buf(0.5)  # Olhar da Coruja: pio
	_tone(b, 0, 0.18, 700, 560, 0.3, "sine", 6.0, 0.02)
	_tone(b, 0.22, 0.25, 640, 500, 0.3, "sine", 5.0, 0.02)
	_add("coruja", b)
	await _maybe_yield()
	b = _buf(1.2)  # Falange de Atenas: lança fincada + escudos
	_noise(b, 0, 0.06, 0.6, 40.0, 0.85)
	_tone(b, 0, 0.3, 140, 70, 0.6, "sine", 8.0)
	for k in 4:
		_tone(b, 0.25 + k * 0.12, 0.3, 880, 880, 0.15, "sine", 9.0)
	_add("falange", b)
	await _maybe_yield()
	# --- Combate ---
	b = _buf(0.14)
	_noise(b, 0, 0.08, 0.5, 30.0, 0.2)
	_tone(b, 0, 0.12, 120, 70, 0.5, "sine", 20.0)
	_add("melee", b)
	await _maybe_yield()
	b = _buf(0.08)
	_tone(b, 0, 0.07, 900, 600, 0.15, "square", 30.0)
	_add("shot", b)
	await _maybe_yield()
	b = _buf(0.09)
	_tone(b, 0, 0.08, 700, 950, 0.12, "sine", 25.0)
	_add("shot_support", b)
	await _maybe_yield()
	b = _buf(0.05)
	_noise(b, 0, 0.04, 0.25, 60.0, 0.7)
	_add("hit", b)
	await _maybe_yield()
	b = _buf(0.45)
	_tone(b, 0, 0.35, 660, 220, 0.3, "square", 6.0)
	_noise(b, 0, 0.12, 0.35, 20.0, 0.4)
	_add("kill", b)
	await _maybe_yield()
	b = _buf(0.6)
	_tone(b, 0, 0.55, 300, 90, 0.3, "saw", 4.0)
	_add("death", b)
	await _maybe_yield()
	b = _buf(0.25)
	_tone(b, 0, 0.1, 523, 523, 0.2, "sine", 10.0)
	_tone(b, 0.08, 0.15, 784, 784, 0.2, "sine", 8.0)
	_add("respawn", b)
	await _maybe_yield()
	# --- Partida ---
	b = _buf(2.0)  # Gongo: ponto liberado
	_tone(b, 0, 2.0, 110, 110, 0.3, "sine", 1.5)
	_tone(b, 0, 2.0, 222, 222, 0.25, "sine", 1.8)
	_tone(b, 0, 1.6, 327, 327, 0.18, "sine", 2.2)
	_tone(b, 0, 1.2, 441, 441, 0.12, "sine", 2.8)
	_noise(b, 0, 0.05, 0.4, 40.0, 0.6)
	_add("unlock", b)
	await _maybe_yield()
	b = _buf(0.07)
	_tone(b, 0, 0.06, 1000, 1000, 0.3, "sine", 40.0)
	_add("tick", b)
	await _maybe_yield()
	b = _buf(0.75)
	var up := [523.0, 659.0, 784.0]
	for k in 3:
		_tone(b, k * 0.12, 0.4 if k < 2 else 0.5, up[k], up[k], 0.18, "square", 5.0)
	_add("capture_us", b)
	await _maybe_yield()
	b = _buf(0.75)
	var down := [659.0, 523.0, 392.0]
	for k in 3:
		_tone(b, k * 0.12, 0.4 if k < 2 else 0.5, down[k], down[k], 0.18, "saw", 5.0)
	_add("capture_them", b)
	await _maybe_yield()
	b = _buf(0.6)
	_tone(b, 0, 0.25, 392, 392, 0.25, "saw", 3.0, 0.02)
	_tone(b, 0.25, 0.3, 311, 311, 0.25, "saw", 3.0, 0.02)
	_add("ult_warning", b)
	await _maybe_yield()
	b = _buf(0.6)
	for k in 3:
		_tone(b, k * 0.15, 0.1, 880, 880, 0.25, "square", 20.0)
	_add("overtime", b)
	await _maybe_yield()
	b = _buf(1.8)
	var vic := [523.0, 659.0, 784.0, 1047.0]
	for k in 4:
		_tone(b, k * 0.13, 0.3, vic[k], vic[k], 0.18, "tri", 4.0)
	for f in vic:
		_tone(b, 0.55, 1.2, f, f, 0.1, "square", 2.0, 0.02)
	_add("victory", b)
	await _maybe_yield()
	b = _buf(1.6)
	var dft := [440.0, 349.0, 294.0]
	for k in 3:
		_tone(b, k * 0.25, 0.4, dft[k], dft[k], 0.2, "saw", 3.0)
	_tone(b, 0.75, 0.9, 147, 147, 0.25, "saw", 2.0)
	_tone(b, 0.75, 0.9, 175, 175, 0.18, "saw", 2.0)
	_add("defeat", b)
	await _maybe_yield()
	# --- Interface ---
	b = _buf(0.08)
	_noise(b, 0, 0.05, 0.3, 40.0, 0.4)
	_tone(b, 0, 0.05, 1200, 1700, 0.15, "sine", 30.0)
	_add("card", b)
	await _maybe_yield()
	b = _buf(0.2)
	_tone(b, 0, 0.18, 110, 110, 0.22, "square", 6.0)
	_tone(b, 0, 0.18, 104, 104, 0.22, "square", 6.0)
	_add("no_ichor", b)
	await _maybe_yield()
	b = _buf(0.04)
	_tone(b, 0, 0.03, 1500, 1500, 0.2, "sine", 80.0)
	_add("click", b)
	sfx_ready = true


# ---------------------------------------------------------------------------
# Música: modo frígio dominante (clima grego) com tique-taque de relojoaria.
const ROOTS := [146.83, 155.56, 146.83, 130.81, 146.83, 155.56, 130.81, 146.83]
const CHORDS := [
	[1.0, 1.1892, 1.4983], [1.0, 1.2599, 1.4983], [1.0, 1.1892, 1.4983], [1.0, 1.2599, 1.4983],
	[1.0, 1.1892, 1.4983], [1.0, 1.2599, 1.4983], [1.0, 1.2599, 1.4983], [1.0, 1.2599, 1.4983],
]
const ARP := [0, 2, 1, 2, 0, 2, 1, 2]


func _music_sample(i: int) -> float:
	var t := float(i) / MUSIC_SR
	var beat := 60.0 / BPM
	var bar_len := beat * 4.0
	var bar := int(t / bar_len) % BARS
	var root: float = ROOTS[bar]
	var chord: Array = CHORDS[bar]
	var v := 0.0
	# Arpejo de lira (colcheias)
	var eighth := beat * 0.5
	var ei := int(t / eighth)
	var lt := t - ei * eighth
	var note: int = ARP[ei % 8]
	var octave := 4.0 if (ei % 8) == 4 else 2.0
	var f: float = root * chord[note] * octave
	v += (sin(TAU * f * lt) + 0.3 * sin(TAU * f * 2.0 * lt)) * exp(-lt * 5.0) * 0.16
	# Baixo nos tempos 1 e 3
	var half := beat * 2.0
	var hi := int(t / half)
	var hl := t - hi * half
	v += _wave("tri", TAU * root * 0.5 * hl) * exp(-hl * 2.2) * 0.22
	# Pad suave
	var bt := fposmod(t, bar_len)
	var pad_env := minf(1.0, bt / 0.4) * minf(1.0, (bar_len - bt) / 0.3)
	for c in chord:
		v += sin(TAU * root * c * t) * 0.035 * pad_env
	# Tique-taque (semicolcheias), mais forte no tempo
	var six := beat * 0.25
	var si := int(t / six)
	var sl := t - si * six
	var hash := fposmod(sin(float(i) * 12.9898) * 43758.5453, 1.0) * 2.0 - 1.0
	var acc := 0.06 if si % 4 == 0 else 0.025
	v += hash * exp(-sl * 120.0) * acc
	return v


## Gera a música por até `budget_ms` milissegundos. Retorna true quando termina.
func generate_music_step(budget_ms: float) -> bool:
	if music_ready:
		return true
	var t0 := Time.get_ticks_usec()
	while _music_pos < _music_total:
		var end := mini(_music_pos + 2000, _music_total)
		for i in range(_music_pos, end):
			_music_buf[i] = _music_sample(i)
		_music_pos = end
		if (Time.get_ticks_usec() - t0) / 1000.0 > budget_ms:
			break
	if _music_pos >= _music_total:
		var s := _stream(_music_buf, MUSIC_SR)
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = _music_total
		_music_player.stream = s
		_music_buf = PackedFloat32Array()
		music_ready = true
		apply_settings()
	return music_ready
