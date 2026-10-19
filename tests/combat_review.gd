extends SceneTree

const Player = preload("res://src/actors/player_ship.gd")
const Weapons = preload("res://src/systems/weapon_controller.gd")
const EnemyActor = preload("res://src/actors/enemy.gd")
const ProjectileActor = preload("res://src/actors/projectile.gd")
const HUD = preload("res://src/ui/terminal_hud.gd")
var failures: Array[String] = []
var sources: Array[String] = []
var dealt := 0.0

func _initialize() -> void:
	call_deferred("run_checks")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func run_checks() -> void:
	var ship := Player.new()
	root.add_child(ship)
	ship.set_physics_process(false)
	ship.set_aim_bias(Vector2.RIGHT, true)
	var weapons := Weapons.new()
	root.add_child(weapons)
	weapons.projectile_requested.connect(func(_o: Vector2, _d: Vector2, stats: Dictionary, _t: StringName): sources.append(String(stats["source_id"])))
	var enemy := EnemyActor.new()
	enemy.configure(&"bit", Vector2(180, 0), {"health": 1000.0}, ship)
	root.add_child(enemy)
	enemy.set_physics_process(false)
	enemy.damaged.connect(func(_e: Node, amount: float, _s: StringName, _p: Vector2): dealt += amount)
	var enemies: Array[Node] = [enemy]
	weapons.tick(1.0, ship, enemies)
	check(sources.has("MASS_DRIVER"), "Automatic primary must fire without M1")
	check(dealt > 0.0, "ARC must automatically damage nearby enemy")
	weapons.attack_held = true
	weapons.tick(0.9, ship, enemies)
	check(is_equal_approx(weapons.precision_charge, 1.0), "Precision must fully charge in 0.9s")
	weapons.attack_held = false
	weapons.tick(0.01, ship, enemies)
	check(sources.has("PRECISION"), "Release must emit precision round")
	var precision_count := sources.count("PRECISION")
	weapons.attack_held = true
	weapons.tick(0.5, ship, enemies)
	ship.blocking = true
	weapons.tick(0.01, ship, enemies)
	check(sources.count("PRECISION") == precision_count, "Guard must cancel charge, not fire it")
	ship.blocking = true
	var shield_before := ship.shield
	ship.take_damage(10.0)
	check(is_equal_approx(shield_before - ship.shield, 2.0), "Guard must prevent 80 percent damage")
	ship.blocking = false
	ship.move_intent = Vector2.UP
	ship.heat = 80.0
	check(ship.try_vent(), "Vent must activate when ready")
	check(ship.heat == 0.0 and ship.boost_left > 0.0, "Vent must clear heat and activate boost")
	check(not ship.try_vent(), "Vent cooldown must prevent repeat boost")
	var nearby := EnemyActor.new()
	nearby.configure(&"bit", Vector2(190, 0), {"health": 100.0}, ship)
	root.add_child(nearby)
	nearby.set_physics_process(false)
	var round := ProjectileActor.new()
	round.configure(Vector2(180, 0), Vector2.RIGHT, {"damage": 24.0, "source_id": "MASS_DRIVER"}, &"player")
	root.add_child(round)
	weapons.set_upgrades({"FORK_ON_KILL": 1})
	enemy.health = 1.0
	var fork_targets: Array[Node] = [enemy, nearby]
	weapons.on_projectile_hit(round, enemy, enemy.global_position, fork_targets)
	check(sources.has("MASS_DRIVER_FORK"), "Lethal primary must spawn a child toward a nearby target")
	var fork_count := sources.count("MASS_DRIVER_FORK")
	round.fork_generation = 1
	weapons.on_projectile_hit(round, enemy, enemy.global_position, fork_targets)
	check(sources.count("MASS_DRIVER_FORK") == fork_count, "Children must never recurse")
	round.queue_free()
	nearby.queue_free()
	enemy.health = 3.0
	enemy.damaged.connect(func(_e: Node, amount: float, _s: StringName, _p: Vector2): check(amount <= 3.0, "Damage accounting must clamp overkill"))
	enemy.take_damage(100.0, &"TEST")
	for id in ["COURIER", "BASTION", "REDLINE", "CONDUCTOR"]:
		var starter := Player.new()
		starter.configure_chassis(id)
		check(starter.hull == starter.max_hull and starter.shield == starter.max_shield, "Starter resources must be filled")
		starter.free()
	var hud := HUD.new()
	root.add_child(hud)
	hud.show_ship_picker()
	var selected: Array[String] = []
	hud.ship_selected.connect(func(id: String): selected.append(id))
	var picker: ColorRect = hud.get("_ship_picker")
	var rows := picker.get_child(0).get_child(0)
	(rows.get_child(3) as Button).pressed.emit()
	check(selected == ["BASTION"], "Starter button must emit its own ship id")
	check(not paused, "Choosing a starter must resume gameplay")
	await process_frame
	hud.set_inspection_data({"chassis": "BASTION", "seed": "TEST", "level": 1, "mods": {}, "upgrade_cards": []})
	hud.toggle_pause(true)
	check(paused, "Escape inspection must pause simulation")
	var dashboard: TabContainer = hud.get("_pause_dashboard")
	check(dashboard.get_tab_count() == 4, "Pause must separate ship, weapons, upgrades and stats")
	hud.toggle_pause(false)
	check(not paused, "Closing inspection must resume simulation")
	hud.queue_free()
	ship.queue_free()
	weapons.queue_free()
	await process_frame
	if failures.is_empty():
		print("COMBAT_REVIEW_OK auto, arc, precision, guard, boost, cooldown, actual_damage, forks, ships, pause")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(2)
