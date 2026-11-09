class_name MovesBot
extends RefCounted
## v2.3: how the play-test bot (scripts/autotest.gd) uses the candle's special move, so balance runs
## include the moves. One simple rule per move, read from the room every physics step while it fights:
##   Skip / Blink   an enemy shot about to hit (or a lodger about to touch): away, across its path
##   Slam / Sparkler  3+ lodgers in reach (the Sparkler also fires at 3+ shots in its radius)
##   Flare Up / Snuff  a guardian in the fight (Flare only above 30 minutes of wax)
## `--nomoves` (Moves.enabled false) turns the moves off for a with / without comparison.

const SHOT_LOOK := 0.35        # s ahead: a shot that will pass this close in that time is "about to hit"
const SHOT_NEAR := 9.0         # px
const CROWD := 3


static func think(w: Node, _mv: Vector2, tgt: Node) -> void:
	var p: Player = w.player
	if p == null or not p.move_ready():
		return
	var id := Moves.for_candle(p.candle_id)
	var pos := p.global_position + Vector2(0, -8)
	match id:
		"skip", "blink":
			var away := _threat(w, p, pos)
			if away != Vector2.ZERO:
				p.use_move(away)
		"slam", "sparkler":
			var r := Moves.SLAM_R if id == "slam" else Moves.SPARK_R * 0.8
			var near := 0
			for e in w.enemies:
				if is_instance_valid(e) and e.alive and e.active and not e.boss and not e.buried \
						and e.global_position.distance_to(p.global_position) <= r + e.radius:
					near += 1
			var shots := 0
			if id == "sparkler":
				for s in w.enemy_shots:
					if is_instance_valid(s) and not s._dead and s.global_position.distance_to(pos) < Moves.SPARK_R * 0.8:
						shots += 1
			if near >= CROWD or shots >= CROWD:
				p.use_move()
		"flare", "snuff":
			var b: Variant = w.get("boss")
			var guardian: bool = b != null and is_instance_valid(b) and b.alive and b.active
			if guardian and (id == "snuff" or p.wax > 30.0) and tgt != null:
				p.use_move()


## The way out of the most pressing danger, or zero: a shot whose path passes within SHOT_NEAR px
## in the next SHOT_LOOK s (dodge across its line, to the side the candle is already on), else a
## lodger closing to touching distance (straight away from it). Directions that run into a wall in
## 30 px are turned round.
static func _threat(w: Node, p: Player, pos: Vector2) -> Vector2:
	var best := 1e9
	var dir := Vector2.ZERO
	for s in w.enemy_shots:
		if not is_instance_valid(s) or s._dead or s.vel.length_squared() < 1.0:
			continue
		var rel: Vector2 = pos - s.global_position
		var v: Vector2 = s.vel
		var t := rel.dot(v) / v.length_squared()   # time of the closest approach
		if t < 0.0 or t > SHOT_LOOK:
			continue
		var miss := (rel - v * t).length()
		if miss < SHOT_NEAR and t < best:
			best = t
			var side := v.normalized().orthogonal()
			dir = side * (1.0 if side.dot(rel) >= 0.0 else -1.0)
	if dir == Vector2.ZERO:
		for e in w.enemies:
			if not is_instance_valid(e) or not e.alive or not e.active or e.buried:
				continue
			var rel2: Vector2 = p.global_position - e.global_position
			if rel2.length() < e.radius + 9.0 and rel2.length() < best:
				best = rel2.length()
				dir = rel2.normalized() if rel2.length() > 0.1 else Vector2.RIGHT
	if dir == Vector2.ZERO:
		return dir
	var room: Room = w.room
	if room and room.blocked(p.global_position + dir * 30.0, Player.RADIUS):
		dir = -dir
	return dir


## One line per run for the playtest log: "moves: skip x14" ("moves: off" with --nomoves).
static func report() -> String:
	if not Moves.enabled:
		return "moves: off (--nomoves)"
	if Moves.uses.is_empty():
		return "moves: none used"
	var parts: Array = []
	for k in Moves.uses:
		parts.append("%s x%d" % [k, int(Moves.uses[k])])
	return "moves: " + ", ".join(parts)
