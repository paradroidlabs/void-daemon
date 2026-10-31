extends Enemy

signal barrier_changed(stage: int)
var shielded := true
var stage := 0
var is_dead := false
var task := "BARRIER / CONDUITS"

func _ready() -> void:
	super._ready()
	var bar=load("res://src/ui/boss_health_bar.gd").new()
	add_child(bar)
	set_barrier(true)

func set_barrier(value: bool) -> void:
	shielded=value
	set_deferred("collision_layer",0 if value else 2)
	if value:
		if is_in_group("enemies"): remove_from_group("enemies")
	else:
		if not is_in_group("enemies"): add_to_group("enemies")
	queue_redraw()

func take_damage(amount: float, source_id: StringName=&"unknown", hit_position: Vector2=Vector2.ZERO) -> bool:
	if shielded or not _alive: return false
	var floor_health := max_health*float(2-stage)/3
	var applied := minf(amount,maxf(0,health-floor_health)) if stage<2 else amount
	var accepted := super.take_damage(applied,source_id,hit_position)
	if _alive and stage<2 and health<=floor_health+0.001:
		stage+=1
		shot_interval=maxf(1.3,2.5-stage*0.4)
		set_barrier(true)
		barrier_changed.emit(stage)
	is_dead=not _alive
	return accepted

func set_gravity_velocity(_value: Vector2) -> void: pass
func apply_impulse(_value: Vector2) -> void: pass
func get_health_ratio() -> float: return health/max_health

func _draw() -> void:
	if not _alive: return
	var color := Color("b5a0ff") if shielded else Color("ff657b")
	draw_circle(Vector2.ZERO,50,Color("190e25"))
	draw_arc(Vector2.ZERO,54,0,TAU,48,color,3,true)
	var corners := PackedVector2Array()
	for i in range(7): corners.append(Vector2.RIGHT.rotated(i*TAU/6+_age_ticks/180.0)*42)
	draw_polyline(corners,color,2,true)
	draw_circle(Vector2.ZERO,18,color)
	if shielded: draw_arc(Vector2.ZERO,76,0,TAU,64,Color(color,0.55),4,true)
	if _state==STATE_AIM: _draw_lane_telegraph(_facing,Color("ffc36b"))
	draw_string(ThemeDB.fallback_font,Vector2(-125,-94),"SUBSTRATE / WARDEN %d" % (stage+1),HORIZONTAL_ALIGNMENT_LEFT,280,14,color)
	draw_string(ThemeDB.fallback_font,Vector2(-145,107),"BARRIER / BREAK TWO CONDUITS" if shielded else "EXPOSED / COMMIT YOUR SALVO",HORIZONTAL_ALIGNMENT_LEFT,320,12,color)
