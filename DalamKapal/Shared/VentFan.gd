class_name VentFan
extends Node2D
## A wall-mounted ventilation fan the player can clean.
##
## The fan spins while running. Dirt builds up over time, which slows the blades and
## dims the sprite. Once dirt passes `clog_threshold` the fan counts as clogged and
## `needs_cleaning` fires, so the room (or a task system) can flag it to the player.
## Call clean() to reset it.

## Emitted the moment dirt crosses clog_threshold.
signal needs_cleaning
## Emitted by clean() once the fan is spotless again.
signal cleaned

## Blade speed when the fan is perfectly clean, as an animation speed multiplier.
@export var clean_speed := 1.0
## Blade speed when fully clogged. Above zero so the fan still struggles round.
@export var clogged_speed := 0.25
## Dirt gained per second. 0.0 stops the fan getting dirty on its own.
@export var dirt_per_second := 0.0
## Dirt level that counts as clogged, from 0.0 to 1.0.
@export_range(0.0, 1.0) var clog_threshold := 0.75
## Current dirt, 0.0 = clean, 1.0 = fully clogged.
@export_range(0.0, 1.0) var dirt := 0.0:
	set(value):
		dirt = clampf(value, 0.0, 1.0)
		_apply_dirt()
## Set false to switch the fan off entirely (blades stop).
@export var running := true:
	set(value):
		running = value
		_apply_dirt()
## Blade position this fan starts on. Give fans in the same room different values so
## they do not all spin in lockstep.
@export_range(0, 3) var start_frame := 0

var is_clogged := false

@onready var _blades: AnimatedSprite2D = $Blades
@onready var _interact: Area2D = $InteractArea


func _ready() -> void:
	_apply_dirt()
	if running:
		_blades.play("spin")
		_blades.frame = start_frame


func _process(delta: float) -> void:
	if dirt_per_second > 0.0 and not is_clogged:
		dirt += dirt_per_second * delta


## Wipes the fan back to spotless.
func clean() -> void:
	dirt = 0.0
	is_clogged = false
	cleaned.emit()


## True while the player stands close enough to interact.
func is_player_in_range() -> bool:
	return not _interact.get_overlapping_bodies().is_empty()


func _apply_dirt() -> void:
	if not is_node_ready():
		return
	# Dirt slows the blades and darkens the whole unit.
	_blades.speed_scale = 0.0 if not running else lerpf(clean_speed, clogged_speed, dirt)
	var grime := lerpf(1.0, 0.55, dirt)
	modulate = Color(grime, grime, grime)

	if dirt >= clog_threshold and not is_clogged:
		is_clogged = true
		needs_cleaning.emit()
