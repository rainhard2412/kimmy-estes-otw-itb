class_name PlayerUnit
extends Node2D
## Bara on the battlefield.
##
## Look: edit battle/PlayerUnit.tscn. Scene contract (unique names):
##   %Visual (Node2D holding the art; flash acts on it)  %Body (the art)
##   %NameLabel (Label, shows "Bara\nhp/max")

@onready var _visual: Node2D = %Visual
@onready var _label: Label = %NameLabel


func set_hp(hp: int, max_hp: int) -> void:
	_label.text = "Bara\n%d/%d" % [hp, max_hp]


func flash() -> void:
	_visual.modulate = Color(3, 3, 3)
	create_tween().tween_property(_visual, "modulate", Color.WHITE, 0.15)
