class_name WalkerNode
extends Node2D
## One enemy walking in the arena. Pure visuals: WalkSim owns where it is;
## Arena moves this node to match.
##
## Look: edit management/Walker.tscn (the shared base) or make a scene that
## inherits it for one enemy type, then drag it into that enemy's
## `walker_scene` slot (data/management/enemy_*.tres).
## Scene contract (unique names): %Visual (Node2D holding the art), %Body (the
## art: a ColorRect now, swap for a Sprite2D / AnimatedSprite2D freely).
## Origin = the enemy's center, so center your art on (0, 0).

## Only set when the enemy has no scene of its own: tints the default box.
var fallback_tint := Color(0, 0, 0, 0)

@onready var _body: CanvasItem = %Body


func _ready() -> void:
	if fallback_tint.a > 0.0 and _body is ColorRect:
		_body.color = fallback_tint
