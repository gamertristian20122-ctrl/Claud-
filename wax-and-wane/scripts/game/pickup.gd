class_name Pickup
extends Node2D
## Wax, coins, bombs, relics on pedestals, shop goods, chests and the trapdoor.
## Position = ground point. Collected by touching it.

var world: Node
var kind := ""        # wax_small wax_big coin bomb relic tonic chest trapdoor page
var item := ""        # relic / tonic id; a diary page's id (scripts/game/diary.gd)
var price := 0
var spr: Node2D
var vel := Vector2.ZERO
var _z := 0.0
var _vz := 0.0
var _t := 0.0
var taken := false
var opened := false
var record: Dictionary   # the room's saved entry for this pickup (removed when taken)
var price_label: Label
var _last_coins := -1
var value := 0.0          # wax_warm: minutes it gives back
var life := 0.0           # wax_warm: seconds before it cools and vanishes
var _wait_leave := false  # after a keepsake swap, wait until the player steps away
var _sweep_v := 0.0       # v2.6: the pickup magnet's speed (0 = resting)

## v2.6 (feel): once a room is clear, its loose drops drift to Tallow on their own (Settings > Game > Pickup
## magnet). They land first (SWEEP_SETTLE), hop, then speed up toward the candle.
const SWEEP_SETTLE := 0.45
const SWEEP_ACCEL := 520.0
const SWEEP_MAX := 230.0


func setup(w: Node, k: String, pos: Vector2, it := "", pr := 0) -> void:
	world = w
	kind = k
	item = it
	price = pr
	position = pos


func pop(v: Vector2) -> void:
	vel = v
	_vz = 70.0


func _ready() -> void:
	match kind:
		"coin":
			var a := AnimatedSprite2D.new()
			a.sprite_frames = Art.anim("0x72/coin_anim", 8.0)
			a.play("default")
			a.frame = randi() % 4
			a.offset = Vector2(0, -4)
			spr = a
		"bomb":
			spr = _sprite("0x72/bomb_f0", Vector2(0, -6))
		"wax_small":
			spr = _sprite("pickups/wax_small", Vector2(0, -5))
		"wax_warm":
			spr = _sprite("pickups/wax_small", Vector2(0, -5))
			life = 2.5
		"wax_big":
			spr = _sprite("pickups/wax_big", Vector2(0, -7))
		"match":
			var a := AnimatedSprite2D.new()
			a.sprite_frames = Art.anim("pickups/match", 8.0)
			a.play("default")
			a.offset = Vector2(0, -6)
			spr = a
		"relic", "tonic", "keepsake":
			var ped := _sprite("pickups/pedestal", Vector2(0, -5))
			add_child(ped)
			spr = _sprite(Items.icon(item), Vector2(0, -18))
			var l := PointLight2D.new()
			l.texture = Art.light_tex
			l.texture_scale = 0.35
			l.energy = 0.6
			l.color = Color(1.0, 0.85, 0.6)
			l.position = Vector2(0, -16)
			add_child(l)
		"chest":
			var a := AnimatedSprite2D.new()
			a.sprite_frames = Art.anim("0x72/chest_full_open_anim", 10.0, false)
			a.offset = Vector2(0, -8)
			spr = a
		"trapdoor":
			var s := _sprite("rooms/trapdoor_open" if Art.has("rooms/trapdoor_open") else "0x72/floor_ladder", Vector2(0, 0))
			s.z_index = -14
			spr = s
		"page":   # v2.5: a torn diary page, fluttering a hand's breadth off the floor (tools/art_story.py)
			var a := AnimatedSprite2D.new()
			a.sprite_frames = Art.anim("story/page", 6.0)
			a.play("default")
			a.frame = randi() % 4
			a.offset = Vector2(-6, -19)
			a.centered = false
			spr = a
	add_child(spr)
	if kind in ["coin", "wax_small", "wax_big", "bomb", "wax_warm", "page"]:
		spr.material = Art.unshaded
	var wax_cost: int = int(record.get("cost_wax", 0)) if record else 0
	if wax_cost > 0:
		# Smoke Altar: paid in minutes cut from the top of the candle
		var lbl := UI.outlined(UI.label("%d" % wax_cost, 8, UI.RED, HORIZONTAL_ALIGNMENT_CENTER))
		lbl.position = Vector2(-12, 3)
		lbl.size = Vector2(24, 8)
		lbl.material = Art.unshaded
		var ic := Sprite2D.new()
		ic.texture = Art.tex("pickups/wax_small")
		ic.position = Vector2(-10, 7)
		ic.material = Art.unshaded
		add_child(lbl)
		add_child(ic)
	if price > 0:
		price_label = UI.outlined(UI.label("%d" % price, 8, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER))
		price_label.position = Vector2(-12, 3)
		price_label.size = Vector2(24, 8)
		var coin := Sprite2D.new()
		coin.texture = Art.tex("ui/icon_coin") if Art.has("ui/icon_coin") else Art.tex("0x72/coin_anim_f0")
		coin.position = Vector2(-9, 7)
		price_label.material = Art.unshaded
		coin.material = Art.unshaded
		add_child(price_label)
		add_child(coin)
		_refresh_price()


func _refresh_price() -> void:
	if price_label:
		var p: int = int(round(price * world.shop_discount))
		price_label.text = "%d" % p
		price_label.add_theme_color_override("font_color", UI.GOLD if world.player and world.player.coins >= p else UI.DIM)


func _sprite(path: String, off: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Art.tex(path)
	s.offset = off
	return s


func _physics_process(dt: float) -> void:
	_t += dt
	if vel.length() > 1:
		var np := global_position + vel * dt
		if world.room and not world.room.blocked(np, 3.0):
			global_position = np
		else:
			vel = -vel * 0.4
		vel = vel.move_toward(Vector2.ZERO, 220 * dt)
	if _vz != 0.0 or _z > 0:
		_vz -= 260 * dt
		_z = maxf(0.0, _z + _vz * dt)
		if _z == 0.0 and _vz < 0:
			_vz = -_vz * 0.35 if absf(_vz) > 30 else 0.0
	if kind == "wax_warm":
		life -= dt
		var k := clampf(1.0 - life / 2.5, 0.0, 1.0)
		spr.modulate = Color("#ee8e2e").lerp(Color("#775c55"), k)
		spr.visible = life > 0.9 or fmod(life, 0.2) > 0.08
		if life <= 0.0 and not taken:
			taken = true
			world.fx_smoke(global_position + Vector2(0, -6))
			queue_free()
			return
	if spr:
		var bob := 0.0
		if kind in ["relic", "tonic", "keepsake"]:
			bob = sin(_t * 3.0) * 1.5
		elif kind == "page":
			bob = roundf(sin(_t * 2.4) * 2.0)
		spr.position.y = -_z + bob
	if price_label and world.player and world.player.coins != _last_coins:
		_last_coins = world.player.coins
		_refresh_price()
	if taken or world.player == null or world.player.dead:
		return
	var p: Player = world.player
	var d := p.global_position.distance_to(global_position)
	if kind in ["relic", "tonic", "wax_big", "keepsake"] and d < 30.0 and (kind != "wax_big" or price > 0):
		var nm := Items.display_name(item) if kind != "wax_big" else "Fresh Candle Stub"
		var ds := Items.desc(item) if kind != "wax_big" else "+18 minutes of wax"
		if price > 0:
			ds += "   -   %d coins" % int(round(price * world.shop_discount))
		if record and int(record.get("cost_wax", 0)) > 0:
			ds += "   -   Costs %d max minutes (%d now)" % [int(record["cost_wax"]), int(record["cost_wax"]) / 2]
			var wc := float(record["cost_wax"])
			if p.wax_max - wc >= float(Candles.def_of(world.candle_id)["wax"]) * 0.45:
				world.hud.preview_cost(pact_cut(p, wc), wc)   # design pass: the trade, shown on the wax bar
		var rite := Items.rite_progress_text(item, p) if kind == "relic" else ""
		if rite != "":
			ds += "   [%s]" % rite
		Records.see(item)   # the Journal: seen
		world.hud.preview_item(nm, ds)
	if kind == "page" and d < 26.0:
		world.hud.preview_item(L.t("A torn page"), L.t("From someone's diary. Walk over it to read it"))
	var reach := 9.0 if kind in ["relic", "tonic", "chest", "keepsake", "page"] else 8.0
	if kind == "trapdoor":
		reach = 7.0
	if _wait_leave and d > reach + 6.0:
		_wait_leave = false
	var pull := RelicFx.pull(world)   # Lucky Ash, Lodestone, Sweep's Brush
	var wants := kind in ["coin", "bomb"] or (kind in ["wax_small", "wax_big"] and p.wax < p.wax_max - 0.5)
	if d < reach and _t > 0.35:
		_collect(p)
	elif _t > SWEEP_SETTLE and float(world.calm_t) > SWEEP_SETTLE and Game.settings.get("magnet", true) and _sweep_wants(p):
		if _sweep_v == 0.0:
			_vz = 55.0   # a little hop as it lifts off the floor
			world.on_sweep()
		_sweep_v = minf(_sweep_v + SWEEP_ACCEL * dt, SWEEP_MAX)
		global_position = global_position.move_toward(p.global_position, _sweep_v * dt)
	elif wants and price == 0 and d < pull.x and _t > 0.5:
		global_position = global_position.move_toward(p.global_position, pull.y * dt)
	elif kind == "wax_warm" and d < 12.0 and _t > 0.3:
		global_position = global_position.move_toward(p.global_position, 40.0 * dt)


## Minutes a wax drop gives (wax_small 6, wax_big 18, times the level's drip bonus and the Honeycomb).
func wax_amount() -> float:
	return (6.0 if kind == "wax_small" else 18.0) * world.wax_bonus() * RelicFx.wax_mult(world)


## The pickup magnet takes loose drops Tallow can use now: coins, bombs, diary pages, wax the candle has room for
## (at least half of it: a stub is not wasted on a scratch, it waits in the room for a deeper cut), a match for
## a keepsake that is not full. Prices, pedestals (relics, tonics, keepsakes), chests, the trapdoor
## and a pact's goods stay where they are.
func _sweep_wants(p: Player) -> bool:
	if price > 0 or (record and (int(record.get("cost_wax", 0)) > 0 or str(record.get("group", "")) != "")):
		return false
	match kind:
		"coin", "bomb", "page":
			return true
		"wax_small", "wax_big":
			return p.wax_max - p.wax >= wax_amount() * 0.5   # never wastes most of a stub: it waits for a deeper cut
		"wax_warm":
			return p.wax < p.wax_max - 0.5
		"match":
			return p.keepsake != "" and p.charge < int(Items.KEEPSAKES[p.keepsake]["pips"])
	return false


## Wax a Smoke Altar / Cracked Mirror relic takes right now (as _collect does it: half the price,
## never below 15 minutes, and never above the shortened candle).
static func pact_cut(p: Player, cost: float) -> float:
	var cut := minf(cost * 0.5, maxf(0.0, p.wax - 15.0))
	return p.wax - minf(p.wax - cut, p.wax_max - cost)


func _collect(p: Player) -> void:
	if kind == "keepsake" and (_t < 1.0 or _wait_leave):
		return
	var wax_cost: int = int(record.get("cost_wax", 0)) if record else 0
	if wax_cost > 0:
		if p.wax_max - wax_cost < float(Candles.def_of(world.candle_id)["wax"]) * 0.45:
			if _t > 1.0:
				world.fx_text(global_position + Vector2(0, -28), "not enough wax", UI.RED)
				_t = 0.36
			return
		p.wax_max -= wax_cost
		p.charred += wax_cost
		# the clock visibly jumps forward, but never below 15 minutes
		var cut := minf(wax_cost * 0.5, maxf(0.0, p.wax - 15.0))
		p.wax = minf(p.wax - cut, p.wax_max)
		if record.has("pact"):
			Specials.on_pact(world, record)   # the Cracked Mirror reuses this cost
		else:
			world.pact = "smoke"
		world.fx_text(global_position + Vector2(0, -30), ("-%d max min" % wax_cost) + (("  -%d now" % int(cut)) if cut > 0.0 else ""), UI.RED)
		Audio.play("snuff_out", 0.0, 0.0, 0.7)
		record["cost_wax"] = 0
	if price > 0:
		var cost := int(round(price * world.shop_discount))
		if kind in ["wax_small", "wax_big"] and p.wax >= p.wax_max - 0.5:
			return
		if p.coins < cost:
			if _t > 1.0:
				world.fx_text(global_position + Vector2(0, -28), "need %d" % cost, UI.RED)
				_t = 0.36
			return
		p.coins -= cost
		price = 0
		if record:
			record["price"] = 0
		Audio.play("shop_buy")
	match kind:
		"coin":
			p.coins += 1
			Audio.play("coin_pickup")
			_take()
		"bomb":
			p.bombs += 1
			Audio.play("bomb_pickup")
			_take()
		"wax_small", "wax_big":
			if p.wax >= p.wax_max - 0.5:
				return
			var amt := wax_amount()
			p.heal(amt)
			Audio.play("wax_pickup")
			world.fx_text(global_position + Vector2(0, -14), "+%d min" % int(amt), UI.WAX)
			_take()
		"wax_warm":
			p.heal(value)
			Audio.play("wax_pickup", 0.0, 0.05, 1.3)
			world.fx_text(global_position + Vector2(0, -14), "+%.1f min" % value, UI.GOLD)
			_take()
		"relic", "tonic":
			world.collect_item(item, global_position, record if record else {})
			_take()
		"keepsake":
			var old := p.keepsake
			var old_charge := p.charge
			p.keepsake = item
			p.charge = int(record.get("charge", 0)) if record else 0
			world.on_keepsake_taken(item, global_position, record if record else {})
			if old != "":
				# swap: leave the old keepsake on this pedestal
				item = old
				(spr as Sprite2D).texture = Art.tex(Items.icon(old))
				if record:
					record["item"] = old
					record["charge"] = old_charge
				_wait_leave = true
			else:
				_take()
		"match":
			if p.keepsake == "" or p.charge >= int(Items.KEEPSAKES[p.keepsake]["pips"]):
				return
			p.charge += 1
			Audio.play("tick", 0.0, 0.0, 1.5)
			world.fx_text(global_position + Vector2(0, -14), "+1 charge", UI.GOLD)
			_take()
		"chest":
			if opened:
				return
			opened = true
			(spr as AnimatedSprite2D).play("default")
			Audio.play("chest_open")
			world.open_chest(global_position)
			RelicFx.on_chest(world, global_position)
			if record:
				world.forget_pickup(record)
				record = {}
		"trapdoor":
			taken = true
			world.descend()
		"page":
			Diary.collect(world, item, global_position, record if record else {})
			_take()


## A helper (the Dust Bunny) brings this coin or bomb to Tallow.
func fetch(p: Player) -> void:
	if taken or price > 0 or not kind in ["coin", "bomb"]:
		return
	_t = maxf(_t, 0.4)
	_collect(p)


func _take() -> void:
	taken = true
	if record:
		world.forget_pickup(record)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.5, 0.2), 0.08)
	tw.tween_callback(queue_free)
