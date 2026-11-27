extends Node
## Debug tool (needs a real window, not --headless): opens the node map, saves
## screenshots, and sends synthetic mouse drags to see whether panning works.
##   godot --path . res://tests/ShotMap.tscn

const OUT := "C:/Users/Baram/AppData/Local/Temp/shot_map_%s.png"

func _ready() -> void:
	var m: Management = preload("res://management/Management.tscn").instantiate()
	add_child(m)
	for i in 30:
		await get_tree().process_frame     # let enemies walk in a bit
	m.sim.trigger_error("daya")
	m.map.open()
	await _frames(6)
	_shot("1_open")
	print("map visible=", m.map.visible, " size=", m.map.size, " pan=", m.map.pan,
		" viewport=", get_viewport().get_visible_rect().size)

	var vp := get_viewport()
	var start := Vector2(160, 60)           # empty area between nodes
	_mouse(vp, start, true)
	for k in 10:
		_motion(vp, start + Vector2(-8, 0) * (k + 1), Vector2(-8, 0))
		await get_tree().process_frame
	_mouse(vp, start + Vector2(-80, 0), false)
	await _frames(4)
	print("after dragging 80px left: pan=", m.map.pan)
	_shot("2_after_drag")
	get_tree().quit()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _shot(tag: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT % tag)
	print("saved ", OUT % tag, " ", img.get_size())

func _mouse(vp: Viewport, pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	vp.push_input(e, true)

func _motion(vp: Viewport, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.position = pos
	e.global_position = pos
	e.relative = rel
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	vp.push_input(e, true)
