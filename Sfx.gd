extends Node
## Sound effects (autoload "Sfx"). Every sound is synthesised in code at
## start-up, so no audio files are needed. Replace any entry in `_streams`
## with a real recording later. Press M in game to mute.

const RATE := 22050

var _streams: Dictionary = {}
var _players: Array = []
var _next: int = 0
var muted: bool = false

## Ambient loop per depth. Root notes are multiples of 0.25 Hz so the
## 4-second loop repeats without a click.
const AMBIENCE_ROOT := [55.0, 49.0, 61.75, 41.25]
const AMBIENCE_LOOP := 4.0
var _amb_player: AudioStreamPlayer
var _amb_streams: Dictionary = {}
var _amb_depth: int = -1
var _drip_timer: float = 3.0
var _rumble_timer: float = 25.0


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for kind in ["chip", "rock", "thud", "found", "damage", "collapse", "coin", "buy", "beep", "blast", "prop", "deny", "fanfare", "hiss", "flap", "drip", "chirp"]:
		_streams[kind] = _synth(kind)
	_amb_player = AudioStreamPlayer.new()
	add_child(_amb_player)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		muted = not muted


func play(kind: String, pitch: float = 1.0, volume_db: float = -8.0) -> void:
	if muted or not _streams.has(kind) or Settings.volume <= 0.001:
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[kind]
	p.pitch_scale = maxf(pitch, 0.05)
	p.volume_db = volume_db + linear_to_db(Settings.volume)
	p.play()


## Starts (or switches) the background drone for a depth.
func start_ambience(depth: int) -> void:
	depth = clampi(depth, 0, AMBIENCE_ROOT.size() - 1)
	if depth == _amb_depth and _amb_player.playing:
		return
	_amb_depth = depth
	if not _amb_streams.has(depth):
		_amb_streams[depth] = _ambience_stream(depth)
	_amb_player.stream = _amb_streams[depth]
	_update_ambience_volume()
	_amb_player.play()


func _ambience_on() -> bool:
	return not muted and Settings.ambience > 0.001


func _update_ambience_volume() -> void:
	_amb_player.volume_db = -14.0 + linear_to_db(Settings.ambience) if _ambience_on() else -80.0


func _process(delta: float) -> void:
	if _amb_player == null or not _amb_player.playing:
		return
	_update_ambience_volume()
	if not _ambience_on():
		return
	var amb_db := linear_to_db(Settings.ambience) - linear_to_db(maxf(Settings.volume, 0.001))
	_drip_timer -= delta
	if _drip_timer <= 0.0:
		_drip_timer = randf_range(2.5, 8.0)
		play("drip", randf_range(0.75, 1.3), -22.0 + amb_db)
	_rumble_timer -= delta
	if _rumble_timer <= 0.0:
		_rumble_timer = randf_range(25.0, 60.0)
		play("collapse", 0.45, -30.0 + amb_db)


func _ambience_stream(depth: int) -> AudioStreamWAV:
	var f: float = AMBIENCE_ROOT[depth]
	var count := int(AMBIENCE_LOOP * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	for i in count:
		var t := float(i) / RATE
		var swell := 0.75 + 0.25 * sin(t * TAU * 0.25)
		var v := (_tone(t, f) * 0.35 + _tone(t, f + 0.25) * 0.25 + _tone(t, f * 2.0 + 0.5) * 0.12) * swell
		if depth == 2:
			# Crystal shimmer.
			v += _tone(t, f * 8.0) * 0.05 * pow(sin(t * TAU * 0.5), 2.0)
		elif depth == 3:
			# A slow heartbeat from far below.
			var beat := fmod(t, AMBIENCE_LOOP / 3.0)
			v += _tone(t, 40.0) * 0.45 * (exp(-beat * 9.0) + 0.7 * exp(-absf(beat - 0.28) * 14.0))
		data.encode_s16(i * 2, int(clampf(v * 0.6, -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = count
	return stream


func _tone(t: float, freq: float) -> float:
	return sin(t * freq * TAU)


func _synth(kind: String) -> AudioStreamWAV:
	var lengths := {
		"chip": 0.07, "rock": 0.09, "thud": 0.2, "found": 0.45, "damage": 0.28,
		"collapse": 1.1, "coin": 0.22, "buy": 0.3, "beep": 0.06, "blast": 0.6,
		"prop": 0.22, "deny": 0.16, "fanfare": 0.8, "hiss": 0.7, "flap": 0.35, "drip": 0.15, "chirp": 0.2,
	}
	var duration: float = lengths[kind]
	var count := int(duration * RATE)
	var data := PackedByteArray()
	data.resize(count * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(kind)
	var low := 0.0  # low-passed noise, for rumbles
	for i in count:
		var t := float(i) / RATE
		var u := float(i) / count        # 0..1 through the sound
		var noise := rng.randf_range(-1.0, 1.0)
		low = lerpf(low, noise, 0.08)
		var v := 0.0
		match kind:
			"chip":
				v = (noise * 0.6 + _tone(t, 1900.0) * 0.4) * exp(-t * 70.0)
			"rock":
				v = (noise * 0.35 + _tone(t, 1050.0) * 0.5 + _tone(t, 2600.0) * 0.2) * exp(-t * 45.0)
			"thud":
				v = (_tone(t, 95.0 - 40.0 * u) * 0.9 + noise * 0.35 * exp(-t * 40.0)) * exp(-t * 16.0)
			"found":
				var note: float = [660.0, 880.0, 1320.0][mini(int(u * 3.0), 2)]
				var nt := fmod(t, duration / 3.0)
				v = (_tone(t, note) * 0.6 + _tone(t, note * 2.0) * 0.2) * exp(-nt * 9.0)
			"damage":
				var f := 240.0 - 130.0 * u
				v = (1.0 if _tone(t, f) > 0.0 else -1.0) * 0.35 * (1.0 - u)
			"collapse":
				v = (low * 3.2 + _tone(t, 55.0) * 0.4) * (1.0 - u) * minf(t * 30.0, 1.0)
			"coin":
				var f2 := 1250.0 if u < 0.35 else 1670.0
				var ct := t if u < 0.35 else t - duration * 0.35
				v = (_tone(t, f2) * 0.5 + _tone(t, f2 * 2.01) * 0.2) * exp(-ct * 18.0)
			"buy":
				v = _tone(t, 440.0 + 660.0 * u) * 0.45 * (1.0 - u)
			"beep":
				v = _tone(t, 1000.0) * 0.5 * sin(u * PI)
			"blast":
				v = (low * 3.5 + noise * 0.5 * exp(-t * 12.0) + _tone(t, 60.0 - 25.0 * u) * 0.6) * exp(-t * 6.0)
			"prop":
				var kt := fmod(t, 0.11)
				v = (_tone(kt, 210.0) * 0.7 + noise * 0.2) * exp(-kt * 45.0)
			"deny":
				v = (1.0 if _tone(t, 150.0) > 0.0 else -1.0) * 0.25 * (1.0 - u)
			"fanfare":
				var note2: float = [523.0, 659.0, 784.0, 1047.0][mini(int(u * 4.0), 3)]
				var ft := fmod(t, duration / 4.0)
				v = (_tone(t, note2) * 0.5 + _tone(t, note2 * 1.5) * 0.2) * exp(-ft * 5.0)
			"hiss":
				v = (noise - low) * 0.7 * sin(u * PI) * (1.0 - u * 0.5)
			"flap":
				v = noise * 0.5 * maxf(0.0, sin(t * TAU * 14.0)) * (1.0 - u)
			"drip":
				v = _tone(t, 1600.0 - 900.0 * u) * 0.6 * exp(-t * 35.0)
			"chirp":
				v = _tone(t, 2600.0 + 1400.0 * fmod(u * 2.0, 1.0)) * 0.35 * sin(fmod(u * 2.0, 1.0) * PI)
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
