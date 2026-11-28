class_name ActorVisual
extends Node2D
## Placeholder look for a character: a simple box body with eyes.
## The node origin is the character's feet.
##
## Isi `texture` dengan sprite karakter nanti; placeholder otomatis diganti.

@export var texture: Texture2D
@export var body_color := Color(0.35, 0.55, 0.95)
@export var body_size := Vector2(10, 14)
## Teks kecil di atas kepala (kosong = tidak ada).
@export var label := ""

## Direction the eyes look at.
var facing := Vector2.DOWN
## Closed eyes (sleeping / blinking).
var eyes_closed := false
## 0..1 walk bounce strength.
var walking := 0.0

var _t := 0.0
var _blink := 2.0


func _process(delta: float) -> void:
	_t += delta
	_blink -= delta
	if _blink < -0.12:
		_blink = randf_range(2.0, 4.5)
	queue_redraw()


func _draw() -> void:
	var bounce := -absf(sin(_t * 12.0)) * 1.5 * walking
	var breathe := sin(_t * 2.0) * 0.4 * (1.0 - walking)

	# Shadow.
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, body_size.x * 0.65, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2(0, bounce), 0.0, Vector2.ONE)

	if texture:
		var ts := texture.get_size()
		draw_texture(texture, Vector2(-ts.x * 0.5, -ts.y))
		_draw_label(-ts.y)
		return

	var w := body_size.x
	var h := body_size.y + breathe
	var body := Rect2(-w * 0.5, -h, w, h)
	draw_rect(body, body_color.darkened(0.15))
	# Head part (top half, lighter).
	draw_rect(Rect2(body.position, Vector2(w, h * 0.5)), body_color.lightened(0.15))
	draw_rect(body, body_color.darkened(0.5), false, 1.0)

	# Eyes follow `facing`.
	var look := facing.normalized() if facing != Vector2.ZERO else Vector2.DOWN
	var eye_y := -h * 0.72 + look.y * 1.0
	var spread := 2.0 * (1.0 - absf(look.x) * 0.35)
	var ex := look.x * 2.0
	if look.y < -0.6:
		pass  # facing away: no eyes
	elif eyes_closed or _blink < 0.0:
		for sx in [-1.0, 1.0]:
			draw_line(Vector2(ex + sx * spread - 1.0, eye_y), Vector2(ex + sx * spread + 1.0, eye_y),
				Color(0.05, 0.05, 0.1), 1.0)
	else:
		for sx in [-1.0, 1.0]:
			draw_rect(Rect2(ex + sx * spread - 0.75, eye_y - 1.25, 1.5, 2.5), Color(0.05, 0.05, 0.1))

	_draw_label(-h)


func _draw_label(top: float) -> void:
	if label == "":
		return
	var font := ThemeDB.fallback_font
	var fs := 5
	var tw := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(font, Vector2(-tw * 0.5, top - 3), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 2, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(-tw * 0.5, top - 3), label,
		HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.85))
