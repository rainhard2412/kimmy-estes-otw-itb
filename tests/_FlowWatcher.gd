extends Node


func _ready() -> void:
	await get_tree().create_timer(4.0).timeout
	print("story_mode=", GameState.story_mode)
	var cs := get_tree().current_scene
	print("current_scene=", cs.scene_file_path if cs else "null")
	get_tree().quit()
