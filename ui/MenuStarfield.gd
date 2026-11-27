class_name MenuStarfield
extends Control
## Procedural 3D starfield drawn behind the main menu.
##
## Idle: stars drift slowly toward the camera, twinkle, and the odd shooting
## star crosses the sky. Raise `speed` and `warp` for a hyperspace jump —
## stars then stretch into streaks rushing past the vanishing point.

const NEAR := 0.03
const COLORS := [
	Color(1.0, 1.0, 1.0),
	Color(1.0, 0.93, 0.78),
	Color(0.8, 0.75, 1.0),
	Color(0.72, 0.88, 1.0),
]
const WARP_TINT := Color(0.7, 0.85, 1.0)

@export var star_count := 320
@export var idle_speed := 0.05

## Depth units travelled per second (1.0 = far plane to camera in one second).
var speed := 0.05
## 0 = twinkling dots, 1 = full hyperspace streaks.
var warp := 0.0
## Pixel offset (mouse parallax / screen shake). Near stars move more.
var parallax := Vector2.ZERO
## Normalized screen position stars fly out of.
var vanishing_point := Vector2(0.5, 0.5)

var _pos := PackedVector3Array()
var _phase := PackedFloat32Array()
var _col := PackedInt32Array()
var _t := 0.0
var _shooting: Array[Dictionary] = []
var _shoot_timer := 2.5


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	speed = idle_speed
	_pos.resize(star_count)
	_phase.resize(star_count)
	_col.resize(star_count)
	for i in star_count:
		_pos[i] = _random_star(randf_range(NEAR, 1.0))
		_phase[i] = randf() * TAU
		_col[i] = randi() % COLORS.size()


func _random_star(z: float) -> Vector3:
	return Vector3(randf_range(-1.25, 1.25), randf_range(-0.8, 0.8), z)


func _process(delta: float) -> void:
	_t += delta
	for i in star_count:
		var p := _pos[i]
		p.z -= speed * delta
		if p.z <= NEAR:
			p = _random_star(1.0)
		_pos[i] = p
	_update_shooting(delta)
	queue_redraw()


func _update_shooting(delta: float) -> void:
	for s in _shooting:
		s.pos += s.vel * delta
		s.life -= delta
	_shooting = _shooting.filter(func(s): return s.life > 0.0)

	if warp > 0.05:
		return
	_shoot_timer -= delta
	if _shoot_timer <= 0.0:
		_shoot_timer = randf_range(2.0, 5.0)
		var dir := Vector2(-1.0 if randf() < 0.5 else 1.0, randf_range(0.3, 0.6)).normalized()
		var life := randf_range(0.6, 1.0)
		_shooting.append({
			"pos": Vector2(randf_range(0.15, 0.85) * size.x, randf_range(0.0, 0.4) * size.y),
			"vel": dir * randf_range(150.0, 230.0),
			"life": life,
			"max": life,
			"len": randf_range(16.0, 30.0),
		})


func _draw() -> void:
	var c := size * vanishing_point
	var k := size.x * 0.5
	var tail := clampf(speed * 0.12, 0.0, 0.7)
	var bounds := Rect2(Vector2(-8, -8), size + Vector2(16, 16))

	# Soft glow at the vanishing point while warping.
	if warp > 0.01:
		for r in [34.0, 20.0, 10.0]:
			draw_circle(c, r * (0.6 + warp * 0.6), Color(0.6, 0.8, 1.0, 0.025 * warp))

	for i in star_count:
		var p := _pos[i]
		var depth := 1.0 - p.z
		var xy := Vector2(p.x, p.y)
		var sp := c + xy / p.z * k + parallax * depth
		var a := clampf(depth * 1.4, 0.12, 1.0) * clampf(depth * 10.0, 0.0, 1.0)
		var twinkle := 0.6 + 0.4 * sin(_t * 2.6 + _phase[i])
		a *= lerpf(twinkle, 1.0, warp)
		var col: Color = COLORS[_col[i]].lerp(WARP_TINT, warp * 0.6)
		col.a = a
		var s := 0.5 + depth * 1.5

		if tail > 0.004:
			var z2 := minf(p.z + tail, 1.0)
			var sp2 := c + xy / z2 * k + parallax * (1.0 - z2)
			if not bounds.has_point(sp2):
				continue
			draw_line(sp2, sp, col, maxf(s * (0.8 + warp * 0.5), 0.6), true)
		else:
			if not bounds.has_point(sp):
				continue
			draw_rect(Rect2(sp - Vector2(s, s) * 0.5, Vector2(s, s)), col)

	for sh in _shooting:
		var fade: float = sin(PI * sh.life / sh.max)
		var dir: Vector2 = sh.vel.normalized()
		var head: Vector2 = sh.pos + parallax * 0.3
		const SEGMENTS := 5
		for j in SEGMENTS:
			var a0 := float(j) / SEGMENTS
			var a1 := float(j + 1) / SEGMENTS
			draw_line(
				head - dir * sh.len * a0,
				head - dir * sh.len * a1,
				Color(1.0, 0.97, 0.9, fade * (1.0 - a0)),
				1.0 - a0 * 0.5,
				true
			)
		draw_rect(Rect2(head - Vector2(0.75, 0.75), Vector2(1.5, 1.5)), Color(1, 1, 1, fade))
