extends SceneTree

var failures: Array[String] = []
var game: Node2D


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func reset_fixture(loadout: String = "gravity") -> void:
	game._lab_loadout = loadout
	game._reset_lab()
	await process_frame
	await process_frame
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.set_move_intent(Vector2.ZERO)
	game.player.set_aim_bias(Vector2.RIGHT, true)
	game.weapon_controller.enabled = false
	for enemy in get_nodes_in_group("enemy_normal"):
		enemy.set_physics_process(false)
		enemy.simulation_enabled = true


func spread() -> float:
	var enemies := get_nodes_in_group("enemy_normal")
	var total := 0.0
	var count := 0
	for i in enemies.size():
		for j in range(i + 1, enemies.size()):
			total += enemies[i].global_position.distance_to(enemies[j].global_position)
			count += 1
	return total / maxf(count, 1)


func tick(frames: int) -> void:
	for frame in frames:
		game.elapsed_time += 1.0 / 60
		game.graviton.tick(1.0 / 60, get_nodes_in_group("enemies"))
		for enemy in get_nodes_in_group("enemy_normal"):
			enemy._physics_process(1.0 / 60)
		for missile in get_nodes_in_group("swarm_missiles"):
			missile.set_physics_process(false)


func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = load("res://src/main.tscn").instantiate()
	game._combat_lab = true
	root.add_child(game)
	game.synth_audio.enabled = false
	await reset_fixture("salvo")
	var before := spread()
	check(game.graviton.begin_charge(), "Salvo-only charge begins")
	tick(48)
	var without_gravity := spread()
	check(get_nodes_in_group("graviton_fields").is_empty(), "Salvo-only mode has no hidden gravity")
	await reset_fixture()
	check(game.graviton.begin_charge(), "Graviton is the offensive hold")
	check(is_instance_valid(game.graviton.field), "Holding begins an actual external gravity field")
	tick(48)
	check(game.graviton.loaded_count == 6, "Holding loads a six-missile rack")
	var with_gravity := spread()
	check(with_gravity < without_gravity * 0.55, "Gravity materially compresses the same moving formation")
	check(game.graviton.field.affected_ids.size() == 12, "Field captures at most its twelve-contact budget")
	check(game.graviton.release_charge(), "Release commits a charged salvo")
	var committed_heat: float = game.player.heat
	check(not game.graviton.release_charge() and game.player.heat == committed_heat, "Repeated release cannot duplicate payload or heat")
	tick(30)
	check(game.graviton.run_stats["missiles"] == 6, "Committed rack launches six actual missiles")
	check(game.source_stats["GRAVITON_SALVO"]["attacks"] == 6, "Every launch is attributed once")
	# Geometry is causally tested independently of any damage multiplier.
	print("GRAVITY_GEOMETRY before=%.2f without=%.2f compressed=%.2f" % [before, without_gravity, with_gravity])

	await reset_fixture()
	var target := Enemy.new()
	target.configure(&"bit", Vector2(1200, 600), {"health": 100, "simulation_enabled": false})
	game.world_root.add_child(target)
	target.damaged.connect(game._record_enemy_damage)
	var neighbor := Enemy.new()
	neighbor.configure(&"bit", Vector2(1240, 600), {"health": 100, "simulation_enabled": false})
	game.world_root.add_child(neighbor)
	neighbor.damaged.connect(game._record_enemy_damage)
	var missile := SwarmMissile.new()
	missile.configure(Vector2(1150, 600), Vector2.RIGHT, target.global_position, target)
	game.world_root.add_child(missile)
	missile.set_physics_process(false)
	missile.detonate(target.global_position, target)
	check(target.health == 76.0, "Direct hit applies one payload, not payload plus duplicate splash")
	check(neighbor.health < 100.0 and neighbor.health > 76.0, "Neighbor receives falloff splash")
	var damage: float = game.damage_dealt
	missile.detonate(target.global_position, target)
	check(game.damage_dealt == damage, "A spent missile cannot detonate twice")
	check(game.source_stats["GRAVITON_SALVO"]["hits"] == 2, "Both actual receivers enter the source ledger")

	await reset_fixture()
	game.player.heat = 80
	check(game.graviton.begin_charge(), "A hot reactor can begin a limited rack")
	tick(48)
	game.graviton.release_charge()
	tick(30)
	check(game.graviton.run_stats["missiles"] == 3 and game.player.heat == 100, "Only affordable missiles commit; launch does not charge heat twice")
	check(game.graviton.run_stats["heat_spent"] == 20, "Gravity startup and salvo costs are explicit")
	await reset_fixture()
	game.graviton.begin_charge()
	tick(12)
	var cost: float = game.player.heat
	game._try_vent()
	check(game.player.phase_uses == 1 and not game.graviton.is_charging, "Escape cancels the uncommitted offensive hold")
	check(not is_instance_valid(game.graviton.field), "Escape itself does not create a gravity field")
	check(not game.graviton.release_charge() and game.player.heat == cost, "Defensive cancellation neither fires nor refunds heat")
	var space := InputEventKey.new()
	space.physical_keycode = KEY_SPACE
	space.pressed = true
	game._unhandled_input(space)
	check(game.player.phase_uses == 1, "Space/Shift aliases share one cooldown")
	game.player.phase_cooldown = 0
	game.player.heat = 100
	game._try_vent()
	check(game.player.phase_uses == 2, "Escape remains available at maximum heat")
	game.player.phase_cooldown = 0
	game.player.global_position = game.ARENA_BOUNDS.end - Vector2(28, 28)
	game._try_vent()
	check(game.ARENA_BOUNDS.has_point(game.player.global_position), "Phase endpoint stays inside the arena")

	await reset_fixture()
	game.graviton.begin_charge()
	game.hud.toggle_pause(true)
	check(paused and not game.graviton.is_charging, "Pause cancels the charge and its sound state")
	game.hud.toggle_pause(false)
	check(not game.graviton.release_charge(), "Resume cannot release a stale charge")
	game.graviton.reload_left = 0
	game.graviton.begin_charge()
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(not game.graviton.is_charging and not game.graviton.release_charge(), "Focus loss clears attack intent")

	await reset_fixture()
	game.hud.set_touch_controls_visible(true)
	var touch := InputEventScreenTouch.new()
	touch.index = 7
	touch.position = Vector2(80, 60)
	touch.pressed = true
	game.hud._on_target_gui_input(touch)
	check(game.graviton.is_charging, "Touch action pad begins the same offensive hold")
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = game.hud._vent_button.get_global_rect().get_center() - game.hud._target_zone.global_position
	game.hud._on_target_gui_input(drag)
	touch.pressed = false
	game.hud._on_target_gui_input(touch)
	check(game.player.phase_uses == 1 and game.graviton.run_stats["salvos"] == 0, "Slide to escape cancels before release, with no accidental salvo")
	game.hud.set_touch_controls_visible(false)

	await reset_fixture("chain")
	for level_index in range(2, 30):
		for choice in game._get_upgrade_offer(level_index):
			check(choice["id"] not in ["VENT_AMPLIFIER", "VENT_COOLANT", "GROUND_LOOP"], "Combo mode excludes inactive VENT mechanics")
	var snapshot: Dictionary = game._build_run_report(false)
	check(snapshot["scorecard"]["combo"].has("phase_uses"), "Full scorecard includes kit and maneuver telemetry")
	game.hud.show_end_screen(false, snapshot)
	check(game.hud._end_panel.find_children("*", "ScrollContainer", true, false).is_empty(), "Combo scorecard stays scroll-free")
	game.hud._end_overlay.visible = false
	game.hud._end_modal()
	game.synth_audio.shutdown()
	paused = false
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("GRAVITON_COMBO_OK geometry / rack / splash / attribution / heat / cancel / phase / touch / offers / scorecard")
	quit(0 if failures.is_empty() else 1)
