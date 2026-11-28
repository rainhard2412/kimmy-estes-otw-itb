class_name SpaceBackground
extends Node2D
## Scrolls the space behind the ship endlessly so the ship looks like it is flying.
##
## Every Parallax2D child is one depth layer. Its scroll_scale.x doubles as its depth:
## 0.0 = infinitely far away (never moves), 1.0 = right behind the hull (full speed).
## Parallax2D already shifts layers by depth when the camera moves; this script adds the
## constant "flight" motion on top, plus a slow sideways sway.
##
## Change cruise_speed at runtime to speed up or brake; the change eases in smoothly.

## Direction space flows across the screen. LEFT means the ship flies to the right.
@export var flow_direction := Vector2.LEFT:
	set(value):
		flow_direction = value.normalized() if value != Vector2.ZERO else Vector2.LEFT
## Target speed in px/s for a layer with depth 1.0.
@export var cruise_speed := 80.0
## How fast the actual speed eases toward cruise_speed. Higher = snappier.
@export var speed_smoothing := 1.2
## Slow sideways sway (perpendicular to the flow) so the ship feels like it floats.
@export var drift_amplitude := 4.0
@export var drift_period := 7.0

var current_speed := 0.0

var _layers: Array[Parallax2D] = []
var _base_offsets: Array[Vector2] = []
## Distance travelled per layer, already wrapped to that layer's repeat_size.
var _travel: Array[Vector2] = []
var _drift_time := 0.0


func _ready() -> void:
	for child in get_children():
		if child is Parallax2D:
			# Motion is driven from here; Parallax2D's own autoscroll would fight it.
			child.autoscroll = Vector2.ZERO
			_layers.append(child)
			_base_offsets.append(child.scroll_offset)
			_travel.append(Vector2.ZERO)
	current_speed = cruise_speed  # Already cruising when the scene opens.


func _process(delta: float) -> void:
	current_speed = lerpf(current_speed, cruise_speed, 1.0 - exp(-speed_smoothing * delta))
	_drift_time = fmod(_drift_time + delta, drift_period)

	var step := flow_direction * current_speed * delta
	var drift := flow_direction.orthogonal() * sin(_drift_time / drift_period * TAU) * drift_amplitude
	for i in _layers.size():
		var layer := _layers[i]
		var depth := layer.scroll_scale.x
		_travel[i] += step * depth
		# Wrap so the value never grows large and loses float precision over a long session.
		# The layer repeats every repeat_size, so a wrapped offset is visually identical.
		if layer.repeat_size.x > 0.0:
			_travel[i].x = fposmod(_travel[i].x, layer.repeat_size.x)
		if layer.repeat_size.y > 0.0:
			_travel[i].y = fposmod(_travel[i].y, layer.repeat_size.y)
		layer.scroll_offset = _base_offsets[i] + _travel[i] + drift * depth
