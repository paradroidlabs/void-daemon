extends Node

signal changed

var master_volume := 0.8
var effects_volume := 0.85
var hive_volume := 0.65
var hive_voice := true
var narrative_windows := true
var reduced_effects := false
var selected_chassis := "graviton"
var persist := true
var _voice := ""


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load("user://experience.cfg") == OK:
		for key in ["master_volume", "effects_volume", "hive_volume", "hive_voice", "narrative_windows", "reduced_effects", "selected_chassis"]:
			if config.has_section_key("experience", key):
				set(key, config.get_value("experience", key))
	master_volume = clampf(master_volume, 0, 1)
	effects_volume = clampf(effects_volume, 0, 1)
	hive_volume = clampf(hive_volume, 0, 1)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(0, master_volume <= 0)
	if AudioServer.get_bus_effect_count(0) == 0:
		var limiter := AudioEffectLimiter.new()
		limiter.ceiling_db = -1
		AudioServer.add_bus_effect(0, limiter)
	if DisplayServer.get_name() != "headless":
		var voices := DisplayServer.tts_get_voices_for_language("en")
		if not voices.is_empty():
			_voice = voices[0]


func update_setting(key: String, value: Variant) -> void:
	set(key, value)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(0, master_volume <= 0)
	if not hive_voice or hive_volume == 0 or master_volume == 0:
		stop_voice()
	if persist:
		var config := ConfigFile.new()
		for field in ["master_volume", "effects_volume", "hive_volume", "hive_voice", "narrative_windows", "reduced_effects", "selected_chassis"]:
			config.set_value("experience", field, get(field))
		config.save("user://experience.cfg")
	changed.emit()


func speak(text: String) -> bool:
	if _voice.is_empty() and DisplayServer.get_name() != "headless":
		var voices := DisplayServer.tts_get_voices_for_language("en")
		if not voices.is_empty():
			_voice = voices[0]
	if not hive_voice or _voice.is_empty() or hive_volume * master_volume <= 0 or DisplayServer.get_name() == "headless":
		return false
	# Offline OS synthesis only. Never access a microphone, files or network.
	DisplayServer.tts_speak(text, _voice, roundi(100 * hive_volume * master_volume), 0.72, 0.88, 0, true)
	return true


func stop_voice() -> void:
	if DisplayServer.get_name() != "headless":
		DisplayServer.tts_stop()


func create_controls(compact: bool = false) -> VBoxContainer:
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 5 if compact else 10)
	for field in ["master_volume", "effects_volume", "hive_volume"]:
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = {"master_volume": "MASTER", "effects_volume": "EFFECTS", "hive_volume": "HIVE VOICE"}[field]
		label.custom_minimum_size.x = 114
		label.add_theme_font_size_override("font_size", 12)
		row.add_child(label)
		var slider := HSlider.new()
		slider.custom_minimum_size = Vector2(120, 44)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.min_value = 0
		slider.max_value = 1
		slider.step = 0.05
		slider.value = get(field)
		slider.value_changed.connect(func(value: float): update_setting(field, value))
		row.add_child(slider)
		rows.add_child(row)
	for field in ["hive_voice", "narrative_windows", "reduced_effects"]:
		var button := CheckButton.new()
		button.text = {"hive_voice": "HIVE SPEECH / SUBTITLES ALWAYS ON", "narrative_windows": "PICTURE-IN-PICTURE FEEDS", "reduced_effects": "REDUCED EFFECTS / NO CAMERA SHAKE"}[field]
		button.add_theme_font_size_override("font_size", 11 if compact else 12)
		button.custom_minimum_size.y = 44
		button.button_pressed = get(field)
		button.toggled.connect(func(value: bool): update_setting(field, value))
		rows.add_child(button)
	return rows
