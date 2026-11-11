extends RefCounted
## Dados de balanceamento do protótipo. Todos os números aqui são
## propostas iniciais e devem ser calibrados em teste.

# --- Partida ---------------------------------------------------------------
const MATCH_TIME := 300.0          # tempo limite (s)
const UNLOCK_TIME := 12.0          # ponto libera após (s)
const POINT_R := 95.0             # raio do ponto de controle (px)
const CAPTURE_TIME := 6.0          # tempo para capturar o ponto (s)
const PROGRESS_RATE := 100.0 / 68.0   # % por segundo enquanto controla (68 s sem disputa; era 80 até 11 nov.)
const CONTESTED_RATE := 0.5         # fração do progresso quando disputado com vantagem numérica
const RESPAWN := 6.0               # tempo de renascimento (s)
const SPAWN_REGEN := 90.0          # cura por segundo dentro da própria base

# --- Pacotes de vida e regeneração (Pacote 5) --------------------------------
## 5 pontos espelhados: 2 de cada lado e 1 no meio (longe do ponto e das bases).
const HEALTH_PACKS := [Vector2(330, 110), Vector2(330, 490), Vector2(950, 110), Vector2(950, 490), Vector2(640, 520)]
const PACK_HEAL := 60.0            # cura na hora ao pegar (100 até 11 nov.: cura demais, partidas por tempo)
const PACK_RESPAWN := 30.0         # s até o frasco voltar (era 20)
const PACK_PICK_R := 18.0          # raio do pacote para pegar (mais o raio do herói)
## Frasco de Ambrosia fora do recuo: vai buscar se a vida estiver abaixo de `hp`
## e o frasco a até `reach` px. Segue os textos da Lore (claude/textos-pacote-5.md):
## Agressivo só pega no caminho; Defensivo usa sempre que pode.
const PACK_DETOUR := {"aggressive": {"hp": 0.5, "reach": 90.0}, "balanced": {"hp": 0.65, "reach": 160.0}, "defensive": {"hp": 0.8, "reach": 240.0}}
## No recuo, troca a base pelo frasco se ele estiver a menos desta fração da
## distância até a base (Equilibrado e Defensivo: qualquer frasco mais perto).
const PACK_OVER_BASE := {"aggressive": 0.5, "balanced": 1.0, "defensive": 1.0}
const REGEN_DELAY := 7.0           # s sem levar dano para começar a regenerar (era 5)
const REGEN_RATE := 5.0            # vida por segundo (era 8; base: 90/s; frasco: 60 na hora)
## Cobertura: abaixo desta fração da vida, sem inimigo a COVER_SAFE px, o herói
## se esconde atrás de uma coluna para regenerar (até COVER_DONE). -1 = nunca.
const COVER_HP := {"aggressive": -1.0, "balanced": 0.4, "defensive": 0.6}
const COVER_DONE := 0.85
const COVER_SAFE := 230.0

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
const GEAR_DMG_BONUS := 0.3        # Controle → Ataque: +30% de dano (+40% testado em 11 nov.: desequilibrou)
const GEAR_DEF_BONUS := 0.3        # Ataque → Defesa: +30% de cura, escudo ou redução
const GEAR_MOVE_SHIELD := 60.0     # Defesa → Movimento: escudo no herói que se desloca (40 testado em 11 nov.)
const GEAR_MOVE_SHIELD_T := 3.0
const CADENCE_FROM := 3            # a partir deste elo seguido, cada elo devolve Ícor
const CADENCE_REFUND := 1.0
const FULL_TURN_LINKS := 4         # elos seguidos para a volta completa
const FULL_TURN_ULT := 10.0        # carga de ultimate para cada herói do time

# --- Comportamento da IA ----------------------------------------------------
## Espera para trocar de comportamento (0 = troca na hora; Pacote 5).
const BEHAVIOR_CD := 0.0
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
## Funções, na ordem de exibição (seleção, galeria e time na partida).
const ROLE_ORDER := ["Tanque", "Dano", "Suporte"]
## Times: 3 heróis sem repetir. Padrão (modo equilibrado): 1 de cada função.
## Modo livre (experimental): no máximo 2 da mesma função.
const TEAM_SIZE := 3
const MAX_PER_ROLE := 2
const DEFAULT_TEAM := ["talos", "artemis", "asclepio"]


## Heróis de uma função, na ordem da galeria.
static func heroes_of_role(role: String) -> Array:
	var out: Array = []
	for hid in HERO_ORDER:
		if HEROES[hid]["role"] == role:
			out.append(hid)
	return out


## Heróis agrupados por função (ROLE_ORDER); dentro da função, os originais
## primeiro (ordem de HERO_ORDER).
static func heroes_by_role() -> Array:
	var out: Array = []
	for role in ROLE_ORDER:
		out.append_array(heroes_of_role(role))
	return out


## Pode pôr `hid` no time? Retorna "" ou o motivo: "full", "dup", "role".
## Padrão: 1 por função; `free` (modo livre): até MAX_PER_ROLE por função.
static func team_add_block(team: Array, hid: String, free_mode := false) -> String:
	if team.has(hid):
		return "dup"
	if team.size() >= TEAM_SIZE:
		return "full"
	var n := 0
	for h in team:
		if HEROES[h]["role"] == HEROES[hid]["role"]:
			n += 1
	return "role" if n >= (MAX_PER_ROLE if free_mode else 1) else ""


## Time válido: 3 heróis sem repetir; 1 de cada função (ou até 2, no modo livre).
static func valid_team(team: Array, free_mode := false) -> bool:
	if team.size() != TEAM_SIZE:
		return false
	var seen: Array = []
	for hid in team:
		if not HEROES.has(hid) or team_add_block(seen, hid, free_mode) != "":
			return false
		seen.append(hid)
	return true


## Time na ordem de exibição: Tanque, Dano, Suporte; originais primeiro.
static func sort_team(team: Array) -> Array:
	var order := heroes_by_role()
	var out := team.duplicate()
	out.sort_custom(func(a, b): return order.find(a) < order.find(b))
	return out


## Todos os times possíveis (ordenados), para a simulação.
static func all_teams(free_mode := false) -> Array:
	var out: Array = []
	var hs := heroes_by_role()
	for i in hs.size():
		for j in range(i + 1, hs.size()):
			for k in range(j + 1, hs.size()):
				var tm := [hs[i], hs[j], hs[k]]
				if valid_team(tm, free_mode):
					out.append(tm)
	return out


## Time sorteado (qualquer time válido do modo, com a mesma chance).
static func random_team(free_mode := false) -> Array:
	var all := all_teams(free_mode)
	return all[randi() % all.size()].duplicate()


## Engrenagens da Roda do Destino que faltam no time (índices de GEARS).
static func missing_gears(team: Array) -> Array:
	var has := {}
	for hid in team:
		for c in HEROES[hid]["cards"]:
			has[gear_of(c)] = true
	var out: Array = []
	for g in GEARS.size():
		if not has.has(g):
			out.append(g)
	return out

## Textos (nome, epíteto, bio, frase) ficam em i18n/textos.csv (HERO_<ID>_*).
const HEROES := {
	"talos": {
		"role": "Tanque", "origin": "lenda",
		"hp": 625.0, "speed": 72.0, "range": 62.0, "dmg": 26.0, "cd": 0.9,
		"radius": 22.0, "color": Color(0.96, 0.6, 0.2), "style": "frontline",
		"splash": 0.5,  # golpe atinge 50% em inimigos a até 45 px do alvo
		"ult": "furia", "cards": ["muralha", "investida", "valvula"],
	},
	"hercules": {
		"role": "Tanque", "origin": "semideus",
		"hp": 630.0, "speed": 80.0, "range": 58.0, "dmg": 33.0, "cd": 1.0, "dive_reach": 0.0,
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
		"hp": 330.0, "speed": 88.0, "range": 180.0, "dmg": 16.0, "cd": 0.8,
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
		"proj_speed": 620.0, "heal": 14.4, "heal_range": 260.0,
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
