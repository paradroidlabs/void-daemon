extends Node2D

const State := preload("res://src/campaign/campaign_state.gd")
const Catalog := preload("res://src/campaign/chapter_catalog.gd")
const Story := preload("res://src/campaign/story_book.gd")
var state = State.new()
var nodes: Array[Dictionary] = Catalog.nodes()
var game: Node2D
var selected_chassis := "graviton"
var resume_requested := false
var touch_controls := false
var _layer: CanvasLayer
var _surface: ColorRect
var _rows: VBoxContainer
var _actions: GridContainer
var _margin: MarginContainer
var _pending: Dictionary = {}
var _offers: Array[String] = []
var screen_mode := "briefing"
var _scene_id := ""
var _scene_page := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_window().size_changed.connect(_relayout_panel)
	state.chassis = selected_chassis
	if resume_requested and not state.load_checkpoint(nodes.size()):
		_brief("No compatible checkpoint was found. Start a new expedition from the hangar.", true)
		return
	if resume_requested:
		var found := -1
		for i in nodes.size():
			if nodes[i]["id"] == state.node_id:
				found = i
		if state.node_id == "__complete__":
			found = nodes.size()
			# A completed .1/.2 draft is not evidence of escaping the new act.
			# Resume its next unplayed stable node, retaining the earned build.
			if not bool(state.flags.get("escaped",false)):
				var next_id := "power_district" if int(state.flags.get("spine_sites",0))==9 and int(state.flags.get("records_delivered",0))==3 else "memory_spine"
				for i in nodes.size():
					if nodes[i]["id"]==next_id: found=i
		if found < 0:
			_brief("This checkpoint references a mission absent from this build. It has not been overwritten.", true)
			return
		state.chapter = found
	if state.chapter >= nodes.size():
		_ending()
	else:
		briefing()


func _panel(title: String, text: String) -> void:
	get_tree().paused = true
	Music.set_context("hangar")
	if is_instance_valid(_layer):
		_layer.queue_free()
	_layer = CanvasLayer.new()
	_layer.layer = 200
	add_child(_layer)
	_surface = ColorRect.new()
	_surface.color = Color("09131d")
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layer.add_child(_surface)
	var margin := MarginContainer.new()
	_margin=margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	for edge in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + edge, 24)
	_surface.add_child(margin)
	_relayout_panel()
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation",12)
	margin.add_child(layout)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus=true
	layout.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 18)
	scroll.add_child(_rows)
	_actions=GridContainer.new()
	_actions.columns=2
	_actions.add_theme_constant_override("h_separation",12)
	_actions.add_theme_constant_override("v_separation",8)
	layout.add_child(_actions)
	_label("VOID//DAEMON / EXPEDITION / " + state.chassis.to_upper(), 14, Color("68f7e5"))
	_label(title, 26, Color("e2efef"))
	_label(text, 18, Color("b6cbd2"))
	_relayout_panel()


func _relayout_panel() -> void:
	if not is_instance_valid(_margin): return
	var dimensions := get_viewport().get_visible_rect().size
	var ui_scale := 1.0
	var window := Vector2(DisplayServer.window_get_size())
	if DisplayServer.get_name()!="headless" and window.x>0 and window.y>0:
		ui_scale=maxf(1,minf(dimensions.x/window.x,dimensions.y/window.y))
	_margin.scale=Vector2.ONE*ui_scale
	_margin.size=dimensions/ui_scale
	if is_instance_valid(_actions): _actions.columns=1 if _margin.size.x<600 else 2


func _label(value: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	_rows.add_child(label)


func _button(caption: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = caption
	button.clip_text=true
	button.custom_minimum_size.y = 52
	button.size_flags_horizontal=Control.SIZE_EXPAND_FILL
	button.pressed.connect(callback)
	_actions.add_child(button)
	return button


func _brief(text: String, error: bool = false) -> void:
	screen_mode="error" if error else "briefing"
	_panel("CHECKPOINT UNAVAILABLE" if error else "EXPEDITION", text)
	_button("RETURN TO HANGAR", show_menu).grab_focus()


func briefing() -> void:
	var node: Dictionary = nodes[state.chapter]
	var scene := Story.scene_for(node["id"])
	if not scene.is_empty() and not state.flags.has(scene+"_choice"):
		show_story(scene)
		return
	screen_mode="briefing"
	_panel(node["title"], node["text"])
	var route := PackedStringArray()
	for i in nodes.size():
		route.append(("[DONE] " if i < state.chapter else ("[HERE] " if i == state.chapter else "[LOCK] ")) + nodes[i]["title"])
	_label("\n".join(route), 14, Color("819ba5"))
	_label("OBJECTIVE: " + node["objective"], 17, Color("ffc36b"))
	_label("CHECKPOINT: mission entry. Retry restores the entry build and hull. Rewards bank only once, after a completed mission.", 13, Color("819ba5"))
	_button("DEPLOY", deploy).grab_focus()
	_button("HANGAR / LEAVE AT CHECKPOINT", show_menu)


func show_story(scene: String) -> void:
	_scene_id=scene
	screen_mode="story"
	var pages := Story.pages(scene)
	_scene_page=clampi(int(state.flags.get(scene+"_page",0)),0,pages.size()-1)
	var page: Dictionary=pages[_scene_page]
	_panel(page["title"],page["text"])
	var art=load("res://src/ui/story_illustration.gd").new()
	art.scene=page["art"]
	_rows.add_child(art)
	_rows.move_child(art,2)
	_label("PROTOTYPE NARRATIVE / PAGE %d OF %d / NO FORCED READING TIMER" % [_scene_page+1,pages.size()],12,Color("819ba5"))
	if _scene_page>0: _button("PREVIOUS PAGE",story_step.bind(-1))
	if _scene_page<pages.size()-1:
		_button("NEXT PAGE",story_step.bind(1))
	else:
		for choice in Story.choices(scene):
			var button := _button(choice["label"],choose_story.bind(choice["id"]))
			button.disabled=choice["id"]=="spoof" and state.hull<16
			_label(choice["effect"],16,Color("ffc36b"))
	_button("RETURN TO HANGAR / KEEP THIS PAGE",show_menu)
	_rows.get_child(0).focus_mode=Control.FOCUS_ALL
	_rows.get_child(0).grab_focus()

func story_step(direction: int) -> void:
	if screen_mode!="story": return
	state.flags[_scene_id+"_page"]=clampi(_scene_page+direction,0,Story.pages(_scene_id).size()-1)
	var error := state.save_checkpoint()
	show_story(_scene_id)
	if error!=OK: _label("PAGE COULD NOT BE SAVED",14,Color("ff657b"))

func choose_story(choice: String) -> void:
	if screen_mode!="story" or _scene_page!=Story.pages(_scene_id).size()-1 or state.flags.has(_scene_id+"_choice"): return
	var allowed := false
	for item in Story.choices(_scene_id):
		if item["id"]==choice: allowed=true
	if not allowed or (choice=="spoof" and state.hull<16): return
	if _scene_id=="listening_room":
		if choice=="spoof": state.hull-=15
		else:
			var capacity := float(ChassisCatalog.get_ship(state.chassis)["hull"])+18*int(state.upgrades.get("HULL_PLATING",0))
			state.hull=minf(capacity,maxf(0,state.hull)+15)
	if _scene_id=="departure_room" and choice=="independent":
		var capacity := float(ChassisCatalog.get_ship(state.chassis)["hull"])+18*int(state.upgrades.get("HULL_PLATING",0))
		state.hull=minf(capacity,maxf(0,state.hull)+15)
	state.flags[_scene_id+"_choice"]=choice
	_scene_id=""
	var error := state.save_checkpoint()
	briefing()
	if error!=OK: _label("CHOICE COULD NOT BE SAVED",14,Color("ff657b"))

func deploy() -> void:
	var scene := Story.scene_for(nodes[state.chapter]["id"])
	if not scene.is_empty() and not state.flags.has(scene+"_choice"):
		show_story(scene)
		return
	screen_mode="play"
	if is_instance_valid(game):
		game.process_mode=Node.PROCESS_MODE_DISABLED
		game.synth_audio.shutdown()
		game.queue_free()
	if is_instance_valid(_layer):
		_layer.queue_free()
	get_tree().paused = false
	game = load("res://src/main.tscn").instantiate()
	game._honor_command_line = false
	game._chassis = state.chassis
	game._combat_lab = true
	game._campaign_mode = true
	game._campaign_kind = nodes[state.chapter]["kind"]
	game._campaign_flags = state.flags.duplicate(true)
	game._using_touch = touch_controls
	game._lab_fixture = "substrate" if game._campaign_kind == "relay" else "boss"
	game._lab_loadout = "gravity"
	game.run_seed_text = state.seed + "/" + nodes[state.chapter]["id"]
	game.campaign_finished.connect(_on_finished, CONNECT_DEFERRED)
	add_child(game)
	game.upgrades = state.upgrades.duplicate(true)
	for id in game.upgrades:
		for rank in range(1, int(game.upgrades[id]) + 1):
			game.player.apply_upgrade(id, rank)
	game.weapon_controller.set_upgrades(game.upgrades)
	game.weapon_controller.enabled = game._campaign_kind != "transit"
	if state.hull >= 0:
		game.player.hull = clampf(state.hull, 1, game.player.max_hull)
		game.player.shield = clampf(state.shield, 0, game.player.max_shield)
	game.hud.restart_requested.disconnect(game._restart_run)
	game.hud.restart_requested.connect(deploy)
	game._update_hud(true)
	state.node_id = nodes[state.chapter]["id"]
	var result := state.save_checkpoint()
	if result != OK:
		game.hud.flash_log("CHECKPOINT WRITE FAILED / SESSION REMAINS PLAYABLE")


func _on_finished(victory: bool, report: Dictionary) -> void:
	state.record_attempt(nodes[state.chapter]["id"],float(report["scorecard"]["time"]),victory)
	var timing_save := state.save_checkpoint()
	if not victory:
		screen_mode="failed"
		_panel("SIGNAL LOST / RETRY CHECKPOINT", str(report.get("scorecard",{}).get("failure_reason","")) + "\nThe mission was not completed. Your entry loadout and hull are preserved; this attempt does not bank rewards or kills.")
		_button("RETRY MISSION", deploy).grab_focus()
		_button("RETURN TO HANGAR", show_menu)
		if timing_save != OK: _label("Attempt timing could not be saved to disk.",14,Color("ff657b"))
		return
	_pending = report["scorecard"].duplicate(true)
	screen_mode="reward"
	_panel("NODE SECURED / SALVAGE", "A service cradle restores 25 hull and recharges your shield. Choose one recovered patch for the next node.")
	if not _pending.get("transit", {}).is_empty():
		_label("Courier escaped: the next picket receives two reinforcements." if _pending["transit"]["courier_escaped"] else "Courier intercepted: its intelligence never reaches the picket.", 18, Color("ffc36b"))
	_offers.clear()
	for id: String in nodes[state.chapter]["reward"]:
		var definition: Dictionary = UpgradeCatalog.get_definition(StringName(id))
		if int(state.upgrades.get(id, 0)) >= int(definition.get("max_rank", 0)):
			continue
		_offers.append(id)
		_button(id + " / R" + str(int(state.upgrades.get(id, 0)) + 1), claim.bind(id))
		_label(definition["description"], 15, Color("819ba5"))
	_button("CONTINUE WITHOUT A PATCH", claim.bind(""))
	_actions.get_child(_actions.get_child_count() - 1).grab_focus()


func claim(id: String) -> void:
	if _pending.is_empty() or (not id.is_empty() and not _offers.has(id)):
		return
	if not id.is_empty():
		state.upgrades[id] = int(state.upgrades.get(id, 0)) + 1
		game.player.apply_upgrade(id, int(state.upgrades[id]))
	state.seconds += float(_pending["time"])
	if not state.attempts.is_empty(): state.attempts.back()["banked"]=true
	state.kills += int(_pending["kills"])
	state.damage += float(_pending["damage"])
	if not _pending.get("transit", {}).is_empty():
		state.flags["courier_escaped"] = bool(_pending["transit"]["courier_escaped"])
	if not _pending.get("facility", {}).is_empty():
		state.flags["archive_recovered"] = bool(_pending["facility"]["archive_recovered"])
	if not _pending.get("recovery", {}).is_empty():
		state.flags["rescued_carriers"] = int(_pending["recovery"]["rescued_carriers"])
	if not _pending.get("expedition", {}).is_empty():
		state.flags["spine_sites"] = int(_pending["expedition"]["spine_sites"])
		state.flags["records_delivered"] = int(_pending["expedition"]["records_delivered"])
	for field in ["power_circuits","convoy_hull","stronghold_keys"]:
		if _pending.get("tactical",{}).has(field): state.flags[field]=_pending["tactical"][field]
	if _pending.get("tactical",{}).has("escaped"): state.flags["escaped"]=bool(_pending["tactical"]["escaped"])
	var new_capacity: float = game.player.max_hull - float(_pending["max_hull"])
	state.hull = minf(game.player.max_hull, float(_pending["hull"]) + new_capacity + 25)
	state.shield = game.player.max_shield
	state.chapter += 1
	state.node_id = nodes[state.chapter]["id"] if state.chapter < nodes.size() else "__complete__"
	_pending.clear()
	var save_error := state.save_checkpoint()
	if state.chapter >= nodes.size():
		_ending()
	else:
		briefing()
	if save_error != OK:
		_label("WARNING: checkpoint could not be written. Do not close this session if you want to retain progress.", 16, Color("ff657b"))


func _ending() -> void:
	screen_mode="ending"
	var saved := int(state.flags.get("rescued_carriers",0))
	_panel("CHAPTER COMPLETE / THE FIRST ARRIVAL", "The receiver closes behind the ship. For a moment its glass reflects only the station's empty sky. Then the transport answers.\n\nVOICE ONE: Arrival time?\nCONTROL: Now.\nVOICE TWO: Do we have a room?\nSHIP: One that moves.\n\n" + ("All three voices survived the yard. None has to answer alone anymore." if saved==3 else "%d of the three voices survived the yard. The silences between them travel too." % saved) + "\n\nThe ledger writes ARRIVED for the first time. It underlines the word.\n\nSUBSTRATE: UNCERTAINTY.\nSHIP: Keep the underline.\n\nEnd of the current playable chapter. Recorded active mission time is shown below; reading and failed attempts remain separate.")
	_label("COMPLETED MISSION TIME %.1f MIN / KILLS %d / DAMAGE %.0f" % [state.seconds / 60, state.kills, state.damage], 18, Color("ffc36b"))
	_label("MEMORY SPINE / %d SITES SECURED / %d RECORDS BANKED\nThe three records agree on one thing: the berth assignment was issued before the dock was built." % [int(state.flags.get("spine_sites",0)),int(state.flags.get("records_delivered",0))],16,Color("68f7e5"))
	var failed_seconds := 0.0
	for attempt in state.attempts:
		if not attempt["won"]: failed_seconds+=float(attempt["seconds"])
	_label("FAILED ATTEMPTS %.1f MIN / READING AND PAUSES EXCLUDED" % (failed_seconds/60),14,Color("819ba5"))
	for attempt in state.attempts:
		if attempt["banked"]: _label("%s / %.1fs" % [attempt["node"],attempt["seconds"]],14,Color("819ba5"))
	_button("RETURN TO HANGAR", show_menu).grab_focus()


func show_menu() -> void:
	get_tree().paused = false
	shutdown()
	get_parent().call_deferred("show_menu")


func shutdown() -> void:
	if is_instance_valid(game):
		game.synth_audio.shutdown()


func _exit_tree() -> void:
	if is_inside_tree():
		get_tree().paused = false
