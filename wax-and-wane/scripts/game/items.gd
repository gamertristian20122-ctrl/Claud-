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
	"wax_seal": {"name": "Wax Seal", "desc": "Everything costs less in the shop"},
}

const TONICS := {
	"flask_red": {"name": "Red Tonic", "desc": "+damage"},
	"flask_blue": {"name": "Blue Tonic", "desc": "+fire rate"},
	"flask_green": {"name": "Green Tonic", "desc": "+speed"},
	"flask_yellow": {"name": "Yellow Tonic", "desc": "+range"},
}


static func icon(id: String) -> String:
	if TONICS.has(id):
		return "0x72/" + id
	return "items/" + id


static func display_name(id: String) -> String:
	if RELICS.has(id):
		return RELICS[id]["name"]
	if TONICS.has(id):
		return TONICS[id]["name"]
	return id


static func desc(id: String) -> String:
	if RELICS.has(id):
		return RELICS[id]["desc"]
	if TONICS.has(id):
		return TONICS[id]["desc"]
	return ""


static func apply(id: String, p: Player, world: Node) -> void:
	if RELICS.has(id):
		p.relics.append(id)
	match id:
		"beeswax":
			p.wax_max += 25.0
			p.heal(25.0)
		"twin_wick":
			p.shots = maxi(p.shots, 2)
			p.spread = 9.0
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
			p.hourglass += 4.0
		"candelabra":
			p.shots = 3
			p.spread = 14.0
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
			world.shop_discount = 0.6
		"flask_red":
			p.damage += 0.2
		"flask_blue":
			p.fire_delay *= 0.9
		"flask_green":
			p.speed *= 1.07
		"flask_yellow":
			p.shot_range *= 1.12
