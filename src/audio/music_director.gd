extends Node

## User-authored local soundtrack, independent of gameplay RNG and SFX volume.
## Two bounded voices crossfade; no tempo, pitch or composition changes.
signal library_changed

const CONTEXTS := ["hangar", "survival", "lab", "debrief", "race"]
const EXTENSIONS := ["ogg", "mp3", "wav"]
var search_roots: Array[String] = []
var playlists: Dictionary = {}
var context := "hangar"
var current_path := ""
var _players: Array[AudioStreamPlayer] = []
var _gains := [0.0, 0.0]
var _targets := [0.0, 0.0]
var _active := -1
var _ducked := false
var _next_index := 0


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	search_roots.append("res://assets/music")
	# Exported games accept raw files beside the EXE; no editor/import required.
	if not OS.has_feature("editor"):
		search_roots.append(OS.get_executable_path().get_base_dir().path_join("music"))
	for i in range(2):
		var voice := AudioStreamPlayer.new()
		voice.name = "MusicVoice%d" % i
		voice.volume_db = -80
		voice.finished.connect(_on_finished.bind(i))
		add_child(voice)
		_players.append(voice)
	reload_library()


func reload_library() -> void:
	playlists.clear()
	playlists["default"] = []
	for folder in CONTEXTS:
		playlists[folder] = []
	for base in search_roots:
		_scan(base, "default")
		for folder in CONTEXTS:
			_scan(base.path_join(folder), folder)
	_next_index = 0
	_select_track(true)
	library_changed.emit()


func _scan(folder: String, category: String) -> void:
	if not DirAccess.dir_exists_absolute(folder):
		return
	var paths: Array[String] = []
	for file in DirAccess.get_files_at(folder):
		# Imported resources can be listed with their remap/import sidecars in PCKs.
		var original: String = file.trim_suffix(".remap").trim_suffix(".import")
		if original.get_extension().to_lower() in EXTENSIONS:
			var path := folder.path_join(original)
			if not paths.has(path):
				paths.append(path)
	paths.sort()
	playlists[category].append_array(paths)


func set_context(value: String) -> void:
	if context == value:
		return
	context = value
	_ducked = false
	_next_index = 0
	_select_track(true)


func set_ducked(value: bool) -> void:
	_ducked = value


func has_active_music() -> bool:
	return _active >= 0 and _players[_active].playing and Experience.music_volume > 0


func _select_track(keep_current: bool = false) -> void:
	var choices: Array = playlists.get(context, [])
	if choices.is_empty():
		choices = playlists.get("default", [])
	if keep_current and current_path in choices and _active >= 0 and _players[_active].playing:
		_next_index = (choices.find(current_path) + 1) % choices.size()
		return
	for offset in choices.size():
		var index := (_next_index + offset) % choices.size()
		var path: String = choices[index]
		var stream := _load_track(path)
		if stream == null:
			continue
		var slot := 0 if _active != 0 else 1
		_players[slot].stop()
		_gains[slot] = 0
		_players[slot].volume_db = -80
		_players[slot].stream = stream
		_players[slot].pitch_scale = 1
		_players[slot].play()
		_targets = [0.0, 0.0]
		_targets[slot] = 1
		_active = slot
		current_path = path
		_next_index = (index + 1) % choices.size()
		return
	_targets = [0.0, 0.0]
	_active = -1
	current_path = ""


func _load_track(path: String) -> AudioStream:
	if path.begins_with("res://") and ResourceLoader.exists(path):
		return load(path) as AudioStream
	if not FileAccess.file_exists(path):
		return null
	match path.get_extension().to_lower():
		"ogg": return AudioStreamOggVorbis.load_from_file(path)
		"mp3": return AudioStreamMP3.load_from_file(path)
		"wav": return AudioStreamWAV.load_from_file(path)
	return null


func _on_finished(slot: int) -> void:
	if slot == _active:
		_select_track()


func _process(delta: float) -> void:
	var duck_db := -8.0 if _ducked else (-6.0 if get_tree().paused else 0.0)
	for i in _players.size():
		_gains[i] = move_toward(_gains[i], _targets[i], delta / 1.5)
		var gain: float = _gains[i] * Experience.music_volume
		_players[i].volume_db = linear_to_db(maxf(gain, 0.0001)) - 9 + duck_db
		# Zero is a true mute, including during crossfades.
		_players[i].volume_linear = 0 if gain <= 0 else db_to_linear(_players[i].volume_db)
		if _targets[i] == 0 and _gains[i] == 0:
			_players[i].stop()
			_players[i].stream = null
