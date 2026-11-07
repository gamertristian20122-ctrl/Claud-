class_name Items
extends RefCounted
## Relics (one of each per run), tonics (unlabelled flasks), keepsakes, rites and gifts.
## Plain stat relics are applied here; anything that needs to run every frame or react to hits,
## kills and rooms lives in RelicFx (scripts/game/relic_fx.gd).

## q = quality tier 0..4 (rarer and stronger as it rises). pools = where it can turn up:
## treasure rooms, the shop, boss rewards, the Smoke Altar, and hollows.
const RELICS := {
	"beeswax": {"name": "Beeswax", "desc": "More wax to burn", "q": 1, "pools": ["treasure", "shop", "boss", "hollow"]},
	"twin_wick": {"name": "Twin Wick", "desc": "Two flames at once", "q": 3, "pools": ["treasure", "boss", "altar"]},
	"blue_flame": {"name": "Blue Flame", "desc": "Hotter. Much hotter", "q": 3, "pools": ["treasure", "boss", "altar"]},
	"bellows": {"name": "Bellows", "desc": "Fire faster", "q": 2, "pools": ["treasure", "shop", "boss"]},
	"lamp_oil": {"name": "Lamp Oil", "desc": "Shots fly further and faster", "q": 1, "pools": ["treasure", "shop", "hollow"]},
	"soft_soles": {"name": "Soft Soles", "desc": "Move faster", "q": 1, "pools": ["treasure", "shop"]},
	"wax_coat": {"name": "Wax Coat", "desc": "Shrug off the first hit in each room", "q": 2, "pools": ["treasure", "shop"]},
	"ember_heart": {"name": "Ember Heart", "desc": "Shots set foes alight", "q": 2, "pools": ["treasure", "hollow"]},
	"sharp_wick": {"name": "Sharp Wick", "desc": "Shots pierce", "q": 2, "pools": ["treasure", "shop"]},
	"moth_friend": {"name": "Moth Friend", "desc": "A moth circles you and blocks shots", "q": 2, "pools": ["treasure", "hollow"]},
	"slow_burn": {"name": "Slow Burn", "desc": "You melt a third slower", "q": 2, "pools": ["treasure", "boss"]},
	"matchbook": {"name": "Matchbook", "desc": "+3 bombs, bigger blasts", "q": 1, "pools": ["shop", "treasure"]},
	"hourglass": {"name": "Hourglass", "desc": "Clearing a room buys back time", "q": 2, "pools": ["treasure", "boss"]},
	"candelabra": {"name": "Candelabra", "desc": "Three flames, a little weaker", "q": 3, "pools": ["treasure", "boss", "altar"]},
	"hot_drip": {"name": "Hot Drip", "desc": "You leave burning wax behind", "q": 1, "pools": ["treasure", "hollow"]},
	"phoenix_feather": {"name": "Phoenix Feather", "desc": "Rekindle once when snuffed", "q": 4, "pools": ["boss", "altar"]},
	"lucky_ash": {"name": "Lucky Ash", "desc": "More drops, more coins", "q": 1, "pools": ["shop", "hollow"]},
	"will_o_wisp": {"name": "Will-o'-Wisp", "desc": "Shots seek the nearest foe", "q": 3, "pools": ["treasure", "altar"]},
	"witching_hour": {"name": "Witching Hour", "desc": "Burn brighter when nearly out", "q": 2, "pools": ["treasure", "hollow"]},
	"pocket_watch": {"name": "Pocket Watch", "desc": "The house moves slower", "q": 2, "pools": ["treasure", "boss"]},
	"iron_stick": {"name": "Iron Candlestick", "desc": "Bigger shots, heavy knockback", "q": 2, "pools": ["treasure", "boss"]},
	"snuffer_cap": {"name": "Snuffer Cap", "desc": "Enemy hits melt less wax", "q": 2, "pools": ["shop", "boss"]},
	"tallow_heart": {"name": "Tallow Heart", "desc": "Refill your wax", "q": 1, "pools": ["boss", "shop"]},
	"spare_wick": {"name": "Spare Wick", "desc": "More damage", "q": 2, "pools": ["treasure", "boss", "shop"]},
	# ---- v2.0: shot modifiers
	"split_wick": {"name": "Split Wick", "desc": "Shots burst into three sparks when they hit", "q": 3, "pools": ["treasure", "boss", "altar"]},
	"tin_sconce": {"name": "Tin Sconce", "desc": "Shots glance off the walls", "q": 1, "pools": ["treasure", "shop"]},
	"old_pipe": {"name": "Old Pipe", "desc": "Shots curl out like smoke rings and come home", "q": 2, "pools": ["treasure", "shop"]},
	"warming_pan": {"name": "Warming Pan", "desc": "Three hot coals circle you", "q": 2, "pools": ["treasure", "hollow"]},
	"lace_fan": {"name": "Lace Fan", "desc": "Two more shots, fanned wide", "q": 2, "pools": ["treasure", "shop", "boss"]},
	"bell_wire": {"name": "Bell Wire", "desc": "Hits ring along the wire to two more foes", "q": 3, "pools": ["treasure", "boss", "altar"]},
	"stove_door": {"name": "Stove Door", "desc": "Hold fire to stoke one great flame", "q": 3, "pools": ["treasure", "altar"]},
	"wick_trimmer": {"name": "Wick Trimmer", "desc": "One shot in five cuts for triple damage", "q": 2, "pools": ["treasure", "shop"]},
	"fire_tongs": {"name": "Fire Tongs", "desc": "Shots stagger foes and shove them back", "q": 1, "pools": ["shop", "treasure"]},
	# ---- v2.0: attacks that change everything
	"blowlamp": {"name": "Blowlamp", "desc": "Your flame becomes a roaring jet", "q": 4, "pools": ["altar", "boss", "treasure"]},
	"pale_taper": {"name": "Pale Taper", "desc": "Ghost shots drift through walls and foes", "q": 4, "pools": ["altar", "boss", "treasure"]},
	"tinderbox": {"name": "Tinderbox", "desc": "Every shot breaks into seeking sparks", "q": 4, "pools": ["altar", "boss", "treasure"]},
	# ---- v2.0: curses on hit
	"cold_wax": {"name": "Cold Wax", "desc": "Hits may set foes in hard wax", "q": 1, "pools": ["treasure", "shop"]},
	"shadow_puppet": {"name": "Shadow Puppet", "desc": "Hits may send foes running scared", "q": 2, "pools": ["treasure", "hollow"]},
	"love_letter": {"name": "Love Letter", "desc": "Hits may charm a foe to fight for you", "q": 3, "pools": ["treasure", "hollow", "altar"]},
	"nightshade": {"name": "Nightshade", "desc": "Hits poison, and the poison spreads", "q": 2, "pools": ["treasure", "shop"]},
	# ---- v2.0: little helpers
	"matchling": {"name": "Matchling", "desc": "A little match follows you and fires too", "q": 3, "pools": ["treasure", "boss"]},
	"paper_lantern": {"name": "Paper Lantern", "desc": "A lantern circles you and catches shots", "q": 2, "pools": ["treasure", "shop"]},
	"dust_bunny": {"name": "Dust Bunny", "desc": "Nibbles foes and fetches coins", "q": 1, "pools": ["hollow", "treasure"]},
	"clockwork_mouse": {"name": "Clockwork Mouse", "desc": "Wind-up mice run at foes and pop", "q": 2, "pools": ["treasure", "shop"]},
	# ---- v2.0: defence
	"thimble": {"name": "Thimble", "desc": "One hit in five slips past you", "q": 2, "pools": ["shop", "treasure"]},
	"scalding_wax": {"name": "Scalding Wax", "desc": "Whatever hurts you gets scalded", "q": 1, "pools": ["treasure", "shop"]},
	"salt_line": {"name": "Salt Line", "desc": "Nothing touches you for 2 s in a new room", "q": 1, "pools": ["shop", "hollow"]},
	"glass_chimney": {"name": "Glass Chimney", "desc": "A glass guard blocks a hit, then regrows", "q": 3, "pools": ["boss", "altar", "shop"]},
	"stopped_clock": {"name": "Stopped Clock", "desc": "When you are hit, the house stops for a breath", "q": 2, "pools": ["treasure", "boss"]},
	# ---- v2.0: finding things
	"house_deed": {"name": "House Deed", "desc": "Every room of every floor, on your map", "q": 0, "pools": ["shop", "treasure"]},
	"dowsing_rod": {"name": "Dowsing Rod", "desc": "Hollow walls shimmer; hollows show on the map", "q": 0, "pools": ["shop", "hollow"]},
	"lodestone": {"name": "Lodestone", "desc": "Coins and drippings fly to you", "q": 0, "pools": ["shop", "treasure"]},
	"pantry_key": {"name": "Pantry Key", "desc": "More chests, and fuller ones", "q": 1, "pools": ["shop", "hollow"]},
	"collection_plate": {"name": "Collection Plate", "desc": "Each cleared room drops coins", "q": 1, "pools": ["shop", "treasure"]},
	"sweep_brush": {"name": "Sweep's Brush", "desc": "Clearing a room sweeps every drop to you", "q": 0, "pools": ["shop"]},
	# ---- v2.0: the clock
	"pendulum": {"name": "Pendulum", "desc": "Burn low and the house slows down", "q": 2, "pools": ["treasure", "boss"]},
	"bell_rope": {"name": "Bell Rope", "desc": "Each guardian you fell rings back 5 minutes", "q": 2, "pools": ["boss", "treasure"]},
	"cuckoo_clock": {"name": "Cuckoo Clock", "desc": "Each quarter hour: +2 min and a burst of sparks", "q": 3, "pools": ["treasure", "boss"]},
	"minute_hand": {"name": "Minute Hand", "desc": "Every kill winds back 4 seconds", "q": 2, "pools": ["treasure", "shop"]},
	"both_ends": {"name": "Lit at Both Ends", "desc": "+50% damage, but you melt faster", "q": 2, "pools": ["treasure", "altar"]},
	# ---- v2.0: odds and ends
	"powder_tin": {"name": "Powder Tin", "desc": "+2 bombs; blasts leave burning ground", "q": 1, "pools": ["shop"]},
	"honeycomb": {"name": "Honeycomb", "desc": "Foes drop wax more often, and it mends more", "q": 1, "pools": ["treasure", "hollow"]},
	"magpie_nest": {"name": "Magpie's Nest", "desc": "Every relic you carry adds a little damage", "q": 3, "pools": ["boss", "altar"]},
	"jet_brooch": {"name": "Jet Brooch", "desc": "After a hit, your next shots strike twice as hard", "q": 2, "pools": ["treasure", "shop"]},
}

## Never offered together (the second would do nothing).
const EXCLUSIVE := {"blowlamp": ["stove_door"], "stove_door": ["blowlamp"]}

## Hold 3 relics of the same Rite and Tallow changes.
const RITES := {
	"hearth": {"name": "Rite of the Hearth", "desc": "Every shot burns; burning foes burst into embers",
		"members": ["blue_flame", "ember_heart", "hot_drip", "bellows", "matchbook", "scalding_wax", "powder_tin"]},
	"clock": {"name": "Rite of the Clock", "desc": "Rooms freeze as you enter; bells give you time",
		"members": ["hourglass", "pocket_watch", "slow_burn", "witching_hour", "phoenix_feather", "cuckoo_clock", "minute_hand", "stopped_clock"]},
	"moth": {"name": "Rite of the Moth", "desc": "A second moth joins you; moths spit fire",
		"members": ["moth_friend", "will_o_wisp", "lamp_oil", "soft_soles", "lucky_ash"]},
	"wick": {"name": "Rite of Many Wicks", "desc": "An extra flame and piercing shots",
		"members": ["twin_wick", "candelabra", "sharp_wick", "spare_wick", "iron_stick", "split_wick", "lace_fan", "wick_trimmer"]},
	"household": {"name": "Rite of the Household", "desc": "A second Matchling joins; helpers hit harder",
		"members": ["matchling", "paper_lantern", "dust_bunny", "clockwork_mouse", "warming_pan", "sweep_brush"]},
	"seance": {"name": "Rite of the Seance", "desc": "Curses take hold twice as often and last longer",
		"members": ["cold_wax", "shadow_puppet", "love_letter", "nightshade", "pale_taper", "dowsing_rod"]},
}

## One held item with charge pips, refilled by clearing rooms.
const KEEPSAKES := {
	"hand_bell": {"name": "Hand Bell", "desc": "Ring it: the house freezes for 3 s", "pips": 3},
	"flare_match": {"name": "Flare Match", "desc": "A ring of 16 burning embers", "pips": 2},
	"winding_key": {"name": "Winding Key", "desc": "Turn the clock back 10 minutes", "pips": 6},
	"smoke_jar": {"name": "Smoke Jar", "desc": "3 s untouchable in a cloud of smoke", "pips": 3},
	"censer": {"name": "Censer", "desc": "Swing it: sweet smoke poisons every foe", "pips": 3},
	"oil_jug": {"name": "Oil Jug", "desc": "Hurl a pool of burning oil ahead", "pips": 2},
	"music_box": {"name": "Music Box", "desc": "Wind it: every foe dances for you a while", "pips": 4},
	"hand_mirror": {"name": "Hand Mirror", "desc": "For 3 s, shots aimed at you turn back", "pips": 3},
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
		_:
			RelicFx.use_keepsake(id, p, world)


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
			_:
				RelicFx.of(world).on_rite(r)
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

## Unlabelled tonics: every flask colour hides a different draught each run (RelicFx.TONIC_FX).
## Until you drink one it reads "???"; after that it is known for the rest of the run.
const TONICS := {
	"flask_red": {"name": "Red Tonic", "desc": "???"},
	"flask_blue": {"name": "Blue Tonic", "desc": "???"},
	"flask_green": {"name": "Green Tonic", "desc": "???"},
	"flask_yellow": {"name": "Yellow Tonic", "desc": "???"},
	"flask_big_red": {"name": "Big Red Tonic", "desc": "???"},
	"flask_big_blue": {"name": "Big Blue Tonic", "desc": "???"},
	"flask_big_green": {"name": "Big Green Tonic", "desc": "???"},
	"flask_big_yellow": {"name": "Big Yellow Tonic", "desc": "???"},
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
		return RelicFx.tonic_name(id)
	if GIFTS.has(id):
		return GIFTS[id]["name"]
	if KEEPSAKES.has(id):
		return KEEPSAKES[id]["name"]
	return id


static func desc(id: String) -> String:
	if RELICS.has(id):
		return RELICS[id]["desc"]
	if TONICS.has(id):
		return RelicFx.tonic_desc(id)
	if GIFTS.has(id):
		return GIFTS[id]["desc"]
	if KEEPSAKES.has(id):
		return KEEPSAKES[id]["desc"] + " (keepsake)"
	return ""


static func tier(id: String) -> int:
	return int(RELICS[id].get("q", 1)) if RELICS.has(id) else 1


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
			p.burn = maxf(p.burn, 2.0)
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
			p.hourglass += 2.0
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
		"fire_tongs":
			p.knockback *= 1.6
		"pale_taper":
			p.pierce += 1
			p.shot_range *= 1.15
		"both_ends":
			p.damage *= 1.5
			p.drain_mult *= 1.2
		"powder_tin":
			p.bombs += 2
		"wax_seal":
			if not p.relics.has("wax_seal"):
				p.relics.append("wax_seal")
			world.recompute_discount()
		"vigil_candle":
			p.wax_max += 12.0
			p.heal(999.0)
		_:
			if TONICS.has(id):
				RelicFx.drink(id, p, world)
	if RELICS.has(id):
		RelicFx.of(world).on_relic(id)
