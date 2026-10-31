extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture(path: String) -> void:
	for i in range(6): await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
func run() -> void:
	root.size=Vector2i(1280,720)
	root.content_scale_size=Vector2i.ZERO
	root.get_node("Experience").persist=false
	var host=load("res://src/campaign/campaign_host.gd").new()
	host.state.persist=false
	host.state.chapter=4
	host.state.node_id="watchdog"
	host.state.hull=80
	root.add_child(host)
	await capture("res://.godot/story-listening-page.png")
	host.story_step(1)
	host.story_step(1)
	await capture("res://.godot/story-listening-choice.png")
	root.size=Vector2i(360,640)
	host._relayout_panel()
	await capture("res://.godot/story-listening-portrait.png")
	root.size=Vector2i(1280,720)
	host._relayout_panel()
	host.show_story("departure_room")
	await capture("res://.godot/story-departure-page.png")
	host.story_step(1)
	host.story_step(1)
	await capture("res://.godot/story-departure-choice.png")
	root.size=Vector2i(360,640)
	host._relayout_panel()
	await capture("res://.godot/story-departure-portrait.png")
	host.queue_free()
	paused=false
	await process_frame
	print("STORY_VISUAL_OK pages / choices / compact layout")
	quit()
