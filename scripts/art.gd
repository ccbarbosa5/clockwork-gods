extends RefCounted
## Imagens do jogo (sprites, retratos, ícones, molduras e efeitos).
## Tudo passa por aqui: carrega com cache e, se o PNG não existir, devolve null
## e quem desenha usa o desenho por código de sempre. Assim o jogo funciona
## igual sem nenhuma imagem, e cada arquivo novo em res://assets/ entra sozinho.
## Nomes e tamanhos esperados: assets/README.md.

const Data = preload("res://scripts/data.gd")

const HERO_SPRITE := "res://assets/heroes/%s_top.png"
const HERO_PORTRAIT := "res://assets/heroes/%s_portrait.png"
const ICON := "res://assets/icons/%s.png"
const CARD_FRAME := "res://assets/cards/frame_%s.png"
const FX := "res://assets/fx/%s.png"

## Lado da imagem inteira do herói na tela (px, base 1280×720). A imagem-fonte
## (256×256) é feita para o anel do time ocupar 80% dela: 2 × (raio + 3) / 0,8.
const HERO_SPRITE_PX := {"talos": 62.0, "artemis": 45.0, "asclepio": 48.0}
## Giro máximo do sprite do herói (graus por segundo).
const HERO_TURN_DEG := 720.0

## Projéteis: imagem, tamanho na tela e quanto a ponta passa da posição do tiro.
## As imagens são desenhadas apontando para a direita (0°).
const PROJECTILES := {
	"pierce": {"fx": "disparo_projetil", "size": Vector2(70, 18), "tip": 6.0},
	"poison": {"fx": "veneno_projetil", "size": Vector2(35, 14), "tip": 5.0},
	"basic": {"fx": "tiro_basico", "size": Vector2(12, 6), "tip": 4.0},
}

static var _cache := {}
static var _ability_ids := {}
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


static func icon(ab_id: String) -> Texture2D:
	return tex(ICON % ab_id)


## Moldura da carta pela função do herói (Tanque, Dano, Suporte).
static func card_frame(role: String) -> Texture2D:
	return tex(CARD_FRAME % role.to_lower())


static func fx(name: String) -> Texture2D:
	return tex(FX % name)


## Chave da habilidade (ex.: "muralha") a partir do dicionário dela em Data.ABILITIES.
static func ability_id(ab: Dictionary) -> String:
	if _ability_ids.is_empty():
		for k in Data.ABILITIES.keys():
			_ability_ids[Data.ABILITIES[k]["name"]] = k
	return _ability_ids.get(ab.get("name", ""), "")


# ---------------------------------------------------------------------------
# Desenho

## Desenha a textura centrada em `c`, com tamanho, giro (rad) e cor/transparência.
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
	draw_centered(ci, t, c, size * scale, rot, Color(tint, tint.a * alpha))
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
