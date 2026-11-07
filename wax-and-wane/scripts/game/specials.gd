class_name Specials
extends Node2D
## Special rooms and mini-bosses (v2.0 "specials" stream).
##
## FloorGen places them (seeded from the floor RNG, so Tonight's Candle is the same for everyone);
## this node (one per world, `Specials.of(world)`) dresses them, runs their logic and pays out.
##   seance    a bell in a chalk ring: ring it and three waves of lodgers answer; a boss relic
##   mirror    a dark door (1 minute to step through); a strong relic for 15 max minutes, or leave it
##   musicbox  3 coins a crank; it plays what it likes
##   study     a lectern: a keepsake, two tonics, or the floor's map; the others crumble
##   font      feed it 4 minutes at a time; each offering makes a payout likelier, the sixth always pays
## Mini-bosses: one ordinary room on floors 2-4 may hold a champion lodger at twice the size.

const TYPES := ["seance", "mirror", "musicbox", "study", "font"]
const INFO := {
	"seance": {"name": "THE SEANCE", "sub": "Ring the bell, and the lodgers answer", "floors": [1, 2, 3, 4], "chance": 0.6,
		"hint": "Ring the bell to call the lodgers. The doors lock until they are gone."},
	"mirror": {"name": "THE CRACKED MIRROR", "sub": "It shows you stronger, and shorter", "floors": [2, 3, 4], "chance": 0.45,
		"hint": "Its gift costs 15 minutes of wax, for good. Or veil the glass."},
	"musicbox": {"name": "THE MUSIC BOX", "sub": "Three coins a turn. It plays what it likes", "floors": [1, 2, 3, 4], "chance": 0.4,
		"hint": "Walk into the box to wind it: 3 coins a turn."},
	"study": {"name": "THE STUDY", "sub": "Read one. The rest turn to dust", "floors": [2, 3, 4], "chance": 0.35,
		"hint": "Take one. The other two will crumble."},
	"font": {"name": "THE WAX FONT", "sub": "It drinks wax, and it gives back", "floors": [1, 2, 3, 4], "chance": 0.3,
		"hint": "4 minutes a gift. Each one raises the odds; the sixth always pays."},
}
## Mini-bosses: a floor lodger grown to twice the size, 6x its health, one extra attack.
const MINIS := {
	"sootling": {"name": "THE GREAT SOOTLING", "sub": "Every chimney in the house fed it", "floor": 2, "extra": "soot_ring"},
	"skelet": {"name": "THE BONE LANDLORD", "sub": "Rent is due. It takes teeth", "floor": 2, "extra": "rent_fan"},
	"chort": {"name": "THE KITCHEN DEVIL", "sub": "The range went out. It blames you", "floor": 3, "extra": "ember_ring"},
	"wogol": {"name": "THE RAFTER KING", "sub": "The beams are its throne", "floor": 3, "extra": "landing_ring"},
	"deathwatch": {"name": "THE DEATHWATCH QUEEN", "sub": "Every tick in the walls is hers", "floor": 4, "extra": "tick_burst"},
	"ice_zombie": {"name": "THE ICEBOX GIANT", "sub": "Shut in with the ice since winter", "floor": 4, "extra": "frost_fan"},
}
const MINI_CHANCE := 0.5
const MINI_HP := 6.0
const MINI_TOUCH := 9.0
## The prop stands on this cell of a special room (an unbreakable "X" for collision and shots).
const PROP_CELL := Vector2i(7, 4)
const ROOM := [
	"...............",
	"...............",
	"...............",
	"...............",
	".......X.......",
	"...............",
	"...............",
	"...............",
	"...............",
]
const WAVES := 3
const WAVE_SIZE := [5, 5, 5]
const WAVE_SIZE_CELLAR := [3, 4, 4]
## The Seance pays a boss-pool relic of tier 0..SEANCE_TIER (it rolls often: the very best stay with the guardians).
const SEANCE_TIER := 2
const MIRROR_TOLL := 1.0
const MIRROR_COST := 15
const CRANK_COST := 3
const FONT_COST := 4.0
const FONT_USES := 6
## Chance that an offering pays, by how many the font has drunk (1st .. 6th). The sixth always pays.
const FONT_ODDS := [0.12, 0.22, 0.34, 0.48, 0.65, 1.0]
## The music box: [outcome, weight]. A relic breaks its spring.
const TUNES := [["nothing", 28.0], ["coins", 22.0], ["wax", 16.0], ["bomb", 12.0], ["tonic", 9.0],
	["lodger", 7.0], ["relic", 6.0]]
const PROP_LIGHT := {"seance": Color(0.62, 0.55, 1.0), "mirror": Color(0.55, 0.78, 1.0), "musicbox": Color(1.0, 0.6, 0.75),
	"study": Color(1.0, 0.85, 0.55), "font": Color(1.0, 0.72, 0.45)}

var world: Node
var _prop: Node2D             # the prop's sprite in the current special room
var _prop_room: Room
var _busy := 0.0              # a crank / an offering in progress
var _cool := 0.0              # Tallow has to step away before the next use
var _say_t := 0.0             # throttle for "not enough" texts
var _wave_t := -1.0           # seance: time until the next wave
var _mini: Enemy
var _mini_room: Dictionary = {}
var _mini_t := 3.0
var _mini_air := false
var _enter_t := 0.0
var font_uses := 0            # this run (saved with Save & Continue)
var minis_beaten: Array = []  # this run


static func of(w: Node) -> Specials:
	var s = w.get_meta("specials") if w.has_meta("specials") else null
	if s != null and is_instance_valid(s):
		return s
	var ns := Specials.new()
	ns.world = w
	ns.name = "Specials"
	w.set_meta("specials", ns)
	w.add_child(ns)
	return ns


static func is_special(t: String) -> bool:
	return t in TYPES


## Door style for a door between a room of type `mine` and its neighbour of type `other`.
static func door_style(other: String, mine: String) -> String:
	if other in TYPES:
		return other
	if mine in TYPES:
		return mine
	return ""


static func grid_for(_t: String) -> Array:
	return RoomTemplates.to_grid(ROOM)


static func minis_for(floor_num: int) -> Array:
	var out: Array = []
	for k in MINIS:
		if int(MINIS[k]["floor"]) == floor_num:
			out.append(k)
	return out


## Has Tallow seen inside this special room, or does a relic tell what it is?
static func known(w: Node, d: Dictionary) -> bool:
	if d.get("visited", false) or d.get("known", false):
		return true
	var rel: Array = w.player.relics if w.player else []
	return rel.has("house_deed") or rel.has("dowsing_rod")


## hud._draw_minimap: the mark of a special room (a "?" until Tallow knows what is inside), and a
## mini-boss room's mark when the House Deed shows it.
static func draw_map_mark(ci: CanvasItem, w: Node, d: Dictionary, pos: Vector2) -> void:
	var t: String = d.get("type", "")
	var path := ""
	if t in TYPES:
		path = "specials/map_" + t if known(w, d) else "specials/map_unknown"
	elif d.has("mini") and not d.get("cleared", false) and w.player and w.player.relics.has("house_deed"):
		path = "specials/map_mini"
	if path == "":
		return
	var tex := Art.tex(path)
	ci.draw_texture(tex, pos + Vector2(floorf((9 - tex.get_width()) / 2.0), floorf((6 - tex.get_height()) / 2.0)))


# ================================================================ hooks (one line each in world.gd)

## world._build_room: dress a special room, mark the Cracked Mirror's toll on its door.
static func on_build(w: Node, r: Room) -> void:
	of(w)._built(r)


## world._on_enter_room: returns true when the room's entry is fully handled here (a mini-boss).
static func on_enter_room(w: Node) -> bool:
	return of(w)._entered()


## world._clear_room: a finished Seance or a beaten mini-boss pays out.
static func on_clear(w: Node) -> void:
	of(w)._cleared()


## room.shot_hits: one of Tallow's shots hit the prop of a special room.
static func prop_shot(r: Room, _c: Vector2i) -> void:
	if r.world and r.world.has_meta("specials"):
		var s: Specials = of(r.world)
		if r.data.get("type", "") == "seance" and r == r.world.room:
			s._ring()


## pickup._collect: a pact other than the Smoke Altar's has been paid (the Cracked Mirror).
static func on_pact(w: Node, rec: Dictionary) -> void:
	if str(rec.get("pact", "")) == "mirror":
		of(w)._mirror_taken()


## world._spawn_pickup_node: our offers are Pickups with their own look.
static func new_pickup(rec: Dictionary) -> Pickup:
	return Offer.new() if str(rec.get("kind", "")) == "offer" else Pickup.new()


## Save & Continue (world.save_extra / load_extra).
func to_dict() -> Dictionary:
	return {"font_uses": font_uses, "minis": minis_beaten.duplicate()}


func from_dict(d: Dictionary) -> void:
	font_uses = int(d.get("font_uses", 0))
	minis_beaten = (d.get("minis", []) as Array).duplicate()


## Play-test log line (only while the autotest bot runs).
func _log(text: String) -> void:
	if world.main and world.main.get("autotest") != null:
		print("[specials] floor %d %s" % [world.floor_num, text])


# ================================================================ building

func _built(r: Room) -> void:
	var d: Dictionary = r.data
	var t: String = d.get("type", "")
	# a toll mark in front of any door that leads to an unpaid Cracked Mirror
	for dir in r.doors.keys():
		var nc: Vector2i = r.cell + dir
		if world.layout["cells"].has(nc):
			var nd: Dictionary = world.layout["cells"][nc]
			if nd["type"] == "mirror" and not nd.get("toll", false):
				_toll_mark(r, dir)
	if not t in TYPES:
		return
	_prop_room = r
	var holder: Node2D = r.obstacle_nodes.get(PROP_CELL)
	if holder == null:
		return
	for ch in holder.get_children():
		if ch is Sprite2D:
			ch.visible = false
	var spr := AnimatedSprite2D.new()
	spr.centered = false
	spr.sprite_frames = _prop_frames(t)
	spr.animation = _prop_anim(t, d)
	spr.play()
	var tex: Texture2D = spr.sprite_frames.get_frame_texture(spr.animation, 0)
	spr.offset = Vector2(-floorf(tex.get_width() / 2.0), -tex.get_height() + 1)
	holder.add_child(spr)
	_prop = spr
	var l := PointLight2D.new()
	l.texture = Art.light_tex
	l.texture_scale = 0.55
	l.energy = 0.75
	l.color = PROP_LIGHT[t]
	l.position = Vector2(0, -18)
	holder.add_child(l)
	holder.set_meta("light", l)
	if t == "font":
		_font_look(d)
	var c := r.center() - r.position
	match t:
		"seance":
			_decal(r, "specials/seance_circle", c + Vector2(0, 2))
			for k in 5:
				var a := -PI / 2.0 + k * TAU / 5.0
				_candle(r, c + Vector2(cos(a) * 52.0, sin(a) * 30.0 + 6.0), k)
		"mirror":
			_decal(r, "specials/mirror_shards", c + Vector2(-22, 18))
			_decal(r, "specials/mirror_shards", c + Vector2(30, 34), true)
		"study":
			_decal(r, "decor/floor_pages_0", c + Vector2(-56, 30))
			_decal(r, "decor/floor_book", c + Vector2(62, -18))
			_decal(r, "decor/floor_pages_1", c + Vector2(44, 44), true)
		"musicbox":
			_decal(r, "decor/floor_cog", c + Vector2(-40, 26))
			_decal(r, "decor/floor_cog", c + Vector2(48, -22), true)
		"font":
			_decal(r, "decor/floor_puddle", c + Vector2(-30, 20))
			_decal(r, "decor/floor_candle_stubs", c + Vector2(40, 30))


func _prop_frames(t: String) -> SpriteFrames:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	var anims := {}
	match t:
		"seance": anims = {"idle": ["bell_f0"], "ring": ["bell_f0", "bell_f1", "bell_f2", "bell_f3"], "done": ["bell_done"]}
		"mirror": anims = {"idle": ["mirror_f0", "mirror_f0", "mirror_f0", "mirror_f1", "mirror_f2", "mirror_f0", "mirror_f0", "mirror_f3"],
			"veiled": ["mirror_veiled"], "broken": ["mirror_broken"]}
		"musicbox": anims = {"idle": ["musicbox_f0"], "crank": ["musicbox_f0", "musicbox_f1", "musicbox_f2", "musicbox_f3"],
			"broken": ["musicbox_broken"]}
		"study": anims = {"idle": ["lectern_f0", "lectern_f0", "lectern_f0", "lectern_f1", "lectern_f1", "lectern_f0"], "done": ["lectern_f0"]}
		"font":
			for k in FONT_USES + 1:
				anims["u%d" % k] = ["font_%d" % k]
			anims["spent"] = ["font_spent"]
	for a in anims:
		sf.add_animation(a)
		sf.set_animation_loop(a, true)
		sf.set_animation_speed(a, 10.0 if a in ["ring", "crank"] else 4.0)
		for n in anims[a]:
			sf.add_frame(a, Art.tex("specials/" + n))
	return sf


func _prop_anim(t: String, d: Dictionary) -> String:
	match t:
		"seance": return "done" if d.get("seance_done", false) else ("ring" if d.get("rung", false) else "idle")
		"mirror": return "broken" if d.get("mirror_taken", false) else ("veiled" if d.get("veiled", false) else "idle")
		"musicbox": return "broken" if d.get("box_broken", false) else "idle"
		"study": return "done" if d.get("read", false) else "idle"
		"font": return "spent" if d.get("font_spent", false) else "u%d" % int(d.get("fed", 0))
	return "idle"


func _decal(r: Room, path: String, lp: Vector2, flip := false) -> void:
	if not Art.has(path):
		return
	var s := Sprite2D.new()
	s.texture = Art.tex(path)
	s.position = lp.round()
	s.flip_h = flip
	r.floor_layer.add_child(s)


## A stub of candle on the chalk ring, its flame unshaded so it reads in the dark.
func _candle(r: Room, lp: Vector2, k: int) -> void:
	var s := Sprite2D.new()
	s.texture = Art.tex("specials/seance_candle")
	s.centered = false
	s.offset = Vector2(-2, -6)
	s.position = lp.round()
	r.objects.add_child(s)
	var f := AnimatedSprite2D.new()
	f.sprite_frames = Art.anim("decor/flame_candle", 7.0 + k * 0.6)
	f.play("default")
	f.frame = k % 4
	f.centered = false
	f.position = Vector2(-1, -9)
	f.material = Art.unshaded
	s.add_child(f)


func _toll_mark(r: Room, dir: Vector2i) -> void:
	var at := {Vector2i.UP: Vector2(136, 44), Vector2i.DOWN: Vector2(136, 166), Vector2i.LEFT: Vector2(30, 98), Vector2i.RIGHT: Vector2(242, 98)}
	var n := Node2D.new()
	n.position = at[dir]
	n.z_index = 2
	n.set_meta("toll", dir)
	var lbl := UI.label("1", 8, UI.RED, HORIZONTAL_ALIGNMENT_CENTER)
	lbl.position = Vector2(-10, -4)
	lbl.size = Vector2(16, 8)
	lbl.material = Art.unshaded
	n.add_child(lbl)
	var ic := Sprite2D.new()
	ic.texture = Art.tex("pickups/wax_small")
	ic.position = Vector2(4, 0)
	ic.material = Art.unshaded
	n.add_child(ic)
	r.add_child(n)


# ================================================================ entering

func _entered() -> bool:
	var r: Room = world.room
	var d: Dictionary = r.data
	var t: String = d.get("type", "")
	_cool = 0.6
	_busy = 0.0
	_enter_t = world.run_time
	if world.player.relics.has("dowsing_rod") or world.player.relics.has("house_deed"):
		for c in world.layout["cells"]:
			var cd: Dictionary = world.layout["cells"][c]
			if cd["type"] in TYPES:
				cd["seen"] = true
				cd["known"] = true
	if d.has("mini") and not d["cleared"]:
		_start_mini(d)
		return true
	if not t in TYPES:
		return false
	if t == "mirror" and not d.get("toll", false):
		d["toll"] = true
		var p: Player = world.player
		p.wax = maxf(1.0, p.wax - MIRROR_TOLL)
		world.fx_text(p.global_position + Vector2(0, -30), "-1 min", UI.RED)
		Audio.play("snuff_out", -4.0, 0.0, 1.3)
	if not d.get("greeted", false):
		d["greeted"] = true
		_log("enter " + t)
		world.hud.show_banner(INFO[t]["name"], INFO[t]["sub"], 1.8)
		if Game.tip("special_" + t, 2):
			world.hud.show_hint(INFO[t]["hint"], 4.0)
	if not d.get("stocked", false):
		d["stocked"] = true
		_stock(t, d)
	return false


func _stock(t: String, d: Dictionary) -> void:
	var c: Vector2 = world.room.center()
	match t:
		"mirror":
			var id := pick_relic(world, ["altar", "boss", "treasure"], 3, 4)
			var a: Pickup = world.add_pickup("relic", c + Vector2(-30, 22), id)
			a.record["cost_wax"] = MIRROR_COST
			a.record["pact"] = "mirror"
			a.record["group"] = "mirror"
			a.queue_free()   # rebuilt so the price shows (it reads the record in _ready)
			world._spawn_pickup_node(world.room, a.record)
			var v: Pickup = world.add_pickup("offer", c + Vector2(30, 22), "veil")
			v.record["group"] = "mirror"
		"study":
			var ks: Array = Items.KEEPSAKES.keys().filter(func(k): return k != world.player.keepsake)
			var a: Pickup = world.add_pickup("keepsake", c + Vector2(-46, 24), ks[world.rng.randi() % ks.size()])
			var b: Pickup = world.add_pickup("offer", c + Vector2(0, 34), "tonics")
			var m: Pickup = world.add_pickup("offer", c + Vector2(46, 24), "map")
			for p in [a, b, m]:
				p.record["group"] = "study"


# ================================================================ every frame

func _physics_process(dt: float) -> void:
	if world == null or world.room == null or world.player == null or world.finished:
		return
	_say_t -= dt
	_tick_mini(dt)
	var r: Room = world.room
	var d: Dictionary = r.data
	var t: String = d.get("type", "")
	if not t in TYPES or world.transitioning or _prop_room != r or not is_instance_valid(_prop):
		return
	var p: Player = world.player
	if p.dead:
		return
	var feet: Vector2 = r.cell_center(PROP_CELL) + Vector2(0, 2)
	var near: bool = p.global_position.distance_to(feet) < 17.0
	if t == "seance" and d.get("rung", false):
		if not d.get("seance_done", false):
			_seance_tick(dt, d)
		return
	if _busy > 0.0:
		_busy -= dt
		if _busy <= 0.0:
			_finish_use(t, d)
		return
	if _cool > 0.0:
		if not near:
			_cool -= dt
		return
	match t:
		"seance":
			if near:
				_ring()
		"musicbox":
			if near and not d.get("box_broken", false):
				if p.coins >= CRANK_COST:
					_crank(d)
				else:
					_say("%d coins a turn" % CRANK_COST, UI.DIM)
			elif near:
				_say("The spring has gone", UI.DIM)
		"font":
			if near and not d.get("font_spent", false):
				if p.wax > FONT_COST + 2.0:
					_feed(d)
				else:
					_say("Too little wax to give", UI.RED)
			elif near:
				_say("The font is full", UI.DIM)
	if near and t in ["mirror", "study"]:
		world.hud.preview_item(INFO[t]["name"], INFO[t]["hint"])


func _say(text: String, col: Color) -> void:
	if _say_t > 0.0:
		return
	_say_t = 1.6
	world.fx_text(world.room.cell_center(PROP_CELL) + Vector2(0, -30), text, col)
	_cool = 0.6


func _play(anim: String) -> void:
	if is_instance_valid(_prop) and _prop is AnimatedSprite2D and _prop.sprite_frames.has_animation(anim):
		_prop.play(anim)


func _squash() -> void:
	if not is_instance_valid(_prop):
		return
	var h: Node2D = _prop.get_parent()
	var tw := h.create_tween()
	tw.tween_property(h, "scale", Vector2(1.12, 0.88), 0.06)
	tw.tween_property(h, "scale", Vector2(0.95, 1.06), 0.08)
	tw.tween_property(h, "scale", Vector2.ONE, 0.1)


# ================================================================ the Seance

func _ring() -> void:
	var r: Room = world.room
	var d: Dictionary = r.data
	if d.get("rung", false) or world.transitioning:
		return
	d["rung"] = true
	d["cleared"] = false
	d["wave"] = 0
	world.room_spawned = false
	r.set_open(false)
	_play("ring")
	_squash()
	Audio.play("bell_toll")
	world.shake(3.0)
	world.fx_ring(r.cell_center(PROP_CELL) + Vector2(0, -14), Color("#cae6f5"))
	world.hud.show_banner("", "The lodgers answer...", 1.4)
	_wave_t = 1.1
	_log("seance rung")


func _seance_tick(dt: float, d: Dictionary) -> void:
	if _wave_t > 0.0:
		_wave_t -= dt
		if _wave_t <= 0.0:
			_spawn_wave(d)
		return
	if world.count_enemies() > 0 or d.get("cleared", false):
		return
	var wave: int = int(d.get("wave", 0))
	if wave >= WAVES:
		# the last of them is gone: the world clears the room and on_clear pays out
		d["seance_done"] = true
		_play("done")
		world.room_spawned = true
		return
	Audio.play("bell_small", 0.0, 0.0, 1.0 + 0.12 * wave)
	world.fx_ring(world.room.cell_center(PROP_CELL) + Vector2(0, -14), Color("#cae6f5"))
	world.fx_text(world.room.cell_center(PROP_CELL) + Vector2(0, -36), "%d of %d" % [wave + 1, WAVES], Color("#cae6f5"))
	_squash()
	_wave_t = 1.2


func _spawn_wave(d: Dictionary) -> void:
	var wave: int = int(d.get("wave", 0)) + 1
	d["wave"] = wave
	var n: int = world.floor_num
	var here: Dictionary = world.POOLS.get(n, world.POOLS[1])
	var next: Dictionary = world.POOLS.get(n + 1, here)
	# from the Crypt up: five a wave. Wave 1 this floor with a heavy; wave 2 half from below, a flyer
	# and a heavy; wave 3 all from below with two heavies, the last one marked. The Cellar's seance is
	# gentler (3 / 4 / 4, only half of the last wave from below, one heavy) so a new candle can win it.
	var picks: Array = []
	var gentle: bool = n <= 1
	var count: int = (WAVE_SIZE_CELLAR if gentle else WAVE_SIZE)[wave - 1]
	for i in count:
		var below: bool = (wave == 3 and (not gentle or i % 2 == 1)) or (wave == 2 and i % 2 == 1 and not gentle)
		var pool: Dictionary = next if below else here
		var lst: Array = pool["e"]
		if i == 0 and wave == 2:
			lst = here["f"]
		elif (not gentle or wave == 3) and i >= count - (2 if wave == 3 and not gentle else 1):
			lst = pool["h"]
		picks.append(lst[world.rng.randi() % lst.size()])
	Audio.play("summon", -2.0)
	for i in picks.size():
		var pos: Vector2 = world.random_free_spot(world.player.global_position, 60.0)
		world.fx_smoke(pos + Vector2(0, -6))
		var champ := ""
		if wave == WAVES and i == picks.size() - 1:
			champ = ["ember", "gilded", "sooty", "chilled"][world.rng.randi() % 4]
		var e: Enemy = world.spawn_enemy(picks[i], pos, champ)
		if e and champ == "":
			# called-up lodgers are half spirit: pale, and they leave no drippings behind
			# (an unknown mark after _ready: no extra health, no glow, no drop in world.on_enemy_killed)
			e.champ = "spirit"
			e.spr.modulate = Color(0.74, 0.82, 1.0, e.spr.modulate.a)
	world.room_t0 = world.run_time


# ================================================================ the Cracked Mirror

func _mirror_taken() -> void:
	var d: Dictionary = world.room.data
	d["mirror_taken"] = true
	_play("broken")
	_squash()
	world.shake(4.0)
	Audio.play("door_burst", -2.0, 0.0, 1.4)
	world.fx_sparks(world.room.cell_center(PROP_CELL) + Vector2(0, -20), Vector2.UP, 8, true)
	Achievements.unlock("mirror_deal")
	_log("mirror deal")


func _veiled() -> void:
	var d: Dictionary = world.room.data
	d["veiled"] = true
	_play("veiled")
	_squash()
	Audio.play("dodge", 0.0, 0.0, 0.8)
	world.player.heal(2.0)
	world.fx_text(world.player.global_position + Vector2(0, -30), "+2 min", UI.WAX)


# ================================================================ the Music Box

func _crank(d: Dictionary) -> void:
	world.player.coins -= CRANK_COST
	d["cranks"] = int(d.get("cranks", 0)) + 1
	_busy = 1.15
	_play("crank")
	_squash()
	Audio.play("coin_pickup", -2.0, 0.0, 0.7)
	world.fx_text(world.room.cell_center(PROP_CELL) + Vector2(0, -30), "-%d" % CRANK_COST, UI.GOLD)
	for k in 4:
		var tw := create_tween()
		tw.tween_interval(0.12 + k * 0.24)
		tw.tween_callback(func(): Audio.play("clock_tick_fast", -3.0, 0.0, 1.0 + 0.1 * k))


func _finish_use(t: String, d: Dictionary) -> void:
	_cool = 0.6
	if t == "musicbox":
		_tune(d)
	elif t == "font":
		_font_pay(d)


func _tune(d: Dictionary) -> void:
	var c: Vector2 = world.room.cell_center(PROP_CELL) + Vector2(0, 10)
	var at: Vector2 = world.room.cell_center(PROP_CELL) + Vector2(0, -30)
	var total := 0.0
	for o in TUNES:
		total += float(o[1])
	var roll: float = world.rng.randf() * total
	var out: String = TUNES[0][0]
	for o in TUNES:
		roll -= float(o[1])
		if roll <= 0.0:
			out = o[0]
			break
	_play("idle")
	_squash()
	_log("music box: " + out)
	var fly := func() -> Vector2: return Vector2(world.rng.randf_range(-1.0, 1.0), world.rng.randf_range(0.4, 1.0)).normalized() * 60.0
	match out:
		"nothing":
			Audio.play("snuff_out", -2.0, 0.0, 1.5)
			world.fx_text(at, "The tune just stops", UI.DIM)
		"coins":
			Audio.play("unlock", -2.0)
			for i in CRANK_COST * 2:
				world.add_pickup("coin", c, "", 0, fly.call())
			world.fx_text(at, "Coins back, twice over!", UI.GOLD)
		"wax":
			Audio.play("wax_bubble")
			world.add_pickup("wax_small" if world.rng.randf() < 0.75 else "wax_big", c, "", 0, fly.call())
			world.fx_text(at, "A sweet little tune", UI.WAX)
		"bomb":
			Audio.play("bomb_pickup")
			world.add_pickup("bomb", c, "", 0, fly.call())
			world.fx_text(at, "Boom-tiddy-boom", UI.EMBER)
		"tonic":
			Audio.play("item_get")
			var tonics := Items.TONICS.keys()
			world.add_pickup("tonic", c + Vector2(0, 14), tonics[world.rng.randi() % tonics.size()])
			world.fx_text(at, "A tonic rolls out", Color("#72d6ce"))
		"lodger":
			Audio.play("summon")
			world.fx_text(at, "Something climbs out!", UI.RED)
			world.shake(3.0)
			var n: int = world.floor_num
			var lst: Array = world.POOLS.get(n, world.POOLS[1])["e"]
			d["cleared"] = false
			world.room.set_open(false)
			for i in (1 if n < 3 else 2):
				var e: Enemy = world.spawn_enemy(lst[world.rng.randi() % lst.size()], c + Vector2(-8 + 16 * i, 6))
				if e:
					e.kvel = fly.call() * 2.0
			world.room_spawned = true
			world.room_t0 = world.run_time
		"relic":
			Audio.play("relic_fanfare")
			world.add_pickup("relic", c + Vector2(0, 18), pick_relic(world, ["shop", "treasure"], 0, 2))
			world.fx_text(at, "THE LUCKY TUNE!", UI.GOLD)
			world.fx_ring(c + Vector2(0, -16), UI.GOLD)
			d["box_broken"] = true
			_play("broken")
			Achievements.unlock("music_box")


# ================================================================ the Wax Font

func _feed(d: Dictionary) -> void:
	var p: Player = world.player
	p.wax -= FONT_COST
	d["fed"] = int(d.get("fed", 0)) + 1
	font_uses += 1
	_busy = 0.7
	_font_look(d)
	_squash()
	Audio.play("sizzle", -2.0)
	world.fx_text(p.global_position + Vector2(0, -30), "-%d min" % int(FONT_COST), UI.RED)
	world.fx_wax_drop(p.global_position + Vector2(0, -10), (world.room.cell_center(PROP_CELL) - p.global_position).normalized() * 60.0)
	if font_uses >= 5:
		Achievements.unlock("font_5")


func _font_look(d: Dictionary) -> void:
	if not is_instance_valid(_prop):
		return
	_play("spent" if d.get("font_spent", false) else "u%d" % mini(int(d.get("fed", 0)), FONT_USES))
	var h: Node = _prop.get_parent()
	if h.has_meta("light"):
		(h.get_meta("light") as PointLight2D).energy = 0.6 + 0.12 * int(d.get("fed", 0))


func _font_pay(d: Dictionary) -> void:
	var fed: int = int(d.get("fed", 0))
	var c: Vector2 = world.room.cell_center(PROP_CELL) + Vector2(0, 12)
	var at: Vector2 = world.room.cell_center(PROP_CELL) + Vector2(0, -32)
	Audio.play("wax_bubble")
	var odds: float = FONT_ODDS[clampi(fed - 1, 0, FONT_ODDS.size() - 1)]
	var paid: bool = world.rng.randf() < odds
	_log("font fed %d: %s" % [fed, "pays" if paid else "drinks"])
	if not paid:
		var nxt: float = FONT_ODDS[clampi(fed, 0, FONT_ODDS.size() - 1)]
		world.fx_text(at, "It drinks.  Next: %d in 10" % int(round(nxt * 10.0)) if fed < FONT_USES - 1 else "It drinks.  The next one pays", UI.WAX)
		if fed >= FONT_USES:
			_font_spent(d)
		return
	world.fx_ring(c + Vector2(0, -18), UI.GOLD)
	if fed >= 4:
		Audio.play("relic_fanfare")
		world.add_pickup("relic", c + Vector2(0, 14), pick_relic(world, ["treasure", "hollow"], 1, 3))
		world.fx_text(at, "The font gives back a relic!", UI.GOLD)
		_font_spent(d)
	elif world.rng.randf() < 0.6:
		Audio.play("coin_pickup")
		for i in 3 + fed:
			world.add_pickup("coin", c, "", 0, Vector2.from_angle(world.rng.randf() * TAU) * 50.0)
		world.fx_text(at, "Coins well up from the wax", UI.GOLD)
	else:
		Audio.play("chest_open", -3.0)
		world.add_pickup("chest", world.free_spot_near(c + Vector2(0, 16), 8.0))
		world.fx_text(at, "A chest floats up", UI.GOLD)


func _font_spent(d: Dictionary) -> void:
	d["font_spent"] = true
	_font_look(d)


# ================================================================ the Study

func _read_map() -> void:
	for c in world.layout["cells"]:
		var cd: Dictionary = world.layout["cells"][c]
		cd["seen"] = true
		if cd["type"] in TYPES:
			cd["known"] = true
	world.room.data["read"] = true
	Audio.play("page_flip")
	world.hud.show_banner("THE HOUSE PLANS", "Every room of this floor, hollows too", 1.8)


func _give_tonics(pos: Vector2) -> void:
	world.room.data["read"] = true
	var tonics := Items.TONICS.keys()
	var a: String = tonics[world.rng.randi() % tonics.size()]
	var b: String = tonics[world.rng.randi() % tonics.size()]
	world.add_pickup("tonic", pos + Vector2(-17, 0), a)
	world.add_pickup("tonic", pos + Vector2(17, 0), b)
	Audio.play("page_flip")


## An offer (study / mirror) was taken. Returns false if it could not be taken right now.
func take_offer(o: Offer) -> bool:
	_log("offer " + o.item)
	match o.item:
		"map": _read_map()
		"tonics": _give_tonics(o.global_position)
		"veil": _veiled()
	world.collect_item("", o.global_position, o.record)   # the other choices crumble
	return true


# ================================================================ clearing

func _cleared() -> void:
	var r: Room = world.room
	var d: Dictionary = r.data
	var c: Vector2 = r.center()
	if d.get("type", "") == "seance" and d.get("seance_done", false) and not d.get("paid", false):
		d["paid"] = true
		world.add_pickup("relic", c + Vector2(0, 28), pick_relic(world, ["boss"], 0, SEANCE_TIER))
		for i in world.rng.randi_range(3, 5):
			world.add_pickup("coin", c + Vector2(0, 18), "", 0, Vector2.from_angle(world.rng.randf() * TAU) * 50.0)
		world.hud.show_banner("THE SEANCE IS OVER", "The lodgers leave a gift", 1.6)
		_log("seance done")
		Audio.play("bell_toll", -2.0, 0.0, 1.2)
		Achievements.unlock("seance")
	if d.has("mini") and not d.get("mini_paid", false) and (_mini == null or not is_instance_valid(_mini) or not _mini.alive):
		d["mini_paid"] = true
		if world.rng.randf() < 0.4:
			world.add_pickup("relic", c + Vector2(0, 8), pick_relic(world, ["treasure", "shop"], 1, 2))
		else:
			world.add_pickup("chest", world.free_spot_near(c + Vector2(0, 8), 8.0))


# ================================================================ mini-bosses

func _start_mini(d: Dictionary) -> void:
	var r: Room = world.room
	r.set_open(false, true)
	Audio.play("door_close", -3.0)
	var tw := create_tween()
	tw.tween_interval(0.35)
	tw.tween_callback(func():
		if world.room != r or world.finished:
			return
		var p: Player = world.player
		var pos: Vector2 = r.center() + Vector2(0, -10)
		if pos.distance_to(p.global_position) < 70.0:
			pos = world.random_free_spot(p.global_position, 90.0)
		spawn_mini(str(d["mini"]), pos)
		# the room may hide a chest or a mimic in its layout; keep those as they are
		for slot in r.spawn_slots():
			if slot[0] == "T":
				world.add_pickup("chest", slot[1])
		world.room_spawned = true
		world.room_t0 = world.run_time)


func spawn_mini(kind: String, pos: Vector2) -> Enemy:
	var r: Room = world.room
	var info: Dictionary = MINIS[kind]
	var e := Enemy.new()
	e.setup(world, kind, pos - r.position, world.floor_num)
	e.set_meta("mini", true)
	r.objects.add_child(e)
	world.enemies.append(e)
	# a champion: twice the size (redrawn, not stretched), six times the health
	e.max_hp *= MINI_HP
	e.hp = e.max_hp
	e.radius = minf(e.radius * 1.5, 8.0)
	e.heavy = true
	e.def = e.def.duplicate()   # our own copy: a champion hits harder than its kin (and than a guardian)
	e.def["touch"] = MINI_TOUCH
	var sf := _mini_frames(kind)
	if sf:
		e.spr.sprite_frames = sf
		e.spr.play("idle")
		var tex: Texture2D = sf.get_frame_texture("idle", 0)
		e.spr.offset = Vector2(-tex.get_width() / 2.0, -tex.get_height())
		e.half_h = tex.get_height() * 0.4
	if Enemy._shadow_big:
		e.shadow.texture = Enemy._shadow_big
	var gl := PointLight2D.new()
	gl.texture = Art.light_tex
	gl.texture_scale = 0.45
	gl.energy = 0.5
	gl.color = Color(1.0, 0.45, 0.35)
	gl.position = Vector2(0, -14)
	e.add_child(gl)
	_mini = e
	_mini_room = r.data
	_mini_t = 2.6
	_mini_air = false
	world.hud.show_banner(info["name"], info["sub"], 1.8)
	world.hud.set_boss(info["name"], true)
	Audio.play("boss_roar", -4.0, 0.0, 1.25)
	_log("mini %s hp %.0f" % [kind, e.max_hp])
	world.shake(3.0)
	return e


func _mini_frames(kind: String) -> SpriteFrames:
	var sname: String = Enemy.DEFS[kind].get("sprite", kind)
	if not Art.has("specials/mini_%s_idle_f0" % sname):
		return null
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	for a in ["idle", "run", "atk"]:
		if not Art.has("specials/mini_%s_%s_f0" % [sname, a]):
			continue
		sf.add_animation(a)
		sf.set_animation_loop(a, true)
		sf.set_animation_speed(a, {"idle": 6.0, "run": 9.0}.get(a, 8.0))
		for tx in Art.seq("specials/mini_%s_%s" % [sname, a]):
			sf.add_frame(a, tx)
	if not sf.has_animation("run"):
		sf.add_animation("run")
		for tx in Art.seq("specials/mini_%s_idle" % sname):
			sf.add_frame("run", tx)
	return sf


func _tick_mini(dt: float) -> void:
	if _mini == null:
		return
	if not is_instance_valid(_mini) or not _mini.alive:
		_mini_down()
		return
	world.hud.set_boss_frac(_mini.hp / _mini.max_hp)
	if not _mini.active or Juice.holding(world) or world.freeze_t > 0.0 or world.player.dead:
		return
	var e := _mini
	var info: Dictionary = MINIS[e.kind]
	if info["extra"] == "landing_ring":
		# the Rafter King: every landing shakes the floor and throws a ring
		var air := e._jump_h > 3.0
		if _mini_air and not air:
			_mini_attack(e, info["extra"])
		_mini_air = air
		return
	_mini_t -= dt * world.time_scale_enemies()
	if _mini_t <= 0.0:
		_mini_t = randf_range(2.5, 3.3) * (0.8 if e.hp < e.max_hp * 0.5 else 1.0)
		_mini_attack(e, info["extra"])


func _mini_attack(e: Enemy, extra: String) -> void:
	var red := Color(1, 0.35, 0.3)
	var pale := Color(0.9, 0.85, 1.0)
	var at := func() -> Vector2: return e.global_position + Vector2(0, -e.half_h)
	match extra:
		"soot_ring":
			e._telegraph(pale)
			e.tele().ring(e.global_position, 20.0, 0.6, pale)
			e.later(0.6, func():
				world.burst(at.call(), 10, 62.0, "bullet_purple", randf() * TAU)
				world.fx_smoke(at.call()))
		"rent_fan":
			e._telegraph(pale)
			e.later(0.55, func():
				var aim: float = (world.player.global_position - at.call()).angle()
				for k in 5:
					world.enemy_shot(at.call(), Vector2.from_angle(aim + (k - 2) * 0.22) * 78.0, "bolt_bone")
				Audio.play("enemy_shoot", -2.0))
		"ember_ring":
			e._telegraph(red)
			e.tele().ring(e.global_position, 22.0, 0.6, red)
			e.later(0.6, func():
				world.burst(at.call(), 12, 58.0, "bullet_purple")
				Audio.play("burn_whoosh", -2.0))
			e.later(0.9, func(): world.burst(at.call(), 12, 58.0, "bullet_purple", PI / 12.0))
		"landing_ring":
			world.shake(2.5)
			Audio.play("thud_heavy", -2.0)
			world.burst(e.global_position + Vector2(0, -4), 10, 60.0, "bolt_ring", randf() * TAU)
		"tick_burst":
			e._telegraph(pale)
			e.tele().ring(e.global_position, 16.0, 0.5, pale)
			e.later(0.5, func():
				world.burst(at.call(), 8, 70.0, "bolt_ring")
				Audio.play("clock_tick_fast"))
			e.later(0.85, func(): world.burst(at.call(), 8, 70.0, "bolt_ring", PI / 8.0))
		"frost_fan":
			e._telegraph(Color(0.6, 0.9, 1.0))
			e.later(0.5, func():
				var aim: float = (world.player.global_position - at.call()).angle()
				for k in 3:
					world.enemy_shot(at.call(), Vector2.from_angle(aim + (k - 1) * 0.3) * 70.0, "bullet_water")
				Audio.play("splash", -2.0))


func _mini_down() -> void:
	var e := _mini
	_mini = null
	world.hud.set_boss("", false)
	if not _mini_room.is_empty():
		_mini_room["mini_beaten"] = true
	var kind: String = e.kind if is_instance_valid(e) else ""
	if is_instance_valid(e):
		var at: Vector2 = e.global_position
		world.shake(5.0)
		world.hitstop(0.12, 0.1)
		Audio.play("gib")
		for i in 3:
			world.fx_poof(at + Vector2(randf_range(-10, 10), randf_range(-20, -4)), false, 1.6)
		world.fx_stain(at, "soot", true)
	if kind == "" or world.player.dead:
		return
	_log("mini %s beaten" % kind)
	if not kind in minis_beaten:
		minis_beaten.append(kind)
	var all: Array = Game.records.get("minis_beaten", [])
	if not kind in all:
		all.append(kind)
		Game.records["minis_beaten"] = all
		Game.save()
	Achievements.unlock("mini_boss")
	if all.size() >= MINIS.size():
		Achievements.unlock("mini_all")


# ================================================================ the play-test bot

## Where the bot should walk to use this room's prop, or null to leave it alone. It rings the bell
## above 65 wax, winds the box twice when rich, feeds the font twice when healthy,
## and only in the first moments in the room, so it never dawdles.
static func bot_target(w: Node) -> Variant:
	if not w.has_meta("specials") or w.room == null:
		return null
	var s: Specials = of(w)
	var d: Dictionary = w.room.data
	var t: String = d.get("type", "")
	if not t in TYPES or s._prop_room != w.room or w.run_time - s._enter_t > 14.0:
		return null
	var p: Player = w.player
	var go := false
	match t:
		"seance": go = not d.get("rung", false) and p.wax > 65.0
		"musicbox": go = not d.get("box_broken", false) and p.coins >= CRANK_COST * 3 and int(d.get("cranks", 0)) < 2
		"font": go = not d.get("font_spent", false) and p.wax > 75.0 and int(d.get("fed", 0)) < 2
	if not go:
		return null
	if s._busy > 0.0 or s._cool > 0.0:   # step back and wait: each use needs a fresh touch
		return w.room.cell_center(PROP_CELL) + Vector2(0, 38)
	return w.room.cell_center(PROP_CELL) + Vector2(0, 12)


# ================================================================ relics

## A relic from the run's pool for one of our rooms: in one of `pools` and of tier qmin..qmax,
## widening the search if nothing is left. Uses the loot RNG, like the other rooms.
static func pick_relic(w: Node, pools: Array, qmin: int, qmax: int) -> String:
	var fx: RelicFx = RelicFx.of(w)
	for pass_i in 3:
		var cand: Array = []
		var wts: Array = []
		var total := 0.0
		for id in w.relic_pool:
			if not Items.RELICS.has(id) or id in w.player.relics or fx._excluded(id):
				continue
			var dd: Dictionary = Items.RELICS[id]
			var q := int(dd.get("q", 1))
			if pass_i < 2 and (q < qmin or q > qmax):
				continue
			if pass_i < 1:
				var ok := false
				for pl in pools:
					if pl in dd.get("pools", []):
						ok = true
				if not ok:
					continue
			var wt: float = [10.0, 8.0, 5.5, 3.0, 1.4][clampi(q, 0, 4)]
			if qmin >= 3:
				wt = 1.0 + q   # the mirror shows the best it has
			cand.append(id)
			wts.append(wt)
			total += wt
		if cand.is_empty():
			continue
		var roll: float = w.rng.randf() * total
		var pick: String = cand[cand.size() - 1]
		for i in cand.size():
			roll -= wts[i]
			if roll <= 0.0:
				pick = cand[i]
				break
		w.relic_pool.erase(pick)
		return pick
	return RelicFx.next_relic(w)


# ================================================================ offers

## A choice on a pedestal that is not a relic: "read the map", "two tonics", "leave it".
class Offer extends Pickup:
	const NAMES := {"map": "Read the Map", "tonics": "Two Tonics", "veil": "Leave It"}
	const DESCS := {"map": "Every room of this floor, hollows too", "tonics": "Two unlabelled draughts",
		"veil": "Veil the glass and keep your wax (+2 min)"}

	func _ready() -> void:
		var ped := Sprite2D.new()
		ped.texture = Art.tex("pickups/pedestal")
		ped.offset = Vector2(0, -5)
		add_child(ped)
		var s := Sprite2D.new()
		s.texture = Art.tex("specials/offer_" + item)
		s.offset = Vector2(0, -18)
		spr = s
		add_child(s)
		var l := PointLight2D.new()
		l.texture = Art.light_tex
		l.texture_scale = 0.3
		l.energy = 0.45
		l.color = Color(1.0, 0.85, 0.6)
		l.position = Vector2(0, -16)
		add_child(l)

	func _physics_process(dt: float) -> void:
		_t += dt
		if spr:
			spr.position.y = sin(_t * 3.0) * 1.5
		if taken or world.player == null or world.player.dead:
			return
		var p: Player = world.player
		var d := p.global_position.distance_to(global_position)
		if d < 30.0:
			world.hud.preview_item(NAMES.get(item, item), DESCS.get(item, ""))
		if d < 9.0 and _t > 0.6:
			taken = true
			Audio.play("item_get")
			world.fx_ring(global_position + Vector2(0, -16), Color(1.0, 0.8, 0.4))
			var tex: Texture2D = (spr as Sprite2D).texture
			p.hold_aloft(tex)
			Specials.of(world).take_offer(self)
			if record:
				world.forget_pickup(record)
			var tw := create_tween()
			tw.tween_property(self, "scale", Vector2(1.5, 0.2), 0.08)
			tw.tween_callback(queue_free)


# ================================================================ tour (--tour --specials)

static func tour(at: Node) -> void:
	var main: Node = at.main
	main.goto("game", {"seed": 11})
	await at._wait(1.6)
	var w: Node = main.current
	var done := {}
	for n in [2, 3, 4]:
		w._start_floor(n)
		await at._wait(2.9)
		w.player.wax = 100.0
		w.player.coins = 30
		var s: Specials = of(w)
		for t in TYPES:
			if done.has(t) and t != "seance":
				continue   # every room once; the Seance on every floor (its waves change)
			var c := _cell_of_type(w, t)
			if c == Vector2i(-99, -99):
				c = _make_special(w, t)
			if c == Vector2i(-99, -99):
				continue
			done[t] = true
			if t == "mirror":   # the dark door and its toll, seen from the room next door
				for dd in FloorGen.DIRS:
					if w.layout["cells"].has(c + dd):
						w.layout["cells"][c + dd]["cleared"] = true
						at._jump(w, c + dd)
						w.player.position = w.room.center() + Vector2(dd.x, dd.y) * -36.0 + Vector2(dd.y, dd.x) * 26.0
						await at._wait(1.0)
						await at._shot("special_%d_mirror_door" % n)
						break
			at._jump(w, c)
			w.player.position = w.room.center() + Vector2(0, 52)
			await at._wait(1.1)
			await at._shot("special_%d_%s" % [n, t])
			var prop: Vector2 = w.room.cell_center(PROP_CELL)
			match t:
				"seance":
					s._ring()
					await at._wait(2.0)
					await at._shot("special_%d_seance_wave" % n)
					for e in w.enemies:
						if is_instance_valid(e) and e.alive:
							e.hp = 0.0
							e._die()
					await at._wait(2.0)
					for e in w.enemies:
						if is_instance_valid(e) and e.alive:
							e.hp = 0.0
							e._die()
					await at._wait(2.2)
					await at._shot("special_%d_seance_wave2" % n)
				"musicbox":
					w.player.position = prop + Vector2(14, 6)
					await at._wait(0.45)
					await at._shot("special_%d_musicbox_crank" % n)
					w.player.position = w.room.center() + Vector2(0, 52)
					await at._wait(0.9)
					await at._shot("special_%d_musicbox_tune" % n)
				"font":
					for k in 3:
						w.player.position = prop + Vector2(-14, 6)
						await at._wait(0.35)
						w.player.position = w.room.center() + Vector2(-20, 52)
						await at._wait(0.9)
					await at._shot("special_%d_font_fed" % n)
				"mirror", "study":
					w.player.position = w.room.center() + Vector2(-30, 46)
					await at._wait(0.6)
					await at._shot("special_%d_%s_offer" % [n, t])
			at._jump(w, w.layout["start"])
			await at._wait(0.3)
		# the mini-boss of this floor
		var mc := _cell_of_mini(w)
		if mc == Vector2i(-99, -99):
			mc = _normal_far(w)
			w.layout["cells"][mc]["mini"] = minis_for(n)[0]
		w.layout["cells"][mc]["cleared"] = false
		at._jump(w, mc)
		w.player.position = w.room.center() + Vector2(0, 46)
		await at._wait(1.6)
		w.player.wax = 100.0
		await at._shot("mini_%d_%s" % [n, w.layout["cells"][mc]["mini"]])
		await at._wait(1.4)
		await at._shot("mini_%d_fight" % n)
		if s._mini and is_instance_valid(s._mini):
			s._mini.hp = 0.0
			s._mini._die()
		await at._wait(1.6)
		await at._shot("mini_%d_reward" % n)
	# the minimap: special rooms you have not looked into are "?", the Dowsing Rod names them
	w._start_floor(3)
	await at._wait(3.0)
	for c in w.layout["cells"]:
		var d: Dictionary = w.layout["cells"][c]
		if d["type"] in TYPES or d["type"] == "normal":
			d["seen"] = true
	await at._wait(0.2)
	await at._shot("special_minimap")
	w.player.relics.append("dowsing_rod")
	w._on_enter_room()
	await at._wait(0.4)
	await at._shot("special_minimap_dowsing")
	# all six champions in a row (frozen), with a plain lodger for scale
	var gc := _normal_far(w)
	w.layout["cells"][gc]["cleared"] = true
	w.layout["cells"][gc]["grid"] = RoomTemplates.to_grid(RoomTemplates.START)
	at._jump(w, gc)
	w.player.position = w.room.center() + Vector2(0, 56)
	var s2: Specials = of(w)
	var k := 0
	for kind in MINIS:
		var e := s2.spawn_mini(kind, w.room.center() + Vector2(-100 + k * 40, -6))
		k += 1
		e.set_physics_process(false)
	var plain: Enemy = w.spawn_enemy("sootling", w.room.center() + Vector2(-100, 34))
	await at._wait(0.2)
	plain.set_physics_process(false)
	for e in w.enemies:
		if is_instance_valid(e):
			e.spr.modulate.a = 1.0
			e.scale = Vector2.ONE
	s2._mini = null
	w.hud.set_boss("", false)
	await at._wait(2.2)
	await at._shot("mini_gallery")


static func _cell_of_type(w: Node, t: String) -> Vector2i:
	for c in w.layout["cells"]:
		if w.layout["cells"][c]["type"] == t:
			return c
	return Vector2i(-99, -99)


static func _cell_of_mini(w: Node) -> Vector2i:
	for c in w.layout["cells"]:
		if w.layout["cells"][c].has("mini"):
			return c
	return Vector2i(-99, -99)


static func _normal_far(w: Node) -> Vector2i:
	var best := Vector2i(-99, -99)
	for c in w.layout["cells"]:
		var d: Dictionary = w.layout["cells"][c]
		if d["type"] == "normal" and (best == Vector2i(-99, -99) or int(d["dist"]) > int(w.layout["cells"][best]["dist"])):
			best = c
	return best


## Tours only: add a special room of type `t` off an ordinary room, the way FloorGen does.
static func _make_special(w: Node, t: String) -> Vector2i:
	var cells: Dictionary = w.layout["cells"]
	for c in cells.keys():
		if cells[c]["type"] != "normal":
			continue
		for dd in FloorGen.DIRS:
			var n: Vector2i = c + dd
			if n.x < 0 or n.y < 0 or n.x >= FloorGen.W or n.y >= FloorGen.H or cells.has(n):
				continue
			var k := 0
			for d2 in FloorGen.DIRS:
				if cells.has(n + d2):
					k += 1
			if k == 1:
				cells[n] = {"type": t, "grid": grid_for(t), "cleared": true, "visited": false, "seen": false,
					"pickups": [], "seed": hash("%s:%s" % [t, n]), "dist": int(cells[c]["dist"]) + 1}
				return n
	return Vector2i(-99, -99)
