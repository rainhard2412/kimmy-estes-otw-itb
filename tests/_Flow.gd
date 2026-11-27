extends Node


func _ready() -> void:
	var menu: Control = load("res://MainMenuAwal.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	await get_tree().process_frame

	var sb: TextureButton = menu.get_node("StartArea/StartButton")
	var mask: BitMap = sb.texture_click_mask
	print("click_mask_size=", mask.get_size())
	print("click_mask_center=", mask.get_bit(960, 476))
	print("click_mask_bottom=", mask.get_bit(960, 1000))

	# Settings / credits are only reachable from the title screen.
	var settings: Control = menu.get_node("SettingsPanel")
	menu.get_node("TopRightMenu/SettingsButton").pressed.emit()
	await get_tree().create_timer(0.2).timeout
	print("settings_panel=", settings.visible)
	settings.get_node("Panel/BackButton").pressed.emit()
	print("settings_closed=", not settings.visible)

	var credits: Control = menu.get_node("CreditsPanel")
	menu.get_node("TopRightMenu/CreditsButton").pressed.emit()
	await get_tree().create_timer(0.2).timeout
	print("credits_panel=", credits.visible)
	credits.get_node("Panel/BackButton").pressed.emit()
	print("credits_closed=", not credits.visible)

	sb.pressed.emit()
	await get_tree().create_timer(0.35).timeout
	print("mode_panel=", menu.get_node("ModePanel").visible)
	print("start_area=", menu.get_node("StartArea").visible)

	var watcher := Node.new()
	watcher.set_script(load("res://tests/_FlowWatcher.gd"))
	get_tree().root.add_child(watcher)
	menu.get_node("ModePanel/StoryButton").pressed.emit()
	# Mode choice shows the ship first; a second press launches it.
	await get_tree().create_timer(2.0).timeout
	print("ship_visible=", menu.get_node("Ship").visible)
	menu._launch()
