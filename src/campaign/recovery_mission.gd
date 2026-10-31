extends Node2D

signal completed(result: Dictionary)
signal failed
signal enemy_spawned(actor: Enemy)
signal message(text: String)

const Carrier := preload("res://src/campaign/archive_carrier.gd")
var player: PlayerShip
var pods: Array[Area2D] = []
var actors: Array[Enemy] = []
var cradle: Area2D
var active := true
var clock := 0.0
var failure_reason := ""
var _attach_time := 0.0
var _attach_id := -1
var _triggered: Dictionary = {}
var _thinking := 0.0
var delivery_units := 2

func setup(ship: PlayerShip, flags: Dictionary = {}) -> void:
	delivery_units=3 if flags.get("berth_room_choice","")=="broadcast" else 2
	player=ship
	player.position=Vector2(0,-160)
	player.velocity=Vector2.ZERO
	cradle=Carrier.new()
	cradle.label="SERVICE CRADLE"
	cradle.max_health=220
	cradle.health=220
	cradle.status="DEFEND"
	add_child(cradle)
	var positions := [Vector2(-1280,-600),Vector2(1280,-500),Vector2(-1100,620)]
	for i in positions.size():
		var pod := Carrier.new()
		pod.position=positions[i]
		pod.label="ARCHIVE %d" % (i+1)
		if delivery_units==3:
			pod.health+=50
			pod.max_health+=50
		add_child(pod)
		pods.append(pod)
		_spawn(&"sentry",positions[i]+Vector2(180,-80),pod)
	_spawn(&"vector",Vector2(1100,600),player)

func _spawn(kind: StringName, point: Vector2, target: Node2D) -> void:
	if living_count() >= 6: return
	var actor := Enemy.new()
	actor.configure(kind,point,{"health":100,"speed":90 if kind==&"vector" else 35,"charge_windup":1.0,"shot_windup":1.0,"shot_interval":2.7},target)
	add_child(actor)
	actor.add_to_group("enemy_normal")
	actors.append(actor)
	actor.contact_hit.connect(func(_enemy, receiver, amount):
		if receiver != player and is_instance_valid(receiver) and receiver.has_method("take_damage"): receiver.take_damage(amount)
	)
	enemy_spawned.emit(actor)

func living(actor) -> bool:
	return is_instance_valid(actor) and not actor.is_queued_for_deletion() and actor.is_alive()

func living_count() -> int:
	var count := 0
	for actor in actors:
		if living(actor): count+=1
	return count

func count(status: String) -> int:
	var result := 0
	for pod in pods:
		if pod.status==status: result+=1
	return result

func towed() -> Area2D:
	for pod in pods:
		if pod.status=="TOWING": return pod
	return null

func tick(delta: float) -> void:
	if not active or player.is_dead: return
	clock+=delta
	if not cradle.is_alive() or count("LOST")==pods.size():
		failure_reason="Service cradle destroyed." if not cradle.is_alive() else "All archive carriers were lost."
		active=false
		failed.emit()
		return
	var tow := towed()
	if tow != null:
		if tow.position.distance_to(player.position) > 500:
			tow.status="STRANDED"
			message.emit("TETHER LOST / ARCHIVE STRANDED AT LAST POSITION")
		else:
			var destination := player.position-player.last_move_direction.normalized()*65
			tow.position=tow.position.move_toward(destination,235*delta)
			if tow.position.length()<130 and player.position.length()<180:
				tow.status="BANKED"
				tow.position=Vector2(-80+count("BANKED")*55,65)
				message.emit("ARCHIVE BANKED / INBOUND INTERCEPTORS")
				var banked := count("BANKED")
				if not _triggered.has(banked):
					_triggered[banked]=true
					_spawn(&"vector",Vector2(850,-650),cradle)
					_spawn(&"sentry",Vector2(-850,650),cradle)
					if delivery_units==3: _spawn(&"vector",Vector2(850,650),cradle)
	else:
		var candidate: Area2D
		for pod in pods:
			if pod.status=="STRANDED" and pod.position.distance_to(player.position)<85 and player.velocity.length()<80:
				candidate=pod
				break
		if candidate != null:
			if _attach_id != candidate.get_instance_id():
				_attach_id=candidate.get_instance_id()
				_attach_time=0
			_attach_time+=delta
			if _attach_time>=1.5:
				candidate.status="TOWING"
				_attach_time=0
				message.emit("ARCHIVE TETHERED / RETURN TO THE CENTRAL CRADLE")
		else:
			_attach_time=0
			_attach_id=-1
	_thinking-=delta
	if _thinking<=0:
		_thinking=0.3
		for actor in actors:
			if not living(actor): continue
			var target: Node2D = cradle
			if actor.position.distance_to(player.position)<300: target=player
			else:
				for pod in pods:
					if pod.status in ["STRANDED","TOWING"] and actor.position.distance_to(pod.position)<440:
						target=pod
						break
			actor.set_target(target)
	if count("BANKED")>0 and count("BANKED")+count("LOST")==pods.size() and living_count()==0 and player.position.length()<180:
		active=false
		completed.emit({"rescued_carriers":count("BANKED"),"lost_carriers":count("LOST"),"cradle_hull":cradle.health,"time":clock})
	queue_redraw()

func snapshot() -> Dictionary:
	return {"text":"RECOVERY / SAVED %d / LOST %d / CRADLE %.0f / HOSTILES %d / COAST NEAR A CARRIER TO TETHER" % [count("BANKED"),count("LOST"),cradle.health,living_count()]}

func _draw() -> void:
	var cyan := Color("68f7e5")
	draw_arc(Vector2.ZERO,130,0,TAU,48,cyan,2,true)
	if not is_instance_valid(player): return
	var tow := towed()
	var goal := Vector2.ZERO
	if tow != null:
		draw_dashed_line(player.position,tow.position,cyan,2,10)
	else:
		var distance := INF
		for pod in pods:
			if pod.status=="STRANDED" and player.position.distance_to(pod.position)<distance:
				distance=player.position.distance_to(pod.position)
				goal=pod.position
	var direction := player.position.direction_to(goal)
	draw_line(player.position+direction*50,player.position+direction*105,cyan,3,true)
	draw_string(ThemeDB.fallback_font,player.position+Vector2(-70,75),"RETURN TO CRADLE" if tow != null else "RECOVER / COAST TO TETHER",HORIZONTAL_ALIGNMENT_LEFT,240,11,cyan)
