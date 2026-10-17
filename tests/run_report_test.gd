extends SceneTree

var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		push_error(message)


func _run() -> void:
	var game = load("res://src/main.tscn").instantiate()
	game._combo_mode = false
	root.add_child(game)
	game.set_physics_process(false)
	game.player.set_physics_process(false)
	# Immediate deaths must yield finite rates and baseline ship stats.
	var empty_report: String = game.hud._format_stats(game._build_run_report(false))
	check(not empty_report.contains("nan") and not empty_report.contains("inf"), "Zero-duration report must be finite")
	check(empty_report.contains("BASELINE"), "Empty build must be explicit")
	game.elapsed_time = 10.0
	for source in [&"MASS_DRIVER", &"ARC_EXE", &"VENT", &"MASS_DRIVER_FORK", &"MASS_DRIVER_RETURN"]:
		var enemy := Enemy.new()
		enemy.configure(&"bit", Vector2(1000, 500), {"health": 10.0, "simulation_enabled": false})
		game.world_root.add_child(enemy)
		enemy.damaged.connect(game._record_enemy_damage)
		enemy.died.connect(game._on_enemy_died)
		game._record_attack(source)
		enemy.take_damage(100.0, source)
		check(is_equal_approx(float(game.source_stats[String(source)]["damage"]), 10.0), "Overkill excluded for %s" % source)
		check(game.source_stats[String(source)]["kills"] == 1, "Kill attribution for %s" % source)
	check(is_equal_approx(game.damage_dealt, 50.0), "All damage sources contribute exactly once")
	game.player.take_damage(40.0)
	game.player.take_damage(40.0) # Invulnerability must reject this hit.
	check(game.player.run_stats["hits_taken"] == 1, "Only accepted player hits count")
	check(game.player.run_stats["shield_absorbed"] == 30.0, "Shield damage attributed separately")
	check(game.player.run_stats["hull_damage"] == 10.0, "Hull damage excludes shield")
	game.player.heal_hull(100.0)
	check(game.player.run_stats["hull_repaired"] == 10.0, "Repairs exclude excess healing")
	game.player.add_heat(90.0)
	game.player.try_vent()
	game.player.try_vent() # Cooldown must reject this vent.
	check(game.player.run_stats["vents"] == 1 and game.player.run_stats["hot_vents"] == 1, "Only successful high-heat vent counted")
	check(game.player.run_stats["heat_vented"] == 90.0, "Vented heat recorded before reset")
	game._smoke_test = true # Collect XP without opening the picker.
	game._on_xp_collected(null, 7, game.player)
	check(game.total_xp_collected == 7 and game.pickups_collected == 1, "Collected XP retained independently of level progress")
	game.upgrades = {"FORK_ON_KILL": 2, "ARC_FANOUT": 1}
	game._spawn_boss()
	game.boss.set_physics_process(false)
	game.boss.health = 12.0
	game.boss.take_damage(100.0, "ARC_EXE")
	check(game.run_ended and paused, "Final boss hit opens paused report")
	check(game.damage_dealt == 62.0, "Boss killing damage included before snapshot")
	check(game.source_stats["ARC_EXE"]["kills"] == 2, "Boss kill attributed before snapshot")
	check(game.kills == 6 and game.kills_by_type["boss"] == 1, "Kill totals reconcile")
	var report: String = game.hud._format_stats(game.hud._end_report)
	for required in ["DAMAGE DEALT  ::  62.0", "AVERAGE DPS  ::  6.2", "HULL DAMAGE / SHIELD ABSORBED", "REACTOR / VENT", "MASS_DRIVER_FORK", "MASS_DRIVER_RETURN", "ARC.EXE", "INSTALLED PATCHES", "FORK_ON_KILL.R2", "TRANSMISSION COMPLETE"]:
		check(report.contains(required), "Report contains %s" % required)
	var card_data: Dictionary = game.hud._end_card.data
	check(card_data["damage"] == 62.0 and card_data["dps"] == 6.2, "Scorecard uses actual final-hit damage")
	check(card_data["sources"]["ARC_EXE"]["damage"] == 22.0, "Weapon graph uses exact source damage")
	check(card_data["patches"].size() == 2, "Every installed patch has a scorecard tile")
	game.source_stats["ARC_EXE"]["damage"] = 999.0
	check(card_data["sources"]["ARC_EXE"]["damage"] == 22.0, "Scorecard is a frozen snapshot")
	game.source_stats["ARC_EXE"]["damage"] = 22.0
	check(game.hud._end_panel.find_children("*", "ScrollContainer", true, false).is_empty(), "Scorecard never creates a scroller")
	# All desktop content is on one sheet. Small viewports use fixed pages.
	for dimensions in [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(640, 360), Vector2i(360, 640)]:
		root.content_scale_size = Vector2i.ZERO
		root.size = dimensions
		game.hud._layout_end_screen()
		for frame in range(4):
			await process_frame
		var bounds: Rect2 = game.hud._end_panel.get_global_rect()
		check(bounds.position.x >= -1 and bounds.end.x <= dimensions.x + 1, "Report fits %s" % dimensions)
		check(bounds.position.y >= -1 and bounds.end.y <= dimensions.y + 1, "Report fits vertically at %s" % dimensions)
		check(game.hud._restart_button.get_global_rect().end.y <= dimensions.y + 1, "Restart stays visible at %s" % dimensions)
		check(game.hud._end_tabs.visible == (dimensions.x < 940), "Only small screens need fixed pages at %s" % dimensions)
		check(game.hud._end_card.get_global_rect().end.y <= game.hud._restart_button.global_position.y, "Scorecard cannot overlap restart at %s" % dimensions)
		if game.hud._end_tabs.visible:
			for index in range(4):
				game.hud._end_tab_buttons[index].pressed.emit()
				check(game.hud._end_card.page == index, "Compact tab selects page %d" % index)
			var key := InputEventKey.new()
			key.keycode = KEY_2
			key.pressed = true
			game.hud._unhandled_input(key)
			check(game.hud._end_card.page == 1, "Compact keyboard selects arsenal")
	# Mouse/touch/controller all activate this native button; R is an alias.
	game.hud.restart_requested.disconnect(game._restart_run)
	var restarted := [false]
	game.hud.restart_requested.connect(func(): restarted[0] = true)
	game.hud._restart_button.pressed.emit()
	check(restarted[0] and not paused and not game.hud._end_overlay.visible, "Restart button closes the scorecard and restores gameplay state")
	game.synth_audio.shutdown()
	paused = false
	game.queue_free()
	await process_frame
	await create_timer(0.1).timeout
	if failures.is_empty():
		print("RUN_REPORT_OK exact damage / attribution / defenses / heat / XP / final hit / visual scorecard / no scrolling")
	quit(0 if failures.is_empty() else 1)
