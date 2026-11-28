extends Node
## Quick preview of the ventilation room: walk the placeholder player around with
## WASD / arrows and watch the door open as you approach. Esc closes.
## The room's camera frames the whole room, so the door is always in view.

func _ready() -> void:
	var scene: Node2D = load("res://DalamKapal/RuangVentilasi/RuangVentilasi.tscn").instantiate()
	add_child(scene)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
