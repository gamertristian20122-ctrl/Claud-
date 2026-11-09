class_name Share
extends RefCounted
## The results screen's Share button: a short, spoiler-free summary of a run to paste anywhere,
## like a daily-puzzle share. No relic, lodger or guardian names; just how far the candle got.
##
##   Wax & Wane - Tonight's Candle 2026-11-08
##   Tallow at level 2: done by 1:41 AM
##   🔥🔥🔥🔥  7 relics, Kindling x14
##
## A seeded or ordinary run names its seed and the night's length ("seed 4821 7730, 7 floors"), so a friend can
## light the same house (Tonight's Candle is always 4 floors).
## One glyph per floor of the night: 🔥 floor cleared, 🔔 snuffed by its guardian, 💨 snuffed in its
## halls, ⌛ the clock ran out there, ⬛ not reached. One more glyph appears only if the run got above the bells.
## Every glyph is a single code point with emoji presentation (no variation selectors), so the text
## stays short on every platform. DesignCheck.share_check() tests the length and that it is stable.

const CLEARED := "🔥"
const GUARDIAN := "🔔"
const HALLS := "💨"
const CLOCK := "⌛"
const UNREACHED := "⬛"


## The text for a run's results params (world._end_run / Records.end_run). Pure: the same params
## always give the same text (the date of Tonight's Candle comes from params["date"]).
static func text(p: Dictionary) -> String:
	var won: bool = p.get("won", false)
	var f := maxi(1, int(p.get("floor", 1)))
	var house := Records.night_of(p)   # the night's length (4 before 2.2)
	var head := "Wax & Wane - "
	if p.get("daily", false):
		head += "Tonight's Candle %s" % str(p.get("date", ""))
	else:
		head += "seed %s, %d floors" % [Records.seed_text(int(p.get("seed", 0))), house]
	# the candle and the run's difficulty level ("Tallow at level 3"; Tonight's Candle is always 2)
	var candle := "%s at level %d" % [str(Candles.def_of(str(p.get("candle", "tallow")))["name"]), int(p.get("level", 2))]
	var how := ""
	if won:
		how = "%s: done by %s" % [candle, Game.clock_text(float(p.get("clock", Game.night_minutes(house))))]
		if f > house:
			how += ", above the bells"   # the secret floor: never "Floor 5" of a four-floor house
	elif f > house:
		how = "%s: snuffed above the bells" % candle
	else:
		how = "%s: snuffed at Floor %d" % [candle, f]
	var glyphs := ""
	for n in range(1, maxi(house, f) + 1):
		if n == house + 1:
			glyphs += " "   # past the house: set apart, unnamed
		glyphs += _glyph(n, f, won, str(p.get("killer", "")), bool(p.get("boss_death", false)))
	var relics: int = (p.get("relics", []) as Array).size()
	var tail := "%d relic%s, Kindling x%d" % [relics, "" if relics == 1 else "s", int(p.get("streak", 0))]
	return "%s\n%s\n%s  %s" % [head, how, glyphs, tail]


static func _glyph(n: int, f: int, won: bool, killer: String, boss_death: bool) -> String:
	if n < f or (n == f and won):
		return CLEARED
	if n > f:
		return UNREACHED
	if killer == "clock":
		return CLOCK
	if boss_death or (killer.begins_with("e:") and bool(Enemy.DEFS.get(killer.substr(2), {}).get("boss", false))):
		return GUARDIAN
	return HALLS


## Length as X counts it (most symbols and every emoji count twice); the share must fit in 280.
static func x_length(s: String) -> int:
	var n := 0
	for i in s.length():
		var c := s.unicode_at(i)
		var light := c <= 4351 or (c >= 8192 and c <= 8205) or (c >= 8208 and c <= 8223) or (c >= 8242 and c <= 8247)
		n += 1 if light else 2
	return n


## Copy to the clipboard (Android, desktop and the web all have one) and say so.
static func copy(p: Dictionary) -> String:
	var t := text(p)
	DisplayServer.clipboard_set(t)
	return t
