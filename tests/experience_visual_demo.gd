extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func capture(path: String) -> void:
	for frame in range(6):
		await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)


func run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	root.get_node("Experience").persist = false
	root.get_node("Experience").hive_voice = false
	var boot = load("res://src/boot.tscn").instantiate()
	root.add_child(boot)
	boot.select_ship("bastion")
	await capture("res://artifacts/hangar_experience.png")
	boot.launch_run(true, "bastion")
	await process_frame
	var game: Node2D = boot.game
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.set_aim_bias(Vector2.RIGHT, true)
	game.player.velocity = Vector2(100, 80)
	game.player.flight_stats["peak_speed"] = game.player.velocity.length()
	game.graviton.begin_charge()
	for frame in range(35):
		game.graviton.tick(1.0 / 60, get_nodes_in_group("enemies"))
		game.elapsed_time += 1.0 / 60
	game._update_hud(true)
	game.hive.transmit("firing_lane", "A straight line. Such a small answer to so many bodies.", true)
	game.hive._visible_left = 5
	game.hive.observe(0.01)
	await capture("res://artifacts/bastion_hive_experience.png")
	game._end_run(false)
	await capture("res://artifacts/bastion_flight_scorecard.png")
	boot.show_menu()
	await process_frame
	boot._settings.show()
	await capture("res://artifacts/experience_settings.png")
	root.size = Vector2i(640, 360)
	await process_frame
	await process_frame
	boot.show_menu()
	await capture("res://artifacts/hangar_compact.png")
	boot._layout.get_child(0).scroll_vertical = 650
	await capture("res://artifacts/hangar_compact_actions.png")
	boot._settings.show()
	await capture("res://artifacts/settings_compact.png")
	print("HIVE_VOICE_AVAILABLE english=%d" % DisplayServer.tts_get_voices_for_language("en").size())
	boot.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	print("EXPERIENCE_VISUAL_OK actual hangar / beam / live feed / scorecard / settings")
	quit()
