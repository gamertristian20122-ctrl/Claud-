class_name Items
extends RefCounted
## Relics (one of each per run) and tonics (stackable small stat boosts).

const RELICS := {
	"beeswax": {"name": "Beeswax", "desc": "More wax to burn"},
	"twin_wick": {"name": "Twin Wick", "desc": "Two flames at once"},
	"blue_flame": {"name": "Blue Flame", "desc": "Hotter. Much hotter"},
	"bellows": {"name": "Bellows", "desc": "Fire faster"},
	"lamp_oil": {"name": "Lamp Oil", "desc": "Shots fly further and faster"},
	"soft_soles": {"name": "Soft Soles", "desc": "Move faster"},
	"wax_coat": {"name": "Wax Coat", "desc": "Shrug off the first hit in each room"},
	"ember_heart": {"name": "Ember Heart", "desc": "Shots set foes alight"},
	"sharp_wick": {"name": "Sharp Wick", "desc": "Shots pierce"},
	"moth_friend": {"name": "Moth Friend", "desc": "A moth circles you and blocks shots"},
	"slow_burn": {"name": "Slow Burn", "desc": "You melt a third slower"},
	"matchbook": {"name": "Matchbook", "desc": "+3 bombs, bigger blasts"},
	"hourglass": {"name": "Hourglass", "desc": "Clearing a room buys back time"},
	"candelabra": {"name": "Candelabra", "desc": "Three flames, a little weaker"},
	"hot_drip": {"name": "Hot Drip", "desc": "You leave burning wax behind"},
	"phoenix_feather": {"name": "Phoenix Feather", "desc": "Rekindle once when snuffed"},
	"lucky_ash": {"name": "Lucky Ash", "desc": "More drops, more coins"},
	"will_o_wisp": {"name": "Will-o'-Wisp", "desc": "Shots seek the nearest foe"},
	"witching_hour": {"name": "Witching Hour", "desc": "Burn brighter when nearly out"},
	"pocket_watch": {"name": "Pocket Watch", "desc": "The house moves slower"},
	"iron_stick": {"name": "Iron Candlestick", "desc": "Bigger shots, heavy knockback"},
	"snuffer_cap": {"name": "Snuffer Cap", "desc": "Enemy hits melt less wax"},
	"tallow_heart": {"name": "Tallow Heart", "desc": "Refill your wax"},
	"spare_wick": {"name": "Spare Wick", "desc": "More damage"},
}

## Hold 3 relics of the same Rite and Tallow changes.
const RITES := {
	"hearth": {"name": "Rite of the Hearth", "desc": "Every shot burns; burning foes burst into embers",
		"members": ["blue_flame", "ember_heart", "hot_drip", "bellows", "matchbook"]},
	"clock": {"name": "Rite of the Clock", "desc": "Rooms freeze as you enter; bells give you time",
		"members": ["hourglass", "pocket_watch", "slow_burn", "witching_hour", "phoenix_feather"]},
	"moth": {"name": "Rite of the Moth", "desc": "A second moth joins you; moths spit fire",
		"members": ["moth_friend", "will_o_wisp", "lamp_oil", "soft_soles", "lucky_ash"]},
	"wick": {"name": "Rite of Many Wicks", "desc": "An extra flame and piercing shots",
		"members": ["twin_wick", "candelabra", "sharp_wick", "spare_wick", "iron_stick"]},
}

## One held item with charge pips, refilled by clearing rooms.
const KEEPSAKES := {
	"hand_bell": {"name": "Hand Bell", "desc": "Ring it: the house freezes for 3 s", "pips": 3},
	"flare_match": {"name": "Flare Match", "desc": "A ring of 16 burning embers", "pips": 2},
	"winding_key": {"name": "Winding Key", "desc": "Turn the clock back 10 minutes", "pips": 6},
	"smoke_jar": {"name": "Smoke Jar", "desc": "3 s untouchable in a cloud of smoke", "pips": 3},
}


static func use_keepsake(id: String, p: Player, world: Node) -> void:
	match id:
		"hand_bell":
			world.freeze_t = 3.0
			Audio.play("bell_toll", 0.0, 0.0, 1.3)
			world.fx_ring(p.global_position + Vector2(0, -10), UI.GOLD)
			world.fx_text(p.global_position + Vector2(0, -34), "THE HOUSE HOLDS ITS BREATH", UI.GOLD)
		"flare_match":
			for k in 16:
				world.shoot_player(p.global_position + Vector2(0, -6), Vector2.from_angle(TAU * k / 16.0), p, p.damage * 2.0)
			for s in world.enemy_shots:
				if is_instance_valid(s) and s.global_position.distance_to(p.global_position) < 70.0:
					s.end()
			Audio.play("explosion", -6.0, 0.05, 1.4)
			world.fx_ring(p.global_position + Vector2(0, -10), UI.EMBER)
		"winding_key":
			p.heal(10.0)
			Audio.play("tick", 0.0, 0.0, 0.8)
			world.fx_text(p.global_position + Vector2(0, -34), "+10 min", UI.GOLD)
			world.fx_ring(p.global_position + Vector2(0, -10), UI.CREAM)
		"smoke_jar":
			p.invuln = 3.0
			for k in 6:
				world.fx_smoke(p.global_position + Vector2.from_angle(TAU * k / 6.0) * 10.0 + Vector2(0, -8))
			Audio.play("teleport", 0.0, 0.05, 0.8)


## Called when a relic is taken: returns "Rite of X 2/3" text and grants the set bonus at 3.
static func check_rite(id: String, p: Player, world: Node) -> String:
	var r := rite_of(id)
	if r == "":
		return ""
	var n := rite_count(p, r)
	if n >= 3 and not r in p.rites:
		p.rites.append(r)
		match r:
			"hearth":
				p.burn = maxf(p.burn, 2.5)
			"clock":
				pass   # handled by the world (room freeze, bells)
			"moth":
				world.add_moth()
			"wick":
				p.shots += 1
				p.pierce += 1
		p.refresh_rite_look()
		world.on_rite(r)
	return "%s %d/3" % [RITES[r]["name"], mini(n, 3)]


static func rite_of(id: String) -> String:
	for r in RITES.keys():
		if id in RITES[r]["members"]:
			return r
	return ""


static func rite_count(p: Player, rite: String) -> int:
	var n := 0
	for id in p.relics:
		if id in RITES[rite]["members"]:
			n += 1
	return n


## "Hearth 1/3" for the relic being previewed (counting what you already hold).
static func rite_progress_text(id: String, p: Player) -> String:
	var r := rite_of(id)
	if r == "":
		return ""
	return "%s %d/3" % [RITES[r]["name"].replace("Rite of the ", "").replace("Rite of ", ""), mini(rite_count(p, r), 3)]

## Special gifts that only appear at a Vigil.
const GIFTS := {
	"vigil_candle": {"name": "Vigil Candle", "desc": "+12 max minutes and a full refill", "icon": "pickups/wax_big"},
	"wax_seal": {"name": "Wax Seal", "desc": "Everything in shops costs less", "icon": "items/wax_seal"},
}

const TONICS := {
	"flask_red": {"name": "Red Tonic", "desc": "+damage"},
	"flask_blue": {"name": "Blue Tonic", "desc": "+fire rate"},
	"flask_green": {"name": "Green Tonic", "desc": "+speed"},
	"flask_yellow": {"name": "Yellow Tonic", "desc": "+range"},
}


static func icon(id: String) -> String:
	if KEEPSAKES.has(id):
		return ("items/ks_" + id) if Art.has("items/ks_" + id) else ("pickups/match_f0" if id == "flare_match" else "items/hourglass")
	if GIFTS.has(id):
		return GIFTS[id]["icon"] if Art.has(GIFTS[id]["icon"]) else "pickups/wax_big"
	if TONICS.has(id):
		return "0x72/" + id
	return "items/" + id


static func display_name(id: String) -> String:
	if RELICS.has(id):
		return RELICS[id]["name"]
	if TONICS.has(id):
		return TONICS[id]["name"]
	if GIFTS.has(id):
		return GIFTS[id]["name"]
	if KEEPSAKES.has(id):
		return KEEPSAKES[id]["name"]
	return id


static func desc(id: String) -> String:
	if RELICS.has(id):
		return RELICS[id]["desc"]
	if TONICS.has(id):
		return TONICS[id]["desc"]
	if GIFTS.has(id):
		return GIFTS[id]["desc"]
	if KEEPSAKES.has(id):
		return KEEPSAKES[id]["desc"] + " (keepsake)"
	return ""


static func apply(id: String, p: Player, world: Node) -> void:
	if RELICS.has(id):
		p.relics.append(id)
	match id:
		"beeswax":
			p.wax_max += 25.0
			p.heal(25.0)
		"twin_wick":
			p.shots += 1
		"blue_flame":
			p.damage *= 1.6
			p.set_blue(true)
		"bellows":
			p.fire_delay *= 0.68
		"lamp_oil":
			p.shot_range *= 1.45
			p.shot_speed *= 1.2
		"soft_soles":
			p.speed *= 1.2
		"wax_coat":
			p.wax_coat = true
			p.coat_ready = true
		"ember_heart":
			p.burn = 2.0
		"sharp_wick":
			p.pierce += 2
		"moth_friend":
			world.add_moth()
		"slow_burn":
			p.drain_mult *= 0.66
		"matchbook":
			p.bombs += 3
			world.bomb_radius *= 1.3
		"hourglass":
			p.hourglass += 3.0
		"candelabra":
			p.shots += 2
			p.damage *= 0.85
		"hot_drip":
			p.hot_drip = true
		"phoenix_feather":
			p.revives += 1
		"lucky_ash":
			p.luck += 0.35
			p.coins += 5
		"will_o_wisp":
			p.homing = maxf(p.homing, 1.0)
		"witching_hour":
			p.witching = true
		"pocket_watch":
			p.slow_aura = 0.25
		"iron_stick":
			p.shot_scale *= 1.4
			p.knockback *= 2.2
			p.damage *= 1.15
		"snuffer_cap":
			p.hit_mult *= 0.7
		"tallow_heart":
			p.wax_max += 10.0
			p.heal(200.0)
		"spare_wick":
			p.damage *= 1.3
		"wax_seal":
			if not p.relics.has("wax_seal"):
				p.relics.append("wax_seal")
			world.recompute_discount()
		"vigil_candle":
			p.wax_max += 12.0
			p.heal(999.0)
		"flask_red":
			p.damage += 0.2
		"flask_blue":
			p.fire_delay *= 0.9
		"flask_green":
			p.speed *= 1.07
		"flask_yellow":
			p.shot_range *= 1.12
