extends Node


func _ready() -> void:
	var paths := [
		"res://asset/AssetMainMenu/START.png",
		"res://asset/AssetMainMenu/Setting.png",
		"res://asset/AssetMainMenu/kredit.png",
		"res://asset/AssetMainMenu/KEluar1.png",
		"res://asset/AssetMainMenu/INNERSIA.png",
	]
	for path in paths:
		var img := Image.load_from_file(path)
		print(path.get_file(), " size=", img.get_size(), " used=", img.get_used_rect())
	get_tree().quit()
