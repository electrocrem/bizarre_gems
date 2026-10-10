extends Node
## Localisation. The texts live in res://i18n/strings.csv (columns: keys, ru, en, tr); Godot
## imports it into translations, and any Label or Button whose text is a key from that file shows
## it in the player's language by itself. In code use L.t("key") or L.t("key", {"n": 5}) for
## texts with {placeholders}. Yandex Games tells us the player's language.

signal language_changed

const SUPPORTED := ["ru", "en", "tr"]

var lang := "ru"


func set_language(code: String) -> void:
	code = code.substr(0, 2).to_lower()
	# Yandex recommends Russian for CIS languages and English elsewhere.
	if code in ["be", "kk", "uk", "uz"]:
		code = "ru"
	lang = code if code in SUPPORTED else "en"
	TranslationServer.set_locale(lang)
	language_changed.emit()


func _ready() -> void:
	TranslationServer.set_locale(lang)


func t(key: String, args := {}) -> String:
	var s := String(tr(key))
	return s.format(args) if not args.is_empty() else s
