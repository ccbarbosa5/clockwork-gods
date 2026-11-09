extends RefCounted
## Dados de balanceamento do protótipo. Todos os números aqui são
## propostas iniciais e devem ser calibrados em teste.

# --- Partida ---------------------------------------------------------------
const MATCH_TIME := 300.0          # tempo limite (s)
const UNLOCK_TIME := 12.0          # ponto libera após (s)
const CAPTURE_TIME := 6.0          # tempo para capturar o ponto (s)
const PROGRESS_RATE := 100.0 / 105.0  # % por segundo enquanto controla
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
const BEHAVIOR_NAMES := {"aggressive": "Agressivo", "balanced": "Equilibrado", "defensive": "Defensivo"}

# --- Times -------------------------------------------------------------------
const TEAM_COLORS := [Color(0.30, 0.66, 1.0), Color(1.0, 0.36, 0.30)]
const TEAM_NAMES := ["Azul", "Vermelho"]
const GOLD := Color(0.95, 0.76, 0.31)
const BRONZE := Color(0.78, 0.54, 0.23)

const HERO_ORDER := ["talos", "artemis", "asclepio"]

const HEROES := {
	"talos": {
		"name": "Talos", "role": "Tanque", "origin": "lenda",
		"hp": 650.0, "speed": 72.0, "range": 62.0, "dmg": 26.0, "cd": 0.9,
		"radius": 22.0, "color": Color(0.78, 0.54, 0.23),
		"ult": "furia", "cards": ["muralha", "investida", "valvula"],
	},
	"artemis": {
		"name": "Ártemis", "role": "Dano", "origin": "deusa",
		"hp": 250.0, "speed": 96.0, "range": 300.0, "dmg": 18.0, "cd": 0.55,
		"radius": 15.0, "color": Color(0.74, 0.80, 0.92),
		"proj_speed": 900.0,
		"ult": "chuva", "cards": ["disparo", "armadilha", "salto"],
	},
	"asclepio": {
		"name": "Asclépio", "role": "Suporte", "origin": "semideus",
		"hp": 280.0, "speed": 90.0, "range": 230.0, "dmg": 10.0, "cd": 0.75,
		"radius": 16.0, "color": Color(0.37, 0.79, 0.54),
		"proj_speed": 620.0, "heal": 15.0, "heal_range": 260.0,
		"ult": "segunda", "cards": ["sopro", "veneno", "engrenagem"],
	},
}

## target: "self" (age na hora), "point" (escolhe local), "ally" (escolhe aliado)
const ABILITIES := {
	# Talos
	"muralha": {"hero": "talos", "name": "Muralha de Bronze", "cost": 3, "target": "point",
		"range": 0.0, "radius": 0.0,
		"desc": "Escudo frontal que bloqueia projéteis por 4 s."},
	"investida": {"hero": "talos", "name": "Investida a Vapor", "cost": 4, "target": "point",
		"range": 260.0, "radius": 0.0,
		"desc": "Avança em linha, causa 45 de dano e atordoa."},
	"valvula": {"hero": "talos", "name": "Válvula de Pressão", "cost": 2, "target": "self",
		"range": 0.0, "radius": 190.0,
		"desc": "Aliados próximos recebem 40% menos dano por 4 s."},
	"furia": {"hero": "talos", "name": "Fúria da Forja", "cost": 0, "target": "self", "ult": true,
		"range": 0.0, "radius": 210.0,
		"desc": "Golpe no chão: 60 de dano e atordoa em área."},
	# Ártemis
	"disparo": {"hero": "artemis", "name": "Disparo Perfurante", "cost": 3, "target": "point",
		"range": 0.0, "radius": 0.0,
		"desc": "Tiro que atravessa inimigos causando 90 de dano."},
	"armadilha": {"hero": "artemis", "name": "Armadilha de Caça", "cost": 2, "target": "point",
		"range": 380.0, "radius": 34.0,
		"desc": "Prende o primeiro inimigo por 1,8 s e causa 30."},
	"salto": {"hero": "artemis", "name": "Salto Lunar", "cost": 3, "target": "self",
		"range": 0.0, "radius": 0.0,
		"desc": "Recua e ganha 60% de velocidade de ataque por 3 s."},
	"chuva": {"hero": "artemis", "name": "Chuva de Prata", "cost": 0, "target": "point", "ult": true,
		"range": 650.0, "radius": 170.0,
		"desc": "Chuva de flechas: dano contínuo e lentidão em área."},
	# Asclépio
	"sopro": {"hero": "asclepio", "name": "Sopro Restaurador", "cost": 3, "target": "self",
		"range": 0.0, "radius": 210.0,
		"desc": "Cura 120 de vida dos aliados ao redor."},
	"veneno": {"hero": "asclepio", "name": "Veneno da Serpente", "cost": 2, "target": "point",
		"range": 0.0, "radius": 0.0,
		"desc": "Dano contínuo e reduz a cura do alvo pela metade."},
	"engrenagem": {"hero": "asclepio", "name": "Engrenagem Vital", "cost": 4, "target": "ally",
		"range": 0.0, "radius": 0.0,
		"desc": "Escudo de 150 em um aliado por 5 s."},
	"segunda": {"hero": "asclepio", "name": "Segunda Chance", "cost": 0, "target": "self", "ult": true,
		"range": 0.0, "radius": 240.0,
		"desc": "Aliados próximos não podem morrer por 3 s."},
}

const ULT_KEYS := ["Q", "W", "E"]
const BEHAVIOR_KEYS := ["Z", "X", "C"]
