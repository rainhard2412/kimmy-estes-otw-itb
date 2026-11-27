extends Node
## Debug tool (needs a real window, not --headless): saves screenshots of the
## main screens so a refactor can be compared before/after.
##   godot --path . res://tests/ShotScenes.tscn -- before
##   godot --path . res://tests/ShotScenes.tscn -- after
## PNGs go to %TEMP%/shot_<tag>_<name>.png

var tag := "before"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		tag = args[0]
	await _battle()
	await _management()
	get_tree().quit()

func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw

func _shot(name: String) -> void:
	var path := "C:/Users/Baram/AppData/Local/Temp/shot_%s_%s.png" % [tag, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)

func _battle() -> void:
	var b: Node = preload("res://battle/Battle.tscn").instantiate()
	b.pace = 0.01
	add_child(b)
	await _frames(40)
	_shot("battle")
	# Circle minigame: skill 4 (Hantaman Kalpataru)
	b.use_skill(3)
	await _frames(3)
	_shot("battle_circle_early")   # ring should still be ~3x the disc
	await _frames(22)
	_shot("battle_circle")
	b.queue_free()
	await _frames(2)

func _management() -> void:
	var m: Node = preload("res://management/Management.tscn").instantiate()
	add_child(m)
	await _frames(40)
	_shot("arena")
	m.sim.trigger_error("daya")
	m.map.open()
	await _frames(8)
	_shot("map")
	m.request_repair("daya")
	await _frames(8)
	_shot("repair")
	m.queue_free()
	await _frames(2)
