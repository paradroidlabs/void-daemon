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
	var music := root.get_node("Music")
	var original_roots: Array[String] = music.search_roots.duplicate()
	var fixture := ProjectSettings.globalize_path("res://.godot/music-fixture")
	DirAccess.make_dir_recursive_absolute(fixture.path_join("lab"))
	# Silent generated test data only, never substituted for the user's music.
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 22050
	var bytes := PackedByteArray()
	bytes.resize(22050 * 2 * 6)
	wav.data = bytes
	check(wav.save_to_wav(fixture.path_join("01-test.wav")) == OK, "Fixture saves a raw WAV outside the import pipeline")
	check(wav.save_to_wav(fixture.path_join("lab/02-lab.wav")) == OK, "Fixture saves a context-specific raw WAV")
	music.search_roots.assign([fixture])
	music.set_context("hangar")
	music.reload_library()
	check(music.playlists["default"].size() == 1 and music.playlists["lab"].size() == 1, "Runtime drop-folder scan separates fallback and context tracks")
	check(music.current_path.ends_with("01-test.wav") and music.has_active_music(), "Raw WAV loads and plays without editor import")
	check(music._players.size() == 2, "Music uses exactly two bounded voices")
	music._process(2)
	var slot: int = music._active
	var full_db: float = music._players[slot].volume_db
	music.set_ducked(true)
	music._process(0)
	check(is_equal_approx(music._players[slot].volume_db, full_db - 8), "Hive ducks music by 8 dB")
	music.set_ducked(false)
	paused = true
	music._process(0)
	check(is_equal_approx(music._players[slot].volume_db, full_db - 6), "Pause keeps music playing quietly")
	paused = false
	music.set_context("survival")
	check(music._active == slot and music.current_path.ends_with("01-test.wav"), "Shared fallback continues across contexts instead of restarting")
	music.set_context("lab")
	check(music._active != slot and music._targets[slot] == 0 and music.current_path.ends_with("02-lab.wav"), "Context-specific soundtrack crossfades")
	music._process(2)
	check(not music._players[slot].playing and music._players[slot].stream == null, "Faded voice releases its stream")
	check(music._players[music._active].pitch_scale == 1, "Music pitch and tempo are never gameplay-modulated")
	settings.update_setting("music_volume", 0.0)
	music._process(0)
	check(music._players[music._active].volume_linear == 0 and not music.has_active_music(), "Music zero is an actual independent mute")
	check(settings.effects_volume > 0 and not AudioServer.is_bus_mute(0), "Muting music does not mute effects or Master")
	settings.update_setting("music_volume", 0.65)
	var controls: VBoxContainer = settings.create_controls()
	check(controls.find_child("ReloadMusicButton", true, false) != null, "Settings have a native reload button")
	controls.free()
	music.search_roots.assign([fixture.path_join("missing")])
	music.reload_library()
	music._process(2)
	check(music.current_path.is_empty() and not music.has_active_music(), "Missing music folder is safe and silent")
	music.search_roots = original_roots
	music.reload_library()
	await process_frame
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("MUSIC_DIRECTOR_OK runtime raw WAV / playlists / fallback continuity / crossfade / hive-pause duck / bounded voices / independent mute / missing files")
	quit(0 if failures.is_empty() else 1)
