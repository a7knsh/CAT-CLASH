extends Node
## Procedural audio: every sound effect and music loop is synthesized at
## runtime (no audio files to import). SFX are short PCM buffers played from a
## voice pool with pitch variation and anti-spam cooldowns. Music is a small
## chiptune sequencer that renders seeded 8-bar loops on a worker thread.

const SR := 22050
const MUSIC_SR := 16000
const VOICES := 20

var _sfx: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0
var _last_play: Dictionary = {}
var _music_a: AudioStreamPlayer
var _music_cache: Dictionary = {}
var _pending: Dictionary = {}
var _want_music := ""
var _rng := RandomNumberGenerator.new()
## Host of a LAN game: sounds are recorded and replayed on clients.
var recorder: Callable


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	_setup_buses()
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_players.append(p)
	_music_a = AudioStreamPlayer.new()
	_music_a.bus = "Music"
	add_child(_music_a)
	_build_sfx()
	apply_volumes()


func _setup_buses() -> void:
	for bname in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bname) == -1:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bname)
			AudioServer.set_bus_send(idx, "Master")


func apply_volumes() -> void:
	var m: float = Settings.get_value("master_volume")
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(m, 0.0001)))
	AudioServer.set_bus_mute(0, m <= 0.001)
	var mi := AudioServer.get_bus_index("Music")
	var si := AudioServer.get_bus_index("SFX")
	var mv: float = Settings.get_value("music_volume")
	var sv: float = Settings.get_value("sfx_volume")
	AudioServer.set_bus_volume_db(mi, linear_to_db(maxf(mv, 0.0001)) - 6.0)
	AudioServer.set_bus_mute(mi, mv <= 0.001)
	AudioServer.set_bus_volume_db(si, linear_to_db(maxf(sv, 0.0001)))
	AudioServer.set_bus_mute(si, sv <= 0.001)


# ------------------------------------------------------------- playback

## Play a named sound. `pitch` scales the base pitch, `vary` adds randomness.
func play(sname: String, volume_db: float = 0.0, pitch: float = 1.0, vary: float = 0.08) -> void:
	if not _sfx.has(sname):
		return
	if recorder.is_valid():
		recorder.call(["snd", sname, volume_db, pitch])
	var now := Time.get_ticks_msec()
	if now - int(_last_play.get(sname, -1000)) < 28:
		return
	_last_play[sname] = now
	var list: Array = _sfx[sname]
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = list[_rng.randi_range(0, list.size() - 1)]
	p.volume_db = volume_db
	p.pitch_scale = maxf(0.2, pitch * (1.0 + _rng.randf_range(-vary, vary)))
	p.play()


func play_impact(material: String, strength: float) -> void:
	var vol := lerpf(-6.0, 2.0, clampf(strength, 0.0, 1.0))
	var pitch := lerpf(1.15, 0.85, clampf(strength, 0.0, 1.0))
	match material:
		"metal", "chain": play("hit_metal", vol - 2.0, pitch)
		"wood": play("hit_wood", vol, pitch)
		"pan": play("hit_pan", vol, pitch)
		"squeak": play("hit_squeak", vol, pitch)
		"fish": play("hit_fish", vol, pitch)
		"bread": play("hit_bread", vol, pitch)
		"energy", "magic": play("hit_energy", vol - 3.0, pitch)
		"glass": play("hit_glass", vol, pitch)
		"soft": play("hit_soft", vol + 2.0, pitch)
		_: play("hit_blunt", vol, pitch)
	# Layer a thump under heavy hits for weight.
	if strength > 0.6:
		play("thump", vol - 2.0, 0.9)


func meow(pitch: float = 1.0) -> void:
	play("meow", -4.0, pitch, 0.12)


# ---------------------------------------------------------------- music

func play_music(track_id: String, params: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		return
	_want_music = track_id
	if _music_cache.has(track_id):
		_start_music(_music_cache[track_id])
		return
	if _pending.has(track_id):
		return
	var task := WorkerThreadPool.add_task(_render_music_task.bind(track_id, params), true, "music")
	_pending[track_id] = task


func stop_music() -> void:
	_want_music = ""
	_music_a.stop()


func _render_music_task(track_id: String, params: Dictionary) -> void:
	var stream := MusicGen.render(params, MUSIC_SR)
	call_deferred("_music_ready", track_id, stream)


func _music_ready(track_id: String, stream: AudioStreamWAV) -> void:
	_music_cache[track_id] = stream
	if _pending.has(track_id):
		WorkerThreadPool.wait_for_task_completion(_pending[track_id])
		_pending.erase(track_id)
	if _want_music == track_id:
		_start_music(stream)


func _start_music(stream: AudioStreamWAV) -> void:
	if _music_a.stream == stream and _music_a.playing:
		return
	_music_a.stream = stream
	_music_a.volume_db = -30.0
	_music_a.play()
	var tw := create_tween()
	tw.tween_property(_music_a, "volume_db", 0.0, 0.8)


func duck_music(amount_db: float, dur: float) -> void:
	if recorder.is_valid():
		recorder.call(["duck", amount_db, dur])
	if not _music_a.playing:
		return
	var tw := create_tween()
	tw.tween_property(_music_a, "volume_db", -amount_db, 0.05)
	tw.tween_property(_music_a, "volume_db", 0.0, dur)


# ------------------------------------------------------------ synthesis

static func _to_stream(buf: PackedFloat32Array, rate: int = SR, loop: bool = false) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	for i in buf.size():
		bytes.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32000.0))
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = bytes
	if loop:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = buf.size()
	return s


func _buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * SR))
	b.fill(0.0)
	return b


## Tone with exponential pitch glide and decay envelope. wave: sine/square/tri/saw
func _tone(b: PackedFloat32Array, f0: float, f1: float, dur: float, vol: float, wave: String = "sine", start: float = 0.0, attack: float = 0.004, vib: float = 0.0) -> void:
	var n := int(dur * SR)
	var s0 := int(start * SR)
	var ph := 0.0
	for i in n:
		var idx := s0 + i
		if idx >= b.size():
			break
		var t := float(i) / n
		var f := f0 * pow(f1 / f0, t)
		if vib > 0.0:
			f *= 1.0 + sin(i / float(SR) * 40.0) * vib
		ph += f / SR
		var p := fmod(ph, 1.0)
		var v := 0.0
		match wave:
			"sine": v = sin(p * TAU)
			"square": v = 1.0 if p < 0.5 else -1.0
			"pulse": v = 1.0 if p < 0.25 else -1.0
			"tri": v = 4.0 * absf(p - 0.5) - 1.0
			"saw": v = 2.0 * p - 1.0
		var env := minf(1.0, i / maxf(1.0, attack * SR)) * pow(1.0 - t, 2.0)
		b[idx] += v * env * vol


func _noise(b: PackedFloat32Array, dur: float, vol: float, lp: float = 1.0, start: float = 0.0, shape: String = "decay", hp: float = 0.0) -> void:
	var n := int(dur * SR)
	var s0 := int(start * SR)
	var y := 0.0
	var yh := 0.0
	for i in n:
		var idx := s0 + i
		if idx >= b.size():
			break
		var t := float(i) / n
		var x := _rng.randf_range(-1.0, 1.0)
		y += lp * (x - y)
		var out := y
		if hp > 0.0:
			yh += hp * (y - yh)
			out = y - yh
		var env := 1.0
		match shape:
			"decay": env = pow(1.0 - t, 2.0)
			"swell": env = sin(t * PI)
			"flat": env = 1.0 - t * 0.3
			"crackle": env = (1.0 - t) * (1.0 if _rng.randf() < 0.3 else 0.15)
		b[idx] += out * env * vol


func _add(name: String, b: PackedFloat32Array) -> void:
	if not _sfx.has(name):
		_sfx[name] = []
	_sfx[name].append(_to_stream(b))


func _build_sfx() -> void:
	var b: PackedFloat32Array
	# Swings / movement
	for v in 2:
		b = _buf(0.14)
		_noise(b, 0.14, 0.5, 0.18 + v * 0.05, 0.0, "swell", 0.05)
		_add("swing_light", b)
	b = _buf(0.26)
	_noise(b, 0.26, 0.6, 0.12, 0.0, "swell", 0.03)
	_tone(b, 180, 90, 0.26, 0.1, "sine")
	_add("swing_heavy", b)
	b = _buf(0.12)
	_noise(b, 0.12, 0.4, 0.35, 0.0, "swell", 0.1)
	_add("dodge", b)
	b = _buf(0.1)
	_tone(b, 280, 560, 0.09, 0.18, "pulse")
	_add("jump", b)
	b = _buf(0.08)
	_tone(b, 110, 50, 0.08, 0.3, "sine")
	_noise(b, 0.05, 0.15, 0.2)
	_add("land", b)
	b = _buf(0.03)
	_noise(b, 0.03, 0.15, 0.5)
	_add("step", b)
	# Impacts
	for v in 3:
		b = _buf(0.12)
		_tone(b, 170 + v * 15, 55, 0.12, 0.6, "sine")
		_noise(b, 0.05, 0.35, 0.4)
		_add("hit_blunt", b)
	b = _buf(0.14)
	_tone(b, 120, 45, 0.14, 0.7, "sine")
	_add("thump", b)
	b = _buf(0.1)
	_tone(b, 150, 70, 0.1, 0.5, "sine")
	_noise(b, 0.04, 0.2, 0.15)
	_add("hit_soft", b)
	for v in 2:
		b = _buf(0.22)
		_tone(b, 1100 + v * 120, 900, 0.22, 0.2, "square")
		_tone(b, 1700 + v * 90, 1500, 0.18, 0.12, "sine")
		_noise(b, 0.04, 0.4, 0.8)
		_add("hit_metal", b)
	b = _buf(0.09)
	_tone(b, 420, 250, 0.08, 0.45, "tri")
	_noise(b, 0.02, 0.3, 0.7)
	_add("hit_wood", b)
	b = _buf(0.4)
	_tone(b, 520, 500, 0.4, 0.35, "sine")
	_tone(b, 785, 760, 0.35, 0.22, "sine")
	_tone(b, 1050, 1000, 0.3, 0.12, "sine")
	_noise(b, 0.03, 0.4, 0.6)
	_add("hit_pan", b)
	b = _buf(0.28)
	_tone(b, 900, 1500, 0.14, 0.35, "square", 0.0, 0.004, 0.02)
	_tone(b, 1500, 1000, 0.14, 0.3, "square", 0.13)
	_add("hit_squeak", b)
	b = _buf(0.16)
	_noise(b, 0.14, 0.6, 0.25)
	_tone(b, 140, 70, 0.12, 0.4, "sine")
	_add("hit_fish", b)
	b = _buf(0.12)
	_noise(b, 0.12, 0.6, 0.7, 0.0, "crackle")
	_add("hit_bread", b)
	b = _buf(0.12)
	_tone(b, 700, 1400, 0.1, 0.25, "square")
	_noise(b, 0.05, 0.2, 0.9)
	_add("hit_energy", b)
	b = _buf(0.3)
	_noise(b, 0.25, 0.4, 0.95, 0.0, "decay", 0.3)
	_tone(b, 2400, 2200, 0.2, 0.1, "sine")
	_tone(b, 3100, 2900, 0.15, 0.08, "sine", 0.05)
	_add("hit_glass", b)
	# Defence
	b = _buf(0.1)
	_tone(b, 220, 180, 0.08, 0.35, "square")
	_noise(b, 0.05, 0.3, 0.6)
	_add("block", b)
	b = _buf(0.35)
	_tone(b, 1500, 1500, 0.35, 0.3, "sine")
	_tone(b, 2250, 2250, 0.3, 0.18, "sine")
	_tone(b, 3000, 3000, 0.2, 0.1, "sine")
	_add("parry", b)
	b = _buf(0.3)
	_tone(b, 300, 120, 0.3, 0.4, "square")
	_noise(b, 0.2, 0.3, 0.3)
	_add("guard_break", b)
	# Items
	b = _buf(0.12)
	_tone(b, 660, 660, 0.05, 0.25, "pulse")
	_tone(b, 990, 990, 0.07, 0.25, "pulse", 0.05)
	_add("pickup", b)
	b = _buf(0.16)
	_noise(b, 0.16, 0.45, 0.25, 0.0, "swell", 0.05)
	_tone(b, 300, 200, 0.06, 0.15, "tri")
	_add("throw", b)
	b = _buf(0.12)
	_tone(b, 1400, 280, 0.12, 0.25, "square")
	_add("shoot_pew", b)
	b = _buf(0.18)
	_tone(b, 240, 150, 0.16, 0.4, "tri")
	_noise(b, 0.06, 0.25, 0.5)
	_add("shoot_bow", b)
	b = _buf(0.08)
	_tone(b, 380, 820, 0.07, 0.35, "sine")
	_add("shoot_pop", b)
	b = _buf(0.7)
	_noise(b, 0.7, 0.9, 0.08)
	_tone(b, 90, 30, 0.5, 0.6, "sine")
	_add("explosion", b)
	b = _buf(0.35)
	_noise(b, 0.3, 0.25, 0.95, 0.0, "decay", 0.5)
	for k in 4:
		_tone(b, 1600 + k * 400, 1600 + k * 400, 0.08, 0.12, "sine", k * 0.06)
	_add("freeze", b)
	b = _buf(0.28)
	_noise(b, 0.28, 0.5, 0.9, 0.0, "crackle", 0.2)
	_tone(b, 90, 60, 0.28, 0.2, "square")
	_add("zap", b)
	b = _buf(0.35)
	_noise(b, 0.35, 0.4, 0.3, 0.0, "crackle")
	_add("fire", b)
	b = _buf(0.12)
	_tone(b, 280, 640, 0.1, 0.35, "sine")
	_add("bubble", b)
	b = _buf(0.3)
	_noise(b, 0.3, 0.5, 0.6, 0.0, "decay", 0.2)
	_add("splash", b)
	b = _buf(0.35)
	_noise(b, 0.3, 0.6, 0.45, 0.0, "crackle")
	_tone(b, 200, 90, 0.15, 0.3, "tri")
	_add("crate_break", b)
	b = _buf(0.6)
	_noise(b, 0.5, 0.8, 0.1)
	_tone(b, 70, 35, 0.6, 0.6, "sine")
	_add("cannon", b)
	b = _buf(0.18)
	for k in 3:
		_tone(b, 660 * pow(1.26, k), 660 * pow(1.26, k), 0.05, 0.2, "pulse", k * 0.05)
	_add("powerup", b)
	b = _buf(0.12)
	_tone(b, 1320, 1760, 0.1, 0.22, "pulse")
	_add("coin", b)
	# Cats
	for v in 3:
		b = _buf(0.42)
		_meow(b, 1.0 + v * 0.12)
		_add("meow", b)
	b = _buf(0.45)
	_noise(b, 0.45, 0.55, 0.9, 0.0, "swell", 0.6)
	_add("hiss", b)
	b = _buf(0.7)
	_tone(b, 700, 300, 0.7, 0.3, "saw", 0.0, 0.05, 0.03)
	_add("yowl", b)
	b = _buf(0.6)
	for k in 15:
		_noise(b, 0.03, 0.4, 0.06, k * 0.04, "decay")
	_add("purr", b)
	# KO + match flow
	b = _buf(0.55)
	_tone(b, 880, 110, 0.5, 0.3, "square")
	_noise(b, 0.4, 0.5, 0.12)
	_add("ko", b)
	b = _buf(0.06)
	_tone(b, 880, 880, 0.04, 0.15, "pulse")
	_add("ui_move", b)
	b = _buf(0.12)
	_tone(b, 660, 660, 0.05, 0.22, "pulse")
	_tone(b, 990, 990, 0.07, 0.22, "pulse", 0.05)
	_add("ui_select", b)
	b = _buf(0.12)
	_tone(b, 660, 660, 0.05, 0.2, "pulse")
	_tone(b, 440, 440, 0.07, 0.2, "pulse", 0.05)
	_add("ui_back", b)
	b = _buf(0.18)
	_tone(b, 150, 140, 0.18, 0.25, "square")
	_add("ui_error", b)
	b = _buf(0.15)
	_tone(b, 880, 880, 0.14, 0.3, "pulse")
	_add("count", b)
	b = _buf(0.5)
	_tone(b, 1320, 1320, 0.45, 0.25, "pulse")
	_tone(b, 660, 660, 0.45, 0.25, "square")
	_tone(b, 990, 990, 0.45, 0.15, "pulse")
	_add("go", b)
	b = _buf(0.7)
	var arp := [523.0, 659.0, 784.0, 1046.0]
	for k in arp.size():
		_tone(b, arp[k], arp[k], 0.22, 0.25, "pulse", k * 0.11)
	_add("round_win", b)
	b = _buf(1.6)
	var fan := [523.0, 523.0, 523.0, 659.0, 784.0, 659.0, 784.0, 1046.0]
	var st := [0.0, 0.12, 0.24, 0.36, 0.6, 0.84, 0.96, 1.08]
	for k in fan.size():
		_tone(b, fan[k], fan[k], 0.4 if k == fan.size() - 1 else 0.14, 0.25, "pulse", st[k])
		_tone(b, fan[k] / 2.0, fan[k] / 2.0, 0.14, 0.15, "tri", st[k])
	_add("victory", b)
	b = _buf(0.6)
	_tone(b, 700, 700, 0.15, 0.25, "square")
	_tone(b, 520, 520, 0.15, 0.25, "square", 0.15)
	_tone(b, 700, 700, 0.15, 0.25, "square", 0.3)
	_tone(b, 520, 520, 0.15, 0.25, "square", 0.45)
	_add("warning", b)
	b = _buf(1.0)
	_noise(b, 1.0, 0.6, 0.04, 0.0, "swell")
	_add("rumble", b)
	b = _buf(0.25)
	_tone(b, 200, 800, 0.25, 0.3, "saw")
	_add("roar", b)


func _meow(b: PackedFloat32Array, pitch: float) -> void:
	# Saw source with pitch contour (rise then fall) through a lowpass whose
	# cutoff opens ("me-") and closes ("-ow"): a cheap formant-ish meow.
	var n := b.size()
	var ph := 0.0
	var y := 0.0
	var y2 := 0.0
	for i in n:
		var t := float(i) / n
		var f := (520.0 + 260.0 * sin(t * PI) - 120.0 * t) * pitch
		ph += f / SR
		var src := 2.0 * fmod(ph, 1.0) - 1.0
		var cut := 0.05 + 0.35 * sin(clampf(t * 1.4, 0.0, 1.0) * PI)
		y += cut * (src - y)
		y2 += cut * (y - y2)
		var env := minf(1.0, t * 12.0) * pow(1.0 - t, 1.2)
		b[i] += y2 * env * 0.55
