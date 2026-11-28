class_name ShipCamera
extends Camera2D
## Camera for ship rooms.
##
## Two modes:
## - fit_room (default): zooms so the whole room fits on screen and holds still. Every
##   door, fan and prop stays visible, whatever the player is doing.
## - follow: with fit_room off and a `target` set, tracks the target. Without a target
##   it falls back to free-look, where WASD / arrow keys pan the view.
##
## In follow / free-look the limits are the room rectangle grown by `space_margin`, so
## the camera can look a little past the hull and the scrolling space stays visible.

@export var target: Node2D
## Room rectangle in the camera parent's local pixels (the room's origin).
@export var room_rect := Rect2(0, 0, 448, 288)
## How far past the hull the camera may look, in pixels.
@export var space_margin := 48.0
@export var free_look_speed := 120.0
## Frame the whole room instead of following. Recommended for single-screen rooms.
@export var fit_room := true:
	set(value):
		fit_room = value
		if is_node_ready():
			_apply_mode()
## Space left around the room in fit_room mode, in world pixels.
@export var fit_padding := 12.0


func _ready() -> void:
	position_smoothing_speed = 6.0
	_apply_mode()
	get_viewport().size_changed.connect(_apply_mode)


func _process(delta: float) -> void:
	if fit_room:
		return
	if is_instance_valid(target):
		global_position = target.global_position
		return
	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input != Vector2.ZERO:
		position += input * free_look_speed * delta
	var half := _half_view()
	position = position.clamp(
		Vector2(limit_left, limit_top) + half,
		Vector2(limit_right, limit_bottom) - half)


func _apply_mode() -> void:
	if fit_room:
		_fit_to_room()
	else:
		position_smoothing_enabled = true
		_update_limits()


## Zoom so room_rect plus padding fills the view, centred on the room.
func _fit_to_room() -> void:
	position_smoothing_enabled = false
	var view := get_viewport_rect().size
	var needed := room_rect.size + Vector2.ONE * fit_padding * 2.0
	var z := minf(view.x / needed.x, view.y / needed.y)
	zoom = Vector2(z, z)
	position = room_rect.get_center()
	# Limits wide open: the fitted view may show a little space around the hull.
	limit_left = -10000000
	limit_top = -10000000
	limit_right = 10000000
	limit_bottom = 10000000
	reset_smoothing()


func _update_limits() -> void:
	var area := room_rect.grow(space_margin)
	# Grow the area to at least the view size, centred on the room, so the camera
	# never shows the room off-centre when zoomed out further than the room is big.
	var view := _half_view() * 2.0
	var grow_by := (view - area.size).max(Vector2.ZERO) / 2.0
	area = area.grow_individual(grow_by.x, grow_by.y, grow_by.x, grow_by.y)
	limit_left = floori(area.position.x)
	limit_top = floori(area.position.y)
	limit_right = ceili(area.end.x)
	limit_bottom = ceili(area.end.y)


func _half_view() -> Vector2:
	return get_viewport_rect().size / zoom / 2.0
