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

const HERO_ORDER := ["talos", "artemis", "asclepio"]

## Textos (nome, epíteto, bio, frase) ficam em i18n/textos.csv (HERO_<ID>_*).
const HEROES := {
	"talos": {
		"role": "Tanque", "origin": "lenda",
		"hp": 650.0, "speed": 72.0, "range": 62.0, "dmg": 26.0, "cd": 0.9,
		"radius": 22.0, "color": Color(0.96, 0.6, 0.2), "style": "frontline",
		"ult": "furia", "cards": ["muralha", "investida", "valvula"],
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
}

const ULT_KEYS := ["Q", "W", "E"]
const BEHAVIOR_KEYS := ["Z", "X", "C"]
