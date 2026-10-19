class_name SynthAudio
extends Node

const MIX_RATE := 22050
const POOL_SIZE := 12

var enabled: bool = true
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
var _charge_player: AudioStreamPlayer
var _thrust_player: AudioStreamPlayer
var _space_player: AudioStreamPlayer
var _loops: Dictionary = {}
var _last_cue: Dictionary = {}
var _kit_id := ""
var _mix_duck := 0.0


func _ready() -> void:
	_build_streams()
	for index in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SynthVoice%02d" % index
		player.bus = &"Master"
		add_child(player)
		_players.append(player)
	for id in ["graviton", "bastion", "scrapper", "redline", "thruster", "space"]:
		_loops[id] = _make_machine_loop({"graviton": 72.0, "bastion": 96.0, "scrapper": 54.0, "redline": 132.0, "thruster": 44.0, "space": 36.0}[id], 0.24 if id != "space" else 0.12)
	_charge_player = _loop_voice("KitContinuous")
	_thrust_player = _loop_voice("ThrusterContinuous")
	_space_player = _loop_voice("VoidBed")
	_thrust_player.stream = _loops["thruster"]
	_space_player.stream = _loops["space"]


func set_charge(active: bool, ratio: float = 0.0, chassis: String = "graviton") -> void:
	if not is_instance_valid(_charge_player):
		return
	if chassis != _kit_id:
		_charge_player.stop()
		_charge_player.stream = _loops.get(chassis, _loops["graviton"])
		_kit_id = chassis
	_charge_player.pitch_scale = lerpf(0.8, 1.45, clampf(ratio, 0, 1))
	_charge_player.volume_db = -25 + ratio * 7 + _effects_db() - _mix_duck
	if active and enabled and not _charge_player.playing:
		_charge_player.play()
	elif not active:
		_charge_player.stop()


func update_flight(ship: PlayerShip, _chassis: String, hive_active: bool) -> void:
	if not enabled or ship.is_dead:
		stop_flight()
		return
	_mix_duck = 5.0 if hive_active else 0.0
	_thrust_player.pitch_scale = 0.8 + minf(1, ship.velocity.length() / ship.move_speed) * 0.35
	_thrust_player.volume_db = -36 + ship.move_intent.length() * 16 + _effects_db() - _mix_duck
	_space_player.volume_db = -33 + _effects_db() - _mix_duck
	if not _space_player.playing:
		_space_player.play()
	if ship.move_intent.length() > 0.02 and not _thrust_player.playing:
		_thrust_player.play()
	elif ship.move_intent.length() <= 0.02:
		_thrust_player.stop()


func stop_flight() -> void:
	for voice in [_thrust_player, _space_player]:
		if is_instance_valid(voice):
			voice.stop()


func _effects_db() -> float:
	return linear_to_db(maxf(Experience.effects_volume, 0.00001))


func _loop_voice(voice_name: String) -> AudioStreamPlayer:
	var voice := AudioStreamPlayer.new()
	voice.name = voice_name
	add_child(voice)
	return voice


func play_cue(cue: StringName) -> void:
	if not enabled or not _streams.has(cue) or _players.is_empty():
		return
	var now := Time.get_ticks_msec()
	var interval := 70 if cue in [&"mass", &"arc", &"impact", &"corona_pulse"] else 25
	if now - int(_last_cue.get(cue, -1000)) < interval:
		return
	_last_cue[cue] = now
	# Critical cues have reserved voices; swarm impacts cannot steal a phase/death.
	var priority := cue in [&"phase", &"boss", &"damage", &"death", &"victory", &"hive_link"]
	var voice := _players[10 + (_next_player % 2) if priority else _next_player % 10]
	_next_player = (_next_player + 1) % 10
	voice.stop()
	voice.stream = _streams[cue]
	voice.volume_db = _volume_for(cue) + _effects_db() - (0 if priority else _mix_duck)
	voice.pitch_scale = 1.0
	voice.play()


func shutdown() -> void:
	enabled = false
	stop_flight()
	for voice in [_thrust_player, _space_player]:
		if is_instance_valid(voice):
			voice.stream = null
			voice.queue_free()
	if is_instance_valid(_charge_player):
		_charge_player.stop()
		_charge_player.stream = null
		_charge_player.queue_free()
	for voice in _players:
		voice.stop()
		voice.stream = null
		voice.queue_free()
	_players.clear()
	_streams.clear()
	_loops.clear()


func _build_streams() -> void:
	_streams[&"mass"] = _make_tone(92.0, 54.0, 0.075, 0.52, 0.03)
	_streams[&"arc"] = _make_tone(720.0, 1320.0, 0.10, 0.32, 0.08)
	_streams[&"vent"] = _make_noise_burst(0.28, 0.58, 110.0)
	_streams[&"upgrade"] = _make_sequence(PackedFloat32Array([330.0, 494.0, 740.0]), 0.11, 0.38)
	_streams[&"damage"] = _make_noise_burst(0.12, 0.50, 64.0)
	_streams[&"boss"] = _make_sequence(PackedFloat32Array([220.0, 165.0, 110.0]), 0.17, 0.46)
	_streams[&"victory"] = _make_sequence(PackedFloat32Array([294.0, 440.0, 587.0, 880.0]), 0.14, 0.38)
	_streams[&"death"] = _make_tone(190.0, 42.0, 0.55, 0.46, 0.26)
	_streams[&"gravity"] = _make_tone(260.0, 60.0, 0.30, 0.4, 0.12)
	_streams[&"rack_load"] = _make_tone(540.0, 860.0, 0.045, 0.18, 0.02)
	_streams[&"salvo"] = _make_noise_burst(0.12, 0.36, 180)
	_streams[&"impact"] = _make_noise_burst(0.18, 0.35, 70)
	_streams[&"phase"] = _make_tone(180.0, 1150.0, 0.17, 0.35, 0.05)
	_streams[&"beam_start"] = _make_noise_burst(0.20, 0.48, 90)
	_streams[&"corona_start"] = _make_tone(55, 180, 0.22, 0.38, 0.2)
	_streams[&"corona_pulse"] = _make_noise_burst(0.10, 0.32, 160)
	_streams[&"collapse"] = _make_tone(165, 28, 0.45, 0.6, 0.35)
	_streams[&"hive_link"] = _make_sequence(PackedFloat32Array([110, 116, 73]), 0.07, 0.24)


func _make_machine_loop(frequency: float, amplitude: float) -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	samples.resize(MIX_RATE)
	var noise_state := 0x13579bdf
	var filtered := 0.0
	for index in MIX_RATE:
		var t := float(index) / MIX_RATE
		var phase := TAU * frequency * t
		noise_state = int((noise_state * 1664525 + 1013904223) & 0xffffffff)
		filtered = lerpf(filtered, float(noise_state & 0xffff) / 32767.5 - 1, 0.15)
		var seam := smoothstep(0, 0.02, t) * (1 - smoothstep(0.98, 1, t))
		var body := sin(phase) * 0.52 + sin(phase * 2) * 0.2 + sin(phase * 3) * 0.08
		samples[index] = (body * (0.88 + sin(TAU * 3 * t) * 0.12) + filtered * 0.32 * seam) * amplitude
	var result := _samples_to_wav(samples)
	result.loop_mode = AudioStreamWAV.LOOP_FORWARD
	result.loop_end = samples.size()
	return result


func _make_tone(start_frequency: float, end_frequency: float, duration: float, amplitude: float, grit: float) -> AudioStreamWAV:
	var frame_count := maxi(1, int(duration * MIX_RATE))
	var samples := PackedFloat32Array()
	samples.resize(frame_count)
	var phase := 0.0
	var noise_state := 0x13579bdf
	for index in range(frame_count):
		var t := float(index) / float(frame_count)
		var frequency := lerpf(start_frequency, end_frequency, t)
		phase += TAU * frequency / float(MIX_RATE)
		noise_state = int((noise_state * 1664525 + 1013904223) & 0xffffffff)
		var noise := (float(noise_state & 0xffff) / 32767.5 - 1.0) * grit
		var envelope := _envelope(t)
		samples[index] = (sin(phase) * (1.0 - grit) + noise) * amplitude * envelope
	return _samples_to_wav(samples)


func _make_noise_burst(duration: float, amplitude: float, tone_frequency: float) -> AudioStreamWAV:
	var frame_count := maxi(1, int(duration * MIX_RATE))
	var samples := PackedFloat32Array()
	samples.resize(frame_count)
	var phase := 0.0
	var noise_state := 0x2468ace1
	for index in range(frame_count):
		var t := float(index) / float(frame_count)
		phase += TAU * lerpf(tone_frequency * 1.7, tone_frequency, t) / float(MIX_RATE)
		noise_state = int((noise_state * 1103515245 + 12345) & 0x7fffffff)
		var noise := float(noise_state & 0xffff) / 32767.5 - 1.0
		samples[index] = (noise * 0.62 + sin(phase) * 0.38) * amplitude * pow(1.0 - t, 1.8)
	return _samples_to_wav(samples)


func _make_sequence(frequencies: PackedFloat32Array, note_duration: float, amplitude: float) -> AudioStreamWAV:
	var note_frames := maxi(1, int(note_duration * MIX_RATE))
	var samples := PackedFloat32Array()
	samples.resize(note_frames * frequencies.size())
	var write_index := 0
	for frequency in frequencies:
		var phase := 0.0
		for index in range(note_frames):
			var t := float(index) / float(note_frames)
			phase += TAU * frequency / float(MIX_RATE)
			samples[write_index] = (sin(phase) + sin(phase * 2.0) * 0.18) * amplitude * _envelope(t)
			write_index += 1
	return _samples_to_wav(samples)


func _samples_to_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for index in range(samples.size()):
		var encoded := int(clampf(samples[index], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(index * 2, encoded)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = MIX_RATE
	stream.stereo = false
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = bytes
	return stream


func _envelope(t: float) -> float:
	var attack := smoothstep(0.0, 0.08, t)
	var release := 1.0 - smoothstep(0.45, 1.0, t)
	return attack * release


func _volume_for(cue: StringName) -> float:
	match cue:
		&"mass", &"arc":
			return -17.0
		&"upgrade":
			return -9.0
		&"vent", &"boss", &"victory", &"death":
			return -6.0
		&"damage":
			return -11.0
		_:
			return -12.0
