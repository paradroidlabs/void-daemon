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
const GravitonSalvoScript := preload("res://src/systems/graviton_salvo.gd")

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
var graviton: GravitonSalvo
var _combo_mode := true
var _combat_lab := false
var _lab_fixture := "cluster"
var _lab_loadout := "chain"
var _joy_unleash := false
var _trigger_blocked := false
var _lab_live := false

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
var total_xp_collected: int = 0
var pickups_collected: int = 0
var kills_by_type := {"bit": 0, "vector": 0, "sentry": 0, "boss": 0}
var source_stats: Dictionary = {}
var debug_boss_skip := false

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
var _capture_viewport_size := Vector2i.ZERO
var _capture_scorecard_page := 0
var _smoke_finishing := false
var _camera_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_parse_command_line()
	DisplayServer.window_set_title("VOID//DAEMON | %s | %s" % [ProjectSettings.get_setting("application/config/version", "prototype"), "COMBAT LAB" if _combat_lab else ("SURVIVAL" if _combo_mode else "CLASSIC")])
	run_seed = UpgradeCatalogScript.stable_hash(run_seed_text)
	_build_world()
	_connect_runtime()
	_update_hud(true)
	if _combat_lab:
		_reset_lab()
	hud.flash_log("GRAVITON KIT // HOLD M1: GATHER + LOAD // RELEASE: SALVO // SHIFT/SPACE: ESCAPE" if _combo_mode else "BOOT COMPLETE // MOVE: WASD OR TOUCH // VENT: SPACE", CYAN)
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
	player.combo_mode = _combo_mode
	if _combo_mode:
		player.name = "Graviton"
		player.heat_cooling_per_second = 22.0
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
	if _combo_mode:
		graviton = GravitonSalvoScript.new()
		world_root.add_child(graviton)
		graviton.setup(player)

	hud = TerminalHUDScript.new()
	hud.name = "TerminalHUD"
	add_child(hud)
	hud.set_combo_mode(_combo_mode, _combat_lab)
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
	weapon_controller.attack_fired.connect(_record_attack)
	hud.upgrade_selected.connect(_on_upgrade_selected)
	hud.restart_requested.connect(_restart_run)
	hud.touch_move_changed.connect(_on_touch_move)
	hud.touch_vent_pressed.connect(_try_vent)
	hud.touch_target_bias.connect(_on_touch_target_bias)
	hud.unleash_started.connect(_begin_unleash)
	hud.unleash_released.connect(_release_unleash)
	hud.combat_cancel_requested.connect(_cancel_active_input)
	hud.lab_fixture_requested.connect(_select_fixture)
	hud.lab_loadout_requested.connect(_select_loadout)
	hud.lab_reset_requested.connect(_reset_lab)
	hud.lab_report_requested.connect(func(): _end_run(false))
	if is_instance_valid(graviton):
		graviton.attack_fired.connect(_record_attack)
		graviton.sfx_requested.connect(synth_audio.play_cue)
		graviton.impact.connect(func(_position: Vector2, _radius: float): _shake_camera(2.0, 0.08))


func _physics_process(delta: float) -> void:
	if run_ended:
		return
	_update_input_intents()
	_poll_controller_unleash()
	if _combat_lab and not _lab_live:
		_update_hud()
		return
	elapsed_time += delta
	spawn_timer -= delta
	if not _combat_lab and not boss_spawned and elapsed_time >= BOSS_SPAWN_TIME:
		_spawn_boss()
	if not _combat_lab and spawn_timer <= 0.0:
		_spawn_wave_tick()
	var enemies: Array[Node] = get_tree().get_nodes_in_group("enemies")
	if is_instance_valid(graviton):
		graviton.tick(delta, enemies)
		synth_audio.set_charge(graviton.is_charging, graviton.charge_ratio)
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
	# Defensive aliases take precedence over a previously focused lab picker.
	if _combo_mode and not run_ended and not get_tree().paused:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode in [KEY_SHIFT, KEY_SPACE]:
			_try_vent()
			get_viewport().set_input_as_handled()
		elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_try_vent()
			get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if run_ended or get_tree().paused:
		return
	if _combo_mode and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_unleash()
		else:
			_release_unleash()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if _combat_lab:
			match event.physical_keycode:
				KEY_F1: _select_fixture("cluster")
				KEY_F2: _select_fixture("dispersed")
				KEY_F3: _select_fixture("boss")
				KEY_F4: _select_loadout("salvo")
				KEY_F5: _select_loadout("gravity")
				KEY_F6: _select_loadout("chain")
				KEY_F7: _end_run(false)
				KEY_R: _reset_lab()
		match event.physical_keycode:
			KEY_SPACE:
				_try_vent()
			KEY_SHIFT:
				if _combo_mode:
					_try_vent()
			KEY_T:
				_using_touch = not _using_touch
				hud.set_touch_controls_visible(_using_touch)
				hud.flash_log("TOUCH LAYER %s" % ("ONLINE" if _using_touch else "OFFLINE"), AMBER)
			KEY_F10:
				if not boss_spawned:
					debug_boss_skip = true
					elapsed_time = BOSS_SPAWN_TIME - 0.1
					hud.flash_log("DEBUG // FAST-FORWARD TO WATCHDOG", MAGENTA)
			KEY_ESCAPE, KEY_P:
				hud.toggle_pause()
	if not _combo_mode and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		_try_vent()
	if event is InputEventJoypadButton and event.pressed:
		if event.button_index == JOY_BUTTON_A or event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			_try_vent()
		elif event.button_index == JOY_BUTTON_START:
			hud.toggle_pause()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(graviton):
		_cancel_active_input()
		if is_instance_valid(hud):
			hud.clear_combat_gesture()


func _begin_unleash() -> void:
	if not _combo_mode or run_ended or get_tree().paused:
		return
	_update_input_intents()
	if graviton.begin_charge():
		if _combat_lab and not _lab_live:
			_lab_live = true
			for enemy in get_tree().get_nodes_in_group("enemy_normal"):
				enemy.simulation_enabled = true
			if is_instance_valid(boss):
				boss.set_physics_process(true)
		synth_audio.set_charge(true, 0)


func _release_unleash() -> void:
	if _combo_mode and not run_ended and not get_tree().paused:
		graviton.release_charge()
		synth_audio.set_charge(false)


func _cancel_active_input() -> void:
	_trigger_blocked = true
	if is_instance_valid(graviton):
		graviton.cancel_charge()
		graviton.abort_pending()
	if is_instance_valid(synth_audio):
		synth_audio.set_charge(false)


func _poll_controller_unleash() -> void:
	if not _combo_mode:
		return
	var devices := Input.get_connected_joypads()
	if devices.is_empty():
		return
	var value := Input.get_joy_axis(devices[0], JOY_AXIS_TRIGGER_RIGHT)
	if value < 0.2:
		if _joy_unleash:
			_release_unleash()
		_joy_unleash = false
		_trigger_blocked = false
	elif value > 0.55 and not _joy_unleash and not _trigger_blocked:
		_joy_unleash = true
		_begin_unleash()


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


func _select_fixture(value: String) -> void:
	if value in ["cluster", "dispersed", "boss"]:
		_lab_fixture = value
		_reset_lab()


func _select_loadout(value: String) -> void:
	if value in ["salvo", "gravity", "chain"]:
		_lab_loadout = value
		_reset_lab()


func _reset_lab() -> void:
	if not _combat_lab:
		return
	_cancel_active_input()
	for child in world_root.get_children():
		if child != player and child != graviton:
			child.queue_free()
	boss = null
	boss_spawned = false
	run_ended = false
	_lab_live = false
	elapsed_time = 0
	kills = 0
	damage_dealt = 0
	source_stats.clear()
	total_xp_collected = 0
	pickups_collected = 0
	xp = 0
	level = 1
	for key in kills_by_type:
		kills_by_type[key] = 0
	for key in player.run_stats:
		player.run_stats[key] = 0
	player.global_position = Vector2.ZERO
	player.velocity = Vector2.ZERO
	player.hull = player.max_hull
	player.shield = player.max_shield
	player.heat = 0
	player.is_dead = false
	player.phase_cooldown = 0
	player.phase_uses = 0
	player.phase_distance = 0
	player._invulnerable_left = 0.3
	graviton.reset()
	graviton.gravity_enabled = _lab_loadout != "salvo"
	upgrades = {"FORK_ON_KILL": 2, "RETURN_VECTOR": 1, "ARC_FANOUT": 1, "CONDUCTIVE_MARK": 1, "DRIVER_RAIL": 1} if _lab_loadout == "chain" else {}
	weapon_controller.enabled = true
	weapon_controller.set_upgrades(upgrades)
	weapon_controller._mass_cooldown = 0.18
	weapon_controller._arc_cooldown = 0.7
	weapon_controller._marked_enemy = null
	for index in range(12 if _lab_fixture == "cluster" else 8):
		var position := Vector2(320 + (index % 4 - 1.5) * 64, (index / 4 - 1) * 72)
		if _lab_fixture != "cluster":
			position = Vector2.RIGHT.rotated(float(index) * TAU / 8.0) * 380
		var enemy: Enemy = EnemyScript.new()
		var kind: StringName = &"bit" if _lab_fixture == "cluster" else (&"sentry" if index % 2 == 0 else &"vector")
		enemy.configure(kind, position, {"health": 125.0, "speed": 30.0 if _lab_fixture == "cluster" else 65.0, "xp": 2, "simulation_enabled": false}, player)
		world_root.add_child(enemy)
		enemy.add_to_group("enemy_normal")
		enemy.died.connect(_on_enemy_died)
		enemy.damaged.connect(_record_enemy_damage)
		enemy.contact_hit.connect(_on_enemy_contact)
		enemy.shot_requested.connect(_on_enemy_shot_requested)
	if _lab_fixture == "boss":
		_spawn_boss()
		boss.set_physics_process(false)
	camera.reset_smoothing()
	hud.set_lab_selection(_lab_fixture, _lab_loadout)
	_update_hud(true)
	hud.flash_log("LAB READY // AIM THEN HOLD M1 // R: RESET // F1-F3: ENCOUNTER // F4-F6: LOADOUT", CYAN)


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
	enemy.damaged.connect(_record_enemy_damage)
	enemy.contact_hit.connect(_on_enemy_contact)
	enemy.shot_requested.connect(_on_enemy_shot_requested)
	spawn_index += 1


func _spawn_projectile(origin: Vector2, direction: Vector2, stats: Dictionary, team: StringName = &"player") -> Projectile:
	var projectile: Projectile = ProjectileScript.new()
	projectile.configure(origin, direction, stats, team)
	if team == &"player":
		_record_attack(projectile.source_id)
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


func _on_projectile_hit(projectile: Area2D, target: Node, _damage: float, hit_position: Vector2) -> void:
	if projectile is Projectile and projectile.team == &"player":
		weapon_controller.on_projectile_hit(projectile, target, hit_position, get_tree().get_nodes_in_group("enemies"))


func _on_projectile_expired(projectile: Area2D, reason: StringName) -> void:
	if projectile is Projectile and projectile.team == &"player" and is_instance_valid(player):
		weapon_controller.on_projectile_expired(projectile, reason, player.global_position)


func _on_enemy_contact(enemy: Area2D, target: Node, amount: float) -> void:
	if target == player:
		player.take_damage(amount, enemy.global_position)


func _on_enemy_died(enemy: Area2D, orb_value: int, death_position: Vector2, source_id: StringName) -> void:
	if run_ended:
		return
	kills += 1
	kills_by_type[String(enemy.enemy_type)] += 1
	_source_entry(source_id)["kills"] += 1
	call_deferred("_spawn_xp", death_position, orb_value)


func _spawn_xp(position: Vector2, value: int) -> void:
	var orb: XpOrb = XpOrbScript.new()
	var angle := TAU * float(_seed_roll("orb", kills) & 0xffff) / 65535.0
	orb.configure(position, value, player, {"initial_velocity": Vector2.RIGHT.rotated(angle) * 70.0})
	world_root.add_child(orb)
	orb.collected.connect(_on_xp_collected)


func _on_xp_collected(_orb: Area2D, value: int, _collector: Node) -> void:
	total_xp_collected += value
	pickups_collected += 1
	xp += value
	if _smoke_test:
		return
	if _combat_lab:
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
		scripted_ids = ["FORK_ON_KILL", "ARC_FANOUT", "SHIELD_CAPACITOR" if _combo_mode else "VENT_AMPLIFIER"]
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
		return _mode_choices(scripted)
	var offer_state := upgrades.duplicate()
	if _combo_mode:
		for id in ["VENT_AMPLIFIER", "VENT_COOLANT", "GROUND_LOOP"]:
			offer_state[id] = int(UpgradeCatalogScript.get_definition(id).get("max_rank", 3))
	return _mode_choices(UpgradeCatalogScript.get_offer(run_seed_text, level_index, offer_state))


func _mode_choices(choices: Array[Dictionary]) -> Array[Dictionary]:
	if _combo_mode:
		for choice in choices:
			if choice["id"] == "OVERCLOCK_KERNEL":
				choice["description"] = "Automatic processes execute faster and generate more heat. Graviton and salvo retain their own cadence."
	return choices


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
	if _combo_mode:
		if run_ended or get_tree().paused:
			return
		_update_input_intents()
		var departure := player.global_position
		if player.try_phase_skip():
			if graviton.is_charging:
				graviton.cancel_charge()
			synth_audio.set_charge(false)
			synth_audio.play_cue(&"phase")
			_show_ring(departure, 35, CYAN, 0.25)
			_show_ring(player.global_position, 40, CYAN, 0.25)
			_show_arc(PackedVector2Array([departure, player.global_position]), CYAN)
			_trigger_blocked = true
		return
	if is_instance_valid(player) and player.try_vent():
		hud.flash_log("VENT // REACTOR PURGED", AMBER)


func _on_player_vented(position: Vector2, heat_ratio: float) -> void:
	_record_attack(&"VENT")
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
	boss.damaged.connect(_record_enemy_damage)
	boss.shot_requested.connect(_on_boss_shot_requested)
	boss.phase_changed.connect(_on_boss_phase_changed)
	hud.flash_log("ROOT PROCESS DETECTED // WATCHDOG_01", MAGENTA)
	synth_audio.play_cue(&"boss")
	_shake_camera(14.0, 0.42)
	_show_ring(boss.global_position, 150.0, MAGENTA, 0.55)


func _on_boss_phase_changed(phase: int) -> void:
	hud.flash_log("WATCHDOG // PHASE %d" % phase, MAGENTA)


func _on_boss_died(_boss_node: Node, _xp_value: int, source_id: String) -> void:
	kills += 1
	kills_by_type["boss"] += 1
	_source_entry(StringName(source_id))["kills"] += 1
	_end_run(true)


func _end_run(victory: bool) -> void:
	if run_ended:
		return
	run_ended = true
	synth_audio.play_cue(&"victory" if victory else &"death")
	weapon_controller.enabled = false
	if is_instance_valid(graviton):
		graviton.stop()
		synth_audio.set_charge(false)
	player.set_move_intent(Vector2.ZERO)
	_update_hud(true)
	hud.show_end_screen(victory, _build_run_report(victory))


func _source_entry(source_id: StringName) -> Dictionary:
	var key := String(source_id)
	if not source_stats.has(key):
		source_stats[key] = {"attacks": 0, "hits": 0, "kills": 0, "damage": 0.0}
	return source_stats[key]


func _record_attack(source_id: StringName) -> void:
	if not run_ended:
		_source_entry(source_id)["attacks"] += 1


func _record_enemy_damage(_enemy: Area2D, amount: float, source_id: StringName, _position: Vector2) -> void:
	if run_ended:
		return
	# Enemy actors report health actually removed, including the killing hit.
	# ARC and VENT use the same path as projectiles; overkill is excluded.
	damage_dealt += amount
	var entry := _source_entry(source_id)
	entry["damage"] += amount
	entry["hits"] += 1


func _build_run_report(victory: bool) -> Dictionary:
	var duration := maxf(elapsed_time, 0.001)
	var ship: Dictionary = player.run_stats
	var damage_taken := float(ship["hull_damage"]) + float(ship["shield_absorbed"])
	var patch_ranks := 0
	var build_lines := PackedStringArray()
	var patch_cards: Array[Dictionary] = []
	var ids := upgrades.keys()
	ids.sort()
	for upgrade_id in ids:
		var rank := int(upgrades[upgrade_id])
		patch_ranks += rank
		var definition: Dictionary = UpgradeCatalogScript.get_definition(StringName(upgrade_id))
		build_lines.append("%s.R%d / %d" % [upgrade_id, rank, int(definition.get("max_rank", rank))])
		patch_cards.append({"id": upgrade_id, "rank": rank, "max_rank": int(definition.get("max_rank", rank)), "target": definition.get("target", "SYSTEM")})
	var sections: Array[Dictionary] = []
	sections.append({"title": "RUN SUMMARY", "rows": {
		"Result": "TRANSMISSION COMPLETE" if victory else "PROCESS TERMINATED",
		"Survived": hud.format_duration(elapsed_time), "Kills / level": "%d / %d" % [kills, level],
		"Damage / DPS": "%.1f / %.1f" % [damage_dealt, damage_dealt / duration],
		"Seed": run_seed_text,
		"Sector": "STATIC_PROOF", "Boss": "DEFEATED" if victory else ("ACTIVE / PHASE %d" % boss.phase if is_instance_valid(boss) else ("NOT DEFEATED" if boss_spawned else "NOT REACHED")),
		"Run mode": ("LAB / %s / %s" % [_lab_fixture.to_upper(), _lab_loadout.to_upper()]) if _combat_lab else ("GRAVITON KIT" if _combo_mode else ("DEBUG / BOSS SKIP" if debug_boss_skip else "STANDARD")),
		"Level": level, "XP collected": total_xp_collected, "XP toward next level": "%d / %d" % [xp, xp_needed],
		"Pickups collected": pickups_collected, "Patches installed": "%d types / %d ranks" % [upgrades.size(), patch_ranks],
	}})
	sections.append({"title": "COMBAT", "rows": {
		"Total kills": kills, "Kills per minute": "%.1f" % (kills * 60.0 / duration),
		"BIT / VECTOR / SENTRY": "%d / %d / %d" % [kills_by_type["bit"], kills_by_type["vector"], kills_by_type["sentry"]],
		"Boss kills": kills_by_type["boss"], "Damage dealt": "%.1f" % damage_dealt,
		"Average DPS": "%.1f" % (damage_dealt / duration),
		"Damage taken": "%.1f" % damage_taken, "Hits taken": ship["hits_taken"],
		"Hull damage / shield absorbed": "%.1f / %.1f" % [ship["hull_damage"], ship["shield_absorbed"]],
	}})
	sections.append({"title": "SHIP / FINAL CONFIGURATION", "rows": {
		"Hull": "%.1f / %.1f" % [player.hull, player.max_hull],
		"Shield": "%.1f / %.1f" % [player.shield, player.max_shield],
		"Hull repaired": "%.1f" % ship["hull_repaired"], "Shield restored": "%.1f" % ship["shield_restored"],
		"Move speed": "%.0f units/s" % player.move_speed, "Distance traveled": "%.0f units" % ship["distance"],
		"Shield recharge": "%.1f/s after %.2fs" % [player.shield_regen_rate, maxf(0.8, player.shield_regen_delay - 0.35 * int(upgrades.get("SHIELD_REBOOT", 0)))],
		"Hit protection": "%.2fs" % (player.collision_grace + 0.12 * int(upgrades.get("KINETIC_DAMPERS", 0))),
	}})
	sections.append({"title": "REACTOR / VENT", "rows": {
		"Final / peak heat": "%.1f / %.1f (cap %.0f)" % [player.heat, ship["peak_heat"], player.max_heat],
		"Heat generated / vented": "%.1f / %.1f" % [ship["heat_generated"], ship["heat_vented"]],
		"Cooling": "%.1f heat/s" % player.heat_cooling_per_second,
		"Time heat-throttled": "%.1fs" % ship["throttled_seconds"],
		"VENT uses / high-heat vents": "%d / %d" % [ship["vents"], ship["hot_vents"]],
		"VENT cooldown": "%.2fs" % maxf(1.7, player.vent_base_cooldown - 0.45 * int(upgrades.get("VENT_COOLANT", 0))),
	}})
	var sources := ["MASS_DRIVER", "MASS_DRIVER_FORK", "MASS_DRIVER_RETURN", "ARC_EXE", "VENT"]
	for source_id in source_stats:
		if not sources.has(source_id):
			sources.append(source_id)
	for source_id in sources:
		var entry := _source_entry(StringName(source_id))
		var damage := float(entry["damage"])
		var rows := {
			"Activations" if source_id in ["ARC_EXE", "VENT"] else "Projectiles fired": entry["attacks"],
			"Hits / kills": "%d / %d" % [entry["hits"], entry["kills"]],
			"Damage / share": "%.1f / %.1f%%" % [damage, damage * 100.0 / maxf(damage_dealt, 0.001)],
			"Average DPS (whole run)": "%.1f" % (damage / duration),
		}
		if source_id == "MASS_DRIVER":
			rows["Round damage / target capacity"] = "24 / %d" % (2 + int(upgrades.get("DRIVER_RAIL", 0)))
			rows["Fire interval (before heat)"] = "%.3fs" % (0.72 / (1.0 + 0.1 * int(upgrades.get("OVERCLOCK_KERNEL", 0))))
		elif source_id == "ARC_EXE":
			rows["Initial damage / chain falloff"] = "13 / 10% per jump"
			rows["Branches / targets per chain"] = "%d / %d" % [1 + int(upgrades.get("ARC_FANOUT", 0)), 3 + int(upgrades.get("CONDUCTIVE_MARK", 0))]
			rows["Cast interval (before heat)"] = "%.3fs" % (1.18 / (1.0 + 0.1 * int(upgrades.get("OVERCLOCK_KERNEL", 0))))
		sections.append({"title": source_id.replace("ARC_EXE", "ARC.EXE"), "rows": rows})
	sections.append({"title": "INSTALLED PATCHES / RANKS", "rows": {
		"Build": "\n".join(build_lines) if not build_lines.is_empty() else "BASELINE / NO PATCHES",
	}})
	var combo: Dictionary = graviton.run_stats.duplicate(true) if is_instance_valid(graviton) else {}
	if _combo_mode:
		combo["phase_uses"] = player.phase_uses
		combo["phase_distance"] = player.phase_distance
		sections.append({"title": "GRAVITON / SALVO KIT", "rows": combo})
	return {"sections": sections, "scorecard": {
		"time": elapsed_time, "kills": kills, "level": level,
		"damage": damage_dealt, "dps": damage_dealt / duration,
		"kills_per_minute": kills * 60.0 / duration,
		"seed": run_seed_text, "sector": "STATIC_PROOF",
		"boss": sections[0]["rows"]["Boss"], "mode": sections[0]["rows"]["Run mode"],
		"xp": total_xp_collected, "pickups": pickups_collected,
		"level_xp": xp, "next_xp": xp_needed,
		"enemies": kills_by_type.duplicate(true), "sources": source_stats.duplicate(true),
		"patches": patch_cards, "patch_ranks": patch_ranks,
		"hull": player.hull, "max_hull": player.max_hull,
		"shield": player.shield, "max_shield": player.max_shield,
		"heat": player.heat, "max_heat": player.max_heat, "ship": ship.duplicate(true),
		"combo": combo, "chassis": "GRAVITON / 01" if _combo_mode else "COURIER / 01",
	}}


func _restart_run() -> void:
	get_tree().paused = false
	if _combat_lab:
		_reset_lab()
		return
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
		"process": "GRAVITON/SALVO+ARC" if _combo_mode else "MASS_DRIVER+ARC.EXE",
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
	if _combo_mode:
		status["phase_cooldown"] = player.phase_cooldown
		status["rack_loaded"] = graviton.loaded_count if graviton.is_charging else 0
		status["rack_affordable"] = mini(int(status["rack_loaded"]), maxi(0, floori((player.max_heat - player.heat) / 4.0)))
		status["rack_charging"] = graviton.is_charging
		status["rack_reload"] = graviton.reload_left
		status["rack_ratio"] = graviton.charge_ratio
		status["lab_live"] = _lab_live
		status["gravity_enabled"] = graviton.gravity_enabled
		status["field_active"] = is_instance_valid(graviton.field) and not graviton.field.expired
	if _combat_lab:
		status.erase("fps")
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
		elif argument == "--classic":
			_combo_mode = false
		elif argument == "--combo-lab":
			_combat_lab = true
			_combo_mode = true
		elif argument.begins_with("--fixture="):
			_lab_fixture = argument.trim_prefix("--fixture=")
		elif argument.begins_with("--loadout="):
			_lab_loadout = argument.trim_prefix("--loadout=")
		elif argument == "--smoke-test":
			_smoke_test = true
		elif argument == "--capture-test":
			_smoke_test = true
			_capture_test = true
		elif argument == "--capture-end-screen":
			_capture_end_screen = true
		elif argument.begins_with("--capture-size="):
			var dimensions := argument.trim_prefix("--capture-size=").split("x")
			if dimensions.size() == 2:
				_capture_viewport_size = Vector2i(maxi(240, int(dimensions[0])), maxi(240, int(dimensions[1])))
		elif argument.begins_with("--capture-page="):
			_capture_scorecard_page = clampi(int(argument.trim_prefix("--capture-page=")), 0, 3)
	if run_seed_text.is_empty():
		run_seed_text = "VOID-0001"
	if _capture_end_screen:
		run_seed_text = END_SCREEN_CAPTURE_SEED
	if _smoke_test or _capture_end_screen:
		_combo_mode = false
	if _lab_fixture not in ["cluster", "dispersed", "boss"]:
		_lab_fixture = "cluster"
	if _lab_loadout not in ["salvo", "gravity", "chain"]:
		_lab_loadout = "chain"


func _seed_roll(channel: String, index: int) -> int:
	return UpgradeCatalogScript.stable_hash("%s|%s|%d" % [run_seed_text, channel, index])


func _start_end_screen_capture() -> void:
	# Do not open the modal from the scene's initial _ready() frame. Windows can
	# report the final viewport size a frame later, which made this visual test
	# intermittently capture only the dimmed background.
	await get_tree().process_frame
	await get_tree().process_frame

	if _capture_viewport_size != Vector2i.ZERO:
		get_window().content_scale_size = Vector2i.ZERO
		get_window().size = _capture_viewport_size
		await get_tree().process_frame
		await get_tree().process_frame
		hud._layout_end_screen()

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
		"VENT_COOLANT": 3,
		"SHIELD_REBOOT": 3,
		"KINETIC_DAMPERS": 2,
	}
	# Synthetic telemetry for the visual fixture only; real runs start at zero.
	source_stats = {
		"MASS_DRIVER": {"attacks": 1560, "hits": 3900, "kills": 480, "damage": 420000.0},
		"MASS_DRIVER_FORK": {"attacks": 960, "hits": 710, "kills": 145, "damage": 100000.0},
		"MASS_DRIVER_RETURN": {"attacks": 860, "hits": 1700, "kills": 180, "damage": 160000.0},
		"ARC_EXE": {"attacks": 930, "hits": 5810, "kills": 403, "damage": 280000.0},
		"VENT": {"attacks": 96, "hits": 212, "kills": 40, "damage": 27654.0},
	}
	kills_by_type = {"bit": 802, "vector": 293, "sentry": 153, "boss": 0}
	total_xp_collected = 3310
	pickups_collected = 1181
	xp = 244
	xp_needed = 305
	for upgrade_id in upgrades:
		for rank in range(1, int(upgrades[upgrade_id]) + 1):
			player.apply_upgrade(upgrade_id, rank)
	player.hull = 0.0
	player.shield = 0.0
	player.heat = 82.0
	player.run_stats.merge({
		"hits_taken": 49, "hull_damage": 189.0, "shield_absorbed": 618.0,
		"hull_repaired": 35.0, "shield_restored": 552.0, "distance": 89000.0,
		"heat_generated": 15088.0, "heat_vented": 5802.0, "peak_heat": 100.0,
		"throttled_seconds": 67.8, "vents": 96, "hot_vents": 61,
	}, true)
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
	hud._set_end_page(_capture_scorecard_page)

	# show_end_screen() pauses the tree. This timer explicitly continues while
	# paused, leaving enough rendered frames for layout and deferred focus.
	await get_tree().create_timer(END_SCREEN_CAPTURE_SETTLE_SECONDS, true, false, true).timeout
	# Synchronize with rendering, not only SceneTree processing. The tree is
	# paused by the modal and a process-frame signal can precede the actual draw.
	await _redraw_report_for_capture()

	var capture_path := ProjectSettings.globalize_path(END_SCREEN_CAPTURE_PATH)
	if _capture_scorecard_page > 0:
		capture_path = capture_path.get_base_dir().path_join("end_screen_page_%d.png" % _capture_scorecard_page)
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


func _redraw_report_for_capture() -> void:
	# Refresh cached GUI draws for hidden Windows GL windows before readback.
	for frame in range(3):
		hud._root.queue_redraw()
		for control in hud._root.find_children("*", "Control", true, false):
			control.queue_redraw()
		await RenderingServer.frame_post_draw


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
