extends Node
## Plays Chapter1 and saves screenshots along the cutscene, then walks Bara.

var _tree: SceneTree


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/_ch1_%s.png" % name)


func _wait(s: float) -> void:
	await _tree.create_timer(s).timeout


func _press_accept() -> void:
	var ev := InputEventAction.new()
	ev.action = "ui_accept"
	ev.pressed = true
	Input.parse_input_event(ev)
	await _tree.process_frame
	ev = ev.duplicate()
	ev.pressed = false
	Input.parse_input_event(ev)


func _ready() -> void:
	_tree = get_tree()
	var ch: Node = load("res://Scene/Chapter1/Chapter1.tscn").instantiate()
	add_child(ch)
	await _wait(1.9)
	await _shot("1_half_open")
	await _wait(3.8)   # 5.7
	await _shot("2_peek")
	await _wait(1.25)  # 6.95 — just after the door
	await _shot("3_door")
	await _wait(1.6)   # 8.55 — mid zoom out
	await _shot("4_zoom")
	await _wait(2.2)   # ~10.7 — first dialogue line typed
	await _shot("5_dialog_rehan")
	for i in 3:
		await _press_accept()  # finish typing
		await _wait(0.1)
		await _press_accept()  # next line
		await _wait(2.4)
	await _shot("6_dialog_thought")
	print("dialog_active=", ch.get_node("DialogueBox").is_active())
	await _press_accept()
	await _wait(0.1)
	await _press_accept()
	await _wait(1.4)
	var bara: Node2D = ch.get_node("Actors/Bara")
	print("can_move=", bara.can_move, " pos=", bara.position)
	Input.action_press("move_right")
	await _wait(1.0)
	Input.action_release("move_right")
	Input.action_press("move_up")
	await _wait(0.5)
	Input.action_release("move_up")
	await _wait(0.3)
	print("after_walk pos=", bara.position)
	await _shot("7_gameplay")
	_tree.quit()
