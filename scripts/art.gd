extends RefCounted
## Imagens do jogo (sprites, retratos, ícones, molduras e efeitos).
## Tudo passa por aqui: carrega com cache e, se o PNG não existir, devolve null
## e quem desenha usa o desenho por código de sempre. Assim o jogo funciona
## igual sem nenhuma imagem, e cada arquivo novo em res://assets/ entra sozinho.
## Nomes e tamanhos esperados: assets/README.md.

const Data = preload("res://scripts/data.gd")

const HERO_SPRITE := "res://assets/heroes/%s_top.png"
const HERO_PORTRAIT := "res://assets/heroes/%s_portrait.png"
## Ilustração de corpo inteiro da Galeria de heróis (512×768).
const HERO_FULL := "res://assets/heroes/%s_full.png"
const ICON := "res://assets/icons/%s.png"
const CARD_FRAME := "res://assets/cards/frame_%s.png"
const FX := "res://assets/fx/%s.png"
const MAP := "res://assets/map/%s.png"
## Logo do jogo no menu (1200×400, desenhado em 540×180).
const LOGO := "res://assets/ui/logo.png"
## Logo na tela de título: ~760 px de largura em 1920 (507 em 1280), a ~60 px
## do topo em 1920 (40 em 720).
const LOGO_SIZE := Vector2(507, 169)
const LOGO_TOP := 40.0
## Fundo da tela de título (1920 × 1080), escalado para cobrir sem distorcer.
const TITLE_BG := "res://assets/ui/title_bg.png"
## Capa da página do itch.io (630 × 500). Não é usada no jogo e fica fora da
## exportação (export_presets.cfg); vai para a página à mão.
const ITCH_COVER := "res://assets/store/itch_cover.png"
## Ícone do jogo (aba do navegador, export web); usado pelo projeto, não pelo código.
const ICON_STORE := "res://assets/store/icon.png"

## Imagens do mapa (map/<nome>.png). "fill" = fração da imagem ocupada pelo
## círculo de jogo (coluna, ponto ou base): o resto é borda, brilho ou detalhe.
## O piso é desenhado esticado na arena inteira (1280×520).
const MAP_IMAGES := {
	"arena_floor": {"src": Vector2i(2560, 1040)},
	"pillar_large": {"src": Vector2i(160, 160), "fill": 0.92},   # colunas de raio 34 e 28
	"pillar_small": {"src": Vector2i(112, 112), "fill": 0.92},   # colunas de raio 22 e 20
	"control_point": {"src": Vector2i(512, 512), "fill": 0.9},   # ponto de raio 95
	"spawn_base": {"src": Vector2i(384, 384), "fill": 0.94},      # bases de raio 75
	"health_pack": {"src": Vector2i(128, 128), "fill": 0.75},     # pacote de vida: 48 px na tela
}
## Colunas com raio a partir deste valor usam pillar_large.
const PILLAR_LARGE_MIN_R := 28.0

## Lado da imagem inteira do herói na tela (px, base 1280×720). A imagem-fonte
## (256×256) é feita para o anel do time ocupar 80% dela: 2 × (raio + 3) / 0,8.
const HERO_SPRITE_PX := {"talos": 62.0, "artemis": 45.0, "asclepio": 48.0, "hercules": 62.0, "zeus": 47.5, "atena": 50.0}
## Giro máximo do sprite do herói (graus por segundo).
const HERO_TURN_DEG := 720.0

## Projéteis: imagem, tamanho na tela e quanto a ponta passa da posição do tiro.
## As imagens são desenhadas apontando para a direita (0°).
const PROJECTILES := {
	"pierce": {"fx": "disparo_projetil", "size": Vector2(70, 18), "tip": 6.0},
	"poison": {"fx": "veneno_projetil", "size": Vector2(35, 14), "tip": 5.0},
	"basic": {"fx": "tiro_basico", "size": Vector2(12, 6), "tip": 4.0},
	"chain": {"fx": "corrente_gancho", "size": Vector2(20, 20), "tip": 8.0},
	"spear": {"fx": "lanca_projetil", "size": Vector2(34, 8), "tip": 4.0},
}

## Efeitos de imagem única ligados por código (fx/<nome>.png), com o tamanho
## na tela em escala 1 (px, base 1280×720). Lista oficial: assets/README.md.
const FX_EFFECTS := {
	# Áreas no chão (diâmetro da área)
	"furia_area": Vector2(420, 420),
	"valvula_area": Vector2(380, 380),
	"sopro_area": Vector2(420, 420),
	"segunda_area": Vector2(480, 480),
	"chuva_area": Vector2(340, 340),
	# Objetos no chão
	"armadilha_aberta": Vector2(44, 44),
	"armadilha_fechada": Vector2(44, 44),
	# Presa ao Talos, convexa para a frente (direita). A arte entregue é uma
	# meia-lua alta (~78×123 px dos 256×128): escala 0,7 e centro a
	# MURALHA_OFFSET px à frente deixam o escudo de pé, sem cobrir o sprite.
	"muralha_arco": Vector2(179, 90),
	# Partículas
	"fumaca": Vector2(26, 26),
	"chuva_flecha": Vector2(12, 12),
	"cura_mais": Vector2(14, 14),
	"veneno_bolha": Vector2(5, 5),
	"atordoado_estrela": Vector2(8, 8),
	# Auras e estados (tamanho do Talos; escala pelo raio do herói)
	"aura_valvula": Vector2(64, 64),
	"aura_engrenagem": Vector2(72, 72),
	"aura_segunda": Vector2(76, 76),
	"aura_raiz": Vector2(64, 64),
	# Ataque e movimento
	"soco_arco": Vector2(64, 32),
	"feixe_cura": Vector2(64, 6),
	# Pacote 3 (Hércules, Zeus, Atena)
	"nemeia_queda": Vector2(150, 150),
	"nemeia_alvo": Vector2(150, 150),
	"pele_juba": Vector2(72, 72),
	"corrente_elo": Vector2(32, 8),
	"trabalho_impacto": Vector2(60, 60),
	"raio_cadeia": Vector2(64, 10),
	"nuvem_area": Vector2(200, 200),
	"raio_queda": Vector2(28, 140),
	"olimpo_area": Vector2(700, 700),
	"aguia_pena": Vector2(12, 12),
	"egide_cupula": Vector2(200, 200),
	"comando_area": Vector2(400, 400),
	"comando_aura": Vector2(72, 72),
	"coruja_olho": Vector2(20, 12),
	"coruja_voo": Vector2(24, 24),
	"falange_area": Vector2(360, 360),
	"escudo_palas": Vector2(88, 88),  # Talos; para cada herói: 2 × (raio + 4) / ESCUDO_PALAS_INNER
}

## Opacidade máxima das áreas grandes no chão (Válvula, Fúria, Sopro, Segunda
## Chance e Chuva de Prata): o efeito continua visível, mas heróis e cores dos
## times leem por cima dele.
const AREA_ALPHA := 0.55
## Escudo de Palas: a faixa de prata entregue começa a 59% do raio da imagem.
const ESCUDO_PALAS_INNER := 0.59
## Falange de Atenas: a parede de escudos entregue é bem opaca; mais leve que as outras áreas.
const FALANGE_ALPHA := 0.4
const RAIN_ALPHA := 0.45

## Distância do centro da imagem da Muralha até o centro do Talos (px).
const MURALHA_OFFSET := 33.0

static var _cache := {}
## Nomes de efeito desenhados por imagem (usado pelos testes).
static var drawn_names := {}
## Quantas imagens foram desenhadas (usado pelos testes).
static var drawn := 0


## Textura do caminho, ou null se o arquivo não existir. Com cache: o disco
## só é consultado uma vez por caminho, mesmo quando falta a imagem.
static func tex(path: String) -> Texture2D:
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	_cache[path] = t
	return t


## Troca a textura de um caminho (testes e prévias). null volta a "sem imagem".
static func set_texture(path: String, t: Texture2D) -> void:
	_cache[path] = t


## Esquece o cache: a próxima consulta olha o disco de novo.
static func clear_cache() -> void:
	_cache.clear()


static func hero_sprite(hid: String) -> Texture2D:
	return tex(HERO_SPRITE % hid)


static func hero_portrait(hid: String) -> Texture2D:
	return tex(HERO_PORTRAIT % hid)


static func hero_full(hid: String) -> Texture2D:
	return tex(HERO_FULL % hid)


static func icon(ab_id: String) -> Texture2D:
	return tex(ICON % ab_id)


## Moldura da carta pela função do herói (Tanque, Dano, Suporte).
static func card_frame(role: String) -> Texture2D:
	return tex(CARD_FRAME % role.to_lower())


static func fx(name: String) -> Texture2D:
	return tex(FX % name)


static func map_tex(name: String) -> Texture2D:
	return tex(MAP % name)


static func pillar_name(r: float) -> String:
	return "pillar_large" if r >= PILLAR_LARGE_MIN_R else "pillar_small"


## Lado na tela de uma imagem redonda do mapa para um círculo de jogo de raio r.
static func map_size(name: String, r: float) -> float:
	return 2.0 * r / float(MAP_IMAGES[name]["fill"])


## Desenha uma imagem do mapa centrada (lado = map_size). false = sem imagem.
static func draw_map(ci: CanvasItem, name: String, c: Vector2, r: float, rot := 0.0, mod := Color.WHITE) -> bool:
	var t := map_tex(name)
	if t == null:
		return false
	drawn_names["map/" + name] = true
	var s := map_size(name, r)
	draw_centered(ci, t, c, Vector2(s, s), rot, mod)
	return true


## Piso esticado num retângulo. false = sem imagem.
static func draw_floor(ci: CanvasItem, rect: Rect2) -> bool:
	var t := map_tex("arena_floor")
	if t == null:
		return false
	drawn += 1
	drawn_names["map/arena_floor"] = true
	ci.draw_texture_rect(t, rect, false)
	return true


## Chave da habilidade (ex.: "muralha") a partir do dicionário dela em Data.ABILITIES.
static func ability_id(ab: Dictionary) -> String:
	return ab.get("id", "")


# ---------------------------------------------------------------------------
# Desenho

## Desenha a textura centrada em `c`, com tamanho, giro (rad) e cor/transparência.
## Desenha a imagem cobrindo o retângulo sem distorcer (corta o que sobrar).
static func draw_cover(ci: CanvasItem, t: Texture2D, rect: Rect2) -> void:
	drawn += 1
	var ts := t.get_size()
	var k := maxf(rect.size.x / ts.x, rect.size.y / ts.y)
	var src_size := rect.size / k
	var src := Rect2((ts - src_size) * 0.5, src_size)
	ci.draw_texture_rect_region(t, rect, src)


static func draw_centered(ci: CanvasItem, t: Texture2D, c: Vector2, size: Vector2, rot := 0.0, mod := Color.WHITE) -> void:
	drawn += 1
	if rot == 0.0:
		ci.draw_texture_rect(t, Rect2(c - size * 0.5, size), false, mod)
		return
	ci.draw_set_transform(c, rot, Vector2.ONE)
	ci.draw_texture_rect(t, Rect2(-size * 0.5, size), false, mod)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Efeito de imagem única animado pelo código: escala, transparência e giro.
## `size` é o tamanho com escala 1. Retorna false se não houver imagem
## (quem chamou desenha o efeito por código).
static func draw_fx(ci: CanvasItem, name: String, c: Vector2, size: Vector2, scale := 1.0, alpha := 1.0, rot := 0.0, tint := Color.WHITE) -> bool:
	var t := fx(name)
	if t == null:
		return false
	drawn_names[name] = true
	draw_centered(ci, t, c, size * scale, rot, Color(tint, tint.a * alpha))
	return true


## Faixa com textura repetida de `a` até `b` (feixe de cura). A textura é
## desenhada na horizontal e repetida ao longo do comprimento. Retorna false
## se não houver imagem.
static func draw_beam(ci: CanvasItem, name: String, a: Vector2, b: Vector2, thickness: float, tint := Color.WHITE) -> bool:
	var t := fx(name)
	if t == null:
		return false
	drawn += 1
	drawn_names[name] = true
	var v := b - a
	var length := v.length()
	if length < 1.0:
		return true
	# Repete a textura mantendo a proporção dela na espessura pedida.
	var tile_w: float = t.get_width() * thickness / maxf(1.0, t.get_height())
	ci.draw_set_transform(a, v.angle(), Vector2.ONE)
	var x := 0.0
	while x < length:
		var w := minf(tile_w, length - x)
		var src := Rect2(0, 0, t.get_width() * w / tile_w, t.get_height())
		ci.draw_texture_rect_region(t, Rect2(x, -thickness * 0.5, w, thickness), src, tint)
		x += tile_w
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	return true


## Projétil apontando na direção do voo. Retorna false se não houver imagem.
static func draw_projectile(ci: CanvasItem, kind: String, pos: Vector2, dir: Vector2, tint := Color.WHITE) -> bool:
	var p: Dictionary = PROJECTILES.get(kind, PROJECTILES["basic"])
	var t := fx(p["fx"])
	if t == null:
		return false
	var size: Vector2 = p["size"]
	# A ponta da imagem fica `tip` px à frente da posição do tiro.
	var tip: float = p["tip"]
	var c := pos + dir * (tip - size.x * 0.5)
	draw_centered(ci, t, c, size, dir.angle(), tint)
	return true


## Textura recortada em círculo (retratos).
static func draw_circle_tex(ci: CanvasItem, t: Texture2D, c: Vector2, r: float, mod := Color.WHITE) -> void:
	drawn += 1
	var pts := PackedVector2Array()
	var uvs := PackedVector2Array()
	var n := 40
	for i in n:
		var a := TAU * float(i) / float(n)
		var d := Vector2(cos(a), sin(a))
		pts.append(c + d * r)
		uvs.append(Vector2(0.5, 0.5) + d * 0.5)
	ci.draw_polygon(pts, PackedColorArray([mod]), uvs, t)
