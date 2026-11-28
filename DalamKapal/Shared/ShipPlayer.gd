class_name ShipPlayer
extends CharacterBody2D
## Top-down player for ship rooms.
##
## Deliberately plain: it walks, it collides, and its look comes from a Sprite2D child
## whose texture is exported. Swap `texture` for the real character art later, or replace
## the Sprite2D with an AnimatedSprite2D, and nothing else here has to change.

@export var speed := 70.0
@export var acceleration := 600.0
## Placeholder art. Scaled to `visual_size` so any source resolution fits the room.
@export var texture: Texture2D:
	set(value):
		texture = value
		_refresh_visual()
## On-screen size of the sprite in pixels.
@export var visual_size := Vector2(20, 20):
	set(value):
		visual_size = value
		_refresh_visual()

var can_move := true

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	_refresh_visual()


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if can_move:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = velocity.move_toward(input * speed, acceleration * delta)
	move_and_slide()


func _refresh_visual() -> void:
	if not is_node_ready() or not is_instance_valid(_sprite):
		return
	_sprite.texture = texture
	if texture:
		# Fit the texture to visual_size regardless of its native resolution.
		_sprite.scale = visual_size / texture.get_size()
