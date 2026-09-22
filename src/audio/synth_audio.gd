class_name SynthAudio
extends Node

const MIX_RATE := 22050
const POOL_SIZE := 12

var enabled: bool = true
var _streams: Dictionary = {}
var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0


func _ready() -> void:
	_build_streams()
	for index in range(POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SynthVoice%02d" % index
		player.bus = &"Master"
		add_child(player)
		_players.append(player)


func play_cue(cue: StringName) -> void:
	if not enabled or not _streams.has(cue) or _players.is_empty():
		return
	var voice := _players[_next_player]
	_next_player = (_next_player + 1) % _players.size()
	voice.stop()
	voice.stream = _streams[cue]
	voice.volume_db = _volume_for(cue)
	voice.pitch_scale = 1.0
	voice.play()


func shutdown() -> void:
	enabled = false
	for voice in _players:
		voice.stop()
		voice.stream = null
		voice.queue_free()
	_players.clear()
	_streams.clear()


func _build_streams() -> void:
	_streams[&"mass"] = _make_tone(92.0, 54.0, 0.075, 0.52, 0.03)
	_streams[&"arc"] = _make_tone(720.0, 1320.0, 0.10, 0.32, 0.08)
	_streams[&"vent"] = _make_noise_burst(0.28, 0.58, 110.0)
	_streams[&"upgrade"] = _make_sequence(PackedFloat32Array([330.0, 494.0, 740.0]), 0.11, 0.38)
	_streams[&"damage"] = _make_noise_burst(0.12, 0.50, 64.0)
	_streams[&"boss"] = _make_sequence(PackedFloat32Array([220.0, 165.0, 110.0]), 0.17, 0.46)
	_streams[&"victory"] = _make_sequence(PackedFloat32Array([294.0, 440.0, 587.0, 880.0]), 0.14, 0.38)
	_streams[&"death"] = _make_tone(190.0, 42.0, 0.55, 0.46, 0.26)


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
