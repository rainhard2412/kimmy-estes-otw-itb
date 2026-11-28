extends Node
## Quick preview: opens the vent room with the camera already on the fan.
## WASD / arrow keys pan, Esc closes.

func _ready() -> void:
	var scene: Node2D = load("res://DalamKapal/RuangVentilasi/RuangVentilasi.tscn").instantiate()
	add_child(scene)
	var fan: Node2D = scene.get_node("Actors/VentFan1")
	var cam: Camera2D = scene.get_node("Camera2D")
	cam.position_smoothing_enabled = false
	cam.zoom = Vector2(1.7, 1.7)          # Close in so all four fans fill the view.
	cam.position = fan.position + Vector2(32, 32)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
