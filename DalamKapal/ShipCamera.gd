class_name ShipCamera
extends Camera2D
## Camera for ship rooms.
##
## Follows `target` when one is set (e.g. the player). Without a target it switches to
## free-look: WASD / arrow keys pan the view, which is handy for previewing a room.
##
## Limits are the room rectangle grown by `space_margin`, so the camera can look a little
## past the hull and the scrolling space stays visible. When the view is larger than that
## area (zoomed out), the room is kept centred instead of pinned to one edge.

@export var target: Node2D
## Room rectangle in the camera parent's local pixels (the room's origin).
@export var room_rect := Rect2(0, 0, 448, 288)
## How far past the hull the camera may look, in pixels.
@export var space_margin := 48.0
@export var free_look_speed := 120.0


func _ready() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 6.0
	_update_limits()
	get_viewport().size_changed.connect(_update_limits)


func _process(delta: float) -> void:
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
