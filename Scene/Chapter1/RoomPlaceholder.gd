@tool
class_name RoomPlaceholder
extends Node2D
## Empty placeholder room (floor grid + walls + bed + door) until the real
## map/tiles are ready. Builds its own wall collisions.
## Nanti cukup hapus node ini dan ganti dengan TileMap / gambar ruangan asli.

@export var room_size := Vector2(384, 216):
	set(v):
		room_size = v
		queue_redraw()
@export var wall_thickness := 12.0
@export var bed_rect := Rect2(56, 128, 46, 24):
	set(v):
		bed_rect = v
		queue_redraw()
@export var door_rect := Rect2(300, 0, 28, 12):
	set(v):
		door_rect = v
		queue_redraw()

const FLOOR := Color(0.12, 0.13, 0.19)
const GRID := Color(0.17, 0.18, 0.26)
const WALL := Color(0.24, 0.26, 0.36)
const WALL_EDGE := Color(0.36, 0.39, 0.52)

## 0 = closed, 1 = slammed open.
var door_open := 0.0:
	set(v):
		door_open = v
		queue_redraw()


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var t := wall_thickness
	_add_wall(Rect2(-t, -t, room_size.x + t * 2, t * 2))                 # top
	_add_wall(Rect2(-t, room_size.y - t, room_size.x + t * 2, t * 2))    # bottom
	_add_wall(Rect2(-t, -t, t * 2, room_size.y + t * 2))                 # left
	_add_wall(Rect2(room_size.x - t, -t, t * 2, room_size.y + t * 2))    # right


func _add_wall(r: Rect2) -> void:
	var body := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	body.position = r.get_center()
	body.add_child(shape)
	add_child(body)


func _draw() -> void:
	var t := wall_thickness
	draw_rect(Rect2(Vector2.ZERO, room_size), FLOOR)
	var step := 16.0
	var x := step
	while x < room_size.x:
		draw_line(Vector2(x, 0), Vector2(x, room_size.y), GRID, 1.0)
		x += step
	var y := step
	while y < room_size.y:
		draw_line(Vector2(0, y), Vector2(room_size.x, y), GRID, 1.0)
		y += step

	# Walls (top wall is taller so it reads as "back wall").
	draw_rect(Rect2(0, 0, room_size.x, t), WALL)
	draw_rect(Rect2(0, t - 2, room_size.x, 2), WALL_EDGE)
	draw_rect(Rect2(0, room_size.y - 4, room_size.x, 4), WALL)
	draw_rect(Rect2(0, 0, 4, room_size.y), WALL)
	draw_rect(Rect2(room_size.x - 4, 0, 4, room_size.y), WALL)

	# Door: dark gap + door leaf swinging open.
	draw_rect(door_rect, Color(0.03, 0.03, 0.06))
	var leaf_w := door_rect.size.x * (1.0 - door_open * 0.8)
	draw_rect(Rect2(door_rect.position, Vector2(leaf_w, door_rect.size.y)), Color(0.45, 0.33, 0.24))
	draw_rect(Rect2(door_rect.position, Vector2(leaf_w, door_rect.size.y)), Color(0.25, 0.17, 0.12), false, 1.0)

	# Bed.
	draw_rect(bed_rect, Color(0.3, 0.22, 0.2))
	draw_rect(bed_rect.grow(-2), Color(0.55, 0.6, 0.75))
	draw_rect(Rect2(bed_rect.position + Vector2(2, 2), Vector2(10, bed_rect.size.y - 4)), Color(0.9, 0.9, 0.95))
	draw_rect(bed_rect, Color(0.15, 0.1, 0.1), false, 1.0)
