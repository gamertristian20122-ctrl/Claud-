extends Node
## Strings (autoload "L"; ROADMAP_V2 4a, the groundwork for the v2.6 translations).
##
## The English source text is the key (gettext style), so code stays readable:
##     UI.label(L.t("Light the wick"))
##     L.t("{name} is ready", {"name": L.t("Skip")})
## `lang/<code>.json` holds one flat object {"key": "text"}; `{name}` placeholders are filled by t().
## Every table found is registered with Godot's TranslationServer, so tr() and auto-translated Labels
## follow the same files. `lang/en.json` is written by `python3 tools/extract_strings.py` from every
## L.t("...") in the scripts and the data tables (candles, moves, achievements, relics); English needs
## no file to work (a missing key is its own text).
##
## Until the Language row arrives (step 4b) the game stays in English; `--lang=xx` tries a table.

const DIR := "res://lang/"
const SOURCE := "en"

var code := SOURCE
var _tables := {}   # code -> {key: text}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for c in available():
		_register(c)
	var want := SOURCE
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			want = a.get_slice("=", 1)
	set_language(want)


## The translated text for an English source string, with {placeholders} filled in.
func t(key: String, args := {}) -> String:
	var s := key
	var tab: Dictionary = _tables.get(code, {})
	if tab.has(key) and str(tab[key]) != "":
		s = str(tab[key])
	return s.format(args) if not args.is_empty() else s


## The language codes with a table in lang/ (always includes the source language).
func available() -> Array[String]:
	var out: Array[String] = [SOURCE]
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".json"):
			var c := f.get_basename()
			if not c in out:
				out.append(c)
	return out


func set_language(c: String) -> void:
	if not _tables.has(c) and c != SOURCE:
		c = SOURCE
	code = c
	TranslationServer.set_locale(c)


func _register(c: String) -> void:
	var path := DIR + c + ".json"
	if not FileAccess.file_exists(path):
		_tables[c] = {}
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_warning("lang: %s is not a flat JSON object" % path)
		_tables[c] = {}
		return
	var tab := {}
	var tr_res := Translation.new()
	tr_res.locale = c
	for k in (parsed as Dictionary):
		if str(k).begins_with("@"):   # "@meta": notes for translators, not text
			continue
		tab[str(k)] = str(parsed[k])
		tr_res.add_message(str(k), str(parsed[k]))
	_tables[c] = tab
	TranslationServer.add_translation(tr_res)
