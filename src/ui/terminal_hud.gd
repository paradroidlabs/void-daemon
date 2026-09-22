class_name TerminalHUD
extends CanvasLayer

## Code-only HUD for VOID//DAEMON's terminal presentation.
##
## The HUD deliberately accepts dictionaries instead of gameplay classes.  That
## keeps it useful while the prototype's data model is still changing.

signal upgrade_selected(index: int)
signal restart_requested
signal touch_move_changed(direction: Vector2)
signal touch_vent_pressed
signal touch_target_bias(direction: Vector2, active: bool)

const CYAN := Color(0.35, 0.95, 1.0, 1.0)
const CYAN_DIM := Color(0.13, 0.50, 0.55, 1.0)
const GREEN := Color(0.38, 1.0, 0.55, 1.0)
const AMBER := Color(1.0, 0.72, 0.22, 1.0)
const RED := Color(1.0, 0.25, 0.28, 1.0)
const MAGENTA := Color(0.95, 0.34, 1.0, 1.0)
const INK := Color(0.015, 0.025, 0.035, 0.94)
const INK_LIGHT := Color(0.025, 0.075, 0.09, 0.94)
const TRANSPARENT := Color(0.0, 0.0, 0.0, 0.0)

const TOUCH_STICK_SIZE := 144.0
const TOUCH_STICK_KNOB_SIZE := 58.0
const TOUCH_MARGIN := 24.0
const MODAL_EDGE_PADDING := 16.0
const END_PANEL_MAX_WIDTH := 680.0
const END_PANEL_MAX_HEIGHT := 520.0

var _root: Control
var _status_panel: PanelContainer
var _runtime_label: Label
var _location_label: Label
var _clock_label: Label
var _combat_label: Label
var _integrity_bar: ProgressBar
var _integrity_label: Label
var _heat_bar: ProgressBar
var _heat_label: Label
var _xp_bar: ProgressBar
var _xp_label: Label
var _vent_label: Label
var _log_label: Label
var _log_tween: Tween

var _upgrade_overlay: ColorRect
var _upgrade_list: VBoxContainer
var _upgrade_buttons: Array[Button] = []
var _end_overlay: ColorRect
var _end_center: CenterContainer
var _end_panel: PanelContainer
var _end_title: Label
var _end_stats_scroll: ScrollContainer
var _end_stats: Label
var _restart_button: Button

var _modal_active := false
var _paused_before_modal := false

var _touch_root: Control
var _touch_requested_visible := false
var _stick_zone: Panel
var _stick_knob: Panel
var _vent_button: Button
var _target_zone: Control
var _stick_touch_index := -1
var _stick_mouse_active := false
var _target_touch_index := -1
var _target_mouse_active := false
var _target_origin := Vector2.ZERO
var _last_move_direction := Vector2.ZERO


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_theme_and_root()
	_build_status()
	_build_touch_controls()
	_build_upgrade_overlay()
	_build_end_overlay()
	set_touch_controls_visible(DisplayServer.is_touchscreen_available())
	get_viewport().size_changed.connect(_layout_touch_controls)
	get_viewport().size_changed.connect(_layout_end_screen)
	_layout_touch_controls()
	_layout_end_screen()


func _exit_tree() -> void:
	# SceneTree.paused survives scene changes, so never leave it stuck if the HUD
	# is freed while one of its modal screens is open.
	if _modal_active and is_inside_tree():
		get_tree().paused = _paused_before_modal


## Updates the persistent HUD. All keys are optional. Commonly useful keys:
## process/weapon, sector/biome, seed, threat, time, kills, level,
## integrity/hp, max_integrity/max_hp, heat, max_heat, xp, xp_next,
## vent_ready, vent_cooldown, and fps.
func set_status(status: Dictionary) -> void:
	var process_name := _pick_text(status, ["process", "weapon"], "NO_PROCESS")
	var level := _pick_int(status, ["level"], 1)
	_runtime_label.text = "VOID//DAEMON  ::  %s.R%02d" % [process_name.to_upper(), level]

	var sector := _pick_text(status, ["sector", "biome"], "UNMAPPED")
	var seed := _pick_text(status, ["seed"], "--------")
	var threat := _pick_text(status, ["threat"], "NOMINAL")
	_location_label.text = "SECTOR %s  //  THREAT %s  //  SEED %s" % [sector.to_upper(), threat.to_upper(), seed]

	_clock_label.text = "T+%s" % _format_time(status.get("time", 0.0))
	var kills := _pick_int(status, ["kills"], 0)
	var fps_suffix := ""
	if status.has("fps"):
		fps_suffix = "  //  %d FPS" % int(status["fps"])
	_combat_label.text = "PURGED %04d%s" % [kills, fps_suffix]

	var integrity := _pick_float(status, ["integrity", "hp"], 100.0)
	var max_integrity := _pick_float(status, ["max_integrity", "max_hp"], 100.0)
	_set_meter(_integrity_bar, _integrity_label, integrity, max_integrity, "INTEGRITY")

	var heat := _pick_float(status, ["heat"], 0.0)
	var max_heat := _pick_float(status, ["max_heat"], 100.0)
	_set_meter(_heat_bar, _heat_label, heat, max_heat, "HEAT")

	var xp := _pick_float(status, ["xp", "experience"], 0.0)
	var xp_next := _pick_float(status, ["xp_next", "next_xp"], 100.0)
	_set_meter(_xp_bar, _xp_label, xp, xp_next, "COMPILE")

	if bool(status.get("vent_ready", false)):
		_vent_label.text = "[VENT:RDY]"
		_vent_label.add_theme_color_override("font_color", GREEN)
	elif status.has("vent_cooldown"):
		_vent_label.text = "[VENT:%0.1fs]" % float(status["vent_cooldown"])
		_vent_label.add_theme_color_override("font_color", AMBER)
	else:
		_vent_label.text = "[VENT:---]"
		_vent_label.add_theme_color_override("font_color", CYAN_DIM)

	if status.has("message"):
		flash_log(str(status["message"]), CYAN)


## Opens a modal, paused upgrade picker. Choices can be strings or dictionaries.
## Dictionary keys understood by the formatter: title/name/label, description/
## effect, and tags. Number keys 1-9 and normal UI focus actions are supported.
func show_upgrade_choices(choices: Array) -> void:
	_clear_upgrade_buttons()
	_end_overlay.visible = false
	_upgrade_overlay.visible = true
	_begin_modal()

	for index in choices.size():
		var button := Button.new()
		button.name = "UpgradeChoice%d" % index
		button.text = _format_choice(choices[index], index)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0.0, 82.0)
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.tooltip_text = "Select upgrade %d" % (index + 1)
		button.pressed.connect(_on_upgrade_pressed.bind(index))
		_upgrade_list.add_child(button)
		_upgrade_buttons.append(button)

	if choices.is_empty():
		var empty := Label.new()
		empty.text = "NO VALID PATCHES // SIGNAL LOST"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_color_override("font_color", RED)
		_upgrade_list.add_child(empty)
	else:
		call_deferred("_focus_first_upgrade")


func hide_upgrade_choices() -> void:
	if not _upgrade_overlay.visible:
		return
	_upgrade_overlay.visible = false
	_clear_upgrade_buttons()
	if not _end_overlay.visible:
		_end_modal()


## Displays a paused run summary. Pressing/tapping the button or R emits
## restart_requested after restoring the SceneTree's previous pause state.
func show_end_screen(victory: bool, stats: Dictionary) -> void:
	_upgrade_overlay.visible = false
	_clear_upgrade_buttons()
	_end_overlay.visible = true
	_begin_modal()

	if victory:
		_end_title.text = "TRANSMISSION COMPLETE"
		_end_title.add_theme_color_override("font_color", GREEN)
	else:
		_end_title.text = "PROCESS TERMINATED"
		_end_title.add_theme_color_override("font_color", RED)
	_end_stats.text = _format_stats(stats)
	_layout_end_screen()
	call_deferred("_reset_end_scroll")
	call_deferred("_focus_restart")


## Shows a short, non-blocking message above the lower edge of the screen.
func flash_log(message: String, color: Color = CYAN) -> void:
	_log_label.text = "> %s" % message.to_upper()
	_log_label.add_theme_color_override("font_color", color)
	_log_label.modulate.a = 1.0
	if is_instance_valid(_log_tween):
		_log_tween.kill()
	_log_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_log_tween.tween_interval(1.8)
	_log_tween.tween_property(_log_label, "modulate:a", 0.0, 0.45)


## Enables the lower-left virtual movement stick, the VENT button, and the
## right-side drag target bias surface. Modal overlays temporarily hide them.
func set_touch_controls_visible(visible: bool) -> void:
	_touch_requested_visible = visible
	_apply_touch_visibility()


func _unhandled_input(event: InputEvent) -> void:
	if _upgrade_overlay.visible:
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.pressed and not key_event.echo:
				var choice_index := _choice_index_for_key(key_event)
				if choice_index >= 0 and choice_index < _upgrade_buttons.size():
					get_viewport().set_input_as_handled()
					_on_upgrade_pressed(choice_index)
		return

	if _end_overlay.visible:
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.pressed and not key_event.echo and key_event.keycode == KEY_R:
				get_viewport().set_input_as_handled()
				_on_restart_pressed()
		return


func _build_theme_and_root() -> void:
	_root = Control.new()
	_root.name = "TerminalHUDRoot"
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var terminal_theme := Theme.new()
	var terminal_font := SystemFont.new()
	terminal_font.font_names = PackedStringArray(["Cascadia Mono", "Consolas", "Menlo", "DejaVu Sans Mono", "monospace"])
	terminal_theme.default_font = terminal_font
	terminal_theme.default_font_size = 16
	terminal_theme.set_color("font_color", "Label", CYAN)
	terminal_theme.set_color("font_shadow_color", "Label", Color(0.0, 0.6, 0.68, 0.35))
	terminal_theme.set_constant("shadow_offset_x", "Label", 1)
	terminal_theme.set_constant("shadow_offset_y", "Label", 1)
	terminal_theme.set_color("font_color", "Button", CYAN)
	terminal_theme.set_color("font_hover_color", "Button", Color.WHITE)
	terminal_theme.set_color("font_pressed_color", "Button", INK)
	terminal_theme.set_color("font_focus_color", "Button", Color.WHITE)
	terminal_theme.set_stylebox("normal", "Button", _make_box(INK_LIGHT, CYAN_DIM, 1, 12.0))
	terminal_theme.set_stylebox("hover", "Button", _make_box(Color(0.04, 0.20, 0.23, 0.98), CYAN, 2, 12.0))
	terminal_theme.set_stylebox("pressed", "Button", _make_box(CYAN, CYAN, 2, 12.0))
	terminal_theme.set_stylebox("focus", "Button", _make_box(TRANSPARENT, AMBER, 3, 9.0))
	terminal_theme.set_stylebox("disabled", "Button", _make_box(INK, CYAN_DIM, 1, 12.0))
	terminal_theme.set_stylebox("panel", "PanelContainer", _make_box(INK, CYAN_DIM, 1, 14.0))
	terminal_theme.set_stylebox("panel", "Panel", _make_box(INK_LIGHT, CYAN_DIM, 1, 8.0))
	terminal_theme.set_stylebox("background", "ProgressBar", _make_box(Color(0.01, 0.035, 0.045, 0.96), CYAN_DIM, 1, 0.0))
	terminal_theme.set_stylebox("fill", "ProgressBar", _make_box(CYAN, CYAN, 0, 0.0))
	terminal_theme.set_color("font_color", "ProgressBar", TRANSPARENT)
	_root.theme = terminal_theme


func _build_status() -> void:
	var margin := MarginContainer.new()
	margin.name = "StatusMargin"
	margin.set_anchors_preset(Control.PRESET_TOP_WIDE)
	margin.offset_left = 18.0
	margin.offset_top = 14.0
	margin.offset_right = -18.0
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_root.add_child(margin)

	_status_panel = PanelContainer.new()
	_status_panel.custom_minimum_size.y = 122.0
	_status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(_status_panel)

	var status_rows := VBoxContainer.new()
	status_rows.add_theme_constant_override("separation", 6)
	_status_panel.add_child(status_rows)

	var heading := HBoxContainer.new()
	status_rows.add_child(heading)
	_runtime_label = _new_label("VOID//DAEMON  ::  NO_PROCESS.R01", 20, CYAN)
	_runtime_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(_runtime_label)
	_clock_label = _new_label("T+00:00.0", 20, AMBER)
	heading.add_child(_clock_label)

	var context := HBoxContainer.new()
	status_rows.add_child(context)
	_location_label = _new_label("SECTOR UNMAPPED  //  THREAT NOMINAL  //  SEED --------", 13, CYAN_DIM)
	_location_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	context.add_child(_location_label)
	_combat_label = _new_label("PURGED 0000", 13, CYAN_DIM)
	context.add_child(_combat_label)

	var meters := HBoxContainer.new()
	meters.add_theme_constant_override("separation", 14)
	status_rows.add_child(meters)
	var integrity := _make_meter("INTEGRITY", CYAN)
	meters.add_child(integrity["container"])
	_integrity_bar = integrity["bar"]
	_integrity_label = integrity["label"]
	var heat := _make_meter("HEAT", RED)
	meters.add_child(heat["container"])
	_heat_bar = heat["bar"]
	_heat_label = heat["label"]
	var xp := _make_meter("COMPILE", MAGENTA)
	meters.add_child(xp["container"])
	_xp_bar = xp["bar"]
	_xp_label = xp["label"]
	_vent_label = _new_label("[VENT:---]", 15, CYAN_DIM)
	_vent_label.custom_minimum_size.x = 116.0
	_vent_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_vent_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meters.add_child(_vent_label)

	var log_margin := MarginContainer.new()
	log_margin.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	log_margin.offset_left = 26.0
	log_margin.offset_right = -26.0
	log_margin.offset_top = -186.0
	log_margin.offset_bottom = -150.0
	log_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(log_margin)
	_log_label = _new_label("", 17, CYAN)
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_log_label.modulate.a = 0.0
	log_margin.add_child(_log_label)


func _build_touch_controls() -> void:
	_touch_root = Control.new()
	_touch_root.name = "TouchControls"
	_touch_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_touch_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_touch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_touch_root)

	_stick_zone = Panel.new()
	_stick_zone.name = "MovementStick"
	_stick_zone.custom_minimum_size = Vector2.ONE * TOUCH_STICK_SIZE
	_stick_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	_stick_zone.gui_input.connect(_on_stick_gui_input)
	_stick_zone.add_theme_stylebox_override("panel", _make_circle_box(Color(0.02, 0.12, 0.14, 0.76), CYAN_DIM, 2, 72))
	_touch_root.add_child(_stick_zone)

	var move_label := _new_label("MOVE", 13, CYAN_DIM)
	move_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	move_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	move_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	move_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_zone.add_child(move_label)

	_stick_knob = Panel.new()
	_stick_knob.custom_minimum_size = Vector2.ONE * TOUCH_STICK_KNOB_SIZE
	_stick_knob.size = Vector2.ONE * TOUCH_STICK_KNOB_SIZE
	_stick_knob.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stick_knob.add_theme_stylebox_override("panel", _make_circle_box(Color(0.18, 0.70, 0.74, 0.82), CYAN, 2, 29))
	_stick_zone.add_child(_stick_knob)

	_vent_button = Button.new()
	_vent_button.name = "TouchVentButton"
	_vent_button.text = "VENT\n[ TAP ]"
	_vent_button.custom_minimum_size = Vector2(128.0, 96.0)
	_vent_button.focus_mode = Control.FOCUS_NONE
	_vent_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_vent_button.add_theme_color_override("font_color", AMBER)
	_vent_button.add_theme_color_override("font_pressed_color", INK)
	_vent_button.add_theme_stylebox_override("normal", _make_box(Color(0.12, 0.075, 0.015, 0.88), AMBER, 2, 16.0))
	_vent_button.add_theme_stylebox_override("pressed", _make_box(AMBER, AMBER, 3, 16.0))
	_vent_button.pressed.connect(_on_touch_vent_pressed)
	_touch_root.add_child(_vent_button)

	_target_zone = Control.new()
	_target_zone.name = "TargetBiasSurface"
	_target_zone.mouse_filter = Control.MOUSE_FILTER_PASS
	_target_zone.gui_input.connect(_on_target_gui_input)
	_touch_root.add_child(_target_zone)
	var target_hint := _new_label("[ DRAG TO BIAS FIRE ]", 12, CYAN_DIM)
	target_hint.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	target_hint.offset_top = -28.0
	target_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	target_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_zone.add_child(target_hint)


func _build_upgrade_overlay() -> void:
	_upgrade_overlay = ColorRect.new()
	_upgrade_overlay.name = "UpgradeOverlay"
	_upgrade_overlay.color = Color(0.005, 0.012, 0.018, 0.91)
	_upgrade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_upgrade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_upgrade_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_upgrade_overlay.visible = false
	_root.add_child(_upgrade_overlay)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.offset_left = 24.0
	center.offset_top = 20.0
	center.offset_right = -24.0
	center.offset_bottom = -20.0
	_upgrade_overlay.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620.0, 0.0)
	panel.add_theme_stylebox_override("panel", _make_box(Color(0.01, 0.045, 0.055, 0.99), CYAN, 2, 22.0))
	center.add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	panel.add_child(rows)
	var title := _new_label("COMPILE INTERRUPT", 26, AMBER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)
	var prompt := _new_label("SELECT PATCH // TAP, ENTER, OR PRESS [1-9]", 13, CYAN_DIM)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(prompt)
	_add_rule(rows)
	_upgrade_list = VBoxContainer.new()
	_upgrade_list.add_theme_constant_override("separation", 9)
	rows.add_child(_upgrade_list)


func _build_end_overlay() -> void:
	_end_overlay = ColorRect.new()
	_end_overlay.name = "EndOverlay"
	_end_overlay.color = Color(0.005, 0.01, 0.016, 0.94)
	_end_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_end_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_end_overlay.visible = false
	_root.add_child(_end_overlay)
	_end_center = CenterContainer.new()
	_end_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_overlay.add_child(_end_center)
	_end_panel = PanelContainer.new()
	_end_panel.clip_contents = true
	_end_panel.add_theme_stylebox_override("panel", _make_box(Color(0.01, 0.035, 0.045, 0.99), CYAN_DIM, 2, 24.0))
	_end_center.add_child(_end_panel)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 16)
	_end_panel.add_child(rows)
	_end_title = _new_label("PROCESS TERMINATED", 28, RED)
	_end_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_end_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_child(_end_title)
	_add_rule(rows)
	_end_stats_scroll = ScrollContainer.new()
	_end_stats_scroll.name = "StatsScroll"
	_end_stats_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_end_stats_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_end_stats_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_end_stats_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_end_stats_scroll.custom_minimum_size.y = 72.0
	rows.add_child(_end_stats_scroll)
	_end_stats = _new_label("", 17, CYAN)
	_end_stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_end_stats.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	_end_stats.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_end_stats.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_end_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_stats_scroll.add_child(_end_stats)
	_restart_button = Button.new()
	_restart_button.text = "RESTART PROCESS  [R]"
	_restart_button.custom_minimum_size.y = 66.0
	_restart_button.focus_mode = Control.FOCUS_ALL
	_restart_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_restart_button.pressed.connect(_on_restart_pressed)
	rows.add_child(_restart_button)


func _make_meter(caption: String, fill_color: Color) -> Dictionary:
	var container := VBoxContainer.new()
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	container.add_theme_constant_override("separation", 2)
	var label := _new_label("%s 000/000" % caption, 12, CYAN)
	container.add_child(label)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(140.0, 11.0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_stylebox_override("fill", _make_box(fill_color, fill_color, 0, 0.0))
	bar.tooltip_text = caption
	container.add_child(bar)
	return {"container": container, "bar": bar, "label": label}


func _new_label(text_value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _add_rule(parent: Control) -> void:
	var rule := HSeparator.new()
	rule.add_theme_constant_override("separation", 1)
	parent.add_child(rule)


func _make_box(background: Color, border: Color, border_width: int, margin: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.border_width_left = border_width
	box.border_width_top = border_width
	box.border_width_right = border_width
	box.border_width_bottom = border_width
	box.content_margin_left = margin
	box.content_margin_top = margin
	box.content_margin_right = margin
	box.content_margin_bottom = margin
	return box


func _make_circle_box(background: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var box := _make_box(background, border, border_width, 0.0)
	box.corner_radius_top_left = radius
	box.corner_radius_top_right = radius
	box.corner_radius_bottom_left = radius
	box.corner_radius_bottom_right = radius
	return box


func _set_meter(bar: ProgressBar, label: Label, current: float, maximum: float, caption: String) -> void:
	maximum = maxf(maximum, 1.0)
	bar.max_value = maximum
	bar.value = clampf(current, 0.0, maximum)
	label.text = "%s %03d/%03d" % [caption, int(round(current)), int(round(maximum))]
	bar.tooltip_text = "%s: %d of %d" % [caption.capitalize(), int(round(current)), int(round(maximum))]


func _begin_modal() -> void:
	if not _modal_active:
		_paused_before_modal = get_tree().paused
		_modal_active = true
	get_tree().paused = true
	_apply_touch_visibility()


func _end_modal() -> void:
	if not _modal_active:
		return
	_modal_active = false
	get_tree().paused = _paused_before_modal
	_apply_touch_visibility()


func _apply_touch_visibility() -> void:
	if not is_instance_valid(_touch_root):
		return
	var should_show := _touch_requested_visible and not _modal_active
	_touch_root.visible = should_show
	if not should_show:
		_reset_stick()
		_reset_target_bias()


func _layout_touch_controls() -> void:
	if not is_instance_valid(_touch_root):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var safe_rect := _get_safe_viewport_rect()
	var safe_left := safe_rect.position.x
	var safe_top := safe_rect.position.y
	var safe_right := viewport_size.x - safe_rect.end.x
	var safe_bottom := viewport_size.y - safe_rect.end.y

	_stick_zone.position = Vector2(safe_left + TOUCH_MARGIN, viewport_size.y - safe_bottom - TOUCH_MARGIN - TOUCH_STICK_SIZE)
	_stick_zone.size = Vector2.ONE * TOUCH_STICK_SIZE
	_center_stick_knob()
	_vent_button.position = Vector2(viewport_size.x - safe_right - TOUCH_MARGIN - 128.0, viewport_size.y - safe_bottom - 28.0 - 96.0)
	_vent_button.size = Vector2(128.0, 96.0)
	_target_zone.position = Vector2(viewport_size.x * 0.5, safe_top + 136.0)
	_target_zone.size = Vector2(maxf(viewport_size.x * 0.5 - safe_right, 0.0), maxf(viewport_size.y - safe_top - safe_bottom - 310.0, 80.0))


func _layout_end_screen() -> void:
	if not is_instance_valid(_end_center) or not is_instance_valid(_end_panel):
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var safe_rect := _get_safe_viewport_rect()
	var padding := minf(MODAL_EDGE_PADDING, minf(safe_rect.size.x, safe_rect.size.y) * 0.04)
	var available_size := Vector2(
		maxf(safe_rect.size.x - padding * 2.0, 1.0),
		maxf(safe_rect.size.y - padding * 2.0, 1.0)
	)

	# CenterContainer offsets are relative to its full-viewport anchors. This
	# keeps the modal inside notches, rounded corners, and phone home indicators.
	_end_center.offset_left = safe_rect.position.x + padding
	_end_center.offset_top = safe_rect.position.y + padding
	_end_center.offset_right = safe_rect.end.x - viewport_size.x - padding
	_end_center.offset_bottom = safe_rect.end.y - viewport_size.y - padding

	# The explicit height turns the stats area into the flexible/scrollable part
	# of the modal. The title and restart button remain outside that scroller.
	_end_panel.custom_minimum_size = Vector2(
		minf(END_PANEL_MAX_WIDTH, available_size.x),
		minf(END_PANEL_MAX_HEIGHT, available_size.y)
	)
	var narrow := available_size.x < 420.0
	var compact := available_size.x < 320.0
	var panel_margin := 12.0 if compact else 24.0
	_end_panel.add_theme_stylebox_override("panel", _make_box(Color(0.01, 0.035, 0.045, 0.99), CYAN_DIM, 2, panel_margin))
	_end_title.add_theme_font_size_override("font_size", 22 if narrow else 28)
	_end_stats.add_theme_font_size_override("font_size", 14 if narrow else 17)
	_restart_button.text = "RESTART  [R]" if compact else "RESTART PROCESS  [R]"
	_restart_button.add_theme_font_size_override("font_size", 14 if compact else 16)
	_end_stats_scroll.custom_minimum_size.y = minf(96.0, maxf(36.0, available_size.y - 220.0))


func _get_safe_viewport_rect() -> Rect2:
	var viewport_size := get_viewport().get_visible_rect().size
	var full_viewport := Rect2(Vector2.ZERO, viewport_size)
	var window_size := Vector2(DisplayServer.window_get_size())
	var display_safe := DisplayServer.get_display_safe_area()
	if window_size.x <= 0.0 or window_size.y <= 0.0 or display_safe.size.x <= 0 or display_safe.size.y <= 0:
		return full_viewport
	# Desktop safe areas may be reported in global monitor coordinates. Ignore
	# those when they clearly do not describe this window; mobile safe areas are
	# window-relative and pass these bounds checks.
	if display_safe.position.x < 0 or display_safe.position.y < 0:
		return full_viewport
	if display_safe.end.x > window_size.x or display_safe.end.y > window_size.y:
		return full_viewport
	var scale := viewport_size / window_size
	var safe_position := Vector2(display_safe.position) * scale
	var safe_size := Vector2(display_safe.size) * scale
	return Rect2(safe_position, safe_size).intersection(full_viewport)


func _on_stick_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _stick_touch_index < 0:
			_stick_touch_index = touch.index
			_set_stick_position(touch.position - _stick_zone.global_position)
			_stick_zone.accept_event()
		elif not touch.pressed and touch.index == _stick_touch_index:
			_stick_touch_index = -1
			_reset_stick()
			_stick_zone.accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_touch_index:
			_set_stick_position(drag.position - _stick_zone.global_position)
			_stick_zone.accept_event()
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_stick_mouse_active = mouse_button.pressed
			if _stick_mouse_active:
				_set_stick_position(mouse_button.position)
			else:
				_reset_stick()
			_stick_zone.accept_event()
	elif event is InputEventMouseMotion and _stick_mouse_active:
		_set_stick_position((event as InputEventMouseMotion).position)
		_stick_zone.accept_event()


func _set_stick_position(local_position: Vector2) -> void:
	var center := _stick_zone.size * 0.5
	var radius := (TOUCH_STICK_SIZE - TOUCH_STICK_KNOB_SIZE) * 0.5
	var delta := local_position - center
	var clamped_delta := delta.limit_length(radius)
	_stick_knob.position = center + clamped_delta - _stick_knob.size * 0.5
	var direction := clamped_delta / radius
	if direction.length() < 0.12:
		direction = Vector2.ZERO
	if not direction.is_equal_approx(_last_move_direction):
		_last_move_direction = direction
		touch_move_changed.emit(direction)


func _reset_stick() -> void:
	_stick_touch_index = -1
	_stick_mouse_active = false
	_center_stick_knob()
	if not _last_move_direction.is_zero_approx():
		_last_move_direction = Vector2.ZERO
		touch_move_changed.emit(Vector2.ZERO)


func _center_stick_knob() -> void:
	if is_instance_valid(_stick_knob):
		_stick_knob.size = Vector2.ONE * TOUCH_STICK_KNOB_SIZE
		_stick_knob.position = (_stick_zone.size - _stick_knob.size) * 0.5


func _on_target_gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and _target_touch_index < 0:
			_target_touch_index = touch.index
			_target_origin = touch.position
			touch_target_bias.emit(Vector2.ZERO, true)
			_target_zone.accept_event()
		elif not touch.pressed and touch.index == _target_touch_index:
			_target_touch_index = -1
			touch_target_bias.emit(Vector2.ZERO, false)
			_target_zone.accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _target_touch_index:
			_emit_target_drag(drag.position)
			_target_zone.accept_event()
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_target_mouse_active = mouse_button.pressed
			if _target_mouse_active:
				_target_origin = mouse_button.global_position
				touch_target_bias.emit(Vector2.ZERO, true)
			else:
				touch_target_bias.emit(Vector2.ZERO, false)
			_target_zone.accept_event()
	elif event is InputEventMouseMotion and _target_mouse_active:
		_emit_target_drag((event as InputEventMouseMotion).global_position)
		_target_zone.accept_event()


func _emit_target_drag(screen_position: Vector2) -> void:
	var bias := (screen_position - _target_origin) / 96.0
	bias = bias.limit_length(1.0)
	if bias.length() < 0.10:
		bias = Vector2.ZERO
	touch_target_bias.emit(bias, true)


func _reset_target_bias() -> void:
	if _target_touch_index >= 0 or _target_mouse_active:
		touch_target_bias.emit(Vector2.ZERO, false)
	_target_touch_index = -1
	_target_mouse_active = false


func _on_touch_vent_pressed() -> void:
	touch_vent_pressed.emit()


func _on_upgrade_pressed(index: int) -> void:
	hide_upgrade_choices()
	upgrade_selected.emit(index)


func _on_restart_pressed() -> void:
	_end_overlay.visible = false
	_end_modal()
	restart_requested.emit()


func _focus_first_upgrade() -> void:
	if _upgrade_overlay.visible and not _upgrade_buttons.is_empty():
		_upgrade_buttons[0].grab_focus()


func _focus_restart() -> void:
	if _end_overlay.visible:
		_restart_button.grab_focus()


func _reset_end_scroll() -> void:
	if is_instance_valid(_end_stats_scroll):
		_end_stats_scroll.scroll_vertical = 0


func _clear_upgrade_buttons() -> void:
	if not is_instance_valid(_upgrade_list):
		return
	for child in _upgrade_list.get_children():
		_upgrade_list.remove_child(child)
		child.queue_free()
	_upgrade_buttons.clear()


func _choice_index_for_key(event: InputEventKey) -> int:
	if event.keycode >= KEY_1 and event.keycode <= KEY_9:
		return int(event.keycode - KEY_1)
	if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9:
		return int(event.physical_keycode - KEY_1)
	if event.keycode >= KEY_KP_1 and event.keycode <= KEY_KP_9:
		return int(event.keycode - KEY_KP_1)
	return -1


func _format_choice(choice: Variant, index: int) -> String:
	var title := "PATCH_%02d" % (index + 1)
	var description := "NO DESCRIPTION"
	var tags := ""
	if choice is Dictionary:
		var data := choice as Dictionary
		title = _pick_text(data, ["title", "name", "label"], title)
		description = _pick_text(data, ["description", "effect", "details"], description)
		if data.has("tags"):
			if data["tags"] is Array:
				var tag_strings := PackedStringArray()
				for tag in data["tags"]:
					tag_strings.append("[%s]" % str(tag).to_upper())
				tags = "  ".join(tag_strings)
			else:
				tags = str(data["tags"])
	else:
		title = str(choice)
		description = "APPLY PATCH TO ACTIVE PROCESS"
	var text := "[%d]  %s\n     %s" % [index + 1, title.to_upper(), description]
	if not tags.is_empty():
		text += "\n     %s" % tags.to_upper()
	return text


func _format_stats(stats: Dictionary) -> String:
	if stats.is_empty():
		return "NO TELEMETRY RECOVERED"
	var preferred_keys := ["time", "kills", "level", "damage", "seed", "sector", "build"]
	var lines := PackedStringArray()
	var used := {}
	for key in preferred_keys:
		if stats.has(key):
			lines.append(_format_stat_line(str(key), stats[key]))
			used[key] = true
	for key in stats:
		if not used.has(key):
			lines.append(_format_stat_line(str(key), stats[key]))
	return "\n".join(lines)


func _format_stat_line(key: String, value: Variant) -> String:
	var display_value := str(value)
	if key == "time" and (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT):
		display_value = _format_time(float(value))
	return "%s  ::  %s" % [key.to_upper().replace("_", " "), display_value]


func _format_time(value: Variant) -> String:
	if not (typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT):
		return str(value)
	var seconds := maxf(float(value), 0.0)
	var minutes := int(seconds) / 60
	var remainder := fmod(seconds, 60.0)
	return "%02d:%04.1f" % [minutes, remainder]


func _pick_text(data: Dictionary, keys: Array, fallback: String) -> String:
	for key in keys:
		if data.has(key):
			return str(data[key])
	return fallback


func _pick_float(data: Dictionary, keys: Array, fallback: float) -> float:
	for key in keys:
		if data.has(key):
			return float(data[key])
	return fallback


func _pick_int(data: Dictionary, keys: Array, fallback: int) -> int:
	for key in keys:
		if data.has(key):
			return int(data[key])
	return fallback
