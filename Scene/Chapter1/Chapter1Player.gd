class_name Chapter1Player
extends CharacterBody2D
## Top-down movement for Bara. Disabled until the opening cutscene ends.

@export var speed := 70.0
@export var acceleration := 600.0

var can_move := false

@onready var visual: ActorVisual = $Visual


func _physics_process(delta: float) -> void:
	var input := Vector2.ZERO
	if can_move:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = velocity.move_toward(input * speed, acceleration * delta)
	move_and_slide()

	if input != Vector2.ZERO:
		visual.facing = input
	visual.walking = move_toward(visual.walking, 1.0 if velocity.length() > 5.0 else 0.0, delta * 8.0)
