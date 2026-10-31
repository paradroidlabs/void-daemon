extends Node2D

## Shared physical/perception rules for authored second-act encounters.
## No wave clock, invisible damage scaling or access to out-of-sight positions.
signal completed(result: Dictionary)
signal failed
signal enemy_spawned(actor: Enemy)
signal message(text: String)

var player: PlayerShip
var bounds := Rect2(-3300,-2500,6600,5000)
var walls: Array[Rect2]=[]
var doors: Array[Vector2]=[]
var actors: Array[Enemy]=[]
var active := true
var clock := 0.0
var failure_reason := ""
var _think_left := 0.0
var _waypoint := Vector2.ZERO

func begin(ship: PlayerShip, start: Vector2) -> void:
	player=ship
	player.position=start
	player.velocity=Vector2.ZERO
	player.arena_bounds=bounds
	player.collision_mask |= 16
	player.combat_geometry.assign(walls)
	for rect in walls:
		var body := StaticBody2D.new()
		body.position=rect.get_center()
		body.collision_layer=16
		body.collision_mask=1
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size=rect.size
		collision.shape=shape
		body.add_child(collision)
		add_child(body)

func room_grid() -> void:
	# Six rooms, two rows, connected through six 600-unit doorways.
	for x in [-1200,1200]:
		for span in [Vector2(-2500,700),Vector2(-1200,2400),Vector2(1800,700)]:
			walls.append(Rect2(x-30,span.x,60,span.y))
		for y in [-1500,1500]:
			doors.append(Vector2(x-120,y))
			doors.append(Vector2(x+120,y))
	for span in [Vector2(-3300,600),Vector2(-2100,1800),Vector2(300,1800),Vector2(2700,600)]:
		walls.append(Rect2(span.x,-30,span.y,60))
	for x in [-2400,0,2400]:
		doors.append(Vector2(x,-120))
		doors.append(Vector2(x,120))

func living(actor) -> bool:
	return is_instance_valid(actor) and not actor.is_queued_for_deletion() and actor.is_alive()

func live_count() -> int:
	var count := 0
	for actor in actors:
		if living(actor): count+=1
	return count

func contested(point: Vector2, radius: float=650) -> bool:
	for actor in actors:
		if living(actor) and actor.position.distance_to(point)<radius: return true
	return false

func spawn_guard(point: Vector2, role: String="flanker", squad: int=0) -> Enemy:
	if live_count()>=8: return null
	var actor=load("res://src/actors/substrate_agent.gd").new()
	actor.role=role
	actor.stable_id="detail_%d_%d" % [squad,actors.size()]
	var kind: StringName=&"sentry" if role=="anchor" else (&"vector" if role=="flanker" else &"bit")
	actor.configure(kind,point,{"health":170 if role=="anchor" else (130 if role=="flanker" else 90),"speed":25 if role=="anchor" else 110,"initial_action_delay":0.25,"charge_trigger_range":370,"charge_speed":340,"charge_windup":1.0,"shot_windup":1.0,"shot_interval":2.2,"firing_range":850,"projectile_stats":{"speed":320,"lifetime":3.0,"damage":10},"xp":2})
	actor.combat_geometry.assign(walls)
	actor.set_meta("home",point)
	actor.set_meta("seen_at",-100.0)
	actor.set_meta("squad",squad)
	add_child(actor)
	actor.add_to_group("enemy_normal")
	actors.append(actor)
	enemy_spawned.emit(actor)
	return actor

func target_for(_actor: Enemy) -> Node2D: return player
func goal() -> Vector2: return Vector2.ZERO

func tick_tactics(delta: float) -> void:
	clock+=delta
	_think_left-=delta
	if _think_left>0: return
	_think_left=0.2
	_waypoint=CombatGeometry.waypoint(player.position,goal(),walls,doors)
	for actor in actors:
		if not living(actor) or not actor.simulation_enabled: continue
		var target := target_for(actor)
		var visible := is_instance_valid(target) and actor.position.distance_to(target.position)<950 and CombatGeometry.clear(actor.position,target.position,walls)
		if visible:
			actor.set_meta("seen_at",clock)
			actor.set_meta("seen_point",target.position)
			actor.set_target(target)
			actor.task="CONTACT / SIGHT"
		elif clock-float(actor.get_meta("seen_at",-100))<3:
			var point: Vector2=actor.get_meta("seen_point")
			actor.set_target_position(CombatGeometry.waypoint(actor.position,point,walls,doors))
			actor.task="SEARCH / LAST SEEN"
		else:
			actor.clear_target()
			actor.task="GUARD / NO CONTACT"

func coast_at(point: Vector2, radius: float=95) -> bool:
	return player.position.distance_to(point)<radius and player.velocity.length()<85

func draw_ring(point: Vector2, label: String, color: Color, progress: float=0) -> void:
	draw_arc(point,95,0,TAU,40,color,2,true)
	if progress>0: draw_arc(point,105,-PI/2,-PI/2+clampf(progress,0,1)*TAU,40,color,4,true)
	draw_string(ThemeDB.fallback_font,point+Vector2(-95,-125),label,HORIZONTAL_ALIGNMENT_LEFT,260,13,color)

func _draw() -> void:
	for rect in walls:
		draw_rect(rect,Color("142932"))
		draw_rect(rect,Color("4c7782"),false,2)
	if is_instance_valid(player):
		var direction := player.position.direction_to(_waypoint)
		draw_line(player.position+direction*55,player.position+direction*115,Color("68f7e5"),3,true)
