extends CanvasLayer
## Scene switching with a fade.

var _rect := ColorRect.new()

func _ready() -> void:
	layer = 100
	_rect.color = Color.BLACK
	_rect.modulate.a = 0.0
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_rect)

func change_scene(path: String) -> void:
	var t := create_tween()
	t.tween_property(_rect, "modulate:a", 1.0, 0.3)
	await t.finished
	get_tree().change_scene_to_file(path)
	t = create_tween()
	t.tween_property(_rect, "modulate:a", 0.0, 0.3)
