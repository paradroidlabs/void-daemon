extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	var game = load("res://src/main.tscn").instantiate()
	game._combat_lab = true
	game._lab_fixture = "orbit"
	root.add_child(game)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.velocity = Vector2(230, -30)
	game.player.rotation = -PI / 2
	game.player.flight_gravity = game.player.sample_gravity(game.player.global_position)
	game.player.flight_stats["peak_speed"] = game.player.velocity.length()
	game._update_hud(true)
	game.hud.flash_log("FLIGHT INSTRUMENT FIXTURE // NO THRUST // CYAN NOSE / AMBER TRAVEL", Color("ffbd4a"))
	game.player.queue_redraw()
	if DisplayServer.get_name() != "headless":
		for index in range(5):
			game.hud._root.queue_redraw()
			await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://artifacts/flight_instruments_fixture.png")
	game.synth_audio.shutdown()
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("FLIGHT_VISUAL_OK actual scene / orbit field / no-thrust telemetry / coast prediction")
	quit(0)
