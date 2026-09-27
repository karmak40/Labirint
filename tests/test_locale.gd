extends "res://tests/lib/test_case.gd"
## Every language has every text, and nothing more.
##
## Every Russian string literal in scripts/ is a translation key (the testbed's
## debug panel is left out: it is a developer's tool). Each .po in locale/ must
## translate every one of them, keep the same %-placeholders in the same order,
## and carry no stale keys. Then: Lang found the languages, switching speaks
## them, the German book keeps nouns capitalised, and the source needs no book.

const SKIP := ["res://scripts/debug_panel.gd"]
const PLACEHOLDER := "%[-+0#]*[0-9]*(?:\\.[0-9]+)?[dsfxXcv%]"

func begin() -> void:
	var keys := {}
	for path in _scripts("res://scripts"):
		if not SKIP.has(path):
			for text in _literals(FileAccess.get_file_as_string(path)):
				if _russian(text):
					keys[text] = path
	check(keys.size() > 300, "the scripts' texts were found", keys.size())
	var lang := root.get_node("Lang")
	check(lang.codes.has("en") and lang.codes.has("de"), "English and German are loaded", lang.codes)
	var pattern := RegEx.create_from_string(PLACEHOLDER)
	for code: String in lang.codes:
		if code == lang.SOURCE:
			continue
		var book: Translation = lang._books[code]
		var missing := []
		var broken := []
		for key: String in keys:
			var said := String(book.get_message(key))
			if said == "":
				missing.append(key)
			elif _marks(pattern, key) != _marks(pattern, said):
				broken.append("%s -> %s" % [key, said])
		check(missing.is_empty(), "%s: every text is translated" % code, missing.slice(0, 12))
		check(broken.is_empty(), "%s: placeholders kept" % code, broken.slice(0, 12))
		var stale := []
		for key: String in book.get_message_list():
			if key != "" and not key.begins_with("@") and not keys.has(key):
				stale.append(key)
		check(stale.is_empty(), "%s: no stale texts" % code, stale.slice(0, 12))
		check(lang.name_of(code) != code, "%s has a name" % code, lang.name_of(code))

	# switching
	lang.use("en")
	check(TranslationServer.translate("Схватка") == "Skirmish", "English speaks", TranslationServer.translate("Схватка"))
	check(lang.lower("Копьё") == "копьё" and lang.lower(TranslationServer.translate("Копьё")) == "spear", "English lower-cases nouns")
	lang.use("de")
	check(TranslationServer.translate("Схватка") == "Gefecht", "German speaks", TranslationServer.translate("Схватка"))
	check(lang.lower(TranslationServer.translate("Копьё")) == "Speer", "German keeps nouns capitalised")
	lang.use("ru")
	check(TranslationServer.translate("Схватка") == "Схватка", "Russian is the source", TranslationServer.translate("Схватка"))
	lang.use("xx")
	check(lang.current() == "ru", "an unknown language falls back to Russian", lang.current())

func step() -> bool:
	return true

func _scripts(folder: String) -> Array:
	var found := []
	for file in DirAccess.get_files_at(folder):
		if file.get_extension() == "gd":
			found.append(folder.path_join(file))
	for sub in DirAccess.get_directories_at(folder):
		found.append_array(_scripts(folder.path_join(sub)))
	return found

## Every string literal in GDScript source, unescaped, comments skipped.
static func _literals(source: String) -> Array:
	var found := []
	var i := 0
	var n := source.length()
	while i < n:
		var c := source[i]
		if c == "#":
			while i < n and source[i] != "\n":
				i += 1
			continue
		if c == "\"" or c == "'":
			i += 1
			var text := ""
			while i < n and source[i] != c:
				if source[i] == "\\" and i + 1 < n:
					var e := source[i + 1]
					text += {"n": "\n", "t": "\t", "\"": "\"", "'": "'", "\\": "\\"}.get(e, "\\" + e)
					i += 2
					continue
				text += source[i]
				i += 1
			i += 1
			found.append(text)
			continue
		i += 1
	return found

static func _russian(text: String) -> bool:
	for ch in text:
		var code := ch.unicode_at(0)
		if (code >= 0x410 and code <= 0x44F) or code == 0x401 or code == 0x451:
			return true
	return false

static func _marks(pattern: RegEx, text: String) -> Array:
	var marks := []
	for found in pattern.search_all(text):
		marks.append(found.get_string())
	return marks
