class_name Areas
extends RefCounted
## The areas of the house (v2.2 "The Long Night", docs/design/LONG_NIGHT.md). A night of N floors is built as
## [Cellar, Crypt] + middle + [Belfry]; the middle fills in a fixed order, the Chapel always the floor just before
## the upper areas. Each area: id, name, theme (rooms/room_<theme>*.png + RoomDecor / AreaGimmicks dressing), the
## night colour (CanvasModulate), its music slot, its reverb (Audio.set_space preset), who lives there (pool, the
## same e / h / f slots as world.POOLS), two guardians (bosses[0] its own, bosses[1] an older one that fits), its
## gimmick (scripts/game/area_gimmicks.gd) and the room-layout tags it likes (RoomTemplates tags, like FLOOR_LIKES).
##
## The five floors of the 2.0 house are described here as read-only copies of world.gd FLOORS / POOLS and
## room_templates.gd FLOOR_LIKES (world.gd still builds them from its own tables until the night stream wires
## Areas in). Batch 2 (conservatory, ballroom, gallery) is listed in the order but not built yet: `built` is false
## and max_floors() stops the night before them.
##
## Hooks for the night stream (docs/streams/v22_areas.md): world.gd builds floor n of an N-floor night from
## `Areas.sequence(N)[n - 1]` through `world.fdef(n)` / `world.fpool(n)` (today they read `world.floor_areas`,
## which only `--area=<id>` fills), `Audio.set_space(Areas.def(id)["space"])`, and RoomTemplates' likes from
## `Areas.def(id)["likes"]`.

const LIST := {
	# ---- the house as it was (2.0): copies of world.FLOORS / POOLS and RoomTemplates.FLOOR_LIKES
	"cellar": {"name": "The Cellar", "theme": "cellar", "dark": Color(0.32, 0.26, 0.27), "music": "floor_1", "space": 1,
		"bosses": ["big_zombie", "wax_mother"], "gimmick": "", "built": true,
		"pool": {"e": ["tiny_zombie", "goblin", "tiny_slug", "cinder_rat", "wax_blob", "tiny_zombie", "goblin"],
			"h": ["muddy", "slug", "skelet", "wax_blob", "zombie"], "f": ["imp", "moth"]},
		"likes": {"webs": 2.0, "furniture": 1.6, "oil": 1.6, "fire": 1.2, "pits": 0.6, "bones": 0.5, "hard": 0.4}},
	"crypt": {"name": "The Crypt", "theme": "crypt", "dark": Color(0.25, 0.27, 0.34), "music": "floor_2", "space": 2,
		"bosses": ["ogre", "sexton"], "gimmick": "", "built": true,
		"pool": {"e": ["goblin", "skelet", "swampy", "cinder_rat", "sootling", "tiny_zombie", "wax_blob"],
			"h": ["pumpkin_dude", "doc", "grave_hand", "snuffer", "zombie", "muddy"], "f": ["imp", "moth", "wisp"]},
		"likes": {"pits": 2.0, "bones": 2.6, "furniture": 1.3, "webs": 1.4, "oil": 0.7}},
	"chapel": {"name": "The Chapel", "theme": "chapel", "dark": Color(0.28, 0.24, 0.34), "music": "floor_3", "space": 3,
		"bosses": ["necro_boss", "choir"], "gimmick": "", "built": true,
		"pool": {"e": ["skelet", "chort", "wogol", "sootling", "wisp", "swampy"],
			"h": ["orc_shaman", "necromancer", "psalter", "waxwork", "masked_orc", "grave_hand"], "f": ["angel", "moth", "psalter", "wisp"]},
		"likes": {"furniture": 2.2, "fire": 1.8, "cover": 1.3, "bones": 0.7, "webs": 0.6}},
	"belfry": {"name": "The Belfry", "theme": "belfry", "dark": Color(0.33, 0.23, 0.22), "music": "floor_4", "space": 4,
		"bosses": ["pendulum", "big_demon"], "gimmick": "", "built": true,
		"pool": {"e": ["chort", "wogol", "ice_zombie", "deathwatch", "cinder_rat", "skelet", "sootling"],
			"h": ["gutterspout", "orc_warrior", "snuffer", "waxwork", "necromancer", "doc"], "f": ["clapper_bat", "imp", "angel", "clapper_bat"]},
		"likes": {"spikes": 1.8, "pits": 1.5, "hard": 1.6, "fire": 1.3, "choke": 1.4, "webs": 1.2}},
	"tower": {"name": "The Clock Tower", "theme": "tower", "dark": Color(0.27, 0.29, 0.40), "music": "floor_5", "space": 4,
		"bosses": ["keeper"], "gimmick": "", "built": true, "secret": true,
		"pool": {"e": ["cog_sentry", "deathwatch", "chort", "wogol", "cog_sentry", "sootling", "skelet"],
			"h": ["gutterspout", "orc_warrior", "waxwork", "snuffer", "cog_sentry", "necromancer"], "f": ["minute_wraith", "minute_wraith", "clapper_bat", "angel"]},
		"likes": {"hard": 1.8, "open": 1.4, "cover": 1.5, "pits": 1.4, "furniture": 1.2, "webs": 0.3, "oil": 0.5, "bones": 0.4}},
	# ---- batch 1 (v2.2)
	"kitchen": {"name": "The Kitchen", "theme": "kitchen", "dark": Color(0.34, 0.25, 0.21), "music": "area_kitchen", "space": 1,
		"bosses": ["stockpot", "wax_mother"], "gimmick": "stoves", "built": true,
		"blurb": "Copper pots, a black range, flour on the flags. Stove tops glow on and off; shoot a boiling pot to spill it",
		"pool": {"e": ["lid_crab", "goblin", "cinder_rat", "lid_crab", "swampy", "sootling", "chort"],
			"h": ["ice_zombie", "chort", "slug", "masked_orc", "lid_crab", "doc"], "f": ["flour_ghost", "imp", "moth", "flour_ghost"]},
		"likes": {"fire": 1.8, "oil": 1.6, "furniture": 1.8, "cover": 1.2, "webs": 0.5, "bones": 0.3, "pits": 0.6}},
	"library": {"name": "The Library", "theme": "library", "dark": Color(0.23, 0.27, 0.26), "music": "area_library", "space": 1,
		"bosses": ["librarian", "necro_boss"], "gimmick": "shelves", "built": true,
		"blurb": "Tall shelves, reading lamps, drifting pages. Bookcases slide on their rails; one shelf may hide a door",
		"pool": {"e": ["bookworm", "inkblot", "deathwatch", "wogol", "bookworm", "cinder_rat"],
			"h": ["orc_shaman", "inkblot", "psalter", "necromancer", "waxwork", "snuffer"], "f": ["psalter", "moth", "angel", "psalter"]},
		"likes": {"furniture": 2.4, "cover": 1.8, "choke": 1.2, "open": 0.8, "fire": 0.6, "webs": 0.8, "bones": 0.3}},
	"attic": {"name": "The Attic", "theme": "attic", "dark": Color(0.19, 0.20, 0.28), "music": "area_attic", "space": 4,
		"bosses": ["dress_form", "ogre"], "gimmick": "dark", "built": true,
		"blurb": "Rafters, trunks and dust sheets under a round moonlit window. Your light is smaller up here: shoot the lanterns",
		"pool": {"e": ["mannequin", "wogol", "deathwatch", "trunk", "mannequin", "sootling", "cinder_rat"],
			"h": ["waxwork", "trunk", "snuffer", "gutterspout", "mannequin", "necromancer"], "f": ["clapper_bat", "moth", "moth", "wisp"]},
		"likes": {"furniture": 2.0, "webs": 2.2, "cover": 1.4, "hard": 1.2, "pits": 0.8, "oil": 0.6}},
	# ---- batch 2 (not built yet: the night stops before them)
	"conservatory": {"name": "The Conservatory", "built": false},
	"ballroom": {"name": "The Ballroom", "built": false},
	"gallery": {"name": "The Gallery", "built": false},
}

const MIN_FLOORS := 4
const MAX_FLOORS := 10
## The middle of the house, in the order it fills: [area, the night length it first appears in].
const BEFORE_CHAPEL := [["kitchen", 5], ["library", 6], ["ballroom", 9], ["gallery", 10]]
const AFTER_CHAPEL := [["conservatory", 8], ["attic", 7]]
## The new areas (batch 1) and the place `--area=<id>` puts them for a test run: the Chapel's floor of today's
## 4-floor night, so the per-floor tables (health, contact damage, melt) match a Chapel run of the same kit.
const NEW := ["kitchen", "library", "attic"]
const TEST_DEPTH := 3
## A test run's kit (--area): what a run arriving on floor 3 typically holds.
const TEST_KIT := ["sharp_wick", "bellows", "beeswax", "lamp_oil", "thimble"]


static func def(id: String) -> Dictionary:
	return LIST.get(id, {})


static func is_built(id: String) -> bool:
	return bool(def(id).get("built", false))


## The ordered area ids of a night of `n` floors (clamped to MIN_FLOORS .. max_floors()).
static func sequence(n: int) -> Array:
	n = clampi(n, MIN_FLOORS, max_floors())
	var before: Array = []
	for p in BEFORE_CHAPEL:
		if n >= int(p[1]):
			before.append(p[0])
	var after: Array = []
	for p in AFTER_CHAPEL:
		if n >= int(p[1]):
			after.append(p[0])
	return ["cellar", "crypt"] + before + ["chapel"] + after + ["belfry"]


## The longest night whose areas are all built (7 with batch 1).
static func max_floors() -> int:
	var best := MIN_FLOORS
	for n in range(MIN_FLOORS, MAX_FLOORS + 1):
		var ok := true
		for id in _raw_sequence(n):
			if not is_built(id):
				ok = false
		if ok:
			best = n
		else:
			break
	return best


static func _raw_sequence(n: int) -> Array:
	var before: Array = []
	for p in BEFORE_CHAPEL:
		if n >= int(p[1]):
			before.append(p[0])
	var after: Array = []
	for p in AFTER_CHAPEL:
		if n >= int(p[1]):
			after.append(p[0])
	return ["cellar", "crypt"] + before + ["chapel"] + after + ["belfry"]


## Where an area sits in a night of `n` floors (1-based; 0 if it is not in that night).
static func depth_in(id: String, n: int) -> int:
	return sequence(n).find(id) + 1


## A floor entry shaped like world.FLOORS[n] (name, theme, dark, music, boss, bosses) for area `id`.
static func floor_def(id: String) -> Dictionary:
	var d := def(id)
	var bosses: Array = d.get("bosses", ["big_zombie"])
	return {"name": d.get("name", "The House"), "theme": d.get("theme", "cellar"), "dark": d.get("dark", Color(0.3, 0.26, 0.28)),
		"music": d.get("music", "floor_1"), "boss": bosses[0], "bosses": bosses, "space": int(d.get("space", 1)), "area": id}


## Who lives in area `id` (the e / h / f slots of world.POOLS).
static func pool(id: String) -> Dictionary:
	return def(id).get("pool", LIST["cellar"]["pool"])


## The area that owns a room theme ("" if none).
static func of_theme(theme: String) -> String:
	for id in LIST.keys():
		if str(LIST[id].get("theme", "")) == theme:
			return id
	return ""


# ---------------------------------------------------------------- test runs (--area=<id>)

## `--area=<id>` (autotest): put the area on floor TEST_DEPTH (or `--areadepth=N`, 1-4) of this run, hand
## Tallow a floor-3 kit and start that floor with the area's own guardian (`second` = its older one).
## A Chapel run of the same kit: `--area=chapel`.
static func test_start(w: Node, id: String, depth := TEST_DEPTH, second := false) -> void:
	if w == null or w.get("player") == null or not LIST.has(id) or not is_built(id):
		push_warning("[area] unknown or unbuilt area %s" % id)
		return
	depth = clampi(depth, 1, 4)
	w.floor_areas[depth] = id
	for rid in TEST_KIT:
		if Items.RELICS.has(rid) and not rid in w.player.relics:
			Items.apply(rid, w.player, w)
	w.player.damage += 0.15 * float(depth - 1)   # the guardians below: "your flame grows"
	w.player.wax = 96.0
	w.player.bombs = 2
	w.player.coins = 10
	w._start_floor(depth)
	var bosses: Array = def(id).get("bosses", [])
	if not bosses.is_empty():
		w.boss_kind = bosses[mini(1 if second else 0, bosses.size() - 1)]
	print("[area] test start: %s on floor %d, %s, relics %s, guardian %s" % [id, depth, Game.clock_text(w.clock_minutes()),
		w.player.relics, w.boss_kind])
