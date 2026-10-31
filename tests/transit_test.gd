extends SceneTree

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)

func run() -> void:
	root.get_node("Experience").persist = false
	var ship = load("res://src/actors/player_ship.gd").new()
	root.add_child(ship)
	ship.set_physics_process(false)
	var route = load("res://src/campaign/gravity_intercept.gd").new()
	root.add_child(route)
	route.setup(ship)
	await physics_frame
	check(ship.gravity_sources.size() == 2 and ship.collision_mask & 16, "Transit has actual gravity and wall collision enabled")
	# Every point and ideal route segment must be clear with ship-sized clearance.
	var start := Vector2(-1350,-450)
	for point: Vector2 in route.gates:
		for rect: Rect2 in route.rocks:
			var inflated := rect.grow(22)
			check(not inflated.has_point(point), "Gate is outside solid collision geometry")
			var corners := [inflated.position, Vector2(inflated.end.x,inflated.position.y), inflated.end, Vector2(inflated.position.x,inflated.end.y)]
			for j in range(4):
				check(Geometry2D.segment_intersects_segment(start,point,corners[j],corners[(j+1)%4]) == null, "Courier reference path clears solid bulkheads")
		start = point
	var result := [{}]
	var failures_emitted := [0]
	route.completed.connect(func(value: Dictionary): result[0] = value)
	route.failed.connect(func(): failures_emitted[0] += 1)
	ship.position = route.gates[3]
	route.tick(0.01)
	check(route.next_gate == 0, "Teleporting to a later gate cannot skip route order")
	var first: Vector2 = route.gates[0]
	var heading := Vector2(-1350,-450).direction_to(first)
	route._previous = first + heading*80
	ship.position = first + heading*20
	route.tick(0.01)
	check(route.next_gate == 0, "Entering a gate in the wrong direction is rejected")
	route._previous = first-heading*300
	ship.position = first
	route.tick(0.01)
	check(route.next_gate == 0, "A teleport-length leap cannot claim a gate")
	ship.position = Vector2(-1350,-450)
	route._previous = ship.position
	for point: Vector2 in route.gates:
		while route.next_gate < route.gates.size() and ship.position.distance_to(point) > 0.1:
			ship.position = ship.position.move_toward(point, 20)
			route.tick(0.01)
	check(not result[0].is_empty() and result[0]["gates"] == 12 and not result[0]["courier_escaped"], "All ordered gates complete and report a clean interception")
	check(failures_emitted[0] == 0, "Successful route does not also fail")
	# Test real CharacterBody motion against the authored StaticBody collider.
	ship.position = Vector2(-800,-200)
	ship.velocity = Vector2(600,0)
	for i in range(20):
		ship.move_and_slide()
		await physics_frame
	check(ship.position.x < -750, "Bulkhead blocks actual ship movement, not just a drawn rectangle")
	route.free()
	var late = load("res://src/campaign/gravity_intercept.gd").new()
	root.add_child(late)
	late.setup(ship)
	late.clock = 149.9
	late.failed.connect(func(): failures_emitted[0] += 1)
	late.tick(0.2)
	late.tick(1)
	check(not late.active and failures_emitted[0] == 1, "Timeout fails once and cannot continue advancing")
	late.free()
	ship.free()
	await process_frame
	if failures.is_empty():
		print("TRANSIT_OK ordered directional gates / no teleport skip / solid clearance / actual collision / gravity / courier outcome / timeout")
	quit(0 if failures.is_empty() else 1)
