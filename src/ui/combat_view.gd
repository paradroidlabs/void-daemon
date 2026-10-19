extends SubViewportContainer

# Combat is rendered into its own rectangle. HUD pixels can never cover it.
var arena: SubViewport
var camera: Camera2D
var zoom_level := 0.82
var lab := false
var footer_height := 120.0


func _init() -> void:
	name = "UnobstructedCombatView"
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena = SubViewport.new()
	arena.name = "CombatViewport"
	arena.world_2d = World2D.new()
	arena.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	arena.handle_input_locally = false
	add_child(arena)


func _ready() -> void:
	get_viewport().size_changed.connect(relayout)
	relayout()


func relayout() -> void:
	var screen := get_viewport().get_visible_rect().size
	var top := 132.0 if lab else 82.0
	position = Vector2(0, top)
	size = Vector2(maxf(1, screen.x), maxf(64, screen.y - top - footer_height))
	queue_redraw()


func attach_camera(value: Camera2D) -> void:
	camera = value
	set_zoom_level(zoom_level)


func set_zoom_level(value: float) -> void:
	zoom_level = clampf(value, 0.65, 1.25)
	if is_instance_valid(camera):
		camera.zoom = Vector2.ONE * zoom_level
		camera.force_update_scroll()


func adjust_zoom(direction: float) -> void:
	set_zoom_level(zoom_level + direction * 0.08)


func screen_to_world(point: Vector2) -> Vector2:
	return arena.get_canvas_transform().affine_inverse() * (point - position)


func world_to_screen(point: Vector2) -> Vector2:
	return position + arena.get_canvas_transform() * point


func contains_screen_point(point: Vector2) -> bool:
	return Rect2(position, size).has_point(point)


func spawn_position(player_position: Vector2, angle: float, jitter: float, bounds: Rect2) -> Vector2:
	var half := size / (2 * zoom_level)
	var center := screen_to_world(position + size * 0.5)
	var fallback := player_position
	var farthest := 0.0
	for turn in 8:
		var direction := Vector2.RIGHT.rotated(angle + turn * PI / 4)
		var edge := minf(half.x / maxf(absf(direction.x), 0.001), half.y / maxf(absf(direction.y), 0.001))
		var candidate := center + direction * maxf(520, edge + 60 + jitter * 80)
		candidate.x = clampf(candidate.x, bounds.position.x + 36, bounds.end.x - 36)
		candidate.y = clampf(candidate.y, bounds.position.y + 36, bounds.end.y - 36)
		var distance := candidate.distance_to(player_position)
		if distance > farthest:
			farthest = distance
			fallback = candidate
		if distance >= 390 and not contains_screen_point(world_to_screen(candidate)):
			return candidate
	# If a very large window sees the whole bounded arena, prefer distance over
	# pretending an offscreen location exists.
	return fallback


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("29434e"), false, 1)
