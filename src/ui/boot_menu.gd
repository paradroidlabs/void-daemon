extends Node

const Catalog := preload("res://src/systems/chassis_catalog.gd")
var menu: Control
var game: Node2D
var selected := "graviton"
var _summary: Label
var _stats: Label
var _preview: Node2D
var _settings: PanelContainer
var _ship_buttons: Array[Button] = []
var _time := 0.0
var _layout: Control
var _compact := false
var _settings_back: Button
var _launch_cli := false
var _seed := "VOID-0001"
var _touch := false
var _direct_flight := false


class BootSurface extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("080f19"))
		for i in range(56):
			var p := Vector2(fposmod(i * 307.7 + 36, size.x), fposmod(i * 193.1 + 62, size.y))
			draw_circle(p, 1 if i % 3 else 1.5, Color(0.32, 0.54, 0.62, 0.3))
		for x in range(0, int(size.x), 80):
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(0.1, 0.28, 0.33, 0.14))
		for y in range(0, int(size.y), 80):
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(0.1, 0.28, 0.33, 0.14))
		var c := Vector2(size.x * 0.76, size.y * 0.40)
		for r in [90, 128, 170]:
			draw_arc(c, r, 0, TAU, 90, Color(0.3, 0.65, 0.68, 0.18), 1, true)


func _ready() -> void:
	get_viewport().size_changed.connect(func():
		if is_instance_valid(menu):
			call_deferred("show_menu")
	)
	selected = Experience.selected_chassis if Experience.selected_chassis in Catalog.ORDER else "graviton"
	var direct := false
	var explicit_chassis := false
	for argument in OS.get_cmdline_user_args():
		if argument in ["--combo-lab", "--classic", "--smoke-test", "--capture-test", "--capture-end-screen", "--skip-menu"] or argument.begins_with("--capture-"):
			direct = true
		if argument.begins_with("--chassis=") and argument.trim_prefix("--chassis=") in Catalog.ORDER:
			selected = argument.trim_prefix("--chassis=")
			explicit_chassis = true
		if argument.begins_with("--seed="):
			_seed = argument.trim_prefix("--seed=").strip_edges().to_upper()
		if argument == "--touch-ui":
			_touch = true
		if argument == "--direct-flight":
			_direct_flight = true
	if _seed.is_empty():
		_seed = "VOID-0001"
	if direct:
		_launch_cli = true
		if not explicit_chassis:
			selected = "graviton"
		launch_run(OS.get_cmdline_user_args().has("--combo-lab"), selected)
	else:
		show_menu()


func show_menu() -> void:
	get_tree().paused = false
	Experience.stop_voice()
	if is_instance_valid(game):
		game.synth_audio.shutdown()
		game.queue_free()
		game = null
	if is_instance_valid(menu):
		menu.queue_free()
	_ship_buttons.clear()
	get_window().title = "VOID//DAEMON | %s | HANGAR" % ProjectSettings.get_setting("application/config/version", "prototype")
	menu = BootSurface.new()
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(menu)
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Consolas", "DejaVu Sans Mono", "monospace"])
	theme.default_font = font
	theme.default_font_size = 15
	for state in ["normal", "hover", "pressed", "focus"]:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("10232d") if state == "normal" else Color("21404b")
		box.border_color = Color("68f7e5") if state != "normal" else Color("2e5960")
		box.set_border_width_all(1 if state == "normal" else 2)
		theme.set_stylebox(state, "Button", box)
	theme.set_color("font_color", "Label", Color("c4d7dd"))
	theme.set_color("font_color", "Button", Color("b8e9e2"))
	menu.theme = theme
	var viewport_size := get_viewport().get_visible_rect().size
	var window_size := Vector2(DisplayServer.window_get_size())
	var ui_scale := 1.0
	if DisplayServer.get_name() != "headless" and window_size.x > 0 and window_size.y > 0:
		ui_scale = maxf(1, minf(viewport_size.x / window_size.x, viewport_size.y / window_size.y))
	_layout = Control.new()
	_layout.scale = Vector2.ONE * ui_scale
	_layout.size = viewport_size / ui_scale
	menu.add_child(_layout)
	_compact = _layout.size.x < 1000 or _layout.size.y < 650
	var column_width := minf(654, _layout.size.x - 32) if _compact else 654.0
	var scroll: ScrollContainer
	if _compact:
		scroll = ScrollContainer.new()
		scroll.position = Vector2(16, 16)
		scroll.size = _layout.size - Vector2(32, 32)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		_layout.add_child(scroll)
	var left := VBoxContainer.new()
	left.position = Vector2.ZERO if _compact else Vector2(52, 40)
	left.size = Vector2(column_width, 620)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 13)
	if _compact:
		scroll.add_child(left)
	else:
		_layout.add_child(left)
	label(left, "BOOT / FLIGHT SYSTEMS ONLINE", 12, Color("68f7e5"))
	label(left, "VOID//DAEMON", 32 if _compact else 50, Color("e0efed"))
	label(left, "THE VOID HAS NOTICED YOU.", 16, Color("d799ff"))
	label(left, "01 / SELECT A CHASSIS", 12, Color("72939e"))
	var ships := GridContainer.new()
	ships.columns = 2 if _compact else 4
	ships.add_theme_constant_override("h_separation", 8)
	ships.add_theme_constant_override("v_separation", 8)
	left.add_child(ships)
	for id in Catalog.ORDER:
		var button := action(ships, Catalog.get_ship(id)["name"], func(): select_ship(id))
		button.custom_minimum_size = Vector2((column_width - 8) / 2 if _compact else 154, 48)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		_ship_buttons.append(button)
	_summary = label(left, "", 16, Color("e0efed"))
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary.custom_minimum_size.y = 62
	_stats = label(left, "", 13, Color("92b2bb"))
	_stats.custom_minimum_size.y = 78
	var controls := label(left, "WASD / ARROWS : THRUST     MOUSE : AIM\nHOLD M1 : CHASSIS ATTACK   SHIFT / SPACE : MANEUVER\nTOUCH : LEFT THRUST + RIGHT HOLD / AIM / RELEASE\nCONTROLLER : LS THRUST / RS AIM / RT ATTACK / RB OR A MANEUVER", 12, Color("92b2bb"))
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	left.add_child(actions)
	var launch := action(actions, "DEPLOY / SURVIVAL", func(): launch_run(false, selected))
	var action_width := (column_width - 12) / 2 if _compact else 314.0
	launch.custom_minimum_size = Vector2(action_width, 54)
	action(actions, "OPEN COMBAT LAB", func(): launch_run(true, selected)).custom_minimum_size = Vector2(action_width, 54)
	var lower := HBoxContainer.new()
	lower.add_theme_constant_override("separation", 12)
	left.add_child(lower)
	action(lower, "SOUND / ACCESSIBILITY", func(): _settings.show(); _settings_back.grab_focus()).custom_minimum_size = Vector2(action_width, 44)
	action(lower, "EXIT", func(): get_tree().quit()).custom_minimum_size = Vector2(action_width, 44)
	label(left, "%s // PROTOTYPE / LIVE HIVE SIGNAL" % ProjectSettings.get_setting("application/config/version", "DEV"), 10, Color("597984"))
	var preview_label := Label.new()
	preview_label.text = "CHASSIS LINK // LIVE SCHEMATIC\n\nCYAN NOSE / AMBER TRAVEL\nTHRUST DOES NOT ERASE MOMENTUM"
	preview_label.position = Vector2(810, 495)
	preview_label.size = Vector2(400, 80)
	preview_label.add_theme_font_size_override("font_size", 12)
	preview_label.add_theme_color_override("font_color", Color("72939e"))
	_layout.add_child(preview_label)
	preview_label.visible = not _compact
	_build_settings()
	select_ship(selected)
	launch.grab_focus()


func _build_settings() -> void:
	var blocker := ColorRect.new()
	blocker.color = Color(0, 0.02, 0.04, 0.84)
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.z_index = 50
	menu.add_child(blocker)
	_settings = PanelContainer.new()
	_settings.z_index = 51
	_settings.visibility_changed.connect(func(): blocker.visible = _settings.visible)
	_settings.position = Vector2(12, 12) if _compact else Vector2(350, 100)
	_settings.size = _layout.size - Vector2(24, 24) if _compact else Vector2(580, 540)
	var box := StyleBoxFlat.new()
	box.bg_color = Color("0b1723")
	box.border_color = Color("68f7e5")
	box.set_border_width_all(2)
	box.set_content_margin_all(14 if _compact else 26)
	_settings.add_theme_stylebox_override("panel", box)
	_layout.add_child(_settings)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_settings.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 14)
	scroll.add_child(rows)
	label(rows, "02 / SIGNAL & SENSORY SYSTEMS", 14 if _compact else 20, Color("68f7e5"))
	var back := action(rows, "BACK TO HANGAR", func(): _settings.hide(); _ship_buttons[Catalog.ORDER.find(selected)].grab_focus())
	_settings_back = back
	rows.add_child(Experience.create_controls())
	var note := label(rows, "HIVE SPEECH USES AN INSTALLED ENGLISH SYSTEM VOICE.\nNO VOICE AVAILABLE? SUBTITLES STILL WORK.\nOBSERVATIONS USE THIS RUN ONLY. NO PERSONAL DATA.", 11, Color("72939e"))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	back.name = "Back"
	_settings.hide()


func _unhandled_input(event: InputEvent) -> void:
	if is_instance_valid(menu) and event.is_action_pressed("ui_cancel") and _settings.visible:
		_settings.hide()
		_ship_buttons[Catalog.ORDER.find(selected)].grab_focus()
		get_viewport().set_input_as_handled()


func select_ship(id: String) -> void:
	selected = id
	Experience.update_setting("selected_chassis", id)
	var spec := Catalog.get_ship(id)
	_summary.text = spec["summary"]
	_stats.text = "M1: %s\nSHIFT / SPACE: %s / %.1fs\nHULL %03d + SHIELD %02d   CRUISE %03d u/s\nTHRUST %03d u/s²   DRAG %.2f/s" % [spec["attack"], spec["maneuver"], spec["cooldown"], spec["hull"], spec["shield"], spec["cruise"], spec["thrust"], spec["drag"]]
	for index in _ship_buttons.size():
		_ship_buttons[index].set_pressed_no_signal(Catalog.ORDER[index] == id)
	if is_instance_valid(_preview):
		_preview.queue_free()
	_preview = preload("res://src/actors/player_ship.gd").new()
	_preview.configure_chassis(id)
	_preview.combo_mode = true
	_preview.position = Vector2(973, 288)
	_preview.scale = Vector2.ONE * 4.2
	_preview.rotation = -PI / 2
	_layout.add_child(_preview)
	_preview.visible = not _compact
	_preview.set_physics_process(false)
	# It is the actual ship renderer; never put this hangar preview in simulation groups.
	_preview.remove_from_group("player")
	_preview.collision_layer = 0
	_preview.collision_mask = 0


func launch_run(lab: bool, id: String, classic: bool = false) -> void:
	get_tree().paused = false
	Experience.stop_voice()
	if is_instance_valid(menu):
		menu.queue_free()
		menu = null
	if is_instance_valid(game):
		game.synth_audio.shutdown()
		game.queue_free()
	game = preload("res://src/main.tscn").instantiate()
	game._honor_command_line = _launch_cli
	_launch_cli = false
	game._chassis = id
	game._combat_lab = lab
	game._combo_mode = not classic
	game.run_seed_text = _seed
	game._using_touch = _touch
	game._direct_flight = _direct_flight
	add_child(game)


func _process(delta: float) -> void:
	_time += delta
	if is_instance_valid(menu) and is_instance_valid(_preview):
		if not Experience.reduced_effects:
			_preview.rotation = -PI / 2 + sin(_time * 0.45) * 0.23
			_preview.unleash_charge_ratio = (sin(_time * 1.7) + 1) * 0.5
			_preview.unleash_loaded = 1 + int(_preview.unleash_charge_ratio * 5) if selected == "graviton" else 0
		_preview.queue_redraw()


func label(parent: Node, text: String, font_size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	parent.add_child(result)
	return result


func action(parent: Node, text: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	if _compact:
		result.add_theme_font_size_override("font_size", 12)
	result.custom_minimum_size.y = 44
	result.pressed.connect(callback)
	parent.add_child(result)
	return result
