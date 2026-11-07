extends Node
## Audio check (-- --autotest --audiotest): proves every sound name exists, exercises the live mix through the
## real game hooks and prints [audio] PASS / FAIL lines plus timed marks. Run it under Godot's movie writer
## (--write-movie out.avi) and tools/import_audio.py `mixcheck` reads the captured sound against the marks.

## Every name the game and the other streams may call (docs/streams/audio.md).
const NAMES := [
	"shoot", "hit_wall", "hit_enemy", "enemy_die", "enemy_shoot", "player_hurt", "wax_pickup", "coin_pickup",
	"bomb_pickup", "bomb_place", "explosion", "door_open", "door_close", "room_clear", "item_get", "chest_open",
	"urn_break", "crate_break", "boss_roar", "boss_die", "bell_toll", "tick", "ui_click", "ui_back", "ui_open",
	"low_wax", "snuff_out", "victory", "shop_buy", "step", "charge", "teleport", "splash", "trapdoor",
	"boss_sting", "match_strike", "burn_whoosh", "splat", "gib", "sizzle", "relic_fanfare", "achievement",
	"ui_move", "door_burst", "fire_crackle", "jar_explode", "web", "page_flip", "bell_small", "clock_tick_fast",
	"moth_flutter", "wax_bubble", "thud_heavy", "summon", "beam_loop", "charge_up", "dodge", "unlock",
]
const TAKES := {"shoot": 3, "hit_enemy": 3, "enemy_die": 3, "step": 4, "coin_pickup": 3, "hit_wall": 3, "splash": 3}
const MUSIC := ["title", "floor_1", "floor_2", "floor_3", "floor_4", "shop", "boss", "final_boss",
	"victory_jingle", "death_jingle"]

var main: Node
var fails := 0


func _ready() -> void:
	main = get_parent().get_parent()
	process_mode = Node.PROCESS_MODE_ALWAYS
	_run()


func _check(ok: bool, what: String) -> void:
	print("[audio] %s %s" % ["PASS" if ok else "FAIL", what])
	if not ok:
		fails += 1


func _mark(what: String) -> void:
	print("[audio] mark %.3f %s" % [Audio._clock, what])


func _wait(s: float) -> void:
	await get_tree().create_timer(s, true, false, true).timeout


func _run() -> void:
	# 1. the catalogue
	var missing: Array = []
	for n in NAMES:
		if not Audio.has_sound(n):
			missing.append(n)
	_check(missing.is_empty(), "every sound name exists (%d names)%s" % [NAMES.size(), "" if missing.is_empty() else " missing " + str(missing)])
	for n in TAKES:
		_check(Audio._get_takes(n).size() == TAKES[n], "%s has %d takes" % [n, TAKES[n]])
	var mm: Array = []
	for m in MUSIC:
		if Audio._load(Audio.MUSIC_DIR + m) == null:
			mm.append(m)
	_check(mm.is_empty(), "every music slot exists%s" % ("" if mm.is_empty() else " missing " + str(mm)))
	for m in ["title", "floor_1", "shop", "boss"]:
		var st := Audio._load(Audio.MUSIC_DIR + m) as AudioStreamOggVorbis
		_check(st != null and st.loop, "%s loops on import" % m)
	Audio.play("definitely_not_a_sound")
	Audio.play("")
	_check(not Audio.has_sound("definitely_not_a_sound"), "unknown names are skipped silently")
	# 2. the live mix, through the real hooks
	_mark("title")
	await _wait(2.5)
	main.goto("game", {"seed": 11})
	await _wait(1.8)
	var w: Node = main.current
	_check(Audio.current_music == "floor_1", "floor 1 plays floor_1 (got %s)" % Audio.current_music)
	_check(Audio.space == 1, "floor 1 sets the cellar space")
	_check(is_equal_approx(Audio.music_intensity, 0.5), "the start room (already clear) gets the calm mix")
	Audio.set_intensity(1.0)
	_mark("combat")
	await _wait(3.0)
	w.room.data["cleared"] = false
	w._clear_room()
	_check(is_equal_approx(Audio.music_intensity, 0.5), "_clear_room sets the calm mix")
	_mark("cleared")
	await _wait(3.0)
	w.toggle_pause()
	_check(Audio.music_paused, "toggle_pause muffles the music")
	_mark("paused")
	await _wait(3.0)
	w.toggle_pause()
	_check(not Audio.music_paused, "unpausing restores the music")
	Audio.set_intensity(1.0)
	_mark("unpaused")
	await _wait(2.5)
	Audio.duck(-8.0, 1.0)
	_mark("duck")
	await _wait(2.5)
	w.player.wax = 9.0
	await _wait(0.3)
	_check(Audio.low_wax, "low wax turns the heartbeat layer on")
	_mark("lowwax")
	await _wait(3.5)
	w.player.wax = 100.0
	await _wait(0.3)
	_check(not Audio.low_wax, "the layer turns off when wax is back")
	_mark("lowwax_end")
	await _wait(2.5)
	Audio.enter_room("shop", true)
	_check(Audio.current_music == "shop", "a shop plays the merchant's tune")
	_mark("shop")
	await _wait(3.0)
	Audio.enter_room("normal", false)
	_check(Audio.current_music == "floor_1", "leaving the shop resumes floor_1")
	_mark("floor_resume")
	await _wait(2.5)
	Audio.music("boss")
	_check(Audio._pool_name.has("boss_sting"), "boss music brings its sting")
	_mark("boss")
	await _wait(3.0)
	_mark("burst")
	for i in 40:
		Audio.play("shoot")
		Audio.play("hit_enemy", 0.0, 0.1)
		if i % 4 == 0:
			Audio.play("enemy_die")
		if i % 13 == 0:
			Audio.play("explosion")
		await _wait(0.025)
	await _wait(2.0)
	Audio.music("")
	await _wait(1.8)
	for f in [1, 2, 3, 4]:
		Audio.set_space(f)
		_mark("space_%d" % f)
		Audio.play("door_close", 0.0, 0.0)
		await _wait(1.6)
	Audio.set_space(1)
	_mark("every_sound")
	for n in NAMES:
		Audio.play(n, -6.0)
		await _wait(0.12)
	await _wait(1.5)
	var id := Audio.loop_start("beam_loop", w)
	_check(id > 0, "loop_start returns an id")
	_mark("loop")
	await _wait(1.5)
	Audio.loop_stop(id)
	await _wait(0.5)
	_mark("death")
	Audio.music("death_jingle", 0.3)
	Audio.play("snuff_out")
	Audio.play("bell_toll", 0.0, 0.0, 0.9)
	await _wait(3.5)
	_check(not Audio.low_wax and is_equal_approx(Audio.music_intensity, 1.0), "a jingle resets the mix")
	_mark("end")
	print("[audio] done: %d failed" % fails)
	Audio.stop_all()
	main.goto("title")
	await _wait(0.6)
	Audio.stop_all()
	await _wait(0.3)
	get_tree().quit(1 if fails > 0 else 0)
