extends Area2D

var health := 140.0
var max_health := 140.0
var status := "STRANDED"
var label := "CARRIER"
var _contact_left := 0.0

func _ready() -> void:
	collision_layer = 1
	collision_mask = 2
	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 20
	collision.shape = circle
	add_child(collision)
	set_meta("team",&"player")

func get_team() -> StringName: return &"player"
func is_alive() -> bool: return health > 0
func receive_contact_hit(amount: float) -> void: take_damage(amount)
func take_damage(amount: float) -> void:
	if status in ["BANKED","LOST"] or _contact_left > 0: return
	health = maxf(0,health-maxf(0,amount))
	_contact_left = 0.4
	if health == 0: status="LOST"
	queue_redraw()

func _physics_process(delta: float) -> void:
	_contact_left = maxf(0,_contact_left-delta)
	queue_redraw()

func _draw() -> void:
	var color := Color("68f7e5") if status != "LOST" else Color("ff657b")
	if status=="BANKED": color=Color("8bdfa4")
	draw_rect(Rect2(-18,-12,36,24),color,false,2)
	draw_line(Vector2(-12,0),Vector2(12,0),color,2)
	draw_rect(Rect2(-22,22,44,4),Color("263b44"))
	draw_rect(Rect2(-22,22,44*health/max_health,4),color)
	draw_string(ThemeDB.fallback_font,Vector2(-65,-32),label+" / "+status,HORIZONTAL_ALIGNMENT_LEFT,180,10,color)
