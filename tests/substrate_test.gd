extends SceneTree

var failures: Array[String] = []
var encounter
var ship


func _initialize() -> void:
	call_deferred("run")


func check(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		push_error(message)


func step(seconds: float) -> void:
	for i in ceili(seconds / 0.2):
		encounter.tick(0.2)


func fixture() -> void:
	if is_instance_valid(encounter):
		encounter.free()
	encounter = load("res://src/systems/substrate_encounter.gd").new()
	root.add_child(encounter)
	ship.position = Vector2(-280, 0)
	ship.velocity = Vector2(180, 0)
	encounter.setup(ship, 4821)
	for agent in encounter.agents:
		agent.set_physics_process(false)


func run() -> void:
	root.get_node("Experience").persist = false
	root.get_node("Experience").hive_voice = false
	var memory := SubstrateMemory.new()
	for i in 5:
		memory.observe(Vector2(180, 0), i * 0.2)
	check(memory.heading_bin == -1, "Five observations cannot qualify a habit")
	memory.observe(Vector2(180, 0), 1.0)
	check(memory.heading_bin == 0, "Six consistent sightings qualify an eastbound hypothesis")
	memory.advance(10)
	check(memory.heading_bin == -1 and memory.observations.is_empty(), "Unrefreshed hypotheses expire")
	for i in 12:
		memory.observe(Vector2(180, 0) if i % 2 else Vector2(-180, 0), 10 + i * 0.1)
	check(memory.heading_bin == -1, "Mixed behavior cannot qualify a dominant hypothesis")
	for i in 6:
		memory.observe(Vector2(-180, 0), 20 + i * 0.1)
	check(memory.heading_bin == 4, "New observations can revise the hypothesis")

	ship = load("res://src/actors/player_ship.gd").new()
	root.add_child(ship)
	ship.set_physics_process(false)
	fixture()
	check(encounter.agents.size() == 5, "Encounter has exactly five role-bearing entities, no wave spawning")
	encounter.relay.set_gravity_velocity(Vector2(100, 0))
	encounter.relay.apply_impulse(Vector2(100, 0))
	check(encounter.relay._gravity_velocity == Vector2.ZERO and encounter.relay._navigation_velocity == Vector2.ZERO, "Relay stays anchored against gathering and knockback")
	check(not encounter.can_see(Vector2.ZERO, Vector2(500, 0)), "Perception has a finite range")
	check(not encounter.can_see(Vector2.ZERO, Vector2(300, 0)), "Sensor shadow blocks an otherwise in-range sighting")
	check(encounter.can_see(Vector2(-20, -280), ship.position), "A clear in-range sighting is accepted")
	step(2.2)
	check(encounter.reports.size() == 2 and encounter.delivered == 0, "Scouts queue delayed reports; no instantaneous shared knowledge")
	var observed: Vector2 = encounter.reports[0]["position"]
	ship.position = Vector2(-1300, 700)
	step(1.6)
	check(encounter.delivered == 2 and encounter.shared_position == observed, "Report delivery uses the captured sighting, not the now-hidden player")
	check(encounter.shared_position != ship.position, "No hidden-position read-through")
	step(4)
	check(encounter.agents[4].task == "GUARD / SEARCH", "Fighters stop pursuing stale shared knowledge")
	check(encounter.agents[1].task == "PATROL / SEARCH", "Scouts have patrol work with no player in sight")

	fixture()
	step(2.2)
	encounter.agents[1].take_damage(10000, &"TEST")
	await process_frame # Validate an actually freed source, not just a dead actor.
	step(1.6)
	check(encounter.delivered == 1 and encounter.prevented == 1, "Killing a scout cancels exactly its pending report")

	fixture()
	step(2.2)
	encounter.shadows.assign([Rect2(100, -1000, 160, 2000)])
	step(4)
	check(encounter.delivered == 0 and encounter.prevented >= 2, "Blocking the radio path prevents reports and eventually expires them")

	fixture()
	step(7.6)
	check(encounter.delivered >= 6 and encounter.memory.heading_bin == 0, "Only delivered repeated movement produces learned behavior")
	check(encounter.agents[4].task == "INTERCEPT / TELL", "Learned report changes the flanker into a telegraphed intercept")
	check(not encounter.decisions.is_empty(), "Tactical decisions carry inspectable evidence provenance")
	var latest: Dictionary = encounter.decisions.back()
	check(latest["knowledge"] == "report", "Out-of-sight fighter uses a shared report, not local omniscience")
	check(Vector2(latest["target"]).distance_to(encounter.shared_position) <= 180.01, "Prediction is capped at 180 world units")
	# The real base attack locks a one-second warning and does not retarget mid-charge.
	var flanker = encounter.agents[4]
	flanker.position = Vector2(-200, 120)
	flanker._state = Enemy.STATE_MOVE
	flanker._action_cooldown_ticks = 0
	encounter._think()
	flanker._physics_process(1.0 / 60)
	check(flanker.get_state() == Enemy.STATE_WINDUP and flanker._state_ticks_remaining >= 59, "Intercept uses a real one-second charge warning")
	var locked: Vector2 = flanker._locked_direction
	ship.position = Vector2(1000, 700)
	step(0.4)
	check(flanker._locked_direction == locked, "Committed attack direction does not read a new hidden position")
	step(9)
	check(encounter.memory.heading_bin == -1, "Losing observations decays adaptation in the live encounter")

	fixture()
	step(7.6)
	var captures := [0]
	encounter.extracted.connect(func(): captures[0] += 1)
	ship.position = encounter.exit_position
	step(0.2)
	check(captures[0] == 0, "Extraction is locked until the relay is destroyed")
	encounter.relay.take_damage(10000, &"TEST")
	step(0.2)
	check(captures[0] == 1 and encounter.objective_complete, "Destroy relay then reach the exit completes the objective once")
	check(encounter.reports.is_empty() and encounter.shared_at < 0 and encounter.memory.heading_bin == -1, "Relay destruction clears shared tracking and hypotheses")
	step(1)
	check(captures[0] == 1, "Completed objective never emits twice")
	encounter.free()
	ship.free()

	# Actual main integration, selector, reports, reset, and objective semantics.
	var game = load("res://src/main.tscn").instantiate()
	game._honor_command_line = false
	game._combat_lab = true
	game._lab_fixture = "substrate"
	root.add_child(game)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	for agent in game.substrate.agents:
		agent.set_physics_process(false)
	check(game._lab_live and game.hud._fixture_picker.selected == 4, "Main exposes a live selectable substrate fixture")
	game.hud.lab_report_requested.emit()
	check(paused and not game.run_ended and game.hud._end_card.data.has("substrate"), "Live inspection captures substrate telemetry without ending")
	check(game.hud._end_tab_buttons[5].visible, "Substrate has an inspectable MIND page on desktop as well as compact")
	game.hud._end_tab_buttons[5].pressed.emit()
	check(game.hud._end_card.page == 5, "MIND page is selectable by native mouse/touch/controller button")
	var before: float = game.substrate.clock
	await create_timer(0.1).timeout
	check(game.substrate.clock == before, "Paused inspection freezes the substrate")
	game.hud.toggle_pause(false)
	game.substrate.relay.take_damage(10000, &"TEST")
	game.player.position = game.substrate.exit_position
	game.substrate.tick(0.2)
	check(game.run_ended and paused and game.hud._end_card.victory, "Extraction opens the actual victory scorecard")
	check(game.hud._end_card.data["boss"] != "DEFEATED", "Extraction never fabricates a boss kill")
	game.hud._restart_button.pressed.emit()
	await process_frame
	check(not paused and not game.run_ended and game.substrate.delivered == 0 and game.substrate.memory.observations.is_empty(), "Reset creates a new session with no previous intelligence")
	game._select_fixture("cluster")
	await process_frame
	check(not is_instance_valid(game.substrate) and not game._lab_live, "Legacy lab fixtures retain their original wait-for-attack contract")
	game.synth_audio.shutdown()
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("SUBSTRATE_OK bounded agents / perception / delayed provenance / scout interruption / radio occlusion / stale evidence / adaptation / locked tell / objective / pause / reset / legacy isolation")
	quit(0 if failures.is_empty() else 1)
