extends SceneTree

var game: Node2D
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func frames(count: int) -> void:
	for frame in count:
		await physics_frame


func touch(pressed: bool, position: Vector2, index: int = 8) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = pressed
	event.position = position
	Input.parse_input_event(event)


func wait_for_charge() -> void:
	for frame in range(90):
		if game.graviton.is_charging:
			return
		await physics_frame
	check(false, "Actual touch input reaches the charging action")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	game = load("res://src/main.tscn").instantiate()
	game._combat_lab = true
	game._using_touch = true
	root.add_child(game)
	await frames(5)
	check(game.hud._vent_button.get_global_rect().end.x <= 1280 and game.hud._vent_button.get_global_rect().end.y <= 720, "Touch escape stays inside the safe viewport")
	var pad: Vector2 = game.hud._target_zone.get_global_rect().get_center()
	var phase: Vector2 = game.hud._vent_button.get_global_rect().get_center()
	var stick: Vector2 = game.hud._stick_zone.get_global_rect().get_center() + Vector2(45, 0)
	touch(true, stick, 2)
	await frames(10)
	check(game.player.move_intent.x > 0.5 and absf(game.player.move_intent.y) < 0.1, "Actual left-thumb GUI input moves in the indicated direction")
	touch(true, pad)
	await wait_for_charge()
	var drag := InputEventScreenDrag.new()
	drag.index = 8
	drag.position = phase
	drag.relative = phase - pad
	Input.parse_input_event(drag)
	await frames(10)
	touch(false, phase)
	touch(false, stick, 2)
	await frames(10)
	check(game.player.phase_uses == 1, "GUI touch slide performs exactly one phase skip")
	check(game.graviton.run_stats["salvos"] == 0 and not game.graviton.is_charging, "GUI touch cancel never emits a release salvo")
	game.player.phase_cooldown = 0
	game.hud._fixture_picker.grab_focus()
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	Input.parse_input_event(space)
	await frames(10)
	check(game.player.phase_uses == 2 and not game.hud._fixture_picker.get_popup().visible, "Space escape takes priority over the focused lab selector")
	space.pressed = false
	Input.parse_input_event(space)
	game._reset_lab()
	await frames(5)
	touch(true, pad)
	await wait_for_charge()
	await frames(55)
	touch(false, pad)
	await frames(35)
	check(game.graviton.run_stats["salvos"] == 1, "Normal touch release commits exactly one salvo")
	check(game.graviton.run_stats["missiles"] == 6, "Touch hold has the full six-cell payoff")
	game.hud._fixture_picker.item_selected.emit(1)
	await frames(5)
	check(game._lab_fixture == "dispersed" and get_nodes_in_group("enemy_normal").size() == 8, "Lab selector creates the dispersed fixture")
	game.hud._loadout_picker.item_selected.emit(0)
	await frames(5)
	check(not game.graviton.gravity_enabled and game.upgrades.is_empty(), "Salvo-only selector removes field and chain upgrades")
	game.hud._fixture_picker.item_selected.emit(2)
	await frames(5)
	check(is_instance_valid(game.boss) and not game.boss.is_physics_processing(), "Boss fixture is ready and waits for attack input")
	var boss_shots := [0]
	game.boss.shot_requested.connect(func(_position: Vector2, _direction: Vector2, _stats: Dictionary): boss_shots[0] += 1)
	touch(true, pad)
	await wait_for_charge()
	await frames(22)
	touch(false, pad)
	await frames(115)
	check(is_instance_valid(game.boss) and game.boss.is_physics_processing(), "Boss encounter runs after the offensive hold")
	check(not get_nodes_in_group("projectile_enemy").is_empty(), "Boss/ranged fixture actually attacks")
	check(boss_shots[0] > 0, "The boss itself emits its attack pattern")
	game.hud.lab_report_requested.emit()
	check(paused and game.run_ended and game.hud._end_overlay.visible, "Lab report pauses and opens the actual scorecard")
	check(not game.hud._end_report["scorecard"]["combo"].is_empty(), "Report contains the live kit telemetry")
	for dimensions in [Vector2i(640, 360), Vector2i(360, 640)]:
		root.content_scale_size = Vector2i.ZERO
		root.size = dimensions
		game.hud._layout_end_screen()
		for frame in range(4):
			await process_frame
		game.hud._end_tab_buttons[4].pressed.emit()
		check(game.hud._end_card.page == 4, "Compact kit telemetry page is selectable")
		check(game.hud._end_tabs.get_global_rect().end.x <= dimensions.x and game.hud._restart_button.get_global_rect().end.y <= dimensions.y, "Five compact tabs and restart fit the viewport")
	game.hud._restart_button.pressed.emit()
	check(not paused and not game.run_ended and game._lab_fixture == "boss", "Report restart returns to the selected encounter")
	game.synth_audio.shutdown()
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("GRAVITON_INPUT_OK two-thumb native touch / cancel-before-phase / full salvo / encounter selectors / boss fire / report / restart")
	quit(0 if failures.is_empty() else 1)
