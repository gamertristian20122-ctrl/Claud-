class_name Candles
extends RefCounted
## The Candle Box: playable candles, each with its own clock rules. Unlocked by goals. Candles are
## sidegrades: how hard a night is belongs to the save slot's difficulty level (world.LEVELS).
## Stats: `wax`, `drain`, `speed`, `damage`, `fire_delay`, `shots`, `hit` (damage taken), `pierce`,
## `light` (the light's size), `dark_hit` (damage to foes beyond the light, dark_mult).
## Look: `body_w` = wax width at the eyes (odd; Tallow 13), `colours` = [highlight, wax, shade, deep],
## `cheek` = the blush, `ink` = eyes and mouth, `straight` = no gumdrop belly (pillar), `foil` = a tea
## light cup, `stripes`.

const ORDER := ["tallow", "tea_light", "party", "pillar", "black_taper", "moonwick"]

const LIST := {
	"tallow": {
		"name": "Tallow", "line": "The last candle in the cellar.",
		"wax": 120.0, "drain": 1.0, "speed": 1.0, "damage": 1.0, "fire_delay": 1.0, "shots": 1,
		"body_w": 13, "colours": ["#fdf7ed", "#fdf7ed", "#e2b694", "#c38d70"], "cheek": "#f78697",
		"blurb": "Stubby, brave, a little teary. Cries wax when he is scared and keeps going anyway.",
		"unlock_text": "",
	},
	"tea_light": {
		"name": "Tea Light", "line": "Lit at 12:40 AM. Small, quick and quick-firing.",
		"wax": 80.0, "drain": 0.8, "speed": 1.15, "damage": 1.0, "fire_delay": 0.8, "shots": 1,
		"body_w": 15, "colours": ["#fdf7ed", "#f3e6cf", "#d3bfa9", "#aa8d7a"], "foil": true, "cheek": "#f78697",
		"unlock_text": "Reach the Crypt",
	},
	"party": {
		"name": "Party Candle", "line": "Two flames, thin wax. Starts with a Flare Match.",
		"wax": 100.0, "drain": 1.1, "speed": 1.05, "damage": 0.8, "fire_delay": 1.0, "shots": 2,
		"body_w": 11, "colours": ["#fdf7ed", "#fdf7ed", "#f78697", "#dc4a7b"], "stripes": true, "cheek": "#dc4a7b",
		"start_keepsake": "flare_match",
		"unlock_text": "Reach a x8 Kindling streak",
	},
	"pillar": {
		"name": "Altar Pillar", "line": "Starts with 15 spare minutes. Slow, sturdy, hits hard.",
		"wax": 135.0, "drain": 1.15, "speed": 0.85, "damage": 1.15, "fire_delay": 1.0, "shots": 1,
		"body_w": 17, "colours": ["#fdf7ed", "#f3e6cf", "#d3bfa9", "#aa8d7a"], "straight": true, "cheek": "#f78697",
		"start_relic": "wax_coat",
		"unlock_text": "Snuff the Chapel's guardian (floor 3)",
	},
	# a sidegrade, not a hard mode (difficulty is the save slot's level now): Tallow's wax and melt,
	# a short light, and foes out in the dark take more damage (dark_mult)
	"black_taper": {
		"name": "Black Taper", "line": "A short, dark light. Foes out in the dark take 50% more damage.",
		"wax": 120.0, "drain": 1.0, "speed": 1.0, "damage": 1.0, "fire_delay": 1.0, "shots": 1,
		"light": 0.75, "dark_hit": 1.5,
		"body_w": 11, "colours": ["#775c55", "#483b3a", "#333333", "#2a2a3a"], "cheek": "#9f294e", "ink": "#d3bfa9",
		"blurb": "Burns black and quiet. It cannot see far, so it makes every spark in the dark count.",
		"unlock_text": "Win a run",
	},
	# the Clock Tower's reward (scripts/game/tower.gd): a pale candle in a silver dish, lit by the moon
	"moonwick": {
		"name": "Moonwick", "line": "Lit by the moon. Quick and thin; its sparks pass through.",
		"wax": 108.0, "drain": 1.0, "speed": 1.08, "damage": 1.0, "fire_delay": 1.0, "shots": 1,
		"body_w": 13, "colours": ["#fdf7ed", "#cae6f5", "#b6cbcf", "#7b8994"], "cheek": "#f78697",
		"pierce": 1, "holder": "tower/holder_silver", "moon": true,
		"unlock_text": "Be done by one, then climb",
	},
}


## Where a candle's light ends, per unit of its texture_scale: the soft light falls to a quarter at
## 88 of its 128 px. Scaled by the light itself, so the edge shrinks as the wax melts.
const LIGHT_EDGE := 88.0


static func is_unlocked(id: String) -> bool:
	return id == "tallow" or id in Game.records.get("unlocked", [])


## The edge of the player's own light, in px from Tallow (Black Taper's "the dark" starts here).
static func light_reach(p: Node) -> float:
	var l: Variant = p.get("light")
	return LIGHT_EDGE * float((l as PointLight2D).texture_scale) if l != null and is_instance_valid(l) else 999.0


## A candle's "dark_hit" (the Black Taper's 1.5) for a foe beyond the edge of its light, else 1.0.
## Enemy.take_hit multiplies every blow by it (sparks, bombs, helpers alike).
static func dark_mult(w: Node, e: Node2D) -> float:
	var p: Variant = w.get("player") if w else null
	if p == null or not is_instance_valid(p):
		return 1.0
	var k := float(def_of(str(p.candle_id)).get("dark_hit", 1.0))
	if k == 1.0:
		return 1.0
	var dark: bool = e.global_position.distance_to((p as Node2D).global_position) > light_reach(p)
	blows += 1
	dark_blows += 1 if dark else 0
	return k if dark else 1.0


## Bot diagnostics (autotest prints them per run): blows landed by a dark_hit candle, and how many
## of them were out in the dark.
static var blows := 0
static var dark_blows := 0


static func def_of(id: String) -> Dictionary:
	return LIST.get(id, LIST["tallow"])
