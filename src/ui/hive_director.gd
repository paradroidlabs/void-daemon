class_name HiveDirector
extends CanvasLayer

# Bounded, gameplay-only observation. There is no model, network or personal-data access.
var game: Node2D
var history: Array[Dictionary] = []
var _seen: Dictionary = {}
var _clock := 0.0
var _cooldown := 6.0
var _visible_left := 0.0
var _sample_left := 0.0
var _current := {}
var _pane: Control


class SignalPane extends Control:
	var host: HiveDirector
	func _draw() -> void:
		if host._current.is_empty():
			return
		var color := Color("d799ff")
		var x := minf(360, size.x * 0.4) + 28
		var y := size.y - 92
		var width := size.x - x - 128
		var font := ThemeDB.fallback_font
		if size.x >= 1100 and Experience.narrative_windows:
			var frame := Rect2(x, y, 112, 72)
			draw_style_box(_box(color), frame)
			draw_string(font, Vector2(x + 5, y + 11), "HIVE SENSOR", HORIZONTAL_ALIGNMENT_LEFT, 102, 9, color)
			var center := frame.get_center() + Vector2(0, 5)
			# A top-down tactical PiP derived from live enemy positions, not a looping movie.
			for radius in [14, 25]:
				draw_arc(center, radius, 0, TAU, 32, Color(color, 0.24), 1, true)
			if is_instance_valid(host.game.player):
				var player: PlayerShip = host.game.player
				var heading := Vector2.RIGHT.rotated(player.rotation)
				draw_colored_polygon(PackedVector2Array([center + heading * 6, center - heading * 4 + heading.orthogonal() * 3, center - heading * 4 - heading.orthogonal() * 3]), Color("68f7e5"))
				var index := 0
				for enemy in host.get_tree().get_nodes_in_group("enemies"):
					if index >= 32:
						break
					if is_instance_valid(enemy) and not enemy.is_queued_for_deletion():
						var offset: Vector2 = (enemy.global_position - player.global_position) * 0.05
						if offset.length() < 27:
							draw_circle(center + offset, 1.5, color)
							index += 1
				var velocity: Vector2 = player.velocity * 0.05
				draw_line(center, center + velocity.limit_length(24), Color("ffbd4a"), 1, true)
			x += 124
			width -= 124
		var height := 72.0
		draw_style_box(_box(color), Rect2(x, y, width, height))
		draw_string(font, Vector2(x + 8, y + 12), "HIVE / %s" % host._current.get("event", "SIGNAL").to_upper(), HORIZONTAL_ALIGNMENT_LEFT, width - 16, 10, color)
		var text: String = host._current.get("text", "")
		var chars := text.length() if Experience.reduced_effects else mini(text.length(), int((7.5 - host._visible_left) * 46))
		var line := ""
		var line_y := y + 30
		for word in text.left(maxi(0, chars)).split(" "):
			if font.get_string_size(line + word, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x > width - 16:
				draw_string(font, Vector2(x + 8, line_y), line, HORIZONTAL_ALIGNMENT_LEFT, width - 16, 11, Color("eee0f7"))
				line_y += 14
				line = ""
				if line_y > y + height - 4:
					return
			line += word + " "
		draw_string(font, Vector2(x + 8, line_y), line, HORIZONTAL_ALIGNMENT_LEFT, width - 16, 11, Color("eee0f7"))

	func _box(color: Color) -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("0c111d")
		box.border_color = Color(color, 0.55)
		box.set_border_width_all(1)
		return box


func _ready() -> void:
	layer = 70
	_pane = SignalPane.new()
	_pane.host = self
	_pane.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_pane)


func reset() -> void:
	history.clear()
	_seen.clear()
	_clock = 0
	_cooldown = 6
	_visible_left = 0
	_current.clear()
	Experience.stop_voice()


func transmit(event: String, text: String, urgent: bool = false) -> bool:
	if _seen.has(event) or (not urgent and _cooldown > 0):
		return false
	_seen[event] = true
	_current = {"event": event, "text": text, "time": _clock}
	history.append(_current.duplicate())
	if history.size() > 12:
		history.pop_front()
	_cooldown = 22
	_visible_left = 7.5
	Experience.speak(text)
	if is_instance_valid(game.synth_audio):
		game.synth_audio.play_cue(&"hive_link")
	return true


func observe(delta: float) -> void:
	if not is_instance_valid(game) or game.run_ended or get_tree().paused:
		_pane.visible = false
		return
	_clock += delta
	_cooldown = maxf(0, _cooldown - delta)
	_visible_left = maxf(0, _visible_left - delta)
	_pane.visible = _visible_left > 0
	_pane.size = get_viewport().get_visible_rect().size
	_pane.queue_redraw()
	_sample_left -= delta
	if _sample_left > 0 or _cooldown > 0:
		return
	_sample_left = 0.3
	var ship: PlayerShip = game.player
	var flight: Dictionary = ship.get_flight_telemetry()
	if is_instance_valid(game.boss) and game.boss.phase >= 2:
		transmit("watchdog_phase", "It has changed its rhythm. Will you change yours?")
	elif ship.heat > 85:
		transmit("reactor", "Your reactor is almost speaking our language. Keep holding.")
	elif ship.shield <= 0:
		transmit("shield", "The second skin is gone. Now we can hear the hull.")
	elif flight["speed"] > 70 and flight["gravity"].length() > 20 and flight["throttle"] < 0.1:
		transmit("gravity_coast", "You stopped burning. You did not stop arriving.")
	elif flight["speed"] > 100 and flight["drift"] > 95:
		transmit("cross_drift", "Your nose points away. Your body still comes toward us.")
	elif ship.phase_uses >= 3:
		transmit("escape_habit", "Three exits. We are learning the shape of your absence.")
	elif is_instance_valid(game.graviton) and game.graviton.run_stats["charges"] >= 4:
		transmit("attack_habit", "Again. That is a rhythm we can remember.")
	else:
		var greeting: String = {"graviton": "You gather us into a single thought. Then you break it apart.", "bastion": "A straight line. Such a small answer to so many bodies.", "scrapper": "You collect what we leave behind. What will you do with us?", "redline": "Come closer. We can both pretend that heat is courage."}.get(game._chassis, "We have noticed you.")
		transmit("first_contact", greeting)


func silence() -> void:
	_pane.visible = false
	Experience.stop_voice()


func _exit_tree() -> void:
	Experience.stop_voice()
