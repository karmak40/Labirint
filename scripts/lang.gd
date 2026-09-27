extends Node
## The languages the game speaks, and which one it speaks now (autoload "Lang").
##
## Russian is the source language: every text in scripts/ is written in Russian
## and is its own translation key, so with Russian chosen nothing is looked up.
## Every other language is one gettext file, res://locale/<code>.po, found and
## loaded here at start; adding a language is adding a file (locale/README.md).
## Controls translate their own text; code that builds a text calls tr() on
## each Russian literal, and data tables (names, descriptions) are translated
## where they are shown.
##
## The choice is kept in user://settings.cfg. LABIRINT_LANG=<code> overrides it
## for one run; tests force Russian, whatever the player picked.

const SOURCE := "ru"
const SOURCE_NAME := "Русский"
const FOLDER := "res://locale"
const SETTINGS := "user://settings.cfg"
## A message every .po carries: the language's name in itself.
const NAME_KEY := "@language"
## A message a .po sets to "no" when its nouns keep their capital letter inside
## a sentence (German), so the text is not lower-cased for "waits: spear".
const LOWER_KEY := "@lowercase"

## Codes of every language there is, the source first.
var codes: Array[String] = [SOURCE]
var _books := {}               ## code -> Translation

## In _init, not _ready: a SceneTree script (a test) gets its _initialize
## before the autoloads are ready, and must be able to overrule the choice.
func _init() -> void:
	_load_books()
	var wanted := OS.get_environment("LABIRINT_LANG")
	if wanted == "":
		var settings := ConfigFile.new()
		if settings.load(SETTINGS) == OK:
			wanted = str(settings.get_value("game", "language", ""))
	if wanted == "":
		wanted = _from_system()
	use(wanted if codes.has(wanted) else SOURCE)

## Every <code>.po in the folder, as a translation.
func _load_books() -> void:
	var files := Array(DirAccess.get_files_at(FOLDER))
	files.sort()
	for file: String in files:
		# an exported game lists "de.po.remap" or the like; the resource path is the same
		var path := FOLDER.path_join(file.trim_suffix(".remap").trim_suffix(".import"))
		if path.get_extension() != "po" or _books.values().any(func(b: Translation) -> bool: return b.resource_path == path):
			continue
		var book := load(path) as Translation
		if book == null:
			push_warning("Lang: could not read %s" % path)
			continue
		var code := book.locale if book.locale != "" else path.get_file().get_basename()
		if code == SOURCE or _books.has(code):
			continue
		book.locale = code
		TranslationServer.add_translation(book)
		_books[code] = book
		codes.append(code)

## The player's system language if there is a book for it; English otherwise,
## if there is English; else the source.
func _from_system() -> String:
	var system := OS.get_locale_language()
	if codes.has(system):
		return system
	return "en" if codes.has("en") else SOURCE

## The code of the language spoken now.
func current() -> String:
	var spoken := TranslationServer.get_locale()
	for code in codes:
		if spoken == code or spoken.begins_with(code + "_"):
			return code
	return SOURCE

## Speaks `code` from now on (controls update themselves; a screen built in
## code must be rebuilt).
func use(code: String) -> void:
	TranslationServer.set_locale(code if codes.has(code) else SOURCE)

## Speaks `code` and remembers it for the next start.
func choose(code: String) -> void:
	use(code)
	var settings := ConfigFile.new()
	settings.load(SETTINGS)
	settings.set_value("game", "language", current())
	settings.save(SETTINGS)

## A language's name in itself: "Deutsch", "English".
func name_of(code: String) -> String:
	if code == SOURCE:
		return SOURCE_NAME
	var book: Translation = _books.get(code)
	var named := String(book.get_message(NAME_KEY)) if book != null else ""
	return named if named != "" else TranslationServer.get_locale_name(code)

## `text` lower-cased to stand inside a sentence, unless the language spoken
## keeps its nouns capitalised.
func lower(text: String) -> String:
	var book: Translation = _books.get(current())
	if book != null and String(book.get_message(LOWER_KEY)) == "no":
		return text
	return text.to_lower()
