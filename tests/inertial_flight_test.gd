extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func advance(ship: Node2D, initial: Vector2, intent: Vector2, duration: float, hz: int) -> Vector2:
	var result := initial
	for frame in range(roundi(duration * hz)):
		var force: Vector2 = ship.get_thrust_acceleration(result, intent)
		result = ship.integrate_velocity(result, force, 1.0 / hz)
	return result


func frames(count: int) -> void:
	for frame in range(count):
		await physics_frame


func _run() -> void:
	var ship = load("res://src/actors/player_ship.gd").new()
	ship.inertial_flight = true
	ship.arena_bounds = Rect2(-5000, -5000, 10000, 10000)
	root.add_child(ship)
	ship.set_physics_process(false)
	var accelerated := advance(ship, Vector2.ZERO, Vector2.RIGHT, 1, 60)
	check(accelerated.x > 250 and accelerated.x < 285, "Thrust builds to a governed cruise rather than teleporting velocity")
	var coast := advance(ship, accelerated, Vector2.ZERO, 1, 60)
	check(coast.x > accelerated.x * 0.75 and coast.x < accelerated.x, "Releasing thrust preserves inertia with gradual drag")
	var turn := advance(ship, accelerated, Vector2.DOWN, 0.25, 60)
	check(turn.x > 200 and turn.y > 80, "Cross-thrust bends travel without deleting lateral momentum")
	var brake := advance(ship, accelerated, Vector2.LEFT, 0.3, 60)
	check(brake.x < accelerated.x * 0.4, "Opposing thrust provides deliberate braking")
	for hz in [30, 60, 120]:
		var timed := advance(ship, Vector2.ZERO, Vector2.RIGHT, 2, hz)
		var reference := advance(ship, Vector2.ZERO, Vector2.RIGHT, 2, 240)
		check(timed.distance_to(reference) < 1.2, "Acceleration is stable across tick rates")
		var decay := advance(ship, Vector2(250, 40), Vector2.ZERO, 2, hz)
		check(decay.distance_to(Vector2(250, 40) * exp(-ship.linear_drag * 2)) < 0.01, "Coast decay is timestep independent")
	var well = load("res://src/world/gravity_well.gd").new()
	well.position = Vector2(120, 50)
	root.add_child(well)
	ship.gravity_sources.append(well)
	check(ship.sample_gravity(Vector2.ZERO).x > 0 and ship.sample_gravity(Vector2.ZERO).y > 0, "Gravity acts in the direction of the actual well")
	check(well.acceleration_at(well.global_position) == Vector2.ZERO, "Soft gravity has no singularity at the center")
	check(well.acceleration_at(well.global_position + Vector2(700, 0)) == Vector2.ZERO, "Gravity is bounded by its advertised field radius")
	var bent: Vector2 = ship.integrate_velocity(Vector2(0, -200), ship.sample_gravity(Vector2.ZERO), 0.1)
	check(bent.x > 0 and bent.y < 0, "Gravity bends an existing trajectory rather than replacing it")
	var capped: Vector2 = ship.integrate_velocity(Vector2(600, 0), Vector2(99999, 0), 1)
	check(capped.length() <= ship.move_speed * 2.2 + 0.01, "Extreme forces cannot create unbounded speeds")
	ship.gravity_sources.clear()
	well.queue_free()
	ship.velocity = Vector2(220, 0)
	ship.rotation = 0
	ship.set_aim_bias(Vector2.UP, true)
	ship.set_move_intent(Vector2.ZERO)
	ship.set_physics_process(true)
	var start: Vector2 = ship.global_position
	await frames(20)
	check(ship.global_position.x > start.x + 30 and absf(ship.global_position.y - start.y) < 1, "Real movement continues along previous velocity after thrust release")
	check(ship.rotation < -1 and ship.velocity.x > 180, "Turning the nose does not snap the flight vector")
	var before_phase: Vector2 = ship.velocity
	ship.combo_mode = true
	check(ship.try_phase_skip(), "Phase escape remains available while coasting")
	check(ship.velocity.is_equal_approx(before_phase), "Phase skip preserves momentum rather than refunding a stop")
	var telemetry: Dictionary = ship.get_flight_telemetry()
	check(telemetry["track"] >= 0 and telemetry["drift"] > 45, "Telemetry distinguishes heading, travel, and drift")
	ship.velocity = Vector2.ZERO
	check(ship.get_flight_telemetry()["track"] == -1, "Stationary ship has no invented track bearing")
	check(ship.flight_stats["coast_seconds"] > 0, "Coasting contributes actual run telemetry")
	ship.queue_free()
	await process_frame
	# Integration: the orbital lab creates a real well and the HUD selection agrees.
	var game = load("res://src/main.tscn").instantiate()
	game._combat_lab = true
	game._lab_fixture = "orbit"
	root.add_child(game)
	await frames(5)
	check(game.player.inertial_flight and game.player.gravity_sources.size() == 1, "Orbit lab wires real navigation gravity into the player")
	check(game.hud._fixture_picker.selected == 3, "Orbit fixture is accurately identified in the selector")
	check(game.hud._flight_panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Telemetry cannot capture combat mouse/touch input")
	game._select_fixture("cluster")
	await frames(3)
	check(game.player.gravity_sources.is_empty(), "Ordinary comparison fixtures remain free of environmental wells")
	check(game.player.velocity.length() < 1, "Fixture reset clears drift instead of leaking prior momentum")
	game.synth_audio.shutdown()
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("INERTIAL_FLIGHT_OK thrust / coast / counterthrust / independent facing / gravity / dt / phase / telemetry / fixture reset")
	quit(0 if failures.is_empty() else 1)
