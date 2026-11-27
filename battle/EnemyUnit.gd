class_name EnemyUnit
extends Node2D
## One enemy on the battlefield.
##
## Look: edit battle/EnemyUnit.tscn (the shared base) or, for one enemy type,
## its own scene in battle/units/ (these inherit this scene). Then drag that
## scene into the enemy's `unit_scene` slot (data/enemies/*.tres).
## Scene contract (unique names, keep them when restyling):
##   %Visual     Node2D holding the art; flash and the wind-up shift act on it
##   %Body       the art itself: a ColorRect now, replace with Sprite2D /
##               AnimatedSprite2D freely (anything inside %Visual works)
##   %NameLabel  Label, shows "name\nhp/max"
##   %Alert      the "!" shown while an archer winds up
##   %ClickArea  Control that receives clicks (resize it to fit the art)

signal clicked(unit: EnemyUnit)

var data: EnemyData
var hp := 0
## Only set when the enemy has no scene of its own: tints the default box.
var fallback_tint := Color(0, 0, 0, 0)

@onready var _visual: Node2D = %Visual
@onready var _body: CanvasItem = %Body
@onready var _label: Label = %NameLabel
@onready var _alert: CanvasItem = %Alert
@onready var _click: Control = %ClickArea


func setup(d: EnemyData) -> EnemyUnit:
	data = d
	hp = d.max_hp
	return self


func _ready() -> void:
	if fallback_tint.a > 0.0 and _body is ColorRect:
		_body.color = fallback_tint
	_click.gui_input.connect(_on_click_input)
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
	_visual.position.x = -3.0 if on else 0.0


func flash() -> void:
	_visual.modulate = Color(3, 3, 3)
	create_tween().tween_property(_visual, "modulate", Color.WHITE, 0.15)


## Fade out and free. Awaitable.
func die() -> void:
	var t := create_tween()
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	await t.finished
	queue_free()


## Where the target arrow should point: top-center of the click area.
func center_top() -> Vector2:
	return position + Vector2(_click.size.x / 2.0, 0.0)


func _on_click_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
