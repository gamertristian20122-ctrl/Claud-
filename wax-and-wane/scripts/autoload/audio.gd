extends Node
## Music with crossfades + pooled, rate-limited sound effects. Missing files are skipped silently.

const SFX_DIR := "res://assets/audio/sfx/"
const MUSIC_DIR := "res://assets/audio/music/"
const POOL_SIZE := 16
## Minimum seconds between two plays of the same effect (keeps busy rooms from turning into noise).
const THROTTLE := {
	"shoot": 0.05, "hit_enemy": 0.04, "hit_wall": 0.05, "enemy_die": 0.05, "enemy_shoot": 0.06,
	"coin_pickup": 0.04, "wax_pickup": 0.05, "step": 0.12, "tick": 0.2, "ui_click": 0.03,
}
const VOLUME := {
	"shoot": -9.0, "hit_wall": -12.0, "hit_enemy": -7.0, "enemy_die": -5.0, "enemy_shoot": -9.0,
	"step": -16.0, "tick": -8.0, "ui_click": -6.0, "ui_back": -6.0, "ui_open": -6.0,
	"coin_pickup": -6.0, "wax_pickup": -4.0, "low_wax": -3.0, "bell_toll": -2.0,
}

var _sfx := {}
var _pool: Array[AudioStreamPlayer] = []
var _next := 0
var _last_play := {}
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var current_music := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool.append(p)
	_music_a = _make_music_player()
	_music_b = _make_music_player()


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	add_child(p)
	return p


func _get_sfx(n: String) -> AudioStream:
	if _sfx.has(n):
		return _sfx[n]
	var s: AudioStream = null
	for ext in [".ogg", ".wav"]:
		var path: String = SFX_DIR + n + ext
		if ResourceLoader.exists(path):
			s = load(path)
			break
	_sfx[n] = s
	return s


func play(n: String, volume_db := 0.0, pitch_jitter := 0.06, pitch := 1.0) -> void:
	var stream := _get_sfx(n)
	if stream == null:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if THROTTLE.has(n) and now - float(_last_play.get(n, -1.0)) < THROTTLE[n]:
		return
	_last_play[n] = now
	var p := _pool[_next]
	_next = (_next + 1) % POOL_SIZE
	p.stream = stream
	p.volume_db = volume_db + float(VOLUME.get(n, 0.0))
	p.pitch_scale = maxf(0.2, pitch + randf_range(-pitch_jitter, pitch_jitter))
	p.play()


func music(n: String, fade := 1.2) -> void:
	if n == current_music:
		return
	current_music = n
	var stream: AudioStream = null
	if n != "":
		for ext in [".ogg", ".wav"]:
			var path: String = MUSIC_DIR + n + ext
			if ResourceLoader.exists(path):
				stream = load(path)
				break
	var old := _music_a if _music_a.playing else _music_b
	var nw := _music_b if old == _music_a else _music_a
	if old.playing:
		var t := create_tween()
		t.tween_property(old, "volume_db", -60.0, fade)
		t.tween_callback(old.stop)
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = not n.ends_with("jingle")
	nw.stream = stream
	nw.volume_db = -40.0
	nw.play()
	var t2 := create_tween()
	t2.tween_property(nw, "volume_db", 0.0, fade * 0.8)


## One-shot jingle over a ducked music track.
func jingle(n: String) -> void:
	music(n, 0.4)
