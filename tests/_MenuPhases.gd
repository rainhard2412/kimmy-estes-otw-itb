extends Node
## Drives the main menu through every phase and saves a screenshot of each.


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/_menu_%s.png" % name)


func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _ready() -> void:
	var menu: Control = load("res://MainMenuAwal.tscn").instantiate()
	add_child(menu)
	await _wait(2.0)
	await _shot("1_idle")

	menu.get_node("StartArea/StartButton").pressed.emit()
	await _wait(0.6)
	menu.get_node("ModePanel/EndlessButton").grab_focus()
	await _wait(0.3)
	await _shot("2_mode")

	menu.get_node("ModePanel/EndlessButton").pressed.emit()
	await _wait(2.2)
	await _shot("3_ready")
	print("phase_after_choose=", menu._phase)

	menu._launch()
	# The scene change frees this node, so let the tree itself quit later.
	var tree := get_tree()
	tree.create_timer(4.5).timeout.connect(func():
		print("story_mode=", GameState.story_mode)
		print("current_scene=", tree.current_scene.scene_file_path if tree.current_scene else "null")
		tree.quit())
	await _wait(0.5)
	await _shot("4_charge")
	await _wait(0.6)
	await _shot("5_warp")
	await _wait(0.5)
	await _shot("6_warp_late")
