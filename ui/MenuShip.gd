class_name MenuShip
extends Control
## Spaceship shown in the launch phase of the main menu.
##
## Drawn from behind (it flies away from the camera, "into" the screen).
## Set `texture` to use your own artwork instead of the built-in drawing.

## Optional ship artwork (PNG transparan, tampak belakang).
@export var texture: Texture2D

## Engine glow strength: ~0.3 idle, 1.0 charging, >1 full burn.
var thrust := 0.35
## Random jitter in local units.
var shake := 0.0
## Idle hover bob (0 = off).
var bob := 1.0

const HULL := Color(0.52, 0.55, 0.7)
const HULL_SHADE := Color(0.4, 0.43, 0.58)
const HULL_DARK := Color(0.28, 0.3, 0.43)
const EDGE := Color(0.72, 0.75, 0.9)
const STRIPE := Color(1.0, 0.55, 0.25)
const GLASS := Color(0.35, 0.8, 1.0)
const FLAME := Color(0.45, 0.85, 1.0)

var _t := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	# Ship is authored in a 64x48 unit box centred on (0, 0).
	var k := size.x / 64.0
	var off := Vector2(0.0, sin(_t * 2.2) * 1.5 * bob)
	if shake > 0.0:
		off += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake
	draw_set_transform(size * 0.5 + off * k, 0.0, Vector2(k, k))

	var burn := thrust * randf_range(0.88, 1.12)

	if texture:
		_draw_glow(Vector2(0, 10), burn * 1.6)
		var ts := texture.get_size()
		var fit := minf(64.0 / ts.x, 48.0 / ts.y)
		var dst := ts * fit
		draw_texture_rect(texture, Rect2(-dst * 0.5, dst), false)
		return

	# Wings (mirrored).
	for sx in [-1.0, 1.0]:
		var m := Vector2(sx, 1.0)
		draw_colored_polygon(_mirror([
			Vector2(-31, 4), Vector2(-9, -3), Vector2(-9, 7), Vector2(-28, 9)], m), HULL_DARK)
		draw_colored_polygon(_mirror([
			Vector2(-24, 4.2), Vector2(-16, 1.6), Vector2(-16, 3.6), Vector2(-24, 6.2)], m), STRIPE)
		draw_colored_polygon(_mirror([
			Vector2(-31, 5), Vector2(-30, -5), Vector2(-28, 4.5)], m), HULL_SHADE)
		draw_line(Vector2(-31, 4) * m, Vector2(-9, -3) * m, EDGE, 0.8)

	# Fuselage with a shaded right half for volume.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -18), Vector2(10, -4), Vector2(9, 9), Vector2(4, 12),
		Vector2(-4, 12), Vector2(-9, 9), Vector2(-10, -4)]), HULL)
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -18), Vector2(10, -4), Vector2(9, 9), Vector2(4, 12), Vector2(0, 12)]), HULL_SHADE)
	# Tail fin.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-1.2, -16), Vector2(-0.6, -24), Vector2(0.9, -24), Vector2(1.2, -16)]), HULL_DARK)
	# Cockpit.
	draw_colored_polygon(PackedVector2Array([
		Vector2(0, -14), Vector2(5, -5), Vector2(0, -3), Vector2(-5, -5)]), GLASS)
	draw_rect(Rect2(-2.2, -10.5, 1.4, 2.4), Color(1, 1, 1, 0.85))

	# Wing-tip navigation lights.
	var blink := 1.0 if fmod(_t, 1.2) < 0.6 else 0.25
	draw_circle(Vector2(-30, 5), 0.9, Color(1.0, 0.3, 0.3, blink))
	draw_circle(Vector2(30, 5), 0.9, Color(0.3, 1.0, 0.5, blink))

	# Engines.
	for ex in [-5.0, 5.0]:
		var e := Vector2(ex, 9)
		draw_circle(e, 3.4, Color(0.13, 0.14, 0.22))
		_draw_glow(e, burn)


func _draw_glow(at: Vector2, amount: float) -> void:
	draw_circle(at, 2.2 + amount * 6.0, Color(FLAME, 0.16))
	draw_circle(at, 1.8 + amount * 3.0, Color(FLAME, 0.45))
	draw_circle(at, 1.1 + amount * 1.2, Color(1, 1, 1, 0.9))


func _mirror(points: Array, m: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(p * m)
	return out
