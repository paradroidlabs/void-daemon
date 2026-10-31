extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func key(code: Key) -> void:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = code
	event.physical_keycode = code
	Input.parse_input_event(event)
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)


func run() -> void:
	root.get_node("Experience").persist = false
	root.get_node("Experience").hive_voice = false
	var game = load("res://src/main.tscn").instantiate()
	game._honor_command_line = false
	game._combat_lab = true
	root.add_child(game)
	await process_frame
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.elapsed_time = 42.0
	game.player.velocity = Vector2(120, 30)
	game.graviton.begin_charge()
	var hull: float = game.player.hull
	var velocity: Vector2 = game.player.velocity
	key(KEY_ESCAPE)
	await process_frame
	check(paused and game.hud.is_paused(), "Escape pauses and opens live stats")
	check(game.hud._live_report and game.hud._end_card.data["in_progress"], "Live scorecard is explicitly not a death report")
	check(not game.run_ended and game.weapon_controller.enabled, "Inspection does not end the run or disable automatic weapons")
	check(not game.graviton.is_charging and game.graviton.run_stats["salvos"] == 0, "Opening stats cancels a hold safely, never releases a shot")
	check(game.hud._end_card.data["time"] == 42, "Snapshot contains the current run time")
	check(not game.hud._end_card.data["patches"].is_empty(), "Live stats include installed lab patches")
	for i in range(5):
		await physics_frame
	check(game.elapsed_time == 42 and game.player.hull == hull and game.player.velocity == velocity, "Inspection freezes world time and preserves ship state")
	check(game.hud._restart_button.text.begins_with("RESUME"), "Primary live action resumes, not restarts")
	# No accidental restart key in live stats.
	key(KEY_R)
	await process_frame
	check(paused and game.elapsed_time == 42, "R cannot accidentally reset the inspected run")
	for dimensions in [Vector2i(1280, 720), Vector2i(640, 360), Vector2i(360, 640)]:
		root.content_scale_size = Vector2i.ZERO
		root.size = dimensions
		game.hud._layout_end_screen()
		for i in range(5):
			await process_frame
		var bounds: Rect2 = game.hud._end_panel.get_global_rect()
		check(bounds.position.x >= 0 and bounds.end.x <= dimensions.x + 1, "Live stats fit width at %s" % dimensions)
		check(bounds.position.y >= 0 and bounds.end.y <= dimensions.y + 1, "Live stats fit height at %s" % dimensions)
		check(game.hud._menu_button.get_global_rect().end.x < game.hud._restart_button.global_position.x, "Options and Resume never overlap")
		check(game.hud._restart_button.size.y >= 44, "Resume is touch-sized")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/live-stats-%dx%d.png" % [dimensions.x, dimensions.y])
		game.hud._menu_button.pressed.emit()
		for i in range(5):
			await process_frame
		var options: Rect2 = game.hud._pause_panel.get_global_rect()
		check(options.position.x >= 0 and options.end.x <= dimensions.x + 1 and options.position.y >= 0 and options.end.y <= dimensions.y + 1, "Pause options fit %s" % dimensions)
		check(game.hud._pause_panel.find_child("music_volume", true, false) != null, "Music mix is adjustable without abandoning the run")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.godot/pause-options-%dx%d.png" % [dimensions.x, dimensions.y])
		game.hud._pause_panel.find_child("LiveStatsButton", true, false).pressed.emit()
	game.hud._menu_button.pressed.emit()
	check(paused and game.hud._pause_overlay.visible and not game.hud._end_overlay.visible, "Pause options keep the same paused session")
	game.hud._pause_panel.find_child("LiveStatsButton", true, false).pressed.emit()
	check(paused and game.hud._end_overlay.visible, "Stats can be reopened from pause options")
	var joy := InputEventJoypadButton.new()
	joy.pressed = true
	joy.button_index = JOY_BUTTON_B
	Input.parse_input_event(joy)
	await process_frame
	check(not paused and not game.hud._end_overlay.visible, "Controller B resumes from live stats")
	game.elapsed_time = 73
	game.hud.lab_report_requested.emit()
	check(paused and not game.run_ended and game.hud._end_card.data["time"] == 73, "Lab Report refreshes the snapshot without ending or resetting")
	game.hud._restart_button.pressed.emit()
	check(not paused and game.elapsed_time == 73 and game.player.velocity == velocity, "Native Resume preserves encounter and inertia")
	game._end_run(false)
	check(game.run_ended and paused and not game.hud._live_report, "Real death still opens the final scorecard")
	check(not game.hud._end_card.data.get("in_progress", false) and game.hud._restart_button.text.begins_with("RESTART"), "Final report restores death/restart semantics")
	paused = false
	game.synth_audio.shutdown()
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("LIVE_STATS_OK Escape / full snapshot / pause invariants / no scrolling / compact touch / options / controller / lab resume / final report")
	quit(0 if failures.is_empty() else 1)
