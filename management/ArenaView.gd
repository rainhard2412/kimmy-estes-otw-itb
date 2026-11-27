class_name ArenaView
extends Node2D
## Draws the top-down arena from a WalkSim. Placeholder shapes only.

var walk: WalkSim
var _t := 0.0


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	if walk == null:
		return
	var a := walk.config.arena_size
	draw_rect(Rect2(Vector2.ZERO, a), Color(0.09, 0.13, 0.11))
	var grid := Color(1, 1, 1, 0.05)
	for x in range(0, int(a.x) + 1, 20):
		draw_line(Vector2(x, 0), Vector2(x, a.y), grid)
	for y in range(0, int(a.y) + 1, 20):
		draw_line(Vector2(0, y), Vector2(a.x, y), grid)

	var wp := walk.wahana_pos.round()
	draw_arc(wp, walk.config.contact_distance, 0.0, TAU, 24, Color(1, 1, 1, 0.12), 1.0)
	for e in walk.enemies:
		var r := Rect2((e.pos - Vector2(5, 5)).round(), Vector2(10, 10))
		draw_rect(r, e.data.color)
		draw_rect(r, Color(0, 0, 0, 0.6), false, 1.0)

	var bob := Vector2(0, roundf(sin(_t * 14.0))) if walk.moving else Vector2.ZERO
	draw_rect(Rect2(wp - Vector2(8, 8) + bob, Vector2(16, 16)), Color(0.3, 0.6, 1.0))
	draw_rect(Rect2(wp - Vector2(8, 8) + bob, Vector2(16, 16)), Color(1, 1, 1, 0.8), false, 1.0)
	var target := walk.nearest_enemy()
	if target != null:
		var d := (target.pos - wp).normalized()
		draw_line(wp + bob, wp + bob + d * 12.0, Color.WHITE, 1.0)
