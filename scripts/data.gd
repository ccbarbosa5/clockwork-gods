extends RefCounted
## Dados de balanceamento do protótipo. Todos os números aqui são
## propostas iniciais e devem ser calibrados em teste.

# --- Partida ---------------------------------------------------------------
const MATCH_TIME := 300.0          # tempo limite (s)
const UNLOCK_TIME := 12.0          # ponto libera após (s)
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
const BEHAVIOR_NAMES := {"aggressive": "Agressivo", "balanced": "Equilibrado", "defensive": "Defensivo"}

# --- Times -------------------------------------------------------------------
const TEAM_COLORS := [Color(0.30, 0.66, 1.0), Color(1.0, 0.36, 0.30)]
const TEAM_NAMES := ["Azul", "Vermelho"]
const GOLD := Color(0.95, 0.76, 0.31)
const BRONZE := Color(0.78, 0.54, 0.23)

## Cartas armadas: o herói usa a habilidade no melhor momento em até ARM_TIME segundos.
const ARM_TIME := 5.0

## Cores por função (não conflitam com azul/vermelho dos times).
const ROLE_COLORS := {"Tanque": Color(0.96, 0.6, 0.2), "Dano": Color(0.72, 0.45, 1.0), "Suporte": Color(0.33, 0.85, 0.45)}

## Tipos de efeito das habilidades (ícone na carta e no mapa).
const EFFECT_NAMES := {"dano": "Dano", "cura": "Cura", "escudo": "Proteção", "controle": "Controle", "mobilidade": "Mobilidade"}

## Estilos de posicionamento da IA. Os padrões de cada função são frontline,
## backline_dps e backline_support. Estilos para heróis futuros:
##   dive            tanque que mergulha na linha de trás inimiga
##   flank           dano que contorna pelas laterais
##   battle_support  suporte que avança junto e causa dano
const STYLES := ["frontline", "backline_dps", "backline_support", "dive", "flank", "battle_support"]

const HERO_ORDER := ["talos", "artemis", "asclepio"]

const HEROES := {
	"talos": {
		"name": "Talos", "role": "Tanque", "origin": "lenda",
		"hp": 650.0, "speed": 72.0, "range": 62.0, "dmg": 26.0, "cd": 0.9,
		"radius": 22.0, "color": Color(0.96, 0.6, 0.2), "style": "frontline",
		"ult": "furia", "cards": ["muralha", "investida", "valvula"],
	},
	"artemis": {
		"name": "Ártemis", "role": "Dano", "origin": "deusa",
		"hp": 250.0, "speed": 96.0, "range": 300.0, "dmg": 18.0, "cd": 0.55,
		"radius": 15.0, "color": Color(0.72, 0.45, 1.0), "style": "backline_dps",
		"proj_speed": 900.0,
		"ult": "chuva", "cards": ["disparo", "armadilha", "salto"],
	},
	"asclepio": {
		"name": "Asclépio", "role": "Suporte", "origin": "semideus",
		"hp": 280.0, "speed": 90.0, "range": 230.0, "dmg": 10.0, "cd": 0.75,
		"radius": 16.0, "color": Color(0.33, 0.85, 0.45), "style": "backline_support",
		"proj_speed": 620.0, "heal": 15.0, "heal_range": 260.0,
		"ult": "segunda", "cards": ["sopro", "veneno", "engrenagem"],
	},
}

## target: "self" (age na hora), "point" (escolhe local), "ally" (escolhe aliado)
const ABILITIES := {
	# Talos
	"muralha": {"effect": "escudo", "short": "Bloqueia tiros", "hero": "talos", "name": "Muralha de Bronze", "cost": 3, "target": "point",
		"range": 0.0, "radius": 0.0,
		"desc": "Escudo frontal que bloqueia projéteis por 4 s."},
	"investida": {"effect": "mobilidade", "short": "Avança e atordoa", "hero": "talos", "name": "Investida a Vapor", "cost": 4, "target": "point",
		"range": 260.0, "radius": 0.0,
		"desc": "Avança em linha, causa 45 de dano e atordoa."},
	"valvula": {"effect": "escudo", "short": "-40% dano no grupo", "hero": "talos", "name": "Válvula de Pressão", "cost": 2, "target": "self",
		"range": 0.0, "radius": 190.0,
		"desc": "Aliados próximos recebem 40% menos dano por 4 s."},
	"furia": {"effect": "controle", "short": "Atordoa em área", "hero": "talos", "name": "Fúria da Forja", "cost": 0, "target": "self", "ult": true,
		"range": 0.0, "radius": 210.0,
		"desc": "Golpe no chão: 60 de dano e atordoa em área."},
	# Ártemis
	"disparo": {"effect": "dano", "short": "Tiro perfurante", "hero": "artemis", "name": "Disparo Perfurante", "cost": 3, "target": "point",
		"range": 0.0, "radius": 0.0,
		"desc": "Tiro que atravessa inimigos causando 90 de dano."},
	"armadilha": {"effect": "controle", "short": "Prende inimigo", "hero": "artemis", "name": "Armadilha de Caça", "cost": 2, "target": "point",
		"range": 380.0, "radius": 34.0,
		"desc": "Prende o primeiro inimigo por 1,8 s e causa 30."},
	"salto": {"effect": "mobilidade", "short": "Recua e acelera", "hero": "artemis", "name": "Salto Lunar", "cost": 3, "target": "self",
		"range": 0.0, "radius": 0.0,
		"desc": "Recua e ganha 60% de velocidade de ataque por 3 s."},
	"chuva": {"effect": "dano", "short": "Dano em área", "hero": "artemis", "name": "Chuva de Prata", "cost": 0, "target": "point", "ult": true,
		"range": 650.0, "radius": 170.0,
		"desc": "Chuva de flechas: dano contínuo e lentidão em área."},
	# Asclépio
	"sopro": {"effect": "cura", "short": "Cura em área", "hero": "asclepio", "name": "Sopro Restaurador", "cost": 3, "target": "self",
		"range": 0.0, "radius": 210.0,
		"desc": "Cura 120 de vida dos aliados ao redor."},
	"veneno": {"effect": "dano", "short": "Veneno, corta cura", "hero": "asclepio", "name": "Veneno da Serpente", "cost": 2, "target": "point",
		"range": 0.0, "radius": 0.0,
		"desc": "Dano contínuo e reduz a cura do alvo pela metade."},
	"engrenagem": {"effect": "escudo", "short": "Escudo no aliado", "hero": "asclepio", "name": "Engrenagem Vital", "cost": 4, "target": "ally",
		"range": 0.0, "radius": 0.0,
		"desc": "Escudo de 150 em um aliado por 5 s."},
	"segunda": {"effect": "cura", "short": "Ninguém morre", "hero": "asclepio", "name": "Segunda Chance", "cost": 0, "target": "self", "ult": true,
		"range": 0.0, "radius": 240.0,
		"desc": "Aliados próximos não podem morrer por 3 s."},
}

const ULT_KEYS := ["Q", "W", "E"]
const BEHAVIOR_KEYS := ["Z", "X", "C"]

# --- Textos da Galeria de heróis (bilíngue) ----------------------------------
## Idioma atual dos textos ("pt" ou "en"). O resto da interface ainda é só PT.
static var lang := "pt"
const LANGS := ["pt", "en"]

## Origem do herói (campo "origin" de HEROES).
const ORIGIN_NAMES := {
	"deus": {"pt": "Deus", "en": "God"},
	"deusa": {"pt": "Deusa", "en": "Goddess"},
	"semideus": {"pt": "Semideus", "en": "Demigod"},
	"lenda": {"pt": "Lenda", "en": "Legend"},
}

## Nome da função em cada idioma (chave = campo "role" de HEROES).
const ROLE_NAMES := {
	"Tanque": {"pt": "Tanque", "en": "Tank"},
	"Dano": {"pt": "Dano", "en": "Damage"},
	"Suporte": {"pt": "Suporte", "en": "Support"},
}

## Nome, epíteto, biografia (até 3 linhas) e frase marcante de cada herói.
## Fonte: claude/textos-galeria.md (Lore, aprovado pelo usuário em 9 nov. 2026).
## O inglês usa termos do glossário ainda em PROPOSTA (Great Gear, Rites, sparks).
const HERO_TEXTS := {
	"talos": {
		"name": {"pt": "Talos", "en": "Talos"},
		"epithet": {"pt": "O Guardião de Bronze", "en": "The Bronze Guardian"},
		"bio": {
			"pt": "O primeiro autômato de Hefesto. Morreu quando o Ícor vazou de sua única veia e renasceu como o molde de todos os corpos dos Ritos. Hoje guarda o selo dos Titãs como um dia guardou Creta.",
			"en": "Hephaestus's first automaton. He died when the Ichor drained from his single vein and was rebuilt as the mold for every body in the Rites. Now he guards the Titans' seal as he once guarded Crete.",
		},
		"quote": {"pt": "Uma veia. Um prego. Nunca mais.", "en": "One vein. One nail. Never again."},
	},
	"artemis": {
		"name": {"pt": "Ártemis", "en": "Artemis"},
		"epithet": {"pt": "A Caçadora de Prata", "en": "The Silver Huntress"},
		"bio": {
			"pt": "Deusa da caça, presa num corpo de latão desde que deu seu Ícor à Grande Engrenagem. Nos Ritos, encontrou a única caçada que lhe resta, e cada tiro precisa contar.",
			"en": "Goddess of the hunt, bound to a brass body since she gave her Ichor to the Great Gear. The Rites are the only hunt she has left, and every shot must count.",
		},
		"quote": {"pt": "Corpo de latão, mira de deusa.", "en": "Body of brass, aim of a goddess."},
	},
	"asclepio": {
		"name": {"pt": "Asclépio", "en": "Asclepius"},
		"epithet": {"pt": "O Médico Fulminado", "en": "The Thunderstruck Healer"},
		"bio": {
			"pt": "O médico que Zeus fulminou por ressuscitar os mortos. Hefesto o chamou para cuidar dos corpos e centelhas dos Ritos, onde todos voltam. A ironia o diverte.",
			"en": "The physician Zeus struck down for raising the dead. Hephaestus called him to tend the bodies and sparks of the Rites, where everyone comes back. He enjoys the irony.",
		},
		"quote": {"pt": "Na arena, ninguém morre de verdade. Finalmente uma regra que eu aprovo.", "en": "In the arena, no one truly dies. Finally, a rule I approve of."},
	},
}


## Texto de um herói no idioma atual (cai para PT se faltar a tradução).
static func hero_text(hid: String, field: String, language := "") -> String:
	var l := language if language != "" else lang
	var d: Dictionary = HERO_TEXTS.get(hid, {}).get(field, {})
	return d.get(l, d.get("pt", ""))


static func origin_name(hid: String, language := "") -> String:
	var l := language if language != "" else lang
	var d: Dictionary = ORIGIN_NAMES.get(HEROES[hid]["origin"], {})
	return d.get(l, d.get("pt", HEROES[hid]["origin"]))


static func role_name(hid: String, language := "") -> String:
	var l := language if language != "" else lang
	var d: Dictionary = ROLE_NAMES.get(HEROES[hid]["role"], {})
	return d.get(l, HEROES[hid]["role"])
