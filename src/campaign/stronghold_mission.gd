extends "res://src/campaign/tactical_arena.gd"

var core: Enemy
var links: Array[Enemy]=[]
var phase := 0
var keys_broken := 0
var guarded: Dictionary={}
var exit_position := Vector2(-2900,0)
var phase_positions := [
	[Vector2(-2400,-1450),Vector2(2400,1450)],
	[Vector2(-2400,1450),Vector2(2400,-1450)],
	[Vector2(0,-1900),Vector2(0,1900)],
]

func setup(ship: PlayerShip, _flags: Dictionary={}) -> void:
	walls=[Rect2(-1640,-1600,80,1150),Rect2(-1640,450,80,1150),Rect2(1560,-1600,80,1150),Rect2(1560,450,80,1150)]
	for x in [-1800,-1400,1400,1800]:
		for y in [-1750,-250,250,1750]: doors.append(Vector2(x,y))
	begin(ship,exit_position)
	core=load("res://src/actors/command_core.gd").new()
	core.configure(&"sentry",Vector2.ZERO,{"health":1800,"speed":0,"collision_radius":54,"shot_windup":1.25,"shot_interval":2.5,"firing_range":950,"xp":30,"projectile_stats":{"speed":250,"damage":16,"lifetime":4.0}},player)
	core.combat_geometry.assign(walls)
	add_child(core)
	actors.append(core)
	enemy_spawned.emit(core)
	core.barrier_changed.connect(_advance_phase,CONNECT_DEFERRED)
	_start_links()

func _start_links() -> void:
	links.clear()
	for i in range(2):
		var link=load("res://src/actors/substrate_agent.gd").new()
		link.role="relay"
		link.task="CONDUIT / BARRIER"
		link.configure(&"bit",phase_positions[phase][i],{"health":160,"speed":0,"simulation_enabled":false,"xp":3})
		link.combat_geometry.assign(walls)
		add_child(link)
		actors.append(link)
		links.append(link)
		enemy_spawned.emit(link)
	message.emit("WARDEN %d / BREAK TWO CONDUITS / BARRIER CANNOT TAKE DAMAGE" % (phase+1))

func _advance_phase(next_phase: int) -> void:
	if not active: return
	phase=next_phase
	_start_links()

func goal() -> Vector2:
	var distance := INF
	var point := Vector2.ZERO
	for link in links:
		if living(link) and player.position.distance_to(link.position)<distance:
			distance=player.position.distance_to(link.position)
			point=link.position
	if not is_inf(distance): return point
	if living(core): return core.position
	for actor in actors:
		if living(actor): return actor.position
	return exit_position

func tick(delta: float) -> void:
	if not active or player.is_dead: return
	for i in links.size():
		var key := phase*2+i
		if living(links[i]) and player.position.distance_to(links[i].position)<1100 and not guarded.has(key) and live_count()<=6:
			guarded[key]=true
			spawn_guard(links[i].position+Vector2(-300,230),"anchor",key)
			spawn_guard(links[i].position+Vector2(300,-230),"flanker",key)
	if living(core) and core.shielded:
		var all_broken := true
		for link in links:
			if living(link): all_broken=false
		if all_broken:
			keys_broken=(phase+1)*2
			core.set_barrier(false)
			message.emit("BARRIER DOWN / WARDEN EXPOSED / ONE THIRD OF CORE PER PHASE")
	tick_tactics(delta)
	if not living(core) and live_count()==0 and player.position.distance_to(exit_position)<120:
		active=false
		completed.emit({"stronghold_keys":keys_broken,"time":clock})
	queue_redraw()

func snapshot() -> Dictionary:
	return {"text":"WARDEN / PHASE %d OF 3 / CONDUITS %d OF 6 / %s" % [phase+1,keys_broken,"BARRIER ACTIVE -> BREAK CONDUITS" if living(core) and core.shielded else ("CORE EXPOSED" if living(core) else "CLEAR SURVIVORS / EXTRACT WEST")],"phase":phase,"keys":keys_broken}

func _draw() -> void:
	super._draw()
	for link in links:
		if living(link):
			draw_dashed_line(link.position,Vector2.ZERO,Color("b5a0ff",0.3),2,28)
			draw_ring(link.position,"WARDEN CONDUIT / DESTROY",Color("b5a0ff"))
	draw_ring(exit_position,"EXIT / WARDEN DOWN",Color("68f7e5"))
