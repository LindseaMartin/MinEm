extends Node
## Sound effects (autoload "Sfx"). Every sound is synthesised in code at
## start-up, so no audio files are needed. Replace any entry in `_streams`
## with a real recording later. Press M in game to mute.

const RATE := 22050

var _streams: Dictionary = {}
var _players: Array = []
var _next: int = 0
var muted: bool = false


func _ready() -> void:
	for i in 8:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	for kind in ["chip", "rock", "thud", "found", "damage", "collapse", "coin", "buy", "beep", "blast", "prop", "deny", "fanfare", "hiss"]:
		_streams[kind] = _synth(kind)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		muted = not muted


func play(kind: String, pitch: float = 1.0, volume_db: float = -8.0) -> void:
	if muted or not _streams.has(kind):
		return
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = _streams[kind]
	p.pitch_scale = maxf(pitch, 0.05)
	p.volume_db = volume_db
	p.play()


func _tone(t: float, freq: float) -> float:
	return sin(t * freq * TAU)


func _synth(kind: String) -> AudioStreamWAV:
	var lengths := {
		"chip": 0.07, "rock": 0.09, "thud": 0.2, "found": 0.45, "damage": 0.28,
		"collapse": 1.1, "coin": 0.22, "buy": 0.3, "beep": 0.06, "blast": 0.6,
		"prop": 0.22, "deny": 0.16, "fanfare": 0.8, "hiss": 0.7,
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
		data.encode_s16(i * 2, int(clampf(v, -1.0, 1.0) * 30000.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.stereo = false
	stream.data = data
	return stream
