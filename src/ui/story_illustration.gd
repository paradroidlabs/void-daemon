extends Control
var scene := "archive"

func _ready() -> void:
	custom_minimum_size=Vector2(160,150)
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var cyan := Color("68f7e5")
	var purple := Color("b4a0ff")
	var center := size*0.5
	draw_rect(Rect2(Vector2.ZERO,size),Color("101e28"))
	draw_rect(Rect2(Vector2.ZERO,size),Color("29424e"),false,1)
	if scene=="archive":
		for i in range(3):
			var c := center+Vector2((i-1)*85,0)
			draw_rect(Rect2(c-Vector2(28,20),Vector2(56,40)),cyan,false,2)
			draw_line(c-Vector2(16,0),c+Vector2(16,0),cyan,2)
			draw_dashed_line(c+Vector2(0,26),center+Vector2(0,58),Color(cyan,0.4),1,5)
	elif scene=="gate":
		for side in [-1,1]:
			draw_rect(Rect2(center+Vector2(side*70-28,-55),Vector2(56,110)),purple,false,2)
		for i in range(5):
			draw_line(center+Vector2(-40,-40+i*20),center+Vector2(40,-40+i*20),Color(cyan,0.35),1)
	else:
		for radius in [24,44,64]: draw_arc(center,radius,0,TAU,64,purple,1,true)
		for i in range(8):
			var p := center+Vector2.RIGHT.rotated(i*TAU/8)*64
			draw_circle(p,3,cyan)
			draw_line(p,center,Color(cyan,0.25),1)
	draw_string(ThemeDB.fallback_font,Vector2(12,20),"ARCHIVE VIEW / RECONSTRUCTION",HORIZONTAL_ALIGNMENT_LEFT,size.x-24,11,Color("819ba5"))
