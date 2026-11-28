extends Node
## Screenshot harness for DalamKapal/RuangVentilasi/RuangVentilasi.tscn.
## Shoots the room from a few camera positions and diffs two frames taken a moment
## apart to prove the space background is really scrolling.

const OUT_DIR := "res://tests/_shots"


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var scene: Node2D = load("res://DalamKapal/RuangVentilasi/RuangVentilasi.tscn").instantiate()
	add_child(scene)

	var room: Node2D = scene.get_node("Ship")
	var cam: Camera2D = scene.get_node("Camera2D")
	var bg: SpaceBackground = scene.get_node("SpaceBackground")
	cam.position_smoothing_enabled = false

	print("cells floor=", room.get_node("Floor").get_used_cells().size(),
		" hull=", room.get_node("Hull").get_used_cells().size(),
		" props=", room.get_node("Props").get_used_cells().size())
	print("room rect (tiles)=", (room.get_node("Floor") as TileMapLayer).get_used_rect())

	# Top-left corner: hull edge plus the space behind it.
	cam.position = Vector2(150, 80)
	await _wait(0.5)
	var a := await _snap("corner_tl_a.png")
	await _wait(1.5)
	var b := await _snap("corner_tl_b.png")
	print("moving pixels between frames: ", _diff(a, b), " (0 would mean the background is static)")

	cam.position = Vector2(330, 215)
	await _wait(0.3)
	await _snap("corner_br.png")

	cam.position = Vector2(224, 144)
	await _wait(0.3)
	await _snap("center.png")

	print("speed=", bg.current_speed)
	for layer: Parallax2D in [bg.get_node("Nebula"), bg.get_node("StarsFar"),
			bg.get_node("StarsMid"), bg.get_node("StarsNear")]:
		print(layer.name, " depth=", layer.scroll_scale.x, " offset=", layer.scroll_offset)
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _snap(file: String) -> Image:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OUT_DIR.path_join(file))
	print("saved ", file, " ", img.get_size())
	return img


## Counts pixels that changed between two frames, sampled on a grid.
func _diff(a: Image, b: Image) -> int:
	var changed := 0
	for y in range(0, a.get_height(), 4):
		for x in range(0, a.get_width(), 4):
			if a.get_pixel(x, y) != b.get_pixel(x, y):
				changed += 1
	return changed
