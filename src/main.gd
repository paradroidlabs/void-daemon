extends Node2D

const PlayerShipScript := preload("res://src/actors/player_ship.gd")
const EnemyScript := preload("res://src/actors/enemy.gd")
const ProjectileScript := preload("res://src/actors/projectile.gd")
const XpOrbScript := preload("res://src/actors/xp_orb.gd")
const WatchdogBossScript := preload("res://src/actors/watchdog_boss.gd")
const WeaponControllerScript := preload("res://src/systems/weapon_controller.gd")
const UpgradeCatalogScript := preload("res://src/systems/upgrade_catalog.gd")
const TerminalHUDScript := preload("res://src/ui/terminal_hud.gd")
const ArenaBackdropScript := preload("res://src/world/arena_backdrop.gd")
const SynthAudioScript := preload("res://src/audio/synth_audio.gd")

const CYAN := Color("68f7e5")
const GREEN := Color("73ff9f")
const AMBER := Color("ffbd4a")
const RED := Color("ff496c")
const MAGENTA := Color("ff4fd8")

const ARENA_BOUNDS := Rect2(-1600.0, -900.0, 3200.0, 1800.0)
const BOSS_SPAWN_TIME := 300.0
const MAX_NORMAL_ENEMIES := 180
const END_SCREEN_CAPTURE_SEED := "END-SCREEN-REGRESSION-001"
const END_SCREEN_CAPTURE_PATH := "res://artifacts/end_screen_capture.png"
const END_SCREEN_CAPTURE_SETTLE_SECONDS := 0.75

var player: PlayerShip
var camera: Camera2D
var weapon_controller: WeaponController
var hud: TerminalHUD
var world_root: Node2D
var backdrop: ArenaBackdrop
var boss: WatchdogBoss
var synth_audio: SynthAudio

var run_seed_text := "VOID-0001"
var run_seed: int = 1
var elapsed_time: float = 0.0
var spawn_timer: float = 0.35
var spawn_index: int = 0
var kills: int = 0
var damage_dealt: float = 0.0
var level: int = 1
var xp: int = 0
var xp_needed: int = 7
var pending_levels: int = 0
var upgrades: Dictionary = {}
var current_offer: Array[Dictionary] = []
var run_ended: bool = false
var boss_spawned: bool = false

var _touch_move := Vector2.ZERO
var _touch_aim := Vector2.RIGHT
var _touch_aim_active := false
var _using_touch := false
var _hud_timer := 0.0
var _smoke_test := false
var _smoke_timer := 0.0
var _capture_test := false
var _capture_done := false
var _capture_end_screen := false
var _smoke_finishing := false
var _camera_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_parse_command_line()
	run_seed = UpgradeCatalogScript.stable_hash(run_seed_text)
	_build_world()
	_connect_runtime()
	_update_hud(true)
	hud.flash_log("BOOT COMPLETE // MOVE: WASD OR TOUCH // VENT: SPACE", CYAN)
	if _capture_end_screen:
		_start_end_screen_capture()
	elif _smoke_test:
		_start_smoke_test()


func _build_world() -> void:
	backdrop = ArenaBackdropScript.new()
	backdrop.name = "ArenaBackdrop"
	backdrop.z_index = -100
	backdrop.configure(ARENA_BOUNDS, run_seed)
	add_child(backdrop)

	world_root = Node2D.new()
	world_root.name = "RuntimeWorld"
	add_child(world_root)

	player = PlayerShipScript.new()
	player.name = "Courier"
	player.global_position = Vector2.ZERO
	player.arena_bounds = ARENA_BOUNDS
	world_root.add_child(player)

	camera = Camera2D.new()
	camera.name = "FollowCamera"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = int(ARENA_BOUNDS.position.x)
	camera.limit_top = int(ARENA_BOUNDS.position.y)
	camera.limit_right = int(ARENA_BOUNDS.end.x)
	camera.limit_bottom = int(ARENA_BOUNDS.end.y)
	camera.enabled = true
	player.add_child(camera)

	weapon_controller = WeaponControllerScript.new()
	weapon_controller.name = "WeaponController"
	weapon_controller.set_upgrades(upgrades)
	add_child(weapon_controller)

	synth_audio = SynthAudioScript.new()
	synth_audio.name = "SynthAudio"
	add_child(synth_audio)

	hud = TerminalHUDScript.new()
	hud.name = "TerminalHUD"
	add_child(hud)
	if _using_touch or OS.has_feature("mobile") or OS.get_cmdline_user_args().has("--touch-ui"):
		hud.set_touch_controls_visible(true)


func _connect_runtime() -> void:
	player.vented.connect(_on_player_vented)
	player.damaged.connect(_on_player_damaged)
	player.died.connect(_on_player_died)
	weapon_controller.projectile_requested.connect(_spawn_projectile)
	weapon_controller.arc_fired.connect(_show_arc)
	weapon_controller.heat_generated.connect(player.add_heat)
	weapon_controller.vent_pulse_requested.connect(_apply_vent_pulse)
	weapon_controller.combat_log.connect(hud.flash_log)
	weapon_controller.sfx_requested.connect(synth_audio.play_cue)
	hud.upgrade_selected.connect(_on_upgrade_selected)
	hud.restart_requested.connect(_restart_run)
	hud.touch_move_changed.connect(_on_touch_move)
	hud.touch_vent_pressed.connect(_try_vent)
	hud.touch_target_bias.connect(_on_touch_target_bias)


func _physics_process(delta: float) -> void:
	if run_ended:
		return
	_update_input_intents()
	elapsed_time += delta
	spawn_timer -= delta
	if not boss_spawned and elapsed_time >= BOSS_SPAWN_TIME:
		_spawn_boss()
	if spawn_timer <= 0.0:
		_spawn_wave_tick()
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	weapon_controller.tick(delta, player, enemies)
	if is_instance_valid(boss) and player.global_position.distance_to(boss.global_position) < boss.collision_radius + 15.0:
		player.take_damage(boss.contact_damage, boss.global_position)

	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.10
		_update_hud()
	if _smoke_test:
		_tick_smoke_test(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE:
				_try_vent()
			KEY_T:
				_using_touch = not _using_touch
				hud.set_touch_controls_visible(_using_touch)
				hud.flash_log("TOUCH LAYER %s" % ("ONLINE" if _using_touch else "OFFLINE"), AMBER)
			KEY_F10:
				if not boss_spawned:
					elapsed_time = BOSS_SPAWN_TIME - 0.1
					hud.flash_log("DEBUG // FAST-FORWARD TO WATCHDOG", MAGENTA)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_try_vent()
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A or event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_try_vent()


func _update_input_intents() -> void:
	var keyboard := Vector2(
		float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),
		float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	).limit_length()
	var controller := Vector2.ZERO
	var joypads := Input.get_connected_joypads()
	if not joypads.is_empty():
		var device: int = joypads[0]
		controller = Vector2(
			Input.get_joy_axis(device, JOY_AXIS_LEFT_X),
			Input.get_joy_axis(device, JOY_AXIS_LEFT_Y)
		)
		if controller.length() < 0.20:
			controller = Vector2.ZERO
		else:
			controller = controller.limit_length()
	var movement := keyboard if keyboard.length_squared() > 0.0 else controller
	if movement.length_squared() <= 0.0:
		movement = _touch_move
	player.set_move_intent(movement)

	var aim_direction := Vector2.RIGHT
	var aim_active := false
	if not joypads.is_empty():
		var device: int = joypads[0]
		var right_stick := Vector2(
			Input.get_joy_axis(device, JOY_AXIS_RIGHT_X),
			Input.get_joy_axis(device, JOY_AXIS_RIGHT_Y)
		)
		if right_stick.length() >= 0.25:
			aim_direction = right_stick.normalized()
			aim_active = true
	if _touch_aim_active:
		aim_direction = _touch_aim
		aim_active = true
	elif not _using_touch and not OS.has_feature("mobile") and not aim_active:
		var mouse_offset := get_global_mouse_position() - player.global_position
		if mouse_offset.length() > 52.0:
			aim_direction = mouse_offset.normalized()
			aim_active = true
	player.set_aim_bias(aim_direction, aim_active)


func _spawn_wave_tick() -> void:
	var normal_count := get_tree().get_nodes_in_group("enemy_normal").size()
	var progress := clampf(elapsed_time / BOSS_SPAWN_TIME, 0.0, 1.0)
	var interval := lerpf(0.52, 0.12, progress)
	spawn_timer = interval * (2.2 if boss_spawned else 1.0)
	if normal_count >= MAX_NORMAL_ENEMIES:
		return
	var batch := 1 + int(elapsed_time / 125.0)
	if boss_spawned:
		batch = 1
	for index in range(batch):
		if normal_count + index >= MAX_NORMAL_ENEMIES:
			break
		_spawn_enemy()


func _spawn_enemy() -> void:
	var roll := _seed_roll("spawn_type", spawn_index)
	var enemy_type: StringName = &"bit"
	if elapsed_time >= 70.0 and roll % 100 < 26:
		enemy_type = &"vector"
	if elapsed_time >= 145.0 and roll % 100 >= 78:
		enemy_type = &"sentry"
	var angle_roll := _seed_roll("spawn_angle", spawn_index)
	var radius_roll := _seed_roll("spawn_radius", spawn_index)
	var angle := TAU * float(angle_roll & 0xffff) / 65535.0
	var radius := 520.0 + float(radius_roll & 0xff) / 255.0 * 180.0
	var position := player.global_position + Vector2.RIGHT.rotated(angle) * radius
	position = Vector2(
		clampf(position.x, ARENA_BOUNDS.position.x + 36.0, ARENA_BOUNDS.end.x - 36.0),
		clampf(position.y, ARENA_BOUNDS.position.y + 36.0, ARENA_BOUNDS.end.y - 36.0)
	)
	if position.distance_to(player.global_position) < 390.0:
		position = player.global_position - Vector2.RIGHT.rotated(angle) * 430.0
		position = Vector2(
			clampf(position.x, ARENA_BOUNDS.position.x + 36.0, ARENA_BOUNDS.end.x - 36.0),
			clampf(position.y, ARENA_BOUNDS.position.y + 36.0, ARENA_BOUNDS.end.y - 36.0)
		)
	var progress := clampf(elapsed_time / BOSS_SPAWN_TIME, 0.0, 1.0)
	var base_health := 16.0 if enemy_type == &"bit" else (31.0 if enemy_type == &"vector" else 38.0)
	var base_speed := 76.0 if enemy_type == &"bit" else (91.0 if enemy_type == &"vector" else 62.0)
	var enemy: Enemy = EnemyScript.new()
	enemy.configure(enemy_type, position, {
		"health": base_health * lerpf(1.0, 2.15, progress),
		"damage": (7.0 if enemy_type == &"bit" else 11.0) * lerpf(1.0, 1.35, progress),
		"speed": base_speed * lerpf(1.0, 1.18, progress),
		"xp": 1 if enemy_type == &"bit" else 2,
		"initial_action_delay": 0.45 + float(roll % 30) * 0.01,
	}, player)
	world_root.add_child(enemy)
	enemy.add_to_group("enemy_normal")
	enemy.died.connect(_on_enemy_died)
	enemy.contact_hit.connect(_on_enemy_contact)
	enemy.shot_requested.connect(_on_enemy_shot_requested)
	spawn_index += 1


func _spawn_projectile(origin: Vector2, direction: Vector2, stats: Dictionary, team: StringName = &"player") -> Projectile:
	var projectile: Projectile = ProjectileScript.new()
	projectile.configure(origin, direction, stats, team)
	projectile.projectile_hit.connect(_on_projectile_hit)
	projectile.expired.connect(_on_projectile_expired)
	world_root.call_deferred("add_child", projectile)
	return projectile


func _on_enemy_shot_requested(_enemy: Area2D, origin: Vector2, direction: Vector2, stats: Dictionary) -> void:
	var shot_stats := stats.duplicate(true)
	shot_stats["source_id"] = "SENTRY"
	shot_stats["color"] = RED
	_spawn_projectile(origin, direction, shot_stats, &"enemy")


func _on_boss_shot_requested(origin: Vector2, direction: Vector2, stats: Dictionary) -> void:
	_spawn_projectile(origin, direction, stats, &"enemy")


func _on_projectile_hit(projectile: Area2D, target: Node, damage: float, hit_position: Vector2) -> void:
	if projectile is Projectile and projectile.team == &"player":
		damage_dealt += damage
		weapon_controller.on_projectile_hit(projectile, target, hit_position, get_tree().get_nodes_in_group("enemies"))


func _on_projectile_expired(projectile: Area2D, reason: StringName) -> void:
	if projectile is Projectile and projectile.team == &"player" and is_instance_valid(player):
		weapon_controller.on_projectile_expired(projectile, reason, player.global_position)


func _on_enemy_contact(enemy: Area2D, target: Node, amount: float) -> void:
	if target == player:
		player.take_damage(amount, enemy.global_position)


func _on_enemy_died(_enemy: Area2D, orb_value: int, death_position: Vector2, _source_id: StringName) -> void:
	kills += 1
	call_deferred("_spawn_xp", death_position, orb_value)


func _spawn_xp(position: Vector2, value: int) -> void:
	var orb: XpOrb = XpOrbScript.new()
	var angle := TAU * float(_seed_roll("orb", kills) & 0xffff) / 65535.0
	orb.configure(position, value, player, {"initial_velocity": Vector2.RIGHT.rotated(angle) * 70.0})
	world_root.add_child(orb)
	orb.collected.connect(_on_xp_collected)


func _on_xp_collected(_orb: Area2D, value: int, _collector: Node) -> void:
	xp += value
	if _smoke_test:
		return
	while xp >= xp_needed:
		xp -= xp_needed
		level += 1
		xp_needed = int(7.0 + pow(float(level), 1.32) * 3.2)
		pending_levels += 1
	if pending_levels > 0 and current_offer.is_empty():
		_open_next_upgrade()


func _open_next_upgrade() -> void:
	if pending_levels <= 0 or run_ended:
		return
	pending_levels -= 1
	current_offer = _get_upgrade_offer(level)
	if current_offer.is_empty():
		player.heal_hull(15.0)
		hud.flash_log("NO LEGAL PATCH // HULL RESTORED", AMBER)
		return
	hud.show_upgrade_choices(current_offer)


func _get_upgrade_offer(level_index: int) -> Array[Dictionary]:
	var scripted_ids: Array[String] = []
	if level_index == 2:
		scripted_ids = ["FORK_ON_KILL", "ARC_FANOUT", "VENT_AMPLIFIER"]
	elif level_index == 3:
		scripted_ids = ["RETURN_VECTOR", "CONDUCTIVE_MARK", "OVERCLOCK_KERNEL"]
	if not scripted_ids.is_empty():
		var scripted: Array[Dictionary] = []
		for upgrade_id in scripted_ids:
			var definition: Dictionary = UpgradeCatalogScript.get_definition(StringName(upgrade_id))
			var current_rank := int(upgrades.get(upgrade_id, 0))
			if not definition.is_empty() and current_rank < int(definition["max_rank"]):
				definition["current_rank"] = current_rank
				definition["next_rank"] = current_rank + 1
				scripted.append(definition)
		return scripted
	return UpgradeCatalogScript.get_offer(run_seed_text, level_index, upgrades)


func _on_upgrade_selected(index: int) -> void:
	if index < 0 or index >= current_offer.size():
		return
	var choice: Dictionary = current_offer[index]
	var upgrade_id := String(choice["id"])
	var rank := int(upgrades.get(upgrade_id, 0)) + 1
	upgrades[upgrade_id] = rank
	player.apply_upgrade(upgrade_id, rank)
	weapon_controller.set_upgrades(upgrades)
	hud.hide_upgrade_choices()
	hud.flash_log("PATCH APPLIED // %s.R%d" % [upgrade_id, rank], GREEN)
	synth_audio.play_cue(&"upgrade")
	current_offer.clear()
	if pending_levels > 0:
		call_deferred("_open_next_upgrade")


func _try_vent() -> void:
	if is_instance_valid(player) and player.try_vent():
		hud.flash_log("VENT // REACTOR PURGED", AMBER)


func _on_player_vented(position: Vector2, heat_ratio: float) -> void:
	weapon_controller.on_vent(position, heat_ratio)


func _apply_vent_pulse(position: Vector2, radius: float, damage: float, force: float) -> void:
	_show_ring(position, radius, AMBER, 0.28)
	_shake_camera(7.0, 0.18)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy is Node2D:
			continue
		var offset := (enemy as Node2D).global_position - position
		var distance := offset.length()
		if distance > radius:
			continue
		var scale := 1.0 - distance / radius
		if enemy.has_method("take_damage"):
			enemy.call("take_damage", damage * lerpf(0.35, 1.0, scale), &"VENT", position)
		if "velocity" in enemy and distance > 0.1:
			enemy.set("velocity", enemy.get("velocity") + offset.normalized() * force * scale)
		(enemy as Node2D).global_position += offset.normalized() * 18.0 * scale


func _on_player_damaged(_amount: float, hull_damage: float) -> void:
	_show_ring(player.global_position, 48.0, RED, 0.16)
	_shake_camera(11.0, 0.22)
	if hull_damage > 0.0:
		hud.flash_log("HULL BREACH // %d DAMAGE" % int(ceil(hull_damage)), RED)
		synth_audio.play_cue(&"damage")


func _on_player_died() -> void:
	_end_run(false)


func _spawn_boss() -> void:
	if boss_spawned or run_ended:
		return
	boss_spawned = true
	for hostile_projectile in get_tree().get_nodes_in_group("projectile_enemy"):
		if is_instance_valid(hostile_projectile) and hostile_projectile.has_method("expire"):
			hostile_projectile.call("expire", &"boss_clear")
	boss = WatchdogBossScript.new()
	boss.name = "WATCHDOG_01"
	boss.global_position = Vector2(
		clampf(player.global_position.x + 560.0, ARENA_BOUNDS.position.x + 100.0, ARENA_BOUNDS.end.x - 100.0),
		clampf(player.global_position.y, ARENA_BOUNDS.position.y + 100.0, ARENA_BOUNDS.end.y - 100.0)
	)
	boss.configure(player, 1.0)
	world_root.add_child(boss)
	boss.died.connect(_on_boss_died)
	boss.shot_requested.connect(_on_boss_shot_requested)
	boss.phase_changed.connect(_on_boss_phase_changed)
	hud.flash_log("ROOT PROCESS DETECTED // WATCHDOG_01", MAGENTA)
	synth_audio.play_cue(&"boss")
	_shake_camera(14.0, 0.42)
	_show_ring(boss.global_position, 150.0, MAGENTA, 0.55)


func _on_boss_phase_changed(phase: int) -> void:
	hud.flash_log("WATCHDOG // PHASE %d" % phase, MAGENTA)


func _on_boss_died(_boss_node: Node, _xp_value: int, _source_id: String) -> void:
	kills += 1
	_end_run(true)


func _end_run(victory: bool) -> void:
	if run_ended:
		return
	run_ended = true
	synth_audio.play_cue(&"victory" if victory else &"death")
	weapon_controller.enabled = false
	player.set_move_intent(Vector2.ZERO)
	var build_parts := PackedStringArray()
	var ids := upgrades.keys()
	ids.sort()
	for upgrade_id in ids:
		build_parts.append("%s.R%d" % [upgrade_id, int(upgrades[upgrade_id])])
	hud.show_end_screen(victory, {
		"time": elapsed_time,
		"kills": kills,
		"level": level,
		"damage": int(damage_dealt),
		"seed": run_seed_text,
		"build": " / ".join(build_parts) if not build_parts.is_empty() else "BASELINE",
	})


func _restart_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _show_arc(points: PackedVector2Array, color: Color) -> void:
	var line := Line2D.new()
	line.points = points
	line.width = 3.0
	line.default_color = color
	line.antialiased = true
	line.z_index = 30
	world_root.add_child(line)
	var tween := line.create_tween()
	tween.tween_property(line, "modulate:a", 0.0, 0.16)
	tween.tween_callback(line.queue_free)


func _show_ring(position: Vector2, radius: float, color: Color, duration: float) -> void:
	var ring := Line2D.new()
	var points := PackedVector2Array()
	for index in range(49):
		points.append(Vector2.RIGHT.rotated(TAU * float(index) / 48.0) * radius)
	ring.points = points
	ring.width = 3.0
	ring.default_color = color
	ring.antialiased = true
	ring.global_position = position
	ring.scale = Vector2.ONE * 0.15
	ring.z_index = 28
	world_root.add_child(ring)
	var tween := ring.create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector2.ONE, duration)
	tween.tween_property(ring, "modulate:a", 0.0, duration)
	tween.chain().tween_callback(ring.queue_free)


func _shake_camera(amount: float, duration: float) -> void:
	if not is_instance_valid(camera):
		return
	if is_instance_valid(_camera_tween):
		_camera_tween.kill()
	_camera_tween = create_tween()
	var step := duration / 4.0
	_camera_tween.tween_property(camera, "offset", Vector2(amount, -amount * 0.55), step)
	_camera_tween.tween_property(camera, "offset", Vector2(-amount * 0.7, amount * 0.45), step)
	_camera_tween.tween_property(camera, "offset", Vector2(amount * 0.35, amount * 0.2), step)
	_camera_tween.tween_property(camera, "offset", Vector2.ZERO, step)


func _update_hud(force: bool = false) -> void:
	if not is_instance_valid(hud) or not is_instance_valid(player):
		return
	var state := player.get_status()
	var threat := "ROOT" if boss_spawned else ("03" if elapsed_time >= 210.0 else ("02" if elapsed_time >= 100.0 else "01"))
	var status := {
		"process": "MASS_DRIVER+ARC.EXE",
		"sector": "STATIC_PROOF",
		"seed": run_seed_text,
		"threat": threat,
		"time": elapsed_time,
		"kills": kills,
		"level": level,
		"integrity": float(state["hull"]) + float(state["shield"]),
		"max_integrity": float(state["max_hull"]) + float(state["max_shield"]),
		"heat": state["heat"],
		"max_heat": state["max_heat"],
		"xp": xp,
		"xp_next": xp_needed,
		"vent_ready": state["vent_ready"],
		"vent_cooldown": state["vent_cooldown"],
		"fps": Engine.get_frames_per_second(),
	}
	if force:
		status["message"] = "SIGNAL LOCKED"
	hud.set_status(status)


func _on_touch_move(direction: Vector2) -> void:
	_using_touch = true
	_touch_move = direction.limit_length()


func _on_touch_target_bias(direction: Vector2, active: bool) -> void:
	_using_touch = true
	_touch_aim_active = active and direction.length_squared() > 0.01
	if _touch_aim_active:
		_touch_aim = direction.normalized()


func _parse_command_line() -> void:
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--seed="):
			run_seed_text = argument.trim_prefix("--seed=").strip_edges().to_upper()
		elif argument == "--touch-ui":
			_using_touch = true
		elif argument == "--smoke-test":
			_smoke_test = true
		elif argument == "--capture-test":
			_smoke_test = true
			_capture_test = true
		elif argument == "--capture-end-screen":
			_capture_end_screen = true
	if run_seed_text.is_empty():
		run_seed_text = "VOID-0001"
	if _capture_end_screen:
		run_seed_text = END_SCREEN_CAPTURE_SEED


func _seed_roll(channel: String, index: int) -> int:
	return UpgradeCatalogScript.stable_hash("%s|%s|%d" % [run_seed_text, channel, index])


func _start_end_screen_capture() -> void:
	# Do not open the modal from the scene's initial _ready() frame. Windows can
	# report the final viewport size a frame later, which made this visual test
	# intermittently capture only the dimmed background.
	await get_tree().process_frame
	await get_tree().process_frame

	# Keep this fixture independent of gameplay progress so visual diffs only
	# reflect intentional end-screen changes.
	elapsed_time = 1337.8
	kills = 1248
	level = 34
	damage_dealt = 987654.0
	boss_spawned = true
	upgrades = {
		"ARC_FANOUT": 2,
		"CONDUCTIVE_MARK": 3,
		"DRIVER_RAIL": 3,
		"FORK_ON_KILL": 3,
		"GROUND_LOOP": 3,
		"HULL_PLATING": 3,
		"OVERCLOCK_KERNEL": 3,
		"RETURN_VECTOR": 2,
		"SHIELD_CAPACITOR": 3,
		"VENT_AMPLIFIER": 3,
	}
	hud.set_status({
		"process": "MASS_DRIVER+ARC.EXE",
		"sector": "STATIC_PROOF",
		"seed": run_seed_text,
		"threat": "ROOT",
		"time": elapsed_time,
		"kills": kills,
		"level": level,
		"integrity": 118.0,
		"max_integrity": 130.0,
		"heat": 82.0,
		"max_heat": 100.0,
		"xp": 244,
		"xp_next": 305,
		"vent_ready": true,
		"vent_cooldown": 0.0,
		"fps": 60,
	})
	# Reproduce the reported failure path exactly; victory uses the same layout.
	_end_run(false)

	# show_end_screen() pauses the tree. This timer explicitly continues while
	# paused, leaving enough rendered frames for layout and deferred focus.
	await get_tree().create_timer(END_SCREEN_CAPTURE_SETTLE_SECONDS, true, false, true).timeout
	# Synchronize with rendering, not only SceneTree processing. The tree is
	# paused by the modal and a process-frame signal can precede the actual draw.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var capture_path := ProjectSettings.globalize_path(END_SCREEN_CAPTURE_PATH)
	var capture_directory := capture_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(capture_directory):
		var directory_error := DirAccess.make_dir_recursive_absolute(capture_directory)
		if directory_error != OK:
			_finish_end_screen_capture(false, capture_path, "directory_error=%d" % directory_error)
			return

	var viewport_texture := get_viewport().get_texture()
	if viewport_texture == null:
		_finish_end_screen_capture(false, capture_path, "renderer_has_no_viewport_texture")
		return
	var image := viewport_texture.get_image()
	if image == null or image.is_empty():
		_finish_end_screen_capture(false, capture_path, "renderer_returned_no_image")
		return
	var save_error := image.save_png(capture_path)
	if save_error != OK:
		_finish_end_screen_capture(false, capture_path, "save_error=%d" % save_error)
		return
	_finish_end_screen_capture(true, capture_path, "size=%dx%d" % [image.get_width(), image.get_height()])


func _finish_end_screen_capture(success: bool, capture_path: String, detail: String) -> void:
	var marker := "END_SCREEN_CAPTURE_OK" if success else "END_SCREEN_CAPTURE_FAIL"
	print("%s path=%s paused=%s %s" % [marker, capture_path, str(get_tree().paused), detail])
	if is_instance_valid(synth_audio):
		synth_audio.shutdown()
	get_tree().paused = false
	get_tree().quit(0 if success else 3)


func _start_smoke_test() -> void:
	var offer_a: Array[Dictionary] = UpgradeCatalogScript.get_offer(run_seed_text, 4, {})
	var offer_b: Array[Dictionary] = UpgradeCatalogScript.get_offer(run_seed_text, 4, {})
	var offer_ids: Array[String] = []
	for card in offer_a:
		offer_ids.append(String(card.get("id", "")))
	var unique_ids := {}
	for upgrade_id in offer_ids:
		unique_ids[upgrade_id] = true
	if JSON.stringify(offer_a) != JSON.stringify(offer_b) or offer_a.size() != 3 or unique_ids.size() != offer_a.size():
		push_error("SMOKE_FAIL deterministic upgrade offer contract")
		synth_audio.shutdown()
		get_tree().quit(2)
		return
	print("SMOKE_CONTRACTS_OK deterministic_offer=%s" % str(offer_ids))

	player.max_hull = 10000.0
	player.hull = 10000.0
	elapsed_time = 170.0
	for index in range(18):
		_spawn_enemy()
	upgrades["FORK_ON_KILL"] = 1
	upgrades["RETURN_VECTOR"] = 1
	upgrades["ARC_FANOUT"] = 1
	upgrades["CONDUCTIVE_MARK"] = 1
	upgrades["GROUND_LOOP"] = 1
	upgrades["VENT_AMPLIFIER"] = 1
	upgrades["OVERCLOCK_KERNEL"] = 1
	weapon_controller.set_upgrades(upgrades)
	player.add_heat(86.0)
	player.try_vent()
	_spawn_boss()
	var type_counts := {"bit": 0, "vector": 0, "sentry": 0}
	for enemy in get_tree().get_nodes_in_group("enemy_normal"):
		var type_key := String(enemy.enemy_type)
		type_counts[type_key] = int(type_counts.get(type_key, 0)) + 1
	print("SMOKE_START seed=%s enemies=%d types=%s boss=%s" % [
		run_seed_text,
		get_tree().get_nodes_in_group("enemies").size(),
		str(type_counts),
		str(is_instance_valid(boss)),
	])


func _tick_smoke_test(delta: float) -> void:
	_smoke_timer += delta
	if _smoke_finishing:
		if _smoke_timer >= 5.25:
			get_tree().quit(0)
		return
	player.set_move_intent(Vector2(0.7, 0.2))
	if _capture_test and not _capture_done and _smoke_timer >= 3.8:
		_capture_done = true
		var viewport_texture := get_viewport().get_texture()
		if viewport_texture == null:
			print("CAPTURE_SKIP renderer_has_no_viewport_texture")
		else:
			var image := viewport_texture.get_image()
			if image == null:
				print("CAPTURE_SKIP renderer_returned_no_image")
			else:
				var capture_name := "prototype_touch_capture.png" if _using_touch else "prototype_capture.png"
				var capture_path := ProjectSettings.globalize_path("res://artifacts/%s" % capture_name)
				var error := image.save_png(capture_path)
				print("CAPTURE_WRITE path=%s error=%d" % [capture_path, error])
	if _smoke_timer >= 5.0:
		print("SMOKE_OK kills=%d projectiles=%d hostile=%d pickups=%d boss_health=%d" % [
			kills,
			get_tree().get_nodes_in_group("projectile").size(),
			get_tree().get_nodes_in_group("projectile_enemy").size(),
			get_tree().get_nodes_in_group("pickup").size(),
			int(boss.health) if is_instance_valid(boss) else 0,
		])
		synth_audio.shutdown()
		_smoke_finishing = true
