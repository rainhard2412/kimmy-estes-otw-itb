class_name EnemyUnit
extends Node2D
## One enemy on the battlefield. Placeholder box until real sprites exist.

signal clicked(unit: EnemyUnit)

const SIZE := Vector2(28, 44)

var data: EnemyData
var hp := 0

var _box := ColorRect.new()
var _label := Label.new()
var _alert := Label.new()

func setup(d: EnemyData) -> EnemyUnit:
	data = d
	hp = d.max_hp
	return self

func _ready() -> void:
	_box.color = data.color
	_box.size = SIZE
	_box.gui_input.connect(_on_box_input)
	add_child(_box)
	_label.add_theme_font_size_override("font_size", 8)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(48, 22)
	_label.position = Vector2((SIZE.x - 48) / 2.0, -24)
	add_child(_label)
	_alert.text = "!"
	_alert.add_theme_font_size_override("font_size", 16)
	_alert.add_theme_color_override("font_color", Color.YELLOW)
	_alert.position = Vector2(SIZE.x / 2.0 - 3, 8)
	_alert.hide()
	add_child(_alert)
	refresh()

func is_alive() -> bool:
	return hp > 0

func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)
	refresh()
	flash()

func refresh() -> void:
	_label.text = "%s\n%d/%d" % [data.label(), hp, data.max_hp]

## Wind-up pose before a ranged shot: tells the player to get ready to block.
func set_telegraph(on: bool) -> void:
	_alert.visible = on
	_box.position.x = -3.0 if on else 0.0

func flash() -> void:
	_box.modulate = Color(3, 3, 3)
	create_tween().tween_property(_box, "modulate", Color.WHITE, 0.15)

## Fade out and free. Awaitable.
func die() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	await t.finished
	queue_free()

func center_top() -> Vector2:
	return position + Vector2(SIZE.x / 2.0, 0)

func _on_box_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
