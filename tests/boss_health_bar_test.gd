extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _run() -> void:
	var world := Node2D.new()
	world.rotation = 0.31
	world.scale = Vector2(1.4, 1.4)
	root.add_child(world)
	var boss = load("res://src/actors/watchdog_boss.gd").new()
	world.add_child(boss)
	boss.set_physics_process(false)
	var bar = boss.get_node("HealthBar")
	check(bar.top_level, "Boss health bar does not inherit rotation or scale")
	for angle in [0.0, PI / 4, -PI / 2, PI * 3, TAU * 3.4]:
		boss.rotation = angle
		boss.position += Vector2(35, 20)
		bar._process(0)
		check(bar.global_position.is_equal_approx(boss.global_position + Vector2(0, -70)), "Bar stays directly above moving/rotating boss")
		check(is_zero_approx(bar.global_rotation), "Bar remains horizontal through arbitrary boss rotations")
		check(bar.global_scale.is_equal_approx(Vector2.ONE), "Parent scale cannot distort the health display")
	boss.take_damage(750, "TEST")
	bar._process(0)
	check(is_equal_approx(bar.health_ratio, 0.5), "Independent bar still reflects actual health")
	boss.take_damage(750, "TEST")
	bar._process(0)
	check(not bar.visible, "Dead boss does not retain a visible bar")
	await process_frame
	await process_frame
	check(not is_instance_valid(bar), "Health bar is freed with its boss, despite top-level transform")
	world.queue_free()
	await process_frame
	if failures.is_empty():
		print("BOSS_HEALTH_BAR_OK upright / follows position / ignores parent scale / health / death / lifetime")
	quit(0 if failures.is_empty() else 1)
