class_name TerminalHUD
extends CanvasLayer

## Code-only HUD for VOID//DAEMON's terminal presentation.
##
## The HUD deliberately accepts dictionaries instead of gameplay classes.  That
## keeps it useful while the prototype's data model is still changing.

signal upgrade_selected(index: int)
signal restart_requested
signal menu_requested
signal zoom_requested(direction: float)
signal touch_move_changed(direction: Vector2)
signal touch_vent_pressed
signal touch_target_bias(direction: Vector2, active: bool)
signal pause_toggled(is_paused: bool)
signal unleash_started
signal unleash_released
signal combat_cancel_requested
signal lab_fixture_requested(value: String)
signal lab_loadout_requested(value: String)
signal lab_reset_requested
signal lab_report_requested

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
const END_PANEL_MAX_WIDTH := 1800.0
const ScorecardScript = preload("res://src/ui/run_scorecard.gd")
const FlightTelemetryScript = preload("res://src/ui/flight_telemetry.gd")

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
var _end_panel: Control
var _end_card: Control
var _end_tabs: HBoxContainer
var _end_tab_buttons: Array[Button] = []
var _end_footer: Label
var _end_report: Dictionary = {}
var _restart_button: Button
var _menu_button: Button
var _pause_overlay: ColorRect
var _pause_center: CenterContainer
var _pause_panel: PanelContainer
var _resume_button: Button
var _pause_restart_button: Button
var _quit_button: Button
var _is_paused := false

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
var _combo_mode := false
var _lab_mode := false
var _phase_swipe_consumed := false
var _target_hint: Label
var _rack_label: Label
var _rack_meter: ProgressBar
var _rack_panel: PanelContainer
var _lab_bar: HBoxContainer
var _fixture_picker: OptionButton
var _loadout_picker: OptionButton
var _touch_pause: Button
var _flight_panel: Control
var _chassis := "graviton"
var _combat_rail: Control
var _zoom_controls: HBoxContainer
var _zoom_label: Label


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_theme_and_root()
	_build_status()
	_build_touch_controls()
	_build_zoom_controls()
	_build_combo_controls()
	_build_upgrade_overlay()
	_build_end_overlay()
	_build_pause_overlay()
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
	_combat_rail.set_snapshot(status)
	_zoom_label.text = "VIEW %03d%%" % roundi(float(status.get("zoom", 0.82)) * 100)
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
	var flight: Dictionary = status.get("flight", {})
	if status.has("fps"):
		fps_suffix = "  //  %d FPS" % int(status["fps"])
	_combat_label.text = "PURGED %04d%s" % [kills, fps_suffix]
	if not flight.is_empty() and _combo_mode:
		_flight_panel.set_flight(flight)
		var viewport_size := get_viewport().get_visible_rect().size
		_flight_panel.visible = not _modal_active
		_flight_panel.position = Vector2(12, viewport_size.y - 92)
		_flight_panel.size = Vector2(minf(360, viewport_size.x * 0.4), 72)
		if viewport_size.x < 700:
			_combat_label.text = "SPD %03.0f  SLIP %02.0f  G %.0f" % [flight.get("speed", 0), flight.get("drift", 0), Vector2(flight.get("gravity", Vector2.ZERO)).length()]

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
	if _combo_mode:
		var cooldown := float(status.get("phase_cooldown", 0))
		var maneuver := String(status.get("maneuver_name", "PHASE SKIP"))
		var short_name: String = {"PHASE SKIP": "PHASE", "BREACH STEP": "BREACH", "TOW STEP": "TOW", "BACKTRACE": "TRACE"}.get(maneuver, maneuver)
		_vent_label.text = "[%s: READY]" % short_name if cooldown <= 0 else "[%s: %.1fs]" % [short_name, cooldown]
		_vent_label.add_theme_color_override("font_color", GREEN if cooldown <= 0 else AMBER)
		_vent_button.text = maneuver + ("\nTAP / SLIDE" if cooldown <= 0 else "\n%.1fs" % cooldown)
		var charging := bool(status.get("rack_charging", false))
		var reload := float(status.get("rack_reload", 0))
		if charging:
			var phase := "GRAVITON ACTIVE" if status.get("field_active", false) else ("FIELD EXPIRED / RACK ARMED" if status.get("gravity_enabled", true) else "SALVO ARMING")
			_rack_label.text = "%s  /  SALVO %d/6  /  AFFORDABLE %d  /  RELEASE TO FIRE" % [phase, status.get("rack_loaded", 0), status.get("rack_affordable", 0)]
		elif reload > 0:
			_rack_label.text = "RACK RELOADING %.1fs  /  ARC + DRIVER FOLLOW-THROUGH" % reload
		else:
			_rack_label.text = "HOLD M1: GRAVITON + LOAD  /  RELEASE: SALVO  /  SHIFT OR SPACE: PHASE"
		_rack_meter.value = float(status.get("rack_ratio", 0)) * 100 if charging else (0 if reload > 0 else 100)
		if _chassis != "graviton":
			var attack := String(status.get("attack_name", "UNLEASH"))
			var action := "HOLD: GATHER / RELEASE: COLLAPSE" if _chassis == "scrapper" else "HOLD: SUSTAIN FIRE / RELEASE: STOP"
			_rack_label.text = "%s // %s // SHIFT/SPACE: %s" % [attack, action, maneuver]
			if reload > 0:
				_rack_label.text = "%s // RECOVERING %.1fs" % [attack, reload]


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

	_end_report = stats.duplicate(true)
	_end_card.set_report(victory, _end_report)
	_set_end_page(0)
	_layout_end_screen()
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


func set_combo_mode(enabled: bool, lab: bool = false) -> void:
	_combo_mode = enabled
	_lab_mode = lab
	_rack_panel.visible = enabled
	_lab_bar.visible = lab
	_vent_button.text = "PHASE SKIP\nTAP / SLIDE" if enabled else "VENT\n[ TAP ]"
	_vent_button.add_theme_font_size_override("font_size", 13 if enabled else 16)
	_vent_button.add_theme_stylebox_override("normal", _make_box(Color(0.12, 0.075, 0.015, 0.88), AMBER, 2, 8 if enabled else 16))
	_vent_button.add_theme_stylebox_override("pressed", _make_box(AMBER, AMBER, 3, 8 if enabled else 16))
	_target_hint.text = "HOLD + DRAG\nGRAVITON / SALVO\nRELEASE TO FIRE" if enabled else "[ DRAG TO BIAS FIRE ]"
	_target_zone.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_PASS
	_layout_touch_controls()


func set_lab_selection(fixture: String, loadout: String) -> void:
	_fixture_picker.select(maxi(0, ["cluster", "dispersed", "boss", "orbit"].find(fixture)))
	_loadout_picker.select(maxi(0, ["salvo", "gravity", "chain"].find(loadout)))


func set_chassis(id: String) -> void:
	_chassis = id
	if id == "graviton":
		return
	_target_hint.text = "HOLD + DRAG\n%s\nRELEASE: %s" % [id.to_upper(), "COLLAPSE" if id == "scrapper" else "STOP FIRE"]
	_loadout_picker.set_item_text(0, "MANUAL ONLY [F4]")
	_loadout_picker.set_item_text(1, "BASE KIT [F5]")
	_loadout_picker.set_item_text(2, "PATCHED CHAIN [F6]")


func clear_combat_gesture() -> void:
	_phase_swipe_consumed = true
	_reset_target_bias()
	_reset_stick()
	combat_cancel_requested.emit()


func _input(event: InputEvent) -> void:
	if not _combo_mode or _modal_active:
		return
	if event is InputEventScreenDrag and event.index == _target_touch_index:
		if _vent_button.get_global_rect().has_point(event.position):
			_consume_phase_swipe()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and not event.pressed and event.index == _target_touch_index and _phase_swipe_consumed:
		_target_touch_index = -1
		touch_target_bias.emit(Vector2.ZERO, false)
		get_viewport().set_input_as_handled()


func _consume_phase_swipe() -> void:
	if _phase_swipe_consumed:
		return
	_phase_swipe_consumed = true
	combat_cancel_requested.emit()
	touch_vent_pressed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if _pause_overlay.visible:
		if event is InputEventKey:
			var key_event := event as InputEventKey
			if key_event.pressed and not key_event.echo:
				if key_event.keycode == KEY_ESCAPE or key_event.keycode == KEY_P:
					get_viewport().set_input_as_handled()
					toggle_pause(false)
					return
				elif key_event.keycode == KEY_R:
					get_viewport().set_input_as_handled()
					toggle_pause(false)
					_on_restart_pressed()
					return
				elif key_event.keycode == KEY_Q:
					get_viewport().set_input_as_handled()
					get_tree().quit()
					return
		if event is InputEventJoypadButton and event.pressed:
			if event.button_index == JOY_BUTTON_START or event.button_index == JOY_BUTTON_B:
				get_viewport().set_input_as_handled()
				toggle_pause(false)
				return
		return

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
			elif key_event.pressed and not key_event.echo and _end_tabs.visible:
				var page_index := _choice_index_for_key(key_event)
				if page_index >= 0 and page_index < _end_tab_buttons.size() and _end_tab_buttons[page_index].visible:
					_set_end_page(page_index)
					get_viewport().set_input_as_handled()
		return

	if event is InputEventKey:
		var key_event := event as InputEventKey
		if key_event.pressed and not key_event.echo:
			if key_event.keycode == KEY_ESCAPE or key_event.keycode == KEY_P:
				get_viewport().set_input_as_handled()
				toggle_pause(true)
				return
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_START:
			get_viewport().set_input_as_handled()
			toggle_pause(true)
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
	log_margin.offset_top = -21.0
	log_margin.offset_bottom = -1.0
	log_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(log_margin)
	_log_label = _new_label("", 10, CYAN)
	_log_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_log_label.modulate.a = 0.0
	log_margin.add_child(_log_label)
	margin.hide()
	_combat_rail = preload("res://src/ui/combat_rail.gd").new()
	_root.add_child(_combat_rail)


func _build_zoom_controls() -> void:
	_zoom_controls = HBoxContainer.new()
	_zoom_controls.add_theme_constant_override("separation", 4)
	_root.add_child(_zoom_controls)
	for direction in [-1.0, 1.0]:
		var button := Button.new()
		button.text = "−" if direction < 0 else "+"
		button.custom_minimum_size = Vector2(44, 44)
		button.pressed.connect(func(): zoom_requested.emit(direction))
		_zoom_controls.add_child(button)
	_zoom_label = _new_label("VIEW 082%", 10, CYAN_DIM)
	_root.add_child(_zoom_label)


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

	_target_zone = Panel.new()
	_target_zone.add_theme_stylebox_override("panel", _make_box(Color(0.08, 0.06, 0.15, 0.48), Color("8272ad"), 1, 8))
	_target_zone.name = "TargetBiasSurface"
	_target_zone.mouse_filter = Control.MOUSE_FILTER_PASS
	_target_zone.gui_input.connect(_on_target_gui_input)
	_touch_root.add_child(_target_zone)
	_target_hint = _new_label("[ DRAG TO BIAS FIRE ]", 13, CYAN)
	_target_hint.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_target_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_target_hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_target_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_target_zone.add_child(_target_hint)
	_touch_pause = Button.new()
	_touch_pause.text = "II"
	_touch_pause.pressed.connect(func(): toggle_pause())
	_touch_root.add_child(_touch_pause)


func _build_combo_controls() -> void:
	_flight_panel = FlightTelemetryScript.new()
	_flight_panel.dock_mode = true
	_flight_panel.visible = false
	_root.add_child(_flight_panel)
	_rack_panel = PanelContainer.new()
	_rack_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rack_panel.add_theme_stylebox_override("panel", _make_box(Color("111e30"), Color("7d70a8"), 1, 2))
	_root.add_child(_rack_panel)
	var stack := VBoxContainer.new()
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rack_panel.add_child(stack)
	_rack_label = _new_label("", 11, Color("d4c7ff"))
	_rack_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_rack_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(_rack_label)
	_rack_meter = ProgressBar.new()
	_rack_meter.show_percentage = false
	_rack_meter.custom_minimum_size.y = 2
	_rack_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rack_meter.add_theme_stylebox_override("fill", _make_box(Color("b4a0ff"), TRANSPARENT, 0, 0))
	stack.add_child(_rack_meter)
	_lab_bar = HBoxContainer.new()
	_lab_bar.add_theme_constant_override("separation", 8)
	_root.add_child(_lab_bar)
	_fixture_picker = OptionButton.new()
	for caption in ["CLUSTER [F1]", "DISPERSED [F2]", "BOSS LANE [F3]", "ORBIT FIELD [F8]"]:
		_fixture_picker.add_item(caption)
	_fixture_picker.item_selected.connect(func(index: int): lab_fixture_requested.emit(["cluster", "dispersed", "boss", "orbit"][index]))
	_lab_bar.add_child(_fixture_picker)
	_loadout_picker = OptionButton.new()
	for caption in ["SALVO ONLY [F4]", "GRAVITON + SALVO [F5]", "FULL CHAIN [F6]"]:
		_loadout_picker.add_item(caption)
	_loadout_picker.item_selected.connect(func(index: int): lab_loadout_requested.emit(["salvo", "gravity", "chain"][index]))
	_lab_bar.add_child(_loadout_picker)
	var reset := Button.new()
	reset.text = "RESET [R]"
	reset.pressed.connect(func(): lab_reset_requested.emit())
	_lab_bar.add_child(reset)
	var report := Button.new()
	report.text = "REPORT [F7]"
	report.pressed.connect(func(): lab_report_requested.emit())
	_lab_bar.add_child(report)
	for control in _lab_bar.get_children():
		control.custom_minimum_size.y = 44
		control.add_theme_font_size_override("font_size", 13)
	_rack_panel.visible = false
	_lab_bar.visible = false


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
	_end_overlay.color = Color("09131d")
	_end_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_end_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_end_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_end_overlay.visible = false
	_root.add_child(_end_overlay)
	_end_panel = Control.new()
	_end_panel.name = "RunScorecardPanel"
	_end_overlay.add_child(_end_panel)
	_end_card = ScorecardScript.new()
	_end_card.name = "RunScorecard"
	_end_panel.add_child(_end_card)
	_end_tabs = HBoxContainer.new()
	_end_tabs.add_theme_constant_override("separation", 6)
	_end_panel.add_child(_end_tabs)
	for index in range(5):
		var tab := Button.new()
		tab.text = ["RUN", "ARSENAL", "SYSTEMS", "BUILD", "KIT"][index]
		tab.toggle_mode = true
		tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab.add_theme_font_size_override("font_size", 11)
		tab.add_theme_stylebox_override("normal", _make_box(INK_LIGHT, CYAN_DIM, 1, 4))
		tab.add_theme_stylebox_override("pressed", _make_box(Color("23544f"), CYAN, 1, 4))
		tab.add_theme_color_override("font_pressed_color", Color.WHITE)
		tab.pressed.connect(_set_end_page.bind(index))
		_end_tabs.add_child(tab)
		_end_tab_buttons.append(tab)
	_end_footer = _new_label("FLIGHT RECORDER  /  RETRY THE SAME SEED", 11, Color("8ba5ad"))
	_end_footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_panel.add_child(_end_footer)
	_restart_button = Button.new()
	_restart_button.text = "RESTART PROCESS  [R]"
	_restart_button.add_theme_stylebox_override("normal", _make_box(Color("153c3e"), CYAN_DIM, 1, 8))
	_restart_button.add_theme_stylebox_override("focus", _make_box(TRANSPARENT, CYAN, 1, 8))
	_restart_button.focus_mode = Control.FOCUS_ALL
	_restart_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_restart_button.pressed.connect(_on_restart_pressed)
	_end_panel.add_child(_restart_button)
	_menu_button = Button.new()
	_menu_button.text = "HANGAR / CHANGE SHIP"
	_menu_button.pressed.connect(func(): _end_modal(); menu_requested.emit())
	_end_panel.add_child(_menu_button)


func _set_end_page(index: int) -> void:
	_end_card.page = clampi(index, 0, 4)
	_end_card.queue_redraw()
	for i in _end_tab_buttons.size():
		_end_tab_buttons[i].set_pressed_no_signal(i == _end_card.page)


func _build_pause_overlay() -> void:
	_pause_overlay = ColorRect.new()
	_pause_overlay.name = "PauseOverlay"
	_pause_overlay.color = Color(0.005, 0.01, 0.016, 0.88)
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	_pause_overlay.visible = false
	_root.add_child(_pause_overlay)

	_pause_center = CenterContainer.new()
	_pause_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(_pause_center)

	_pause_panel = PanelContainer.new()
	_pause_panel.custom_minimum_size = Vector2(460.0, 280.0)
	_pause_panel.add_theme_stylebox_override("panel", _make_box(Color(0.01, 0.035, 0.045, 0.99), CYAN, 2, 24.0))
	_pause_center.add_child(_pause_panel)

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 14)
	_pause_panel.add_child(rows)

	var title := _new_label("PROCESS SUSPENDED", 26, AMBER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(title)

	var prompt := _new_label("// SYSTEM STANDBY // SELECT OPERATION", 13, CYAN_DIM)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(prompt)

	_add_rule(rows)

	_resume_button = Button.new()
	_resume_button.name = "ResumeButton"
	_resume_button.text = "RESUME PROCESS  [ESC / P]"
	_resume_button.custom_minimum_size = Vector2(0.0, 48.0)
	_resume_button.focus_mode = Control.FOCUS_ALL
	_resume_button.add_theme_font_size_override("font_size", 16)
	_resume_button.add_theme_color_override("font_color", CYAN)
	_resume_button.add_theme_stylebox_override("normal", _make_box(Color(0.015, 0.04, 0.05, 0.95), CYAN_DIM, 2, 8.0))
	_resume_button.add_theme_stylebox_override("hover", _make_box(Color(0.05, 0.12, 0.15, 0.98), CYAN, 2, 8.0))
	_resume_button.add_theme_stylebox_override("focus", _make_box(Color(0.05, 0.12, 0.15, 0.98), CYAN, 2, 8.0))
	_resume_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_resume_button.pressed.connect(func(): toggle_pause(false))
	rows.add_child(_resume_button)

	_pause_restart_button = Button.new()
	_pause_restart_button.name = "PauseRestartButton"
	_pause_restart_button.text = "RESTART RUN  [R]"
	_pause_restart_button.custom_minimum_size = Vector2(0.0, 44.0)
	_pause_restart_button.focus_mode = Control.FOCUS_ALL
	_pause_restart_button.add_theme_font_size_override("font_size", 15)
	_pause_restart_button.add_theme_color_override("font_color", AMBER)
	_pause_restart_button.add_theme_stylebox_override("normal", _make_box(Color(0.015, 0.04, 0.05, 0.95), AMBER * 0.7, 1, 8.0))
	_pause_restart_button.add_theme_stylebox_override("hover", _make_box(Color(0.05, 0.12, 0.15, 0.98), AMBER, 2, 8.0))
	_pause_restart_button.add_theme_stylebox_override("focus", _make_box(Color(0.05, 0.12, 0.15, 0.98), AMBER, 2, 8.0))
	_pause_restart_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_pause_restart_button.pressed.connect(func():
		toggle_pause(false)
		_on_restart_pressed()
	)
	rows.add_child(_pause_restart_button)
	var hangar := Button.new()
	hangar.text = "HANGAR / CHANGE SHIP / SETTINGS"
	hangar.custom_minimum_size.y = 44
	hangar.pressed.connect(func(): toggle_pause(false); menu_requested.emit())
	rows.add_child(hangar)

	_quit_button = Button.new()
	_quit_button.name = "QuitButton"
	_quit_button.text = "QUIT TO DESKTOP  [Q]"
	_quit_button.custom_minimum_size = Vector2(0.0, 40.0)
	_quit_button.focus_mode = Control.FOCUS_ALL
	_quit_button.add_theme_font_size_override("font_size", 14)
	_quit_button.add_theme_color_override("font_color", RED)
	_quit_button.add_theme_stylebox_override("normal", _make_box(Color(0.015, 0.04, 0.05, 0.95), RED * 0.7, 1, 8.0))
	_quit_button.add_theme_stylebox_override("hover", _make_box(Color(0.05, 0.12, 0.15, 0.98), RED, 2, 8.0))
	_quit_button.add_theme_stylebox_override("focus", _make_box(Color(0.05, 0.12, 0.15, 0.98), RED, 2, 8.0))
	_quit_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_quit_button.pressed.connect(func(): get_tree().quit())
	rows.add_child(_quit_button)


## Opens or closes the pause overlay and toggles scene tree pause.
func toggle_pause(force_state = null) -> void:
	if _upgrade_overlay.visible or _end_overlay.visible:
		return
	if force_state != null:
		_is_paused = bool(force_state)
	else:
		_is_paused = not _is_paused

	_pause_overlay.visible = _is_paused
	if _is_paused:
		_begin_modal()
		_resume_button.grab_focus()
	else:
		_end_modal()
	pause_toggled.emit(_is_paused)


func is_paused() -> bool:
	return _is_paused


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
	if _combo_mode:
		clear_combat_gesture()
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
	_zoom_controls.visible = not _modal_active
	_zoom_label.visible = not _modal_active
	if is_instance_valid(_flight_panel):
		_flight_panel.visible = _combo_mode and not _modal_active
	_touch_root.visible = should_show
	if is_instance_valid(_rack_panel):
		_rack_panel.visible = _combo_mode and not _modal_active
		_lab_bar.visible = _lab_mode and not _modal_active
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
	if _combo_mode:
		_target_zone.position = Vector2(viewport_size.x - safe_right - 256, viewport_size.y - safe_bottom - 330)
		_target_zone.size = Vector2(220, 178)
	_touch_pause.position = Vector2(viewport_size.x - safe_right - 56, safe_top + 82)
	_touch_pause.size = Vector2(44, 44)
	if is_instance_valid(_rack_panel):
		_rack_panel.position = Vector2(0, viewport_size.y - 120)
		_rack_panel.size = Vector2(viewport_size.x, 24)
		_lab_bar.position = Vector2(safe_left + 12, safe_top + 84)
	_zoom_controls.position = Vector2(viewport_size.x - 112, viewport_size.y - 78)
	_zoom_label.position = Vector2(viewport_size.x - 112, viewport_size.y - 24)


func _layout_end_screen() -> void:
	if not is_instance_valid(_end_panel):
		return
	var safe_rect := _get_safe_viewport_rect()
	var padding := minf(MODAL_EDGE_PADDING, minf(safe_rect.size.x, safe_rect.size.y) * 0.04)
	var available_size := Vector2(
		maxf(safe_rect.size.x - padding * 2.0, 1.0),
		maxf(safe_rect.size.y - padding * 2.0, 1.0)
	)

	# canvas_items retains a large logical viewport in small windows. Counter
	# its downscale so page selection and 44px targets use the displayed size.
	var ui_scale := 1.0
	var window_size := Vector2(DisplayServer.window_get_size())
	if DisplayServer.get_name() != "headless" and window_size.x > 0 and window_size.y > 0:
		var viewport_size := get_viewport().get_visible_rect().size
		ui_scale = maxf(1.0, minf(viewport_size.x / window_size.x, viewport_size.y / window_size.y))
	_end_panel.scale = Vector2.ONE * ui_scale
	_end_panel.size = Vector2(minf(END_PANEL_MAX_WIDTH, available_size.x / ui_scale), available_size.y / ui_scale)
	_end_panel.position = safe_rect.position + (safe_rect.size - _end_panel.size * ui_scale) * 0.5
	var panel_size := _end_panel.size
	var compact := panel_size.x < 940 or panel_size.y - 58 < 530
	_end_tabs.visible = compact
	_end_tab_buttons[4].visible = not _end_card.data.get("combo", {}).is_empty()
	for index in _end_tab_buttons.size():
		_end_tab_buttons[index].text = (["RUN", "GUNS", "SHIP", "BUILD", "KIT"] if panel_size.x < 420 else ["RUN", "ARSENAL", "SYSTEMS", "BUILD", "KIT"])[index]
	_end_card.position = Vector2.ZERO
	_end_card.size = Vector2(panel_size.x, panel_size.y - (106 if compact else 58))
	_end_tabs.position = Vector2(0, panel_size.y - 98)
	_end_tabs.size = Vector2(panel_size.x, 44)
	_restart_button.position = Vector2(maxf(0, panel_size.x - 300), panel_size.y - 44)
	_restart_button.size = Vector2(minf(panel_size.x, 300), 44)
	_restart_button.add_theme_font_size_override("font_size", 14)
	_menu_button.position = Vector2(0, panel_size.y - 44)
	_menu_button.size = Vector2(minf(260, panel_size.x * 0.42), 44)
	_menu_button.add_theme_font_size_override("font_size", 11)
	_restart_button.size.x = minf(300, panel_size.x * 0.55)
	_restart_button.position.x = panel_size.x - _restart_button.size.x
	_end_footer.visible = panel_size.x > 1000
	_end_footer.position = Vector2(278, panel_size.y - 30)
	_end_footer.size = Vector2(maxf(panel_size.x - 600, 1), 24)


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
			# gui_input positions are already local to the receiving Control.
			_set_stick_position(touch.position)
			_stick_zone.accept_event()
		elif not touch.pressed and touch.index == _stick_touch_index:
			_stick_touch_index = -1
			_reset_stick()
			_stick_zone.accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _stick_touch_index:
			_set_stick_position(drag.position)
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
			_phase_swipe_consumed = false
			touch_target_bias.emit(Vector2.ZERO, true)
			if _combo_mode:
				unleash_started.emit()
			_target_zone.accept_event()
		elif not touch.pressed and touch.index == _target_touch_index:
			if _combo_mode and not _phase_swipe_consumed:
				unleash_released.emit()
			_target_touch_index = -1
			touch_target_bias.emit(Vector2.ZERO, false)
			_target_zone.accept_event()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == _target_touch_index:
			if _combo_mode and _vent_button.get_global_rect().has_point(_target_zone.global_position + drag.position):
				_consume_phase_swipe()
			_emit_target_drag(drag.position)
			_target_zone.accept_event()
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_LEFT:
			_target_mouse_active = mouse_button.pressed
			if _target_mouse_active:
				_target_origin = mouse_button.global_position
				touch_target_bias.emit(Vector2.ZERO, true)
				_phase_swipe_consumed = false
				if _combo_mode:
					unleash_started.emit()
			else:
				if _combo_mode and not _phase_swipe_consumed:
					unleash_released.emit()
				touch_target_bias.emit(Vector2.ZERO, false)
			_target_zone.accept_event()
	elif event is InputEventMouseMotion and _target_mouse_active:
		if _combo_mode and _vent_button.get_global_rect().has_point(event.global_position):
			_consume_phase_swipe()
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
		if _combo_mode:
			combat_cancel_requested.emit()
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
	if stats.has("sections"):
		var report := PackedStringArray()
		for section in stats["sections"]:
			report.append("[ %s ]" % String(section.get("title", "STATS")))
			var rows: Dictionary = section.get("rows", {})
			for caption in rows:
				var value := str(rows[caption])
				if value.contains("\n"):
					report.append("%s\n%s" % [String(caption).to_upper(), value])
				else:
					report.append("%s  ::  %s" % [String(caption).to_upper(), value])
			report.append("")
		return "\n".join(report)
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


func format_duration(seconds: float) -> String:
	return _format_time(seconds)


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
