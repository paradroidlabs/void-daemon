extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func run() -> void:
	root.size = Vector2i(1280,720)
	root.content_scale_size = Vector2i.ZERO
	var game = load("res://src/main.tscn").instantiate()
	root.add_child(game)
	var picker_rows: Node = game.hud._ship_picker.get_child(0).get_child(0)
	(picker_rows.get_child(2) as Button).pressed.emit()
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	for frame in 3:
		await process_frame
	var rect: Rect2 = game.combat_view.get_global_rect()
	check(not game.hud._ship_diagram.visible, "Module schematic is not floating over combat")
	check(not game.hud._status_panel.is_visible_in_tree(), "Original oversized HUD stays hidden")
	check(game.player.get_viewport() == game.combat_view.arena, "Courier combat uses the isolated view")
	check(not rect.intersects(game.hud._zoom_controls.get_global_rect()), "Zoom buttons do not cover combat")
	game.hud.set_ship_diagram({"FORK_ON_KILL": 2}, 0.6, 0.5, 0.2, "COURIER")
	check(not game.hud._ship_diagram.visible, "Live module updates cannot reopen the obstructing panel")
	game.hud.toggle_pause(true)
	check(paused and game.hud._pause_dashboard.get_tab_count() == 4, "Full inspection remains available while paused")
	game.hud.toggle_pause(false)
	check(not game.hud._ship_diagram.visible, "Resume cannot reopen the panel")
	for value in [0.65,0.82,1.25]:
		game.combat_view.set_zoom_level(value)
		var point := Vector2(100,50)
		check(game.combat_view.screen_to_world(game.combat_view.world_to_screen(point)).distance_to(point) < 0.01, "Courier aiming transform is correct at each zoom")
	game.combat_view.set_zoom_level(0.82)
	game.hud._zoom_controls.get_child(0).pressed.emit()
	check(is_equal_approx(game.combat_view.zoom_level, 0.74), "Courier zoom button controls the actual camera")
	if DisplayServer.get_name() != "headless":
		for frame in 5:
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/courier_docked_ui.png")
	game.synth_audio.shutdown()
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("COURIER_LAYOUT_OK no active schematic / full pause inspection retained / isolated view / bounded zoom / correct aiming")
	quit(0 if failures.is_empty() else 1)
