class_name Pickup
extends Node2D
## Wax, coins, bombs, relics on pedestals, shop goods, chests and the trapdoor.
## Position = ground point. Collected by touching it.

var world: Node
var kind := ""        # wax_small wax_big coin bomb relic tonic chest trapdoor
var item := ""        # relic / tonic id
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
		"wax_big":
			spr = _sprite("pickups/wax_big", Vector2(0, -7))
		"relic", "tonic":
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
	add_child(spr)
	if price > 0:
		price_label = UI.label("%d" % price, 8, UI.GOLD, HORIZONTAL_ALIGNMENT_CENTER)
		price_label.position = Vector2(-12, 3)
		price_label.size = Vector2(24, 8)
		var coin := Sprite2D.new()
		coin.texture = Art.tex("ui/icon_coin") if Art.has("ui/icon_coin") else Art.tex("0x72/coin_anim_f0")
		coin.position = Vector2(-9, 7)
		add_child(price_label)
		add_child(coin)
		_refresh_price()


func _refresh_price() -> void:
	if price_label:
		var p: int = int(round(price * world.shop_discount))
		price_label.text = "%d" % p


func _sprite(path: String, off: Vector2) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = Art.tex(path)
	s.offset = off
	return s


func _physics_process(dt: float) -> void:
	_t += dt
	if vel.length() > 1:
		var np := position + vel * dt
		if world.room and not world.room.blocked(np, 3.0):
			position = np
		else:
			vel = -vel * 0.4
		vel = vel.move_toward(Vector2.ZERO, 220 * dt)
	if _vz != 0.0 or _z > 0:
		_vz -= 260 * dt
		_z = maxf(0.0, _z + _vz * dt)
		if _z == 0.0 and _vz < 0:
			_vz = -_vz * 0.35 if absf(_vz) > 30 else 0.0
	if spr:
		var bob := 0.0
		if kind in ["relic", "tonic"]:
			bob = sin(_t * 3.0) * 1.5
		spr.position.y = -_z + bob
	if taken or world.player == null or world.player.dead:
		return
	var p: Player = world.player
	var d := p.global_position.distance_to(global_position)
	var reach := 9.0 if kind in ["relic", "tonic", "chest"] else 8.0
	if kind == "trapdoor":
		reach = 7.0
	if d < reach and _t > 0.35:
		_collect(p)
	elif kind in ["coin", "wax_small", "wax_big", "bomb"] and d < 22.0 and p.luck > 0.0 and _t > 0.5:
		position = position.move_toward(p.global_position, 40.0 * dt)


func _collect(p: Player) -> void:
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
			var amt := 6.0 if kind == "wax_small" else 18.0
			p.heal(amt)
			Audio.play("wax_pickup")
			world.fx_text(global_position + Vector2(0, -14), "+%d min" % int(amt), UI.WAX)
			_take()
		"relic", "tonic":
			world.collect_item(item, global_position)
			_take()
		"chest":
			if opened:
				return
			opened = true
			(spr as AnimatedSprite2D).play("default")
			Audio.play("chest_open")
			world.open_chest(global_position)
			if record:
				world.forget_pickup(record)
				record = {}
		"trapdoor":
			taken = true
			world.descend()


func _take() -> void:
	taken = true
	if record:
		world.forget_pickup(record)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.5, 0.2), 0.08)
	tw.tween_callback(queue_free)
