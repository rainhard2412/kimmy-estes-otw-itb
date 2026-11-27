extends Node


func _ready() -> void:
	var menu: Control = load("res://MainMenuAwal.tscn").instantiate()
	add_child(menu)
	await get_tree().create_timer(1.0).timeout
	var area: Control = menu.get_node("StartArea")
	var sb: TextureButton = menu.get_node("StartArea/StartButton")
	print("area visible=", area.visible, " mod=", area.modulate, " scale=", area.scale, " pos=", area.position, " size=", area.size)
	print("start visible=", sb.visible, " self_mod=", sb.self_modulate, " mod=", sb.modulate, " scale=", sb.scale, " pos=", sb.position, " size=", sb.size)
	print("start texture=", sb.texture_normal, " disabled=", sb.disabled, " mask=", sb.texture_click_mask)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://tests/_current_menu.png")
	get_tree().quit()
