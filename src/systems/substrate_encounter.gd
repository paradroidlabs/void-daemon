class_name SubstrateEncounter
extends Node2D

signal notice(event: String, text: String)
signal extracted

const Agent := preload("res://src/actors/substrate_agent.gd")
const Memory := preload("res://src/systems/substrate_memory.gd")
const THINK_STEP := 0.2
const SIGHT_RANGE := 440.0
const REPORT_DELAY := 1.25
const LINK_RANGE := 620.0
const SHARED_TTL := 2.5
var player: PlayerShip
var agents: Array[SubstrateAgent] = []
var relay: SubstrateAgent
var memory := Memory.new()
var clock := 0.0
var active := true
var objective_complete := false
var exit_position := Vector2(-680, 0)
# These are explicitly non-solid sensor clouds, not physical walls.
var shadows: Array[Rect2] = [Rect2(100, -80, 100, 160)]
var delivered := 0
var prevented := 0
var reports: Array[Dictionary] = []
var shared_position := Vector2.ZERO
var shared_velocity := Vector2.ZERO
var shared_at := -100.0
var decisions: Array[Dictionary] = []
var _think_left := 0.0
var _sample_at: Dictionary = {}
var _local: Dictionary = {}
var _relay_lost := false
var _last_belief := -1
var _phase := 0.0


func setup(ship: PlayerShip, seed_value: int) -> void:
	player = ship
	_phase = float(posmod(seed_value, 1000)) / 1000 * TAU
	_spawn("relay", "relay", &"bit", Vector2(400, 0), 260, 0)
	_spawn("scout_a", "scout", &"bit", Vector2(-20, -220), 105, 145)
	_spawn("scout_b", "scout", &"bit", Vector2(-20, 220), 105, 145)
	_spawn("anchor", "anchor", &"sentry", Vector2(380, -170), 150, 70)
	_spawn("flanker", "flanker", &"vector", Vector2(380, 180), 135, 130)


func _spawn(id: String, role: String, kind: StringName, point: Vector2, hp: float, speed: float) -> void:
	var agent := Agent.new()
	agent.role = role
	agent.stable_id = id
	agent.configure(kind, point, {"health": hp, "speed": speed, "damage": 7,
		"xp": 2, "charge_windup": 1.0, "charge_recovery": 0.9, "charge_cooldown": 3.4,
		"charge_trigger_range": 310, "charge_speed": 300, "shot_windup": 0.95,
		"shot_interval": 3.0, "initial_action_delay": 2.0, "preferred_range": 260,
		"color": Color("83d8ce") if role == "scout" else (Color("b4a0ff") if role == "relay" else Color("ffc36b"))})
	add_child(agent)
	agent.add_to_group("enemy_normal")
	agents.append(agent)
	if role == "relay":
		relay = agent
		agent.collision_radius = 22
		agent._update_collision_shape()
		agent.task = "BREAK LINK"


func living(agent) -> bool:
	return is_instance_valid(agent) and not agent.is_queued_for_deletion() and agent.is_alive()


func link_alive() -> bool:
	return living(relay)


func can_see(origin: Vector2, point: Vector2) -> bool:
	if origin.distance_squared_to(point) > SIGHT_RANGE * SIGHT_RANGE:
		return false
	return clear_signal(origin, point)


func clear_signal(origin: Vector2, point: Vector2) -> bool:
	for rect in shadows:
		if rect.has_point(origin) or rect.has_point(point):
			return false
		var corners := [rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]
		for i in range(4):
			if Geometry2D.segment_intersects_segment(origin, point, corners[i], corners[(i + 1) % 4]) != null:
				return false
	return true


func tick(delta: float) -> void:
	if not active or not is_instance_valid(player) or player.is_dead:
		return
	clock += delta
	memory.advance(clock)
	if not link_alive() and not _relay_lost:
		_relay_lost = true
		prevented += reports.size()
		reports.clear()
		shared_at = -100
		memory = Memory.new()
		notice.emit("relay_lost", "Relay severed. Shared tracking is gone. Reach the cyan exit.")
	if _relay_lost and player.global_position.distance_to(exit_position) <= 64 and not objective_complete:
		objective_complete = true
		active = false
		extracted.emit()
		return
	_think_left -= delta
	if _think_left <= 0:
		_think_left = THINK_STEP
		_think()
	queue_redraw()


func _think() -> void:
	# Validate the source and link again at delivery, not just when queued.
	for i in range(reports.size() - 1, -1, -1):
		var report: Dictionary = reports[i]
		var source: Enemy = report["source"].get_ref()
		if not living(source) or not link_alive():
			prevented += 1
			reports.remove_at(i)
			continue
		if clock < float(report["due"]):
			continue
		if source.global_position.distance_to(relay.global_position) > LINK_RANGE or not clear_signal(source.global_position, relay.global_position):
			if clock > float(report["due"]) + 2:
				prevented += 1
				reports.remove_at(i)
			continue
		# Never refresh a delayed sighting from the current, possibly hidden player.
		if float(report["time"]) > shared_at:
			shared_position = report["position"]
			shared_velocity = report["velocity"]
			shared_at = report["time"]
		memory.observe(report["velocity"], float(report["time"]))
		delivered += 1
		if delivered == 1:
			notice.emit("first_report", "Contact reported. We can share what the scout survived to see.")
		reports.remove_at(i)
	# Delayed delivery must not resurrect evidence older than the window.
	memory.advance(clock)
	if memory.heading_bin != _last_belief:
		_last_belief = memory.heading_bin
		if _last_belief >= 0:
			notice.emit("pattern_%d" % memory.revisions, "A repeated travel vector. We will meet you ahead of it.")
		else:
			notice.emit("pattern_lost_%d" % memory.revisions, "The old pattern no longer fits. Search again.")
	for agent in agents:
		if not living(agent) or agent.role == "relay":
			continue
		var visible := can_see(agent.global_position, player.global_position)
		if visible:
			_local[agent.stable_id] = {"position": player.global_position, "time": clock}
		if agent.role == "scout":
			_scout(agent, visible)
		else:
			_fighter(agent)


func _scout(agent: SubstrateAgent, visible: bool) -> void:
	var pending := false
	for report in reports:
		if report["id"] == agent.stable_id:
			pending = true
	if visible and link_alive() and not pending and clock >= float(_sample_at.get(agent.stable_id, 2.0)):
		reports.append({"source": weakref(agent), "id": agent.stable_id, "position": player.global_position,
			"velocity": player.velocity, "time": clock, "due": clock + REPORT_DELAY})
		_sample_at[agent.stable_id] = clock + 1.5
	var local: Dictionary = _local.get(agent.stable_id, {})
	if not local.is_empty() and clock - float(local["time"]) <= 1.5:
		var seen: Vector2 = local["position"]
		var away := seen.direction_to(agent.global_position)
		var side := -1 if agent.stable_id == "scout_a" else 1
		agent.set_target_position(seen + away * 340 + away.orthogonal() * side * 70)
		agent.task = "REPORT PENDING" if pending else "SHADOW CONTACT"
	else:
		var side := -1 if agent.stable_id == "scout_a" else 1
		agent.set_target_position(Vector2(20 + sin(clock * 0.4 + _phase) * 140, side * 220))
		agent.task = "PATROL / SEARCH"
	if pending and link_alive() and agent.global_position.distance_to(relay.global_position) > LINK_RANGE - 50:
		agent.set_target_position(relay.global_position + Vector2(-160, 0))
		agent.task = "RETURN TO LINK"


func _fighter(agent: SubstrateAgent) -> void:
	var local: Dictionary = _local.get(agent.stable_id, {})
	var has_local := not local.is_empty() and clock - float(local["time"]) <= 1.0
	var has_shared := link_alive() and clock - shared_at <= SHARED_TTL
	if not has_local and not has_shared:
		# Agents still guard/patrol with the player absent. No global target node.
		if agent.role == "flanker":
			agent.charge_trigger_range = 0
			agent.set_target_position(Vector2(380, 180) + Vector2(sin(clock * 0.5) * 100, 0))
		else:
			agent.clear_target()
		agent.task = "GUARD / SEARCH"
		return
	var point: Vector2 = local["position"] if has_local else shared_position
	if agent.role == "flanker":
		agent.charge_trigger_range = 310
		if has_shared and memory.heading_bin >= 0:
			# Prediction is bounded and uses only a delivered observation.
			point = shared_position + Vector2.RIGHT.rotated(memory.heading_bin * TAU / 8) * minf(180, shared_velocity.length() * 0.65)
			agent.task = "INTERCEPT / TELL"
		else:
			agent.task = "FLANK / TELL"
			agent.charge_trigger_range = 220
	else:
		agent.task = "SCREEN / AIM"
	agent.set_target_position(point)
	decisions.append({"time": clock, "agent": agent.stable_id, "task": agent.task,
		"target": point, "knowledge": "local" if has_local else "report", "belief": memory.heading_bin})
	if decisions.size() > 32:
		decisions.pop_front()


func snapshot() -> Dictionary:
	var units: Array[Dictionary] = []
	for agent in agents:
		if living(agent):
			units.append({"id": agent.stable_id, "role": agent.role, "task": agent.task,
				"health": agent.health, "state": String(agent.get_state())})
	return {"reports": delivered, "prevented": prevented, "pending": reports.size(),
		"link": link_alive(), "memory": memory.snapshot(), "decisions": decisions.duplicate(true),
		"units": units,
		"objective": "EXTRACTED" if objective_complete else ("BREAK RELAY" if link_alive() else "REACH EXIT")}


func _draw() -> void:
	var font := ThemeDB.fallback_font
	for rect in shadows:
		draw_rect(rect, Color(0.12, 0.15, 0.29, 0.45))
		draw_rect(rect, Color("627296"), false, 1)
		draw_string(font, rect.position + Vector2(8, 18), "SHADOW / HIDE", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 16, 10, Color("b8c6e2"))
		draw_string(font, rect.position + Vector2(8, 35), "NON-SOLID", HORIZONTAL_ALIGNMENT_LEFT, rect.size.x - 16, 10, Color("8295b8"))
	var exit_color := Color("68f7e5") if not link_alive() else Color("42636b")
	draw_arc(exit_position, 64, 0, TAU, 48, exit_color, 2, true)
	draw_string(font, exit_position + Vector2(-65, -77), "EXTRACT / READY" if not link_alive() else "EXTRACT / LOCKED", HORIZONTAL_ALIGNMENT_CENTER, 130, 11, exit_color)
	for report in reports:
		var source: Enemy = report["source"].get_ref()
		if living(source) and link_alive():
			var color := Color("ffc36b") if clear_signal(source.global_position, relay.global_position) else Color("ff657b")
			draw_dashed_line(source.global_position, relay.global_position, Color(color, 0.45), 1, 8)
			var progress := clampf(1 - (float(report["due"]) - clock) / REPORT_DELAY, 0, 1)
			draw_circle(source.global_position.lerp(relay.global_position, progress), 4, color)
