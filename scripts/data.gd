extends RefCounted
## Dados de balanceamento do protótipo. Todos os números aqui são
## propostas iniciais e devem ser calibrados em teste.

# --- Partida ---------------------------------------------------------------
const MATCH_TIME := 300.0          # tempo limite (s)
const UNLOCK_TIME := 12.0          # ponto libera após (s)
const POINT_R := 95.0             # raio do ponto de controle (px)
const CAPTURE_TIME := 6.0          # tempo para capturar o ponto (s)
const PROGRESS_RATE := 100.0 / 80.0   # % por segundo enquanto controla
const CONTESTED_RATE := 0.5         # fração do progresso quando disputado com vantagem numérica
const RESPAWN := 6.0               # tempo de renascimento (s)
const SPAWN_REGEN := 90.0          # cura por segundo dentro da própria base

# --- Ícor -----------------------------------------------------------------
const ICHOR_MAX := 10.0
const ICHOR_START := 5.0
const ICHOR_INTERVAL := 2.5        # +1 Ícor a cada X segundos
const KILL_REWARD := 1
const KILL_BONUS_LEADER := 1       # bônus anti-snowball

# --- Carga da ultimate (pontos por unidade) --------------------------------
const ULT_DMG := 0.06              # por ponto de dano causado
const ULT_HEAL := 0.07             # por ponto de cura
const ULT_MIT := 0.06              # por ponto de dano mitigado
const ULT_POINT := 0.45            # por segundo no ponto
const ULT_PASSIVE := 0.3           # por segundo, sempre

# --- Roda do Destino (sistema "engrenar", claude/sistema-engrenar.md) -------
## Engrenagens em ciclo: Movimento → Controle → Ataque → Defesa → Movimento.
const GEARS := ["move", "control", "attack", "defense"]
## Tipo de carta → engrenagem (índice em GEARS). Cura junta com Proteção.
const EFFECT_GEAR := {"mobilidade": 0, "controle": 1, "dano": 2, "escudo": 3, "cura": 3}
## Ícone de cada engrenagem (tipo de efeito usado no desenho).
const GEAR_ICON := ["mobilidade", "controle", "dano", "escudo"]
const GEAR_WINDOW := 5.0           # s que a engrenagem fica engatada após o efeito
const GEAR_CTRL_BONUS := 0.5       # Movimento → Controle: controle dura +50%
const GEAR_DMG_BONUS := 0.4        # Controle → Ataque: +40% de dano
const GEAR_DEF_BONUS := 0.3        # Ataque → Defesa: +30% de cura, escudo ou redução
const GEAR_MOVE_SHIELD := 40.0     # Defesa → Movimento: escudo no herói que se desloca
const GEAR_MOVE_SHIELD_T := 3.0
const CADENCE_FROM := 3            # a partir deste elo seguido, cada elo devolve Ícor
const CADENCE_REFUND := 1.0
const FULL_TURN_LINKS := 4         # elos seguidos para a volta completa
const FULL_TURN_ULT := 10.0        # carga de ultimate para cada herói do time

# --- Comportamento da IA ----------------------------------------------------
const BEHAVIOR_CD := 10.0
const BEHAVIORS := ["aggressive", "balanced", "defensive"]
## Parâmetros de cada comportamento (px; a dica mostra em metros).
##   retreat      recua abaixo desta fração da vida (volta com RETREAT_BACK)
##   front        tanque fica estes px à frente do centro do ponto
##   wait_group   tanque para se ficar mais de WAIT_GROUP_DIST px à frente do grupo
##   dps_back     herói de dano fica estes px atrás do tanque
##   aggro        persegue inimigos a até estes px
##   leash        e só até estes px além da borda do ponto (-1 = sem limite)
const BEHAVIOR_PARAMS := {
	"aggressive": {"retreat": 0.15, "front": 150.0, "wait_group": false, "dps_back": 40.0, "aggro": 560.0, "leash": -1.0},
	"balanced": {"retreat": 0.3, "front": 20.0, "wait_group": true, "dps_back": 90.0, "aggro": 400.0, "leash": 380.0},
	"defensive": {"retreat": 0.35, "front": 0.0, "wait_group": true, "dps_back": 90.0, "aggro": 320.0, "leash": 220.0},
}
const RETREAT_BACK := 0.8
const WAIT_GROUP_DIST := 280.0

# --- Times -------------------------------------------------------------------
const TEAM_COLORS := [Color(0.30, 0.66, 1.0), Color(1.0, 0.36, 0.30)]
const GOLD := Color(0.95, 0.76, 0.31)
const BRONZE := Color(0.78, 0.54, 0.23)

## Cartas armadas: o herói usa a habilidade no melhor momento em até ARM_TIME segundos.
const ARM_TIME := 5.0

## Cores por função (não conflitam com azul/vermelho dos times).
const ROLE_COLORS := {"Tanque": Color(0.96, 0.6, 0.2), "Dano": Color(0.72, 0.45, 1.0), "Suporte": Color(0.33, 0.85, 0.45)}

## Tipos de efeito das habilidades (ícone na carta e no mapa). Nomes: i18n (EFFECT_*).
const EFFECTS := ["dano", "cura", "escudo", "controle", "mobilidade"]

## Estilos de posicionamento da IA. Os padrões de cada função são frontline,
## backline_dps e backline_support. Estilos para heróis futuros:
##   dive            tanque que mergulha na linha de trás inimiga
##   flank           dano que contorna pelas laterais
##   battle_support  suporte que avança junto e causa dano
const STYLES := ["frontline", "backline_dps", "backline_support", "dive", "flank", "battle_support"]

## Todos os heróis (ordem da galeria).
const HERO_ORDER := ["talos", "artemis", "asclepio", "hercules", "zeus", "atena"]
## Cada time tem um herói de cada função, nesta ordem (posição = tecla da ultimate).
const ROLE_ORDER := ["Tanque", "Dano", "Suporte"]
const DEFAULT_TEAM := ["talos", "artemis", "asclepio"]


## Heróis de uma função, na ordem da galeria.
static func heroes_of_role(role: String) -> Array:
	var out: Array = []
	for hid in HERO_ORDER:
		if HEROES[hid]["role"] == role:
			out.append(hid)
	return out


## Time válido: 3 heróis, um de cada função, na ordem de ROLE_ORDER.
static func valid_team(team: Array) -> bool:
	if team.size() != ROLE_ORDER.size():
		return false
	for i in team.size():
		if not HEROES.has(team[i]) or HEROES[team[i]]["role"] != ROLE_ORDER[i]:
			return false
	return true


## Time sorteado (um herói por função).
static func random_team() -> Array:
	var out: Array = []
	for role in ROLE_ORDER:
		var opts := heroes_of_role(role)
		out.append(opts[randi() % opts.size()])
	return out

## Textos (nome, epíteto, bio, frase) ficam em i18n/textos.csv (HERO_<ID>_*).
const HEROES := {
	"talos": {
		"role": "Tanque", "origin": "lenda",
		"hp": 650.0, "speed": 72.0, "range": 62.0, "dmg": 26.0, "cd": 0.9,
		"radius": 22.0, "color": Color(0.96, 0.6, 0.2), "style": "frontline",
		"splash": 0.5,  # golpe atinge 50% em inimigos a até 45 px do alvo
		"ult": "furia", "cards": ["muralha", "investida", "valvula"],
	},
	"hercules": {
		"role": "Tanque", "origin": "semideus",
		"hp": 610.0, "speed": 80.0, "range": 58.0, "dmg": 33.0, "cd": 1.0, "dive_reach": 0.0,
		"radius": 21.0, "color": Color(0.96, 0.6, 0.2), "style": "dive",
		"ult": "trabalho", "cards": ["nemeia", "pele", "corrente"],
	},
	"zeus": {
		"role": "Dano", "origin": "deus",
		"hp": 320.0, "speed": 92.0, "range": 270.0, "dmg": 18.0, "cd": 0.7, "kite": 180.0, "group_bias": 0.0,
		"radius": 16.0, "color": Color(0.72, 0.45, 1.0), "style": "flank",
		# Ataque básico: raio instantâneo que salta para 1 inimigo a até 90 px (7 de dano).
		"basic": "chain", "chain_dmg": 8.0, "chain_range": 90.0,
		"chain_cast": [68.0, 51.0, 38.0, 29.0],  # Corrente de Raios: dano de cada salto
		"ult": "olimpo", "cards": ["raios", "nuvem", "aguia"],
	},
	"atena": {
		"role": "Suporte", "origin": "deusa",
		"hp": 320.0, "speed": 88.0, "range": 180.0, "dmg": 16.0, "cd": 0.8,
		"radius": 17.0, "color": Color(0.33, 0.85, 0.45), "style": "battle_support",
		"proj_speed": 700.0, "basic": "spear",
		# Passiva Escudo de Palas: cada acerto do básico dá 10 de escudo ao aliado
		# mais ferido a até 220 px (acumula até 60, dura 4 s).
		"pallas": {"amount": 10.0, "max": 60.0, "range": 220.0, "time": 4.0},
		"ult": "falange", "cards": ["egide", "comando", "coruja"],
	},
	"artemis": {
		"role": "Dano", "origin": "deusa",
		"hp": 250.0, "speed": 96.0, "range": 300.0, "dmg": 18.0, "cd": 0.55,
		"radius": 15.0, "color": Color(0.72, 0.45, 1.0), "style": "backline_dps",
		"proj_speed": 900.0,
		"ult": "chuva", "cards": ["disparo", "armadilha", "salto"],
	},
	"asclepio": {
		"role": "Suporte", "origin": "semideus",
		"hp": 280.0, "speed": 90.0, "range": 230.0, "dmg": 10.0, "cd": 0.75,
		"radius": 16.0, "color": Color(0.33, 0.85, 0.45), "style": "backline_support",
		"proj_speed": 620.0, "heal": 15.0, "heal_range": 260.0,
		"ult": "segunda", "cards": ["sopro", "veneno", "engrenagem"],
	},
}

## Nome, resumo da carta e descrição ficam em i18n/textos.csv (AB_<ID>_NAME/SHORT/DESC).
## target: "self" (age na hora), "point" (escolhe local), "ally" (escolhe aliado)
const ABILITIES := {
	# Talos
	"muralha": {"id": "muralha", "effect": "escudo", "hero": "talos", "cost": 3, "target": "point",
		"range": 0.0, "radius": 0.0},
	"investida": {"id": "investida", "effect": "mobilidade", "hero": "talos", "cost": 4, "target": "point",
		"range": 260.0, "radius": 0.0},
	"valvula": {"id": "valvula", "effect": "escudo", "hero": "talos", "cost": 2, "target": "self",
		"range": 0.0, "radius": 190.0},
	"furia": {"id": "furia", "effect": "controle", "hero": "talos", "cost": 0, "target": "self", "ult": true,
		"range": 0.0, "radius": 210.0},
	# Ártemis
	"disparo": {"id": "disparo", "effect": "dano", "hero": "artemis", "cost": 3, "target": "point",
		"range": 0.0, "radius": 0.0},
	"armadilha": {"id": "armadilha", "effect": "controle", "hero": "artemis", "cost": 2, "target": "point",
		"range": 380.0, "radius": 34.0},
	"salto": {"id": "salto", "effect": "mobilidade", "hero": "artemis", "cost": 3, "target": "self",
		"range": 0.0, "radius": 0.0},
	"chuva": {"id": "chuva", "effect": "dano", "hero": "artemis", "cost": 0, "target": "point", "ult": true,
		"range": 650.0, "radius": 170.0},
	# Asclépio
	"sopro": {"id": "sopro", "effect": "cura", "hero": "asclepio", "cost": 3, "target": "self",
		"range": 0.0, "radius": 210.0},
	"veneno": {"id": "veneno", "effect": "dano", "hero": "asclepio", "cost": 2, "target": "point",
		"range": 0.0, "radius": 0.0},
	"engrenagem": {"id": "engrenagem", "effect": "escudo", "hero": "asclepio", "cost": 4, "target": "ally",
		"range": 0.0, "radius": 0.0},
	"segunda": {"id": "segunda", "effect": "cura", "hero": "asclepio", "cost": 0, "target": "self", "ult": true,
		"range": 0.0, "radius": 240.0},
	# Hércules
	"nemeia": {"id": "nemeia", "effect": "mobilidade", "hero": "hercules", "cost": 3, "target": "point",
		"range": 300.0, "radius": 75.0},
	"pele": {"id": "pele", "effect": "escudo", "hero": "hercules", "cost": 2, "target": "self",
		"range": 0.0, "radius": 0.0},
	"corrente": {"id": "corrente", "effect": "controle", "hero": "hercules", "cost": 3, "target": "point",
		"range": 330.0, "radius": 0.0},
	"trabalho": {"id": "trabalho", "effect": "controle", "hero": "hercules", "cost": 0, "target": "self", "ult": true,
		"range": 90.0, "radius": 0.0},
	# Zeus
	"raios": {"id": "raios", "effect": "dano", "hero": "zeus", "cost": 3, "target": "point",
		"range": 280.0, "radius": 150.0},
	"nuvem": {"id": "nuvem", "effect": "controle", "hero": "zeus", "cost": 3, "target": "point",
		"range": 450.0, "radius": 100.0},
	"aguia": {"id": "aguia", "effect": "mobilidade", "hero": "zeus", "cost": 2, "target": "point",
		"range": 200.0, "radius": 0.0},
	"olimpo": {"id": "olimpo", "effect": "dano", "hero": "zeus", "cost": 0, "target": "self", "ult": true,
		"range": 0.0, "radius": 350.0},
	# Atena
	"egide": {"id": "egide", "effect": "escudo", "hero": "atena", "cost": 3, "target": "point",
		"range": 300.0, "radius": 100.0},
	"comando": {"id": "comando", "effect": "mobilidade", "hero": "atena", "cost": 3, "target": "self",
		"range": 0.0, "radius": 200.0},
	"coruja": {"id": "coruja", "effect": "controle", "hero": "atena", "cost": 2, "target": "point",
		"range": 400.0, "radius": 0.0},
	"falange": {"id": "falange", "effect": "escudo", "hero": "atena", "cost": 0, "target": "self", "ult": true,
		"range": 0.0, "radius": 180.0},
}


const ULT_KEYS := ["Q", "W", "E"]
const BEHAVIOR_KEYS := ["Z", "X", "C"]


## Engrenagem da carta na Roda do Destino (-1 para ultimates).
static func gear_of(card: String) -> int:
	var ab: Dictionary = ABILITIES[card]
	if ab.get("ult", false):
		return -1
	return EFFECT_GEAR[ab["effect"]]
