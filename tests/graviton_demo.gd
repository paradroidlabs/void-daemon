extends SceneTree

var game: Node2D
var timeline: Array[Dictionary] = []
var rendered := false


func _initialize() -> void:
	call_deferred("_run")


func mouse(pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = Vector2(940, 360)
	event.global_position = event.position
	Input.parse_input_event(event)


func frames(count: int) -> void:
	for frame in count:
		await physics_frame


func capture(name: String) -> void:
	if not rendered:
		return
	game.hud._root.queue_redraw()
	for frame in range(3):
		game.graviton.queue_redraw()
		await RenderingServer.frame_post_draw
	var capture_name := name.replace("graviton_", "graviton_touch_") if game._using_touch else name
	get_root().get_texture().get_image().save_png("res://artifacts/" + capture_name + ".png")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	root.content_scale_size = Vector2i(1280, 720)
	rendered = DisplayServer.get_name() != "headless"
	game = load("res://src/main.tscn").instantiate()
	game._combat_lab = true
	root.add_child(game)
	await frames(3)
	for enemy in get_nodes_in_group("enemies"):
		enemy.damaged.connect(func(_enemy: Node, amount: float, source: StringName, _position: Vector2): timeline.append({"time": game.elapsed_time, "source": str(source), "amount": amount}))
	mouse(true)
	for frame in range(120):
		if game.graviton.is_charging:
			break
		await physics_frame
	await frames(52)
	print("GRAVITON_ARM time=%.3f loaded=%d heat=%.2f" % [game.graviton.charge_time, game.graviton.loaded_count, game.player.heat])
	await capture("graviton_charge")
	var grouped: int = game.graviton.run_stats["grouped"]
	mouse(false)
	await frames(20)
	await capture("graviton_salvo")
	await frames(90)
	await capture("graviton_followthrough")
	var first_missile := INF
	var following_arc := false
	for event in timeline:
		if event["source"] == "GRAVITON_SALVO":
			first_missile = minf(first_missile, event["time"])
		elif event["source"] == "ARC_EXE" and event["time"] > first_missile:
			following_arc = true
	var okay: bool = grouped > 0 and game.graviton.run_stats["missiles"] == 6 and game.damage_dealt > 0 and following_arc
	for id in ["MASS_DRIVER", "MASS_DRIVER_FORK", "MASS_DRIVER_RETURN"]:
		okay = okay and float(game.source_stats.get(id, {}).get("damage", 0)) > 0
	print("GRAVITON_FLOW grouped=%d missiles=%d kills=%d damage=%.2f arc_after_salvo=%s sources=%s" % [grouped, game.graviton.run_stats["missiles"], game.kills, game.damage_dealt, following_arc, str(game.source_stats)])
	game._end_run(false)
	await create_timer(0.1, true).timeout
	await capture("graviton_scorecard")
	game.synth_audio.shutdown()
	paused = false
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit(0 if okay else 1)
