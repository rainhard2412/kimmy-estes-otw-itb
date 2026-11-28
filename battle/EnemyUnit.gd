class_name EnemyUnit
extends BattleUnit
## One enemy on the battlefield. Its animation poses (attack, hurt, windup,
## stunned, die, idle) are explained in battle/BattleUnit.gd.
##
## Look: edit battle/EnemyUnit.tscn (the shared base) or, for one enemy type,
## its own scene in battle/units/ (these inherit this scene). Then drag that
## scene into the enemy's `unit_scene` slot (data/enemies/*.tres).
## Scene contract (unique names, keep them when restyling):
##   %Visual     Node2D holding the art; flash and the built-in motions act on it
##   %Body       the art itself: a ColorRect now, replace with Sprite2D /
##               AnimatedSprite2D freely (anything inside %Visual works)
##   %NameLabel  Label, shows "name\nhp/max"
##   %Alert      the "!" shown while an archer winds up
##   %ClickArea  Control that receives clicks (resize it to fit the art)
## Optional, for your own animations (see BattleUnit.gd):
##   %Anim (AnimationPlayer)  or  %Sprite (AnimatedSprite2D)

signal clicked(unit: EnemyUnit)

var data: EnemyData
var hp := 0
## Only set when the enemy has no scene of its own: tints the default box.
var fallback_tint := Color(0, 0, 0, 0)

@onready var _body: CanvasItem = %Body
@onready var _label: Label = %NameLabel
@onready var _alert: CanvasItem = %Alert
@onready var _click: Control = %ClickArea


## Enemies stand on the right and hit toward Bara, so their lunge goes left.
func _lunge() -> Vector2:
	return Vector2(-lunge_distance, 0.0)


func setup(d: EnemyData) -> EnemyUnit:
	data = d
	hp = d.max_hp
	return self


func _ready() -> void:
	if fallback_tint.a > 0.0 and _body is ColorRect:
		_body.color = fallback_tint
	_click.gui_input.connect(_on_click_input)
	refresh()
	super._ready()   # starts the idle pose


func is_alive() -> bool:
	return hp > 0


func take_damage(amount: int) -> void:
	hp = maxi(hp - amount, 0)
	refresh()
	flash()
	if hp > 0:   # a defeated enemy plays its die pose instead (see die())
		play_pose(HURT)


func refresh() -> void:
	_label.text = "%s\n%d/%d" % [data.label(), hp, data.max_hp]


## Wind-up before a ranged shot: tells the player to get ready to block.
## Plays the `windup` pose (holds its last frame) until it is switched off.
func set_telegraph(on: bool) -> void:
	_alert.visible = on
	play_pose(WINDUP if on else IDLE)


func flash() -> void:
	_visual.modulate = Color(3, 3, 3)
	create_tween().tween_property(_visual, "modulate", Color.WHITE, 0.15)


## Plays the `die` pose, then fades out and frees. Awaitable.
func die() -> void:
	var t := create_tween()
	t.tween_interval(play_pose(DIE))
	t.tween_property(self, "modulate:a", 0.0, 0.3)
	await t.finished
	queue_free()


## Where the target arrow should point: top-center of the click area.
func center_top() -> Vector2:
	return position + Vector2(_click.size.x / 2.0, 0.0)


func _on_click_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(self)
