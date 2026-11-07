extends Node
## Music and sound for the whole game (autoload "Audio"). Missing or unknown sounds are skipped silently.
##
## Buses (default_bus_layout.tres; recreated here if the layout is missing):
##   Master <- HardLimiter, so stacked sounds never clip
##   Music  <- the player's music volume (Game.settings) + a LowPassFilter driven by set_intensity / set_paused
##   SFX    <- the player's sound volume; "dry" sounds (UI, pickups, the hurt sound, the low-wax layer)
##   Room   -> SFX   world sounds; a Reverb that set_space() shapes per floor (cellar dry ... chapel big)
##   Score  -> Music the two music players; its volume carries intensity + ducking
##
## Public API (see docs/streams/audio.md):
##   play(name, volume_db, pitch_jitter, pitch)   one-shot; picks a random take (<name>_2.ogg ...) + pitch/level jitter
##   music(name, fade) / jingle(name)            cross-faded music; floor and shop tracks resume where they left off
##   enter_room(type, cleared)                   shop music in shops, calm mix in cleared rooms, full mix in fights
##   set_intensity(x) / set_paused(on)           1 = fight, 0.5 = cleared (gentle low-pass), paused = strong low-pass
##   duck(db, secs)                              dip the music for a big moment (big sounds also duck on their own)
##   set_low_wax(on, frac)                       heartbeat + ticking layer while the candle is nearly out
##   set_space(floor_num)                        per-floor reverb on world sounds (0 = none)
##   loop_start(name, follow, volume_db, pitch) -> id, loop_stop(id, fade)   looping sounds (beam_loop ...)
##   stop_all()                                  silence everything (e.g. before quitting)

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL_SIZE := 24
const MAX_TAKES := 6

## Minimum seconds between two plays of the same effect (keeps busy rooms from turning into noise).
const THROTTLE := {
	"shoot": 0.05, "hit_enemy": 0.04, "hit_wall": 0.05, "enemy_die": 0.05, "enemy_shoot": 0.06,
	"coin_pickup": 0.04, "wax_pickup": 0.05, "step": 0.12, "tick": 0.2, "ui_click": 0.03, "ui_move": 0.04,
	"splash": 0.06, "splat": 0.05, "gib": 0.06, "sizzle": 0.12, "fire_crackle": 0.3, "moth_flutter": 0.15,
	"wax_bubble": 0.15, "web": 0.08, "page_flip": 0.06, "clock_tick_fast": 0.1, "dodge": 0.08,
	"boss_sting": 2.0,
}
## Level trim per sound, in dB (the files are loudness-matched by tools/make_audio.py; this sets the mix).
const VOLUME := {
	"shoot": -9.0, "hit_wall": -12.0, "hit_enemy": -7.0, "enemy_die": -5.0, "enemy_shoot": -9.0,
	"step": -16.0, "tick": -8.0, "ui_click": -6.0, "ui_back": -6.0, "ui_open": -6.0,
	"coin_pickup": -6.0, "wax_pickup": -4.0, "low_wax": -3.0, "bell_toll": -2.0,
	"boss_sting": 0.0, "match_strike": -4.0, "burn_whoosh": -4.0, "splat": -5.0, "gib": -4.0, "sizzle": -6.0,
	"relic_fanfare": -1.0, "achievement": -3.0, "ui_move": -8.0, "door_burst": -2.0, "fire_crackle": -8.0,
	"jar_explode": -3.0, "web": -5.0, "page_flip": -5.0, "bell_small": -3.0, "clock_tick_fast": -4.0,
	"moth_flutter": -8.0, "wax_bubble": -7.0, "thud_heavy": -2.0, "summon": -3.0, "beam_loop": -6.0,
	"charge_up": -4.0, "dodge": -6.0, "unlock": -3.0,
}
## Random level jitter (+/- dB) for the sounds heard many times a minute.
const LEVEL_JITTER := {
	"shoot": 1.0, "hit_enemy": 1.5, "enemy_die": 1.0, "step": 2.0, "coin_pickup": 1.0, "hit_wall": 1.5,
	"splash": 1.0, "enemy_shoot": 1.0, "splat": 1.0, "gib": 1.0,
}
## Sounds that bypass the room reverb (UI, pickups, the player's own feedback): crisp and always clear.
const DRY := {
	"ui_click": true, "ui_back": true, "ui_open": true, "ui_move": true, "page_flip": true, "achievement": true,
	"unlock": true, "player_hurt": true, "low_wax": true, "clock_tick_fast": true, "coin_pickup": true,
	"wax_pickup": true, "bomb_pickup": true, "item_get": true, "relic_fanfare": true, "shop_buy": true,
	"victory": true, "tick": true, "snuff_out": true,
}
## Voice priority: 0 = may be cut first, 2 = never cut by anything lower.
const PRIORITY := {
	"step": 0, "shoot": 0, "hit_wall": 0, "hit_enemy": 0, "ui_move": 0, "tick": 0, "coin_pickup": 0,
	"enemy_shoot": 0, "splash": 0, "splat": 0, "moth_flutter": 0, "fire_crackle": 0, "wax_bubble": 0,
	"player_hurt": 2, "low_wax": 2, "boss_roar": 2, "boss_die": 2, "boss_sting": 2, "bell_toll": 2,
	"explosion": 2, "item_get": 2, "relic_fanfare": 2, "snuff_out": 2, "victory": 2, "achievement": 2,
	"unlock": 2, "room_clear": 2,
}
## Most simultaneous copies of one sound (the oldest copy restarts instead): no phasing walls of noise.
const MAX_VOICES := {
	"shoot": 3, "hit_enemy": 3, "hit_wall": 3, "enemy_die": 3, "enemy_shoot": 3, "step": 2, "coin_pickup": 3,
	"splash": 2, "explosion": 3, "tick": 2, "splat": 3, "gib": 2, "sizzle": 2,
}
## Music ducking that big moments trigger by themselves: name -> [dB, seconds held].
const AUTO_DUCK := {
	"boss_roar": [-7.0, 1.0], "boss_die": [-10.0, 2.2], "boss_sting": [-9.0, 1.6], "explosion": [-4.0, 0.35],
	"bell_toll": [-4.0, 1.6], "player_hurt": [-3.0, 0.3], "relic_fanfare": [-8.0, 1.8], "item_get": [-5.0, 1.2],
	"jar_explode": [-2.5, 0.25], "thud_heavy": [-2.5, 0.3], "door_burst": [-2.5, 0.3], "achievement": [-4.0, 1.0],
}
## Per-floor space for the Room bus: [room_size, damping, wet, predelay_ms, spread, hipass]
const SPACES := {
	1: [0.28, 0.75, 0.07, 12.0, 0.6, 0.25],   # Cellar: small, low ceiling, damp and dry
	2: [0.82, 0.42, 0.19, 34.0, 0.9, 0.15],   # Crypt: long stone vaults
	3: [0.90, 0.28, 0.22, 48.0, 1.0, 0.10],   # Chapel: the biggest, brightest hall
	4: [0.70, 0.12, 0.15, 26.0, 1.0, 0.35],   # Belfry: open, airy timber tower (bright, thin lows)
}
## Intensity -> music low-pass cutoff (Hz) and Score volume (dB), interpolated between these points.
const INTENSITY_POINTS := [[0.0, 420.0, -7.0], [0.5, 4800.0, -2.0], [1.0, 20500.0, 0.0]]
const LOW_WAX_CUTOFF := 7500.0
const LOW_WAX_MUSIC_DB := -3.0
const HEART_DB := -3.0

var current_music := ""
var music_intensity := 1.0
var music_paused := false
var low_wax := false
var space := 0

var _takes := {}            # name -> Array[AudioStream] (empty = unknown, so it is never searched again)
var _last_take := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_name: Array[String] = []
var _pool_prio: Array[int] = []
var _pool_t: Array[float] = []
var _last_play := {}
var _music: Array[AudioStreamPlayer] = []
var _music_tween: Array[Tween] = [null, null]
var _active := 0
var _positions := {}
var _floor_music := ""
var _ducks: Array = []      # [db, until_s, release_s]
var _room_duck_until := 0.0
var _cut := 20500.0
var _score_db := 0.0
var _room_db := 0.0
var _low_frac := 1.0
var _low_seen := 0.0
var _heart: AudioStreamPlayer
var _heart_db := -60.0
var _loops := {}            # id -> [AudioStreamPlayer, WeakRef or null]
var _next_loop := 1
var _clock := 0.0          # seconds of unscaled time (ignores pause and Engine.time_scale)
var _rng := RandomNumberGenerator.new()   # own generator: sound variation never shifts gameplay randomness
var _bus_music := -1
var _bus_sfx := -1
var _bus_room := -1
var _bus_score := -1
var _lpf: AudioEffectLowPassFilter
var _lpf_idx := -1
var _reverb: AudioEffectReverb
var _reverb_idx := -1
var _lpf_on := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "Room"
		add_child(p)
		_pool.append(p)
		_pool_name.append("")
		_pool_prio.append(0)
		_pool_t.append(0.0)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Score"
		add_child(m)
		_music.append(m)
	_heart = AudioStreamPlayer.new()
	_heart.bus = "SFX"
	add_child(_heart)


# ---------------------------------------------------------------- buses

func _ensure_bus(bus_name: String, send: String) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
	if send != "":
		AudioServer.set_bus_send(idx, send)
	return idx


func _find_effect(bus: int, cls: String) -> int:
	for i in AudioServer.get_bus_effect_count(bus):
		if AudioServer.get_bus_effect(bus, i).is_class(cls):
			return i
	return -1


func _setup_buses() -> void:
	_bus_music = _ensure_bus("Music", "Master")
	_bus_sfx = _ensure_bus("SFX", "Master")
	_bus_room = _ensure_bus("Room", "SFX")
	_bus_score = _ensure_bus("Score", "Music")
	if _find_effect(0, "AudioEffectHardLimiter") < 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -0.5
		AudioServer.add_bus_effect(0, lim)
	_lpf_idx = _find_effect(_bus_music, "AudioEffectLowPassFilter")
	if _lpf_idx < 0:
		var f := AudioEffectLowPassFilter.new()
		f.cutoff_hz = 20500.0
		f.db = AudioEffectFilter.FILTER_12DB
		AudioServer.add_bus_effect(_bus_music, f)
		_lpf_idx = AudioServer.get_bus_effect_count(_bus_music) - 1
	_lpf = AudioServer.get_bus_effect(_bus_music, _lpf_idx) as AudioEffectLowPassFilter
	AudioServer.set_bus_effect_enabled(_bus_music, _lpf_idx, false)
	_reverb_idx = _find_effect(_bus_room, "AudioEffectReverb")
	if _reverb_idx < 0:
		AudioServer.add_bus_effect(_bus_room, AudioEffectReverb.new())
		_reverb_idx = AudioServer.get_bus_effect_count(_bus_room) - 1
	_reverb = AudioServer.get_bus_effect(_bus_room, _reverb_idx) as AudioEffectReverb
	_reverb.dry = 1.0
	AudioServer.set_bus_effect_enabled(_bus_room, _reverb_idx, false)


# ---------------------------------------------------------------- sound effects

func _load(path_no_ext: String) -> AudioStream:
	for ext in [".ogg", ".wav"]:
		var path: String = path_no_ext + ext
		if ResourceLoader.exists(path):
			return load(path) as AudioStream
	return null


## All takes of a sound: <name>.ogg, then <name>_2.ogg, <name>_3.ogg ... (stops at the first gap).
func _get_takes(n: String) -> Array:
	if _takes.has(n):
		return _takes[n]
	var list: Array = []
	if n != "":
		var s := _load(SFX_DIR + n)
		if s != null:
			list.append(s)
			for i in range(2, MAX_TAKES + 1):
				var v := _load(SFX_DIR + "%s_%d" % [n, i])
				if v == null:
					break
				list.append(v)
		else:
			print_verbose("Audio: no sound named '%s'" % n)
	_takes[n] = list
	return list


## True if a sound with this name exists (so callers can fall back to another one).
func has_sound(n: String) -> bool:
	return not _get_takes(n).is_empty()


func _pick_take(n: String, list: Array) -> AudioStream:
	if list.size() == 1:
		return list[0]
	var last: int = _last_take.get(n, -1)
	var i := _rng.randi() % (list.size() - 1)
	if last >= 0 and i >= last:
		i += 1
	elif last < 0:
		i = _rng.randi() % list.size()
	_last_take[n] = i
	return list[i]


func _now() -> float:
	return _clock


func _voice_for(n: String, prio: int) -> int:
	var now := _now()
	var same := 0
	var oldest_same := -1
	for i in POOL_SIZE:
		if _pool[i].playing and _pool_name[i] == n:
			same += 1
			if oldest_same < 0 or _pool_t[i] < _pool_t[oldest_same]:
				oldest_same = i
	if same >= int(MAX_VOICES.get(n, 99)):
		return oldest_same
	for i in POOL_SIZE:
		if not _pool[i].playing:
			return i
	# all busy: steal the oldest voice of the lowest priority that is not above ours
	var best := -1
	for i in POOL_SIZE:
		if _pool_prio[i] > prio:
			continue
		if best < 0 or _pool_prio[i] < _pool_prio[best] or (_pool_prio[i] == _pool_prio[best] and _pool_t[i] < _pool_t[best]):
			best = i
	if best >= 0 and now - _pool_t[best] < 0.03 and _pool_prio[best] == prio:
		return -1   # everything just started; dropping this one is less noticeable than cutting another
	return best


func play(n: String, volume_db := 0.0, pitch_jitter := 0.06, pitch := 1.0) -> void:
	var list := _get_takes(n)
	if list.is_empty():
		return
	if n == "low_wax" and low_wax:
		return   # the low-wax layer already carries the heartbeat
	var now := _now()
	if THROTTLE.has(n) and now - float(_last_play.get(n, -1.0)) < THROTTLE[n]:
		return
	_last_play[n] = now
	var prio: int = PRIORITY.get(n, 1)
	var v := _voice_for(n, prio)
	if v < 0:
		return
	var p := _pool[v]
	p.stop()
	p.stream = _pick_take(n, list)
	p.bus = "SFX" if DRY.has(n) else "Room"
	var jit: float = LEVEL_JITTER.get(n, 0.0)
	p.volume_db = volume_db + float(VOLUME.get(n, 0.0)) + _rng.randf_range(-jit, jit)
	p.pitch_scale = maxf(0.2, pitch + _rng.randf_range(-pitch_jitter, pitch_jitter))
	p.play()
	_pool_name[v] = n
	_pool_prio[v] = prio
	_pool_t[v] = now
	if AUTO_DUCK.has(n) and not current_music.ends_with("jingle"):
		duck(AUTO_DUCK[n][0], AUTO_DUCK[n][1])
	if n == "player_hurt":
		_room_duck_until = now + 0.25   # the hurt sound cuts through the room for a moment


## Start a looping sound (e.g. "beam_loop"). If `follow` is given, the loop stops by itself when that node is freed.
## Returns an id for loop_stop(), or 0 if the sound does not exist.
func loop_start(n: String, follow: Node = null, volume_db := 0.0, pitch := 1.0) -> int:
	var list := _get_takes(n)
	if list.is_empty():
		return 0
	var s := (list[0] as AudioStream).duplicate() as AudioStream
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	var p := AudioStreamPlayer.new()
	p.bus = "SFX" if DRY.has(n) else "Room"
	p.stream = s
	p.volume_db = volume_db + float(VOLUME.get(n, 0.0))
	p.pitch_scale = maxf(0.2, pitch)
	add_child(p)
	p.play()
	var id := _next_loop
	_next_loop += 1
	_loops[id] = [p, weakref(follow) if follow != null else null]
	return id


func loop_stop(id: int, fade := 0.15) -> void:
	if not _loops.has(id):
		return
	var p: AudioStreamPlayer = _loops[id][0]
	_loops.erase(id)
	if not is_instance_valid(p):
		return
	var t := create_tween()
	t.tween_property(p, "volume_db", -60.0, maxf(fade, 0.01))
	t.tween_callback(p.queue_free)


func _stop_all_loops() -> void:
	for id in _loops.keys():
		loop_stop(id, 0.2)


## Silence everything at once (before quitting, so no playback is left running at exit).
func stop_all() -> void:
	for p in _pool:
		p.stop()
	for m in _music:
		m.stop()
	_heart.stop()
	for id in _loops.keys():
		var lp: AudioStreamPlayer = _loops[id][0]
		if is_instance_valid(lp):
			lp.stop()
			lp.queue_free()
	_loops.clear()
	current_music = ""
	low_wax = false


# ---------------------------------------------------------------- music

func _is_resumable(n: String) -> bool:
	return n.begins_with("floor_") or n == "shop"


func music(n: String, fade := 1.2) -> void:
	if n == current_music:
		return
	var old := _music[_active]
	var prev := current_music
	if _is_resumable(prev) and old.playing:
		_positions[prev] = old.get_playback_position()
	current_music = n
	if n.begins_with("floor_"):
		_floor_music = n
	if n == "" or n == "title" or n.ends_with("jingle"):
		# leaving a run: nothing carries over into the menus / the end of the run
		_positions.clear()
		_ducks.clear()
		music_intensity = 1.0
		music_paused = false
		low_wax = false
		if n == "title" or n == "":
			_floor_music = ""
			set_space(0)
			_stop_all_loops()
	var stream: AudioStream = _load(MUSIC_DIR + n) if n != "" else null
	if old.playing:
		_fade_player(_active, -60.0, fade, true)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = not n.ends_with("jingle")
	if (n == "boss" or n == "final_boss") and not (prev == "boss" or prev == "final_boss"):
		play("boss_sting")   # every boss reveal gets the stab (throttled, so an extra call does not double it)
	_active = 1 - _active
	var nw := _music[_active]
	nw.stop()
	nw.stream = stream
	nw.volume_db = -40.0
	var from := 0.0
	if _positions.has(n):
		var length := stream.get_length()
		from = fmod(float(_positions[n]), length) if length > 0.0 else 0.0
	nw.play(from)
	_fade_player(_active, 0.0, fade * 0.8, false)


func _fade_player(i: int, to_db: float, secs: float, stop_after: bool) -> void:
	if _music_tween[i] != null and _music_tween[i].is_valid():
		_music_tween[i].kill()
	var p := _music[i]
	var t := create_tween()
	t.tween_property(p, "volume_db", to_db, maxf(secs, 0.01))
	if stop_after:
		t.tween_callback(p.stop)
	_music_tween[i] = t


## One-shot jingle over a ducked music track.
func jingle(n: String) -> void:
	music(n, 0.4)


## Called on entering a room: the merchant's tune in shops, the floor's track elsewhere; full mix in a fight,
## a calmer, gently filtered mix once the room is clear.
func enter_room(room_type: String, cleared: bool) -> void:
	if room_type == "shop":
		music("shop")
	elif current_music == "shop" and _floor_music != "":
		music(_floor_music)
	set_intensity(0.5 if cleared and room_type != "shop" else 1.0)   # the merchant's tune is heard in full


## 1.0 = combat (full music), 0.5 = room cleared (gentle low-pass, a little quieter), 0.0 = muffled.
func set_intensity(x: float) -> void:
	music_intensity = clampf(x, 0.0, 1.0)


## Pause menu: a strong low-pass and a dip; restores the room's intensity afterwards.
func set_paused(on: bool) -> void:
	music_paused = on


## Dip the music by `db` (negative) for `secs`, then let it recover. Overlapping ducks use the deepest one.
func duck(db: float, secs: float) -> void:
	_ducks.append([minf(db, 0.0), _now() + maxf(secs, 0.0), 0.5])


## The candle is nearly out: a heartbeat + fast ticking layer that speeds up as `frac` (wax left / threshold) falls,
## with the music pulled back a little. Call every frame while it applies; it fades out on its own when not refreshed.
func set_low_wax(on: bool, frac := 1.0) -> void:
	_low_seen = _now()
	_low_frac = clampf(frac, 0.0, 1.0)
	if on == low_wax:
		return
	low_wax = on
	if on and not _heart.playing:
		var s := _load(SFX_DIR + "low_wax_loop")
		if s == null:
			return
		if s is AudioStreamOggVorbis:
			(s as AudioStreamOggVorbis).loop = true
		_heart.stream = s
		_heart_db = -40.0
		_heart.volume_db = _heart_db
		_heart.play()


## Per-floor acoustics for world sounds (1 Cellar ... 4 Belfry; 0 or unknown = no reverb).
func set_space(floor_num: int) -> void:
	space = floor_num
	if _reverb == null:
		return
	if not SPACES.has(floor_num):
		AudioServer.set_bus_effect_enabled(_bus_room, _reverb_idx, false)
		return
	var s: Array = SPACES[floor_num]
	_reverb.room_size = s[0]
	_reverb.damping = s[1]
	_reverb.wet = s[2]
	_reverb.dry = 1.0
	_reverb.predelay_msec = s[3]
	_reverb.predelay_feedback = 0.25
	_reverb.spread = s[4]
	_reverb.hipass = s[5]
	AudioServer.set_bus_effect_enabled(_bus_room, _reverb_idx, true)


# ---------------------------------------------------------------- the live mix

func _intensity_target(x: float) -> Vector2:
	var pts: Array = INTENSITY_POINTS
	for i in range(1, pts.size()):
		var a: Array = pts[i - 1]
		var b: Array = pts[i]
		if x <= float(b[0]):
			var k := (x - float(a[0])) / maxf(float(b[0]) - float(a[0]), 0.0001)
			var cut := exp(lerpf(log(float(a[1])), log(float(b[1])), k))
			return Vector2(cut, lerpf(float(a[2]), float(b[2]), k))
	var last: Array = pts[pts.size() - 1]
	return Vector2(float(last[1]), float(last[2]))


func _duck_db(now: float) -> float:
	var d := 0.0
	for i in range(_ducks.size() - 1, -1, -1):
		var k: Array = _ducks[i]
		var over: float = now - float(k[1])
		if over > float(k[2]):
			_ducks.remove_at(i)
			continue
		var g: float = float(k[0]) * (1.0 - clampf(over / float(k[2]), 0.0, 1.0))
		d = minf(d, g)
	return d


func _process(delta: float) -> void:
	# unscaled time: the mix moves at the same speed in slow-motion, in the 4x play-test and in movie captures
	var dt := clampf(delta / maxf(Engine.time_scale, 0.001), 0.0, 0.1)
	_clock += dt
	var now := _clock
	var tree := get_tree()
	if music_paused and not tree.paused:
		music_paused = false
	if low_wax and not tree.paused and now - _low_seen > 1.5:
		low_wax = false
	# music: cutoff + level
	var jingle_on := current_music.ends_with("jingle")
	var x := 0.0 if music_paused else music_intensity
	if jingle_on:
		x = 1.0
	var tgt := _intensity_target(x)
	var cut_t := tgt.x
	var vol_t := tgt.y
	if low_wax and not music_paused:
		cut_t = minf(cut_t, LOW_WAX_CUTOFF)
		vol_t += LOW_WAX_MUSIC_DB
	var tc := 0.12 if music_paused else 0.35
	_cut = exp(lerpf(log(_cut), log(cut_t), 1.0 - exp(-dt / tc)))
	if _lpf != null:
		var on := _cut < 19000.0
		if on:
			_lpf.cutoff_hz = _cut
		if on != _lpf_on:
			_lpf_on = on
			AudioServer.set_bus_effect_enabled(_bus_music, _lpf_idx, on)
	vol_t += _duck_db(now)
	var vt := 0.05 if vol_t < _score_db else 0.25   # duck fast, recover slowly
	_score_db = lerpf(_score_db, vol_t, 1.0 - exp(-dt / vt))
	AudioServer.set_bus_volume_db(_bus_score, _score_db)
	# room bus: give way to the hurt sound
	var room_t := -4.0 if now < _room_duck_until else 0.0
	_room_db = lerpf(_room_db, room_t, 1.0 - exp(-dt / (0.03 if room_t < _room_db else 0.2)))
	AudioServer.set_bus_volume_db(_bus_room, _room_db)
	# low-wax layer: louder and faster as the wax runs out
	if _heart.playing:
		var h_t := HEART_DB + 3.0 * (1.0 - _low_frac) if low_wax else -60.0
		if music_paused:
			h_t -= 12.0
		_heart_db = lerpf(_heart_db, h_t, 1.0 - exp(-dt / (0.4 if h_t > _heart_db else 0.6)))
		_heart.volume_db = _heart_db
		_heart.pitch_scale = lerpf(1.0, 1.3, 1.0 - _low_frac)
		if not low_wax and _heart_db < -55.0:
			_heart.stop()
	# loops whose owner is gone
	for id in _loops.keys():
		var wr = _loops[id][1]
		if wr != null and (wr as WeakRef).get_ref() == null:
			loop_stop(id, 0.1)
