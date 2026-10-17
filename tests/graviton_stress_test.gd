extends SceneTree


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = load("res://src/main.tscn").instantiate()
	game._combat_lab = true
	game._using_touch = true
	root.add_child(game)
	for enemy in get_nodes_in_group("enemy_normal"):
		enemy.queue_free()
	await process_frame
	game.player.shield = 100000
	game.player.max_shield = 100000
	game._touch_aim_active = true
	game._touch_aim = Vector2.RIGHT
	game._lab_live = true
	for index in range(180):
		var enemy := Enemy.new()
		var position := Vector2.RIGHT.rotated(float(index) * TAU / 180) * (240 + index % 4 * 45)
		enemy.configure([&"bit", &"vector", &"sentry"][index % 3], position, {"health": 10000, "speed": 65}, game.player)
		game.world_root.add_child(enemy)
		enemy.add_to_group("enemy_normal")
		enemy.damaged.connect(game._record_enemy_damage)
		enemy.died.connect(game._on_enemy_died)
		enemy.contact_hit.connect(game._on_enemy_contact)
		enemy.shot_requested.connect(game._on_enemy_shot_requested)
	game._spawn_boss()
	game.boss.health = 100000
	game.boss.max_health = 100000
	game.boss.phase = 3
	var max_missiles := 0
	var max_fields := 0
	var max_pulled := 0
	var peak_physics_ms := 0.0
	var samples: Array[float] = []
	var peak_frame := 0
	for frame in range(330):
		if frame in [0, 180]:
			game._begin_unleash()
		if frame in [56, 236]:
			game._release_unleash()
		await physics_frame
		max_missiles = maxi(max_missiles, get_nodes_in_group("swarm_missiles").size())
		max_fields = maxi(max_fields, get_nodes_in_group("graviton_fields").size())
		if is_instance_valid(game.graviton.field):
			max_pulled = maxi(max_pulled, game.graviton.field.contacts.size())
		var milliseconds: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000
		if milliseconds > peak_physics_ms:
			peak_physics_ms = milliseconds
			peak_frame = frame
		if frame > 30:
			samples.append(milliseconds)
	var sum := 0.0
	for source in game.source_stats.values():
		sum += float(source["damage"])
	var okay: bool = not game.run_ended and max_missiles > 0 and max_missiles <= 6 and max_fields <= 1 and max_pulled <= 12 and absf(sum - game.damage_dealt) < 0.01 and get_nodes_in_group("enemy_normal").size() == 180
	samples.sort()
	print("GRAVITON_STRESS_%s normals=180 boss=true missiles_peak=%d fields_peak=%d pulled_peak=%d damage=%.2f physics_peak_ms=%.2f peak_frame=%d warm_median_ms=%.2f warm_p95_ms=%.2f (simulation only, not a rendered/mobile FPS claim)" % ["OK" if okay else "FAIL", max_missiles, max_fields, max_pulled, game.damage_dealt, peak_physics_ms, peak_frame, samples[samples.size() / 2], samples[floori(samples.size() * 0.95)]])
	game.synth_audio.shutdown()
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	quit(0 if okay else 1)
