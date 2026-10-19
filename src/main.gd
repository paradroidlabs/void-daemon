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
var _capture_pause := false
var _smoke_finishing := false
var _camera_tween: Tween
var chassis := "COURIER"
var _damage_window: Array[Dictionary] = []
var _source_damage := {}
var damage_taken := 0.0
var damage_blocked := 0.0
var _touch_block := false
var _floating_count := 0
var _primary_flash := 0.0
var _arc_flash := 0.0
var combat_view: SubViewportContainer
var _mouse_precision_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_parse_command_line()
	get_window().title = "VOID//DAEMON | COURIER EXPERIMENT / 4ade"
	run_seed = UpgradeCatalogScript.stable_hash(run_seed_text)
	_build_world()
	_connect_runtime()
	_update_hud(true)
	hud.flash_log("AUTO WEAPONS // M1 CHARGE + RELEASE // M2 GUARD // SHIFT BOOST // ESC STATS", CYAN)
	if _capture_end_screen:
		_start_end_screen_capture()
	elif _smoke_test:
		_start_smoke_test()
	else:
		hud.show_ship_picker()


func _build_world() -> void:
	combat_view = preload("res://src/ui/combat_view.gd").new()
	combat_view.footer_height = 64
	add_child(combat_view)
	backdrop = ArenaBackdropScript.new()
	backdrop.name = "ArenaBackdrop"
	backdrop.z_index = -100
	backdrop.configure(ARENA_BOUNDS, run_seed)
	combat_view.arena.add_child(backdrop)

	world_root = Node2D.new()
	world_root.name = "RuntimeWorld"
	combat_view.arena.add_child(world_root)

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
	combat_view.attach_camera(camera)

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
	hud.zoom_requested.connect(combat_view.adjust_zoom)
	player.vented.connect(_on_player_vented)
	player.damaged.connect(_on_player_damaged)
	player.died.connect(_on_player_died)
	player.blocked.connect(func(amount: float):
		damage_blocked += amount
		hud.flash_log("GUARD // %.0f BLOCKED" % amount, CYAN)
	)
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
	hud.touch_block_changed.connect(func(active: bool): _touch_block = active)
	hud.ship_selected.connect(_select_ship)
	hud.pause_toggled.connect(func(paused: bool):
		if paused:
			weapon_controller.precision_charge = 0.0
			weapon_controller._precision_was_held = false
	)
	weapon_controller.weapon_triggered.connect(func(weapon: String, hits: int):
		if weapon == "FORK":
			hud.pulse_fork()
		elif weapon == "MASS_DRIVER" or weapon == "PRECISION":
			_primary_flash = 0.18
		else:
			_arc_flash = 0.25
			hud.flash_log("ARC // %d CONTACTS CHAINED" % hits, Color("9aa7ff"))
	)


func _physics_process(delta: float) -> void:
	if run_ended:
		return
	_update_input_intents()
	elapsed_time += delta
	_primary_flash = maxf(0.0, _primary_flash - delta)
	_arc_flash = maxf(0.0, _arc_flash - delta)
	while not _damage_window.is_empty() and elapsed_time - float(_damage_window[0]["time"]) > 5.0:
		_damage_window.pop_front()
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


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_mouse_precision_active = false


func _unhandled_input(event: InputEvent) -> void:
	if not run_ended and not get_tree().paused:
		if event is InputEventMouseButton and event.pressed:
			if event.button_index == MOUSE_BUTTON_LEFT:
				_mouse_precision_active = combat_view.contains_screen_point(event.position)
			elif event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and combat_view.contains_screen_point(event.position):
				combat_view.adjust_zoom(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1)
				get_viewport().set_input_as_handled()
				return
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_EQUAL, KEY_PLUS, KEY_MINUS, KEY_KP_ADD, KEY_KP_SUBTRACT]:
			combat_view.adjust_zoom(-1 if event.physical_keycode in [KEY_MINUS, KEY_KP_SUBTRACT] else 1)
			get_viewport().set_input_as_handled()
			return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SHIFT:
				_try_vent()
			KEY_T:
				_using_touch = not _using_touch
				hud.set_touch_controls_visible(_using_touch)
				hud.flash_log("TOUCH LAYER %s" % ("ONLINE" if _using_touch else "OFFLINE"), AMBER)
			KEY_F10:
				if not boss_spawned:
					elapsed_time = BOSS_SPAWN_TIME - 0.1
					hud.flash_log("DEBUG // FAST-FORWARD TO WATCHDOG", MAGENTA)
			KEY_ESCAPE, KEY_P:
				hud.toggle_pause()
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A:
			_try_vent()
		elif event.button_index == JOY_BUTTON_START:
			hud.toggle_pause()


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
	player.blocking = (Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_physical_key_pressed(KEY_SPACE) or _touch_block) and not player.guard_broken
	weapon_controller.attack_held = (_mouse_precision_active and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) or (_using_touch and _touch_aim_active) or (_smoke_test and fmod(_smoke_timer, 1.8) < 1.0)
	if not joypads.is_empty():
		player.blocking = (player.blocking or Input.is_joy_button_pressed(joypads[0], JOY_BUTTON_LEFT_SHOULDER)) and not player.guard_broken
		weapon_controller.attack_held = weapon_controller.attack_held or Input.is_joy_button_pressed(joypads[0], JOY_BUTTON_RIGHT_SHOULDER)

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
		var mouse_offset: Vector2 = combat_view.screen_to_world(get_viewport().get_mouse_position()) - player.global_position
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
	var position: Vector2 = combat_view.spawn_position(player.global_position, angle, float(radius_roll & 0xff) / 255.0, ARENA_BOUNDS)
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
	enemy.damaged.connect(_on_damage_dealt)
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


func _on_player_damaged(amount: float, hull_damage: float) -> void:
	damage_taken += amount
	hud.show_damage_feedback(amount, hull_damage)
	_show_damage_number(player.global_position, amount, RED, "HULL" if hull_damage > 0.0 else "SHIELD")
	_update_hud()
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
	boss.damaged.connect(_on_damage_dealt)
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
		"damage_taken": int(damage_taken),
		"damage_blocked": int(damage_blocked),
		"chassis": chassis,
		"seed": run_seed_text,
		"build": " / ".join(build_parts) if not build_parts.is_empty() else "BASELINE",
	})


func _restart_run() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _show_arc(points: PackedVector2Array, color: Color) -> void:
	var line := Line2D.new()
	line.points = points
	line.width = 1.5
	line.default_color = color
	line.antialiased = true
	line.z_index = 30
	world_root.add_child(line)
	line.process_mode = Node.PROCESS_MODE_ALWAYS
	var tween := line.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(line, "modulate:a", 0.0, 0.09)
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
	ring.process_mode = Node.PROCESS_MODE_ALWAYS
	var tween := ring.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS).set_parallel(true)
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
		"chassis": chassis,
		"zoom": combat_view.zoom_level,
	}
	if force:
		status["message"] = "SIGNAL LOCKED"
	hud.set_status(status)
	hud.set_combat_status("DPS %.1f [5s]  //  %s" % [_get_dps(), chassis],
		"AUTO DRIVER %s  |  AUTO ARC %s  |  GUARD %.0f  |  SHIFT BOOST %s" % [
			"FIRING" if _primary_flash > 0.0 else "READY", "CHAINING" if _arc_flash > 0.0 else ("READY" if weapon_controller._arc_cooldown <= 0.0 else "%.1fs" % weapon_controller._arc_cooldown),
			player.guard, "READY" if player.vent_cooldown <= 0.0 else "%.1fs" % player.vent_cooldown])
	hud.set_inspection_data(_get_inspection_data())
	hud.set_ship_diagram(upgrades, weapon_controller.precision_charge, _primary_flash, _arc_flash, chassis)


func _get_dps() -> float:
	var total := 0.0
	for sample in _damage_window:
		total += float(sample["amount"])
	return total / minf(5.0, maxf(elapsed_time, 0.1))


func _on_damage_dealt(_target: Node, amount: float, source: StringName, position: Vector2) -> void:
	damage_dealt += amount
	_source_damage[source] = float(_source_damage.get(source, 0.0)) + amount
	_damage_window.append({"time": elapsed_time, "amount": amount})
	_show_damage_number(position, amount, Color("9aa7ff") if source == &"ARC_EXE" else CYAN)


func _show_damage_number(position: Vector2, amount: float, color: Color, prefix: String = "") -> void:
	if _floating_count >= 40:
		return
	_floating_count += 1
	var label := Label.new()
	label.text = "%s %s" % [prefix, "%.1f" % amount if amount < 1.0 else "%.0f" % amount]
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", 17)
	label.position = position + Vector2(-12, -24)
	label.z_index = 45
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	world_root.add_child(label)
	var tween := label.create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 35.0, 0.55)
	tween.tween_property(label, "modulate:a", 0.0, 0.55)
	tween.chain().tween_callback(func():
		_floating_count -= 1
		label.queue_free()
	)


func _get_inspection_data() -> Dictionary:
	var sources: Array = []
	for source in _source_damage:
		sources.append([String(source).replace("_", " "), "%.0f  /  %.1f%%" % [_source_damage[source], 100.0 * float(_source_damage[source]) / maxf(1, damage_dealt)]])
	if sources.is_empty():
		sources.append(["NO HITS YET", "0"])
	var installed: Array = []
	for id in upgrades:
		var definition: Dictionary = UpgradeCatalogScript.get_definition(StringName(id))
		installed.append([String(id).replace("_", " "), "RANK %d" % upgrades[id], definition.get("description", "")])
	return {
		"chassis": chassis, "seed": run_seed_text, "level": level, "mods": upgrades.duplicate(),
		"meters": [["HULL", roundi(player.hull), roundi(player.max_hull), "ff6675"], ["SHIELD", roundi(player.shield), roundi(player.max_shield), "59f2ff"], ["GUARD", roundi(player.guard), 100, "9aa7ff"], ["HEAT", roundi(player.heat), roundi(player.max_heat), "ffbd4a"]],
		"summary": [["ROLLING DPS", "%.1f" % _get_dps(), "Actual damage / last 5 seconds"], ["RUN TIME", "%02d:%02d" % [int(elapsed_time) / 60, int(elapsed_time) % 60], "%d enemies purged" % kills], ["BUILD PROGRESS", "LEVEL %d" % level, "%d / %d XP to next upgrade" % [xp, xp_needed]]],
		"weapons": [
			["MASS DRIVER / AUTO", "%.0f DMG / %.2fs" % [weapon_controller.primary_damage, weapon_controller.primary_interval], "%d pierce. Mouse / right touch pad biases targeting. Fires without holding attack." % (1 + int(upgrades.get("DRIVER_RAIL", 0)))],
			["ARC / AUTO", "%.0f DMG / %.2fs" % [weapon_controller.arc_damage, weapon_controller.arc_interval], "Nearest target within 260 units. Up to %d hits / chain; 140-unit jumps. Independent of Driver." % (3 + int(upgrades.get("CONDUCTIVE_MARK", 0)))],
			["PRECISION / MANUAL", "1.2x - 4x DRIVER", "Hold M1 for up to 0.9s, release to fire. 2-6 extra pierce; 8-20 heat. Guard cancels charging."],
			["CHILD PROCESSES / ON KILL", "%d CHILD SHOTS" % int(upgrades.get("FORK_ON_KILL", 0)), "Lethal Driver / Precision hits send children toward nearby enemies. 45% parent damage. Children never fork again."]],
		"sources": sources, "upgrade_cards": installed,
		"stat_groups": [
			["COMBAT RECORD", [["Total damage dealt", "%.0f" % damage_dealt], ["Damage taken", "%.0f" % damage_taken], ["Damage prevented by guard", "%.0f" % damage_blocked], ["Kills", str(kills)], ["Rolling DPS (5s)", "%.1f" % _get_dps()]]],
			["MOBILITY + THERMALS", [["Move speed", "%.0f units/s" % player.move_speed], ["Cooling", "%.1f heat/s" % player.heat_cooling_per_second], ["Vent cooldown remaining", "%.1fs" % player.vent_cooldown], ["Effective vent cooldown", "%.1fs" % maxf(1.7, player.vent_base_cooldown - player._vent_cooldown_reduction)], ["Cadence multiplier", "x%.2f" % (1.0 + 0.1 * int(upgrades.get("OVERCLOCK_KERNEL", 0)))], ["Heat throttle", "x%.2f" % player.get_throttle_scale()]]],
			["DEFENSE", [["Shield regeneration", "%.1f/s" % player.shield_regen_rate], ["Shield regen delay", "%.1fs" % maxf(0.8, player.shield_regen_delay - player._shield_delay_reduction)], ["Hit grace", "%.2fs" % (player.collision_grace + player._extra_collision_grace)], ["Guard mitigation", "80% / 55% movement speed"], ["Guard drain / regeneration", "38/s / 24/s"]]]]
	}


func _select_ship(id: String) -> void:
	chassis = id
	player.configure_chassis(id)
	if id == "BASTION":
		weapon_controller.primary_damage = 32.0
		weapon_controller.primary_interval = 0.9
	elif id == "REDLINE":
		weapon_controller.primary_damage = 18.0
		weapon_controller.primary_interval = 0.5
	elif id == "CONDUCTOR":
		weapon_controller.arc_damage = 18.0
		weapon_controller.arc_interval = 0.9
	_update_hud()


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
		elif argument == "--capture-pause":
			_capture_pause = true
			_capture_test = true
			_smoke_test = true
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
		if _capture_pause:
			_capture_pause_screen()
			return
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


func _capture_pause_screen() -> void:
	_update_hud()
	hud.toggle_pause(true)
	await get_tree().create_timer(0.5, true).timeout
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(ProjectSettings.globalize_path("res://artifacts/pause_review.png"))
	var dashboard: TabContainer = hud.get("_pause_dashboard")
	for index in range(1, 4):
		dashboard.current_tab = index
		await get_tree().create_timer(0.15, true).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/pause_tab_%d.png" % index))
	dashboard.current_tab = 0
	get_window().content_scale_size = Vector2i(640, 720)
	get_window().size = Vector2i(640, 720)
	hud.toggle_pause(false)
	hud.toggle_pause(true)
	await get_tree().create_timer(0.3, true).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://artifacts/pause_compact.png"))
	synth_audio.shutdown()
	await get_tree().create_timer(0.2, true).timeout
	get_tree().quit()
