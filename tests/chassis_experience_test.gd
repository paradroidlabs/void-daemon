extends SceneTree

var failures: Array[String] = []
var game: Node2D


func _initialize() -> void:
	call_deferred("run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func fixture(id: String) -> void:
	if is_instance_valid(game):
		game.synth_audio.shutdown()
		game.queue_free()
		await process_frame
	game = load("res://src/main.tscn").instantiate()
	game._combat_lab = true
	game._chassis = id
	game._lab_loadout = "salvo"
	root.add_child(game)
	game.synth_audio.enabled = false
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.set_aim_bias(Vector2.RIGHT, true)
	game.weapon_controller.enabled = false
	var index := 0
	for enemy in get_nodes_in_group("enemy_normal"):
		enemy.set_physics_process(false)
		enemy.health = 10000
		enemy.max_health = 10000
		enemy.position = Vector2(140 + index * 6, 0)
		index += 1
	await physics_frame


func tick(seconds: float, hz: int = 60, cool: bool = false) -> void:
	for frame in range(roundi(seconds * hz)):
		if cool:
			game.player.heat = maxf(0, game.player.heat - game.player.heat_cooling_per_second / hz)
		game.elapsed_time += 1.0 / hz
		game.graviton.tick(1.0 / hz, get_nodes_in_group("enemies"))


func run() -> void:
	root.size = Vector2i(1280, 720)
	root.get_node("Experience").persist = false
	for id in ["bastion", "redline"]:
		var reference := 0.0
		for hz in [30, 60, 120]:
			await fixture(id)
			check(game.player.chassis_id == id and not game.weapon_controller.enabled, "Manual-only diagnostic has correct chassis and no hidden autos")
			check(game.graviton.begin_charge(), "Channel begins")
			tick(2, hz)
			var dealt: float = game.damage_dealt
			if reference == 0:
				reference = dealt
			check(absf(reference - dealt) < 0.1, "Fixed damage cadence does not gain DPS with framerate: " + id)
			check(game.graviton.run_stats["hits"] == game.source_stats["SIEGE_LANCE" if id == "bastion" else "CORONA_DRIVE"]["hits"], "Kit and actual damage ledger agree")
			var damage_before: float = game.damage_dealt
			check(game.graviton.release_charge(), "Releasing ends sustained fire")
			tick(0.6, hz)
			check(game.damage_dealt == damage_before, "Channel cannot damage after release")
			check(not game.graviton.release_charge(), "Duplicate release is inert")
		print("CHASSIS_CADENCE %s two_seconds_damage=%.2f" % [id, reference])
		await fixture(id)
		game.graviton.begin_charge()
		tick(20, 60, true)
		check(game.player.heat <= 100, "Long holds never exceed heat cap")
		if id == "redline":
			check(not game.graviton.is_charging and game.graviton.run_stats["overheat_stops"] == 1, "Redline must manage its real reactor budget")
		else:
			check(game.graviton.is_charging, "Bastion can sustain its base beam before automatic weapon heat")
		game.hud.toggle_pause(true)
		check(not game.graviton.is_charging, "Pause cancels sustained damage rather than firing on resume")
		game.hud.toggle_pause(false)
		check(game.graviton.run_stats["hits"] <= game.graviton.run_stats["damage_ticks"] * (3 if id == "bastion" else 6), "Per-tick target cap is bounded")

	await fixture("scrapper")
	check(game.graviton.begin_charge(), "Scrapper clamp begins")
	tick(1.2)
	check(is_instance_valid(game.graviton.field) and game.graviton.field.affected_ids.size() <= 12, "Scrapper has a real bounded gathering field")
	var before: float = game.damage_dealt
	check(game.graviton.release_charge(), "Release collapses Scrapper field")
	check(game.damage_dealt > before and game.source_stats["GRAVITY_COLLAPSE"]["hits"] == 12, "Collapse damages at most twelve actual contacts")
	check(is_equal_approx(game.graviton.run_stats["heat_spent"], 35.6), "Clamp startup, holding and collapse heat are charged once")
	game.player.set_move_intent(Vector2.LEFT)
	game._try_vent()
	await process_frame
	var decoy: Node2D
	for child in game.world_root.get_children():
		if child is TowDecoy:
			decoy = child
	check(is_instance_valid(decoy), "Tow Step leaves its own real decoy")
	if is_instance_valid(decoy):
		var captured: Array[Node2D] = decoy._captured.duplicate()
		check(captured.size() <= 12 and not captured.is_empty(), "Tow Step captures a bounded set of nearby normal enemies")
		decoy.queue_free()
		await process_frame
		for enemy in captured:
			check(enemy._target == game.player, "Decoy lifetime restores actual enemy targets")

	await fixture("redline")
	game.player.position = Vector2(300, 0)
	game.player._history_clock = 1.6
	game.player._position_history.assign([{"time": 0.0, "position": Vector2.ZERO}, {"time": 0.4, "position": Vector2(80, 0)}, {"time": 1.5, "position": Vector2(280, 0)}])
	game.player.heat = 77
	game.player.hull = 33
	game.player.velocity = Vector2(130, 20)
	game._try_vent()
	check(game.player.position.x < 100 and game.player.phase_uses == 1, "Backtrace recalls a recent recorded position")
	check(game.player.heat == 77 and game.player.hull == 33 and game.player.velocity == Vector2(130, 20), "Backtrace never restores heat, health or velocity")
	check(game.player.phase_cooldown == 6.5, "Backtrace has its own shared-alias cooldown")
	game._reset_lab()
	check(game.player._position_history.is_empty(), "Fixture reset cannot recall history from a previous encounter")
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	game.player.velocity = Vector2(160, 0)
	game.player.rotation = PI
	game.hive._cooldown = 0
	game.hive.observe(0.3)
	check(game.hive.history.back()["event"] == "cross_drift", "Hive narration is selected by real heading versus travel")
	check(not game.hive.transmit("cross_drift", "duplicate", true), "Hive does not repeat a triggered observation")
	game.hive._cooldown = 0
	game.player.heat = 90
	game.hive.observe(0.3)
	check(game.hive.history.back()["event"] == "reactor", "Reactor event comes from actual heat")
	check(game.hive._pane.mouse_filter == Control.MOUSE_FILTER_IGNORE, "PiP cannot steal gameplay input")
	game._end_run(false)
	check(not game.hive._pane.visible, "Hive windows stay off the final scorecard")
	check(game.hud._end_card.data["combo"]["maneuver_cooldown"] == 6.5, "Scorecard records the selected chassis cooldown")
	game.synth_audio.shutdown()
	game.queue_free()
	await process_frame
	game = null
	for id in ["bastion", "redline", "scrapper"]:
		await fixture(id)
		for enemy in get_nodes_in_group("enemy_normal"):
			enemy.queue_free()
		await process_frame
		game._spawn_boss()
		game.boss.set_physics_process(false)
		game.boss.position = Vector2(160, 0)
		game.boss.health = 10
		game.graviton.begin_charge()
		tick(0.6)
		if id == "scrapper":
			game.graviton.release_charge()
		check(game.run_ended and game.damage_dealt == 10, "Killing hit ends run with no overkill: " + id)
		check(game.hud._end_card.data["combo"]["hits"] == 1, "Final kit contact is captured before synchronous boss death: " + id)
		check(not game.graviton.enabled and not game.graviton.is_charging, "Boss death retires ongoing manual damage")
		game.synth_audio.shutdown()
		game.queue_free()
		await process_frame
		game = null

	var boot = load("res://src/boot.tscn").instantiate()
	root.add_child(boot)
	check(is_instance_valid(boot.menu) and not is_instance_valid(boot.game), "Normal boot opens the hangar, not live combat")
	for id in ChassisCatalog.ORDER:
		boot.select_ship(id)
		check(boot._preview.chassis_id == id and boot._stats.text.contains(ChassisCatalog.get_ship(id)["maneuver"]), "Hangar schematic and controls match selected chassis")
	boot.launch_run(true, "bastion")
	await process_frame
	check(boot.game.player.chassis_id == "bastion" and boot.game._combat_lab, "Menu launches selected chassis into actual lab")
	boot.game.hud.toggle_pause(true)
	boot.game._return_to_menu()
	await process_frame
	await process_frame
	check(not paused and is_instance_valid(boot.menu), "Hangar return unwinds pause and gameplay")
	boot.launch_run(false, "scrapper")
	await process_frame
	check(not boot.game._combat_lab and boot.game._chassis == "scrapper", "A new deployment does not inherit the previous lab mode")
	boot.launch_run(false, "graviton", true)
	await process_frame
	boot.game._restart_run()
	await process_frame
	await process_frame
	check(not boot.game._combo_mode, "Classic comparison rules survive their own restart")
	boot.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("CHASSIS_EXPERIENCE_OK four kits / fixed cadence / heat / cancellation / decoy cleanup / position-only rewind / hive evidence / boot / menu return")
	quit(0 if failures.is_empty() else 1)
