class_name Unlocks
extends RefCounted
## "One more run": 18 relics and 2 keepsakes are not in the house yet. Each one moves in when an
## achievement (or a milestone) is earned, and the achievement says what it brings.
##
## Only relics added in 2.0 are locked, so nothing a 1.x save could already find goes away; an
## achievement earned before this table existed unlocks its item at once.
##
## The relic pool of a run is filtered once, in world._ready (Unlocks.pool), so every picker
## (treasure, shops, guardians, the Smoke Altar, hollows and the special rooms) respects it.
## Tonight's Candle and typed-in seeded runs use the FIXED pool (everything unlocked by default),
## so the same seed gives the same house to every player, whatever they have unlocked.

## item id -> where it comes from: {"ach": achievement id} or {"runs": candles lit}.
const TABLE := {
	"dust_bunny": {"ach": "first_snuff"},
	"clockwork_mouse": {"ach": "night_shift"},
	"sweep_brush": {"ach": "chimney_sweep"},
	"bell_rope": {"ach": "floor_belfry"},
	"nightshade": {"ach": "boss_crypt"},
	"glass_chimney": {"ach": "boss_untouched"},
	"cuckoo_clock": {"ach": "win_early"},
	"tinderbox": {"ach": "kindling_12"},
	"magpie_nest": {"ach": "mantel"},
	"dowsing_rod": {"ach": "hollow"},
	"both_ends": {"ach": "smoke_pact"},
	"stopped_clock": {"ach": "ks_hand_bell"},
	"pendulum": {"ach": "ks_winding_key"},
	"pale_taper": {"ach": "two_oclock"},
	"salt_line": {"ach": "seance"},
	"blowlamp": {"ach": "mini_boss"},
	"honeycomb": {"ach": "font_5"},
	"minute_hand": {"runs": 5},
	# keepsakes
	"hand_mirror": {"ach": "mirror_deal"},
	"music_box": {"ach": "music_box"},
}

## Test switch (autotest --unlockall): everything counts as unlocked.
static var force_all := false


static func is_locked_item(id: String) -> bool:
	return TABLE.has(id)


static func is_unlocked(id: String) -> bool:
	if force_all or not TABLE.has(id):
		return true
	var src: Dictionary = TABLE[id]
	if src.has("ach"):
		return Achievements.is_unlocked(str(src["ach"]))
	if src.has("runs"):
		return int(Game.records.get("runs", 0)) >= int(src["runs"])
	return true


## True when this run must use the default pool (Tonight's Candle, a typed-in seed).
static func fixed(w: Node) -> bool:
	return bool(w.get("daily")) or bool(w.get_meta("seeded", false))


static func _ok(w: Node, id: String) -> bool:
	return (not TABLE.has(id)) if fixed(w) else is_unlocked(id)


## The run's relic pool (world._ready). Shuffled later by the world, from the run seed.
static func pool(w: Node) -> Array:
	return Items.RELICS.keys().filter(func(id): return _ok(w, id))


## Keepsakes that may turn up in this run (treasure rooms, shops, the Study).
static func keepsakes(w: Node) -> Array:
	return Items.KEEPSAKES.keys().filter(func(id): return _ok(w, id))


static func pick_keepsake(w: Node) -> String:
	var ks := keepsakes(w)
	return ks[w.rng.randi() % ks.size()]


## The achievement record that unlocks `id` ({} for a milestone or an item that is never locked).
static func achievement_of(id: String) -> Dictionary:
	var a: String = TABLE.get(id, {}).get("ach", "")
	if a == "":
		return {}
	for e in Achievements.LIST:
		if e["id"] == a:
			return e
	return {}


## How to bring it into the house, in a few words: "Big Game: snuff a house champion".
static func goal_text(id: String) -> String:
	if not TABLE.has(id):
		return ""
	var src: Dictionary = TABLE[id]
	if src.has("runs"):
		var n := int(src["runs"])
		return "Light %d candles (%d so far)" % [n, mini(int(Game.records.get("runs", 0)), n)]
	var a := achievement_of(id)
	if a.is_empty():
		return ""
	if a.get("hidden", false) and not Achievements.is_unlocked(a["id"]):
		return "A secret of the house"
	var d: String = a["desc"]
	return "%s: %s" % [a["name"], d.substr(0, 1).to_lower() + d.substr(1)]


## The item an achievement brings into the house ("" if none).
static func reward_of(ach_id: String) -> String:
	for id in TABLE:
		if TABLE[id].get("ach", "") == ach_id:
			return id
	return ""


static func unlocked_items() -> Array:
	return TABLE.keys().filter(func(id): return is_unlocked(id))


## Items unlocked since they were last announced: marks them known (and new in the Journal).
## Called at the end of a run (results: NEW IN THE HOUSE) and when the title opens (anything
## unlocked by an old save or between runs gets its Journal dot).
static func take_new() -> Array:
	var known: Array = Game.records.get("unlocks_known", [])
	var out: Array = []
	if force_all:
		return out
	for id in unlocked_items():
		if not id in known:
			known.append(id)
			out.append(id)
			Records.mark_new("r:" + id)
	Game.records["unlocks_known"] = known
	return out
