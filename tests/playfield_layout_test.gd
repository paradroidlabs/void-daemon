extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i.ZERO
	root.get_node("Experience").persist = false
	var game = load("res://src/main.tscn").instantiate()
	game._combat_lab = true
	root.add_child(game)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	for frame in 4:
		await process_frame
	for dimensions in [Vector2i(1280,720), Vector2i(1920,1080), Vector2i(640,360)]:
		root.size = dimensions
		for frame in 3:
			await process_frame
		game.combat_view.relayout()
		game.hud._layout_touch_controls()
		game._update_hud()
		var rect: Rect2 = game.combat_view.get_global_rect()
		check(game.player.get_viewport() == game.combat_view.arena, "Actors really render into the dedicated combat viewport")
		check(not rect.intersects(game.hud._flight_panel.get_global_rect()), "Flight data never occupies combat pixels")
		check(not rect.intersects(game.hud._rack_panel.get_global_rect()), "Attack dock cannot obscure enemies")
		check(not rect.intersects(game.hud._zoom_controls.get_global_rect()), "Touch zoom controls live outside combat")
		check(rect.position.y >= 82 and rect.end.y <= dimensions.y - 120, "Entire combat view lies between HUD bands")
		check(not game.hud._status_panel.is_visible_in_tree(), "Obsolete oversized HUD is not still drawn")
		for level in [0.65,0.82,1.25]:
			game.combat_view.set_zoom_level(level)
			game.camera.force_update_scroll()
			var point := Vector2(220, -80)
			var screen: Vector2 = game.combat_view.world_to_screen(point)
			check(game.combat_view.screen_to_world(screen).distance_to(point) < 0.01, "Mouse/world mapping remains correct at every zoom and aspect")
	game.combat_view.set_zoom_level(-100)
	check(game.combat_view.zoom_level == 0.65, "Zoom out is bounded")
	root.size = Vector2i(1280,720)
	await process_frame
	game.combat_view.relayout()
	game.camera.force_update_scroll()
	for index in 16:
		var spawn: Vector2 = game.combat_view.spawn_position(game.player.global_position, index * TAU / 16, 0.5, game.ARENA_BOUNDS)
		check(not game.combat_view.contains_screen_point(game.combat_view.world_to_screen(spawn)), "Wider zoom does not spawn enemies visibly inside the combat view")
	game.combat_view.set_zoom_level(100)
	check(game.combat_view.zoom_level == 1.25, "Zoom in is bounded")
	game.combat_view.set_zoom_level(0.82)
	game.hud._zoom_controls.get_child(0).pressed.emit()
	check(is_equal_approx(game.combat_view.zoom_level, 0.74), "Touch zoom button operates the actual camera")
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_UP
	wheel.pressed = true
	wheel.position = game.combat_view.get_global_rect().get_center()
	game._unhandled_input(wheel)
	check(is_equal_approx(game.combat_view.zoom_level, 0.82), "Mouse wheel operates the same zoom model")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = Vector2(50, 20)
	game._unhandled_input(click)
	check(not game.graviton.is_charging, "Clicking passive HUD space cannot start an attack")
	game._reset_lab()
	check(is_equal_approx(game.combat_view.zoom_level, 0.82), "Fixture reset preserves chosen view")
	game.hive.transmit("test", "The hive stays outside your firing lane.", true)
	game.hive.observe(0.01)
	check(game.hive._pane.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Narrative remains click-through")
	game.synth_audio.shutdown()
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("PLAYFIELD_LAYOUT_OK isolated combat viewport / no passive HUD overlap / aspect ratios / zoom bounds / shared zoom input / aim mapping / no HUD fire")
	quit(0 if failures.is_empty() else 1)
