extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func run() -> void:
	var settings := root.get_node("Experience")
	settings.persist = false
	var audio = load("res://src/audio/synth_audio.gd").new()
	root.add_child(audio)
	var ship = load("res://src/actors/player_ship.gd").new()
	root.add_child(ship)
	ship.set_physics_process(false)
	for id in ChassisCatalog.ORDER:
		audio.set_charge(true, 0.7, id)
		check(audio._kit_id == id and audio._charge_player.stream == audio._loops[id], "Each kit has a dedicated continuous sound identity")
		audio.set_charge(false)
		check(not audio._charge_player.playing, "Release/cancel stops continuous kit audio")
	check(audio._players.size() == 12, "One-shot voice count stays bounded")
	for cue in [&"beam_start", &"corona_start", &"corona_pulse", &"collapse", &"hive_link", &"phase", &"salvo"]:
		check(audio._streams.has(cue), "All new gameplay cues resolve: " + String(cue))
	var all_streams: Array = audio._streams.values() + audio._loops.values()
	for stream: AudioStreamWAV in all_streams:
		var peak := 0.0
		var power := 0.0
		var bytes := stream.data
		for offset in range(0, bytes.size(), 2):
			var sample := float(bytes.decode_s16(offset)) / 32768
			peak = maxf(peak, absf(sample))
			power += sample * sample
		check(peak < 0.95 and peak > 0.01 and power > 0, "Synth asset is non-silent and has peak headroom")
	ship.set_move_intent(Vector2.RIGHT)
	audio.update_flight(ship, "graviton", false)
	check(audio._thrust_player.playing and audio._space_player.playing, "Engine responds to actual thrust")
	ship.set_move_intent(Vector2.ZERO)
	audio.update_flight(ship, "graviton", true)
	check(not audio._thrust_player.playing and audio._mix_duck == 5, "Coasting silences thrust and hive feed ducks effects")
	settings.update_setting("master_volume", 0.0)
	check(AudioServer.is_bus_mute(0), "Master zero is an actual mute")
	settings.update_setting("master_volume", 0.8)
	settings.update_setting("effects_volume", 0.0)
	check(audio._effects_db() < -90, "Effects volume silences continuous and transient roles")
	settings.update_setting("effects_volume", 0.85)
	audio.shutdown()
	all_streams.clear()
	check(not audio.enabled and audio._players.is_empty() and audio._streams.is_empty(), "Shutdown releases bounded voices and data")
	audio.queue_free()
	ship.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("EXPERIENCE_AUDIO_OK distinct continuous roles / all cues / waveform headroom / bounded voices / thrust-coast / ducking / mute / cleanup")
	quit(0 if failures.is_empty() else 1)
