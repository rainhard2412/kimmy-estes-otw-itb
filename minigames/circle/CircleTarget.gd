class_name CircleTarget
extends Control
## One on-screen circle: a disc that shows when it is hit-able and a ring that
## shrinks onto it. Pure visuals; CircleMinigame owns the timing and grading.
##
## Look: edit minigames/circle/CircleTarget.tscn. Scene contract:
##   %Disc (TextureRect, tinted by the exports below)  %Ring (TextureRect)  %Number (Label)
## Put real art in the Disc/Ring textures. Both are stretched to fit
## `circle_radius` from the config, so art size never overrides that setting.
## Set the tints to white if your art already has its own colors.

## Disc color while the hit window is still open / after the GOOD window ended.
@export var normal_tint := Color(0.95, 0.75, 0.2, 0.85)
@export var late_tint := Color(0.9, 0.3, 0.25, 0.7)
## How much bigger than the disc the ring starts, shrinking to 1.0 at the ideal moment.
@export var ring_start_scale := 3.0

@onready var _disc: Control = %Disc
@onready var _ring: Control = %Ring
@onready var _number: Label = %Number


## Call after the target is in the tree. `center` is in the parent's coordinates.
func setup(index: int, center: Vector2, radius: float) -> void:
	var d := Vector2(radius * 2.0, radius * 2.0)
	size = d
	position = center - Vector2(radius, radius)
	for c: Control in [_disc, _ring, _number]:
		c.position = Vector2.ZERO
		c.size = d
	_ring.pivot_offset = Vector2(radius, radius)
	_number.text = str(index + 1)
	show_progress(0.0, 1.0, 2.0)


## `age` = seconds since spawn, `ideal` = the perfect moment, `late_after` =
## when the GOOD window closes.
func show_progress(age: float, ideal: float, late_after: float) -> void:
	var t := clampf(age / maxf(ideal, 0.001), 0.0, 1.0)
	_ring.scale = Vector2.ONE * lerpf(ring_start_scale, 1.0, t)
	_disc.self_modulate = late_tint if age > late_after else normal_tint
