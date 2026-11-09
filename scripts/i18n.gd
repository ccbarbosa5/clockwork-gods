extends RefCounted
## Idiomas (PT/EN). Todo texto que o jogador vê sai de i18n/textos.csv
## (colunas chave, pt, en), importado pelo Godot como tradução. Célula EN
## vazia cai para PT (locale/fallback = "pt" em project.godot).
## Uso: T.t("CHAVE"), T.tf("CHAVE", [args]) e os atalhos abaixo.

const SETTINGS := "user://settings.cfg"
const LANGS := ["pt", "en"]
## 1 metro = 30 px. Só na exibição: as regras continuam em px.
const PX_PER_M := 30.0

## Arquivo onde a escolha é salva (os testes trocam para não mexer no real).
static var settings_path := SETTINGS


static func t(key: String) -> String:
	return TranslationServer.translate(key)


static func tf(key: String, args: Array) -> String:
	return t(key) % args


## Idioma atual: "pt" ou "en".
static func lang() -> String:
	return "pt" if TranslationServer.get_locale().begins_with("pt") else "en"


## Idioma a usar quando o jogador nunca escolheu: português do navegador
## ou do sistema → PT; qualquer outro → EN.
static func detect(os_locale: String) -> String:
	return "pt" if os_locale.to_lower().begins_with("pt") else "en"


## Chamado ao abrir o jogo: usa a escolha salva ou detecta pelo sistema.
static func init() -> void:
	var cfg := ConfigFile.new()
	var saved := ""
	if cfg.load(settings_path) == OK:
		saved = str(cfg.get_value("geral", "idioma", ""))
	TranslationServer.set_locale(saved if saved in LANGS else detect(OS.get_locale()))


## Troca o idioma e salva a escolha.
static func set_lang(l: String, save := true) -> void:
	if not l in LANGS:
		return
	TranslationServer.set_locale(l)
	if save:
		var cfg := ConfigFile.new()
		cfg.load(settings_path)  # mantém as outras opções (som)
		cfg.set_value("geral", "idioma", l)
		cfg.save(settings_path)


static func toggle() -> void:
	set_lang("en" if lang() == "pt" else "pt")


## Texto de uma chave num idioma específico (sem trocar o idioma atual).
static func in_lang(key: String, l: String) -> String:
	for loc in [l, "pt"]:
		var tr := TranslationServer.get_translation_object(loc)
		if tr != null and tr.get_locale().begins_with(loc):
			var s := String(tr.get_message(key))
			if s != "":
				return s
	return key


# ---------------------------------------------------------------------------
# Números

## Número com 1 casa decimal no formato do idioma (3,0 em PT; 3.0 em EN).
static func num(v: float, decimals := 1) -> String:
	var s := String.num(v, decimals)
	if decimals > 0 and not "." in s:
		s += "." + "0".repeat(decimals)
	return s.replace(".", ",") if lang() == "pt" else s


## Distância em px mostrada em metros: "10,0 m".
static func meters(px: float) -> String:
	return tf("FMT_METERS", [num(px / PX_PER_M)])


## Velocidade em px/s mostrada em m/s: "2,4 m/s".
static func mps(px_s: float) -> String:
	return tf("FMT_MPS", [num(px_s / PX_PER_M)])


# ---------------------------------------------------------------------------
# Atalhos dos dados do jogo

static func hero_name(hid: String) -> String:
	return t("HERO_%s_NAME" % hid.to_upper())


## Campo de texto do herói: "epithet", "bio", "quote" ou "name".
static func hero_text(hid: String, field: String, l := "") -> String:
	var key := "HERO_%s_%s" % [hid.to_upper(), field.to_upper()]
	return in_lang(key, l) if l != "" else t(key)


static func ab_name(id: String) -> String:
	return t("AB_%s_NAME" % id.to_upper())


static func ab_short(id: String) -> String:
	return t("AB_%s_SHORT" % id.to_upper())


static func ab_desc(id: String) -> String:
	return t("AB_%s_DESC" % id.to_upper())


## Função ("Tanque", "Dano", "Suporte" são os identificadores no código).
static func role_name(role: String) -> String:
	return t("ROLE_%s" % role.to_upper())


static func origin_name(origin: String) -> String:
	return t("ORIGIN_%s" % origin.to_upper())


static func effect_name(effect: String) -> String:
	return t("EFFECT_%s" % effect.to_upper())


static func behavior_name(b: String) -> String:
	return t("BEH_%s" % b.to_upper())


static func team_name(team: int) -> String:
	return t("TEAM_%d" % team)
