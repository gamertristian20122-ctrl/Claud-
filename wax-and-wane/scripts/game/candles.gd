class_name Candles
extends RefCounted
## The Candle Box: playable candles, each with its own clock rules. Unlocked by goals.

const ORDER := ["tallow", "tea_light", "party", "pillar", "black_taper", "moonwick"]

const LIST := {
	"tallow": {
		"name": "Tallow", "line": "The last candle in the cellar.",
		"wax": 120.0, "drain": 1.0, "speed": 1.0, "damage": 1.0, "fire_delay": 1.0, "shots": 1,
		"body_w": 10, "colours": ["#fdf7ed", "#f3e6cf", "#d3bfa9", "#aa8d7a"],
		"unlock_text": "",
	},
	"tea_light": {
		"name": "Tea Light", "line": "Lit at 12:40 AM. Small, quick and quick-firing.",
		"wax": 80.0, "drain": 0.8, "speed": 1.15, "damage": 1.0, "fire_delay": 0.8, "shots": 1,
		"body_w": 12, "colours": ["#fdf7ed", "#f3e6cf", "#d3bfa9", "#aa8d7a"], "foil": true,
		"unlock_text": "Reach the Crypt",
	},
	"party": {
		"name": "Party Candle", "line": "Two flames, thin wax. Starts with a Flare Match.",
		"wax": 100.0, "drain": 1.1, "speed": 1.05, "damage": 0.8, "fire_delay": 1.0, "shots": 2,
		"body_w": 8, "colours": ["#fdf7ed", "#fdf7ed", "#f78697", "#dc4a7b"], "stripes": true,
		"start_keepsake": "flare_match",
		"unlock_text": "Reach a x8 Kindling streak",
	},
	"pillar": {
		"name": "Altar Pillar", "line": "Lit at 11:45 PM. Slow, sturdy, hits hard.",
		"wax": 135.0, "drain": 1.15, "speed": 0.85, "damage": 1.15, "fire_delay": 1.0, "shots": 1,
		"body_w": 14, "colours": ["#fdf7ed", "#f3e6cf", "#d3bfa9", "#aa8d7a"],
		"start_relic": "wax_coat",
		"unlock_text": "Snuff the Hollow Warden (floor 3)",
	},
	"black_taper": {
		"name": "Black Taper", "line": "Hard mode. Lit at 12:20 AM. Melts fast; every boss offers a Smoke Altar.",
		"wax": 100.0, "drain": 1.4, "speed": 1.0, "damage": 1.0, "fire_delay": 1.0, "shots": 1, "hit": 1.3,
		"body_w": 8, "colours": ["#775c55", "#483b3a", "#333333", "#2a2a3a"],
		"unlock_text": "Win a run",
	},
	# the Clock Tower's reward (scripts/game/tower.gd): a pale candle in a silver dish, lit by the moon
	"moonwick": {
		"name": "Moonwick", "line": "Lit by the moon. Quick and thin; its sparks pass through.",
		"wax": 108.0, "drain": 1.0, "speed": 1.08, "damage": 1.0, "fire_delay": 1.0, "shots": 1,
		"body_w": 10, "colours": ["#fdf7ed", "#cae6f5", "#b6cbcf", "#7b8994"],
		"pierce": 1, "holder": "tower/holder_silver", "moon": true,
		"unlock_text": "Be done by one, then climb",
	},
}


static func is_unlocked(id: String) -> bool:
	return id == "tallow" or id in Game.records.get("unlocked", [])


static func def_of(id: String) -> Dictionary:
	return LIST.get(id, LIST["tallow"])
