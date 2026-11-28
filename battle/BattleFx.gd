class_name BattleFx
extends Node2D
## Small procedural battle effects (no art needed): hit bursts, the kick's
## fire arc, the smash shockwave, shield bubble, heal pluses, sparks, dust,
## floating damage numbers and dash afterimages.
##
## Spawn with  BattleFx.spawn(parent, BattleFx.Kind.PUNCH, position, pace)
## Every effect frees itself when done. `pace` is the battle's pace (tests run
## with a tiny pace, so effects finish almost instantly there).
##
## To tweak the look, edit the numbers in _draw_* and _add_particles below.

enum Kind { PUNCH, KICK, SMASH, SHIELD, HEAL, BLOCK, HURT, DUST }

## Seconds each effect's drawing takes (particles may live a bit longer).
const DURATION := {
	Kind.PUNCH: 0.25, Kind.KICK: 0.35, Kind.SMASH: 0.55, Kind.SHIELD: 0.6,
	Kind.HEAL: 0.7, Kind.BLOCK: 0.25, Kind.HURT: 0.25, Kind.DUST: 0.0,
}

const WHITE_HOT := Color(1.0, 0.97, 0.8)
const EMBER := Color(1.0, 0.55, 0.1)
const EMBER_DEEP := Color(0.85, 0.12, 0.05)
const SHIELD_BLUE := Color(0.45, 0.85, 1.0)
const HEAL_GREEN := Color(0.45, 1.0, 0.5)

var kind := Kind.PUNCH
## 0..1 through the effect; drawing reads it.
var progress := 0.0:
	set(v):
		progress = v
		queue_redraw()

var _pace := 1.0
var _particle_life := 0.0


static func spawn(parent: Node, k: Kind, at: Vector2, pace := 1.0) -> BattleFx:
	var fx := BattleFx.new()
	fx.kind = k
	fx.position = at
	fx.z_index = 10
	fx._pace = maxf(pace, 0.01)
	parent.add_child(fx)
	return fx


## Floating number / word above a unit (damage, "+5", "BLOK!").
static func number(parent: Node, at: Vector2, text: String, color: Color, pace := 1.0, big := false) -> void:
	var l := Label.new()
	l.text = text
	l.z_index = 20
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 12 if big else 9)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.02, 0.02))
	l.add_theme_constant_override("outline_size", 3)
	l.size = Vector2(60, 14)
	l.position = at - Vector2(30, 14)
	l.pivot_offset = l.size / 2.0
	l.scale = Vector2(1.6, 1.6)
	parent.add_child(l)
	var p := maxf(pace, 0.01)
	var t := l.create_tween()
	t.tween_property(l, "scale", Vector2.ONE, 0.12 * p).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(l, "position:y", l.position.y - 14.0, 0.7 * p).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.25 * p)
	t.tween_callback(l.queue_free)


## A fading copy of `sprite` left behind while Bara dashes.
static func afterimage(parent: Node, sprite: Sprite2D, pace := 1.0, tint := Color(1.0, 0.45, 0.15, 0.55)) -> void:
	if sprite == null or sprite.texture == null:
		return
	var g := Sprite2D.new()
	g.texture = sprite.texture
	g.centered = sprite.centered
	g.offset = sprite.offset
	g.flip_h = sprite.flip_h
	g.modulate = tint
	g.z_index = -1
	parent.add_child(g)
	g.global_transform = sprite.global_transform
	var t := g.create_tween()
	t.tween_property(g, "modulate:a", 0.0, 0.22 * maxf(pace, 0.01))
	t.tween_callback(g.queue_free)


func _ready() -> void:
	_add_particles()
	var t := create_tween()
	var dur: float = DURATION[kind] * _pace
	if dur > 0.0:
		t.tween_property(self, "progress", 1.0, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_interval(maxf(_particle_life * _pace - dur, 0.0) + 0.02)
	t.tween_callback(queue_free)


# ------------------------------------------------------------------ particles

func _add_particles() -> void:
	match kind:
		Kind.PUNCH:
			_sparks(10, [WHITE_HOT, Color(1, 0.8, 0.3), Color(1, 0.5, 0.1, 0)], Vector2(50, 110), 0.3, Vector2.RIGHT, 70.0)
		Kind.KICK:
			_sparks(14, [Color(1, 0.9, 0.4), EMBER, Color(0.6, 0.1, 0, 0)], Vector2(40, 100), 0.45, Vector2(1, -0.4), 60.0, Vector2(0, -30))
			_sparks(6, [WHITE_HOT, Color(1, 1, 1, 0)], Vector2(60, 120), 0.2, Vector2.RIGHT, 40.0)
		Kind.SMASH:
			_sparks(28, [WHITE_HOT, Color(1, 0.8, 0.2), EMBER_DEEP, Color(0.3, 0, 0, 0)], Vector2(60, 160), 0.6, Vector2.RIGHT, 180.0, Vector2(0, 60), 1.5)
			_sparks(12, [Color(1, 0.7, 0.2), Color(0.8, 0.1, 0, 0)], Vector2(15, 40), 0.9, Vector2.UP, 50.0, Vector2(0, -25))
		Kind.SHIELD:
			_sparks(12, [Color(0.8, 1, 1), SHIELD_BLUE, Color(0.2, 0.5, 1, 0)], Vector2(10, 30), 0.7, Vector2.UP, 40.0, Vector2(0, -20))
		Kind.HEAL:
			_sparks(10, [Color(0.9, 1, 0.9), HEAL_GREEN, Color(0.2, 0.9, 0.3, 0)], Vector2(8, 25), 0.8, Vector2.UP, 30.0, Vector2(0, -15))
		Kind.BLOCK:
			_sparks(10, [Color(0.9, 1, 1), SHIELD_BLUE, Color(0.3, 0.6, 1, 0)], Vector2(40, 90), 0.3, Vector2.RIGHT, 80.0, Vector2(0, 80))
		Kind.HURT:
			_sparks(9, [Color(1, 0.9, 0.9), Color(1, 0.25, 0.2), Color(0.5, 0, 0, 0)], Vector2(30, 80), 0.3, Vector2.LEFT, 70.0, Vector2(0, 90))
		Kind.DUST:
			_sparks(8, [Color(0.85, 0.8, 0.75, 0.8), Color(0.6, 0.55, 0.5, 0)], Vector2(10, 35), 0.4, Vector2.LEFT, 35.0, Vector2(0, -10), 1.5)


func _sparks(amount: int, colors: Array, speed: Vector2, life: float, dir: Vector2,
		spread: float, gravity := Vector2.ZERO, size := 1.0) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.direction = dir
	p.spread = spread
	p.gravity = gravity
	p.initial_velocity_min = speed.x
	p.initial_velocity_max = speed.y
	p.damping_min = 60.0
	p.damping_max = 120.0
	p.scale_amount_min = size
	p.scale_amount_max = size * 2.0
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	for i in colors.size():
		offs.append(float(i) / maxf(colors.size() - 1, 1))
	g.offsets = offs
	g.colors = PackedColorArray(colors)
	p.color_ramp = g
	p.speed_scale = 1.0 / _pace
	add_child(p)
	p.emitting = true
	_particle_life = maxf(_particle_life, life)


# ------------------------------------------------------------------ drawing

func _draw() -> void:
	if progress >= 1.0:
		return
	match kind:
		Kind.PUNCH: _draw_punch()
		Kind.KICK: _draw_kick()
		Kind.SMASH: _draw_smash()
		Kind.SHIELD: _draw_shield()
		Kind.HEAL: _draw_heal()
		Kind.BLOCK: _draw_block()
		Kind.HURT: _draw_hurt()


func _fade(c: Color, a: float) -> Color:
	return Color(c.r, c.g, c.b, c.a * clampf(a, 0.0, 1.0))


## White impact star.
func _draw_punch() -> void:
	var p := progress
	var a := 1.0 - p
	draw_circle(Vector2.ZERO, lerpf(5.0, 1.0, p), _fade(WHITE_HOT, a))
	var r := lerpf(3.0, 11.0, p)
	for i in 8:
		var d := Vector2.from_angle(TAU * i / 8.0 + 0.4)
		var outer := r * (1.35 if i % 2 == 0 else 0.85)
		draw_line(d * r * 0.45, d * outer, _fade(Color(1, 0.9, 0.55), a), 1.0)


## Burning crescent swept by Bara's kick, plus a small hit flash.
func _draw_kick() -> void:
	var p := progress
	var a := 1.0 - p
	var sweep := lerpf(0.2, 2.4, minf(p * 1.8, 1.0))
	var start := -2.0
	var c := Vector2(-8, 2)
	var w := lerpf(5.0, 1.0, p)
	draw_arc(c, 13.0, start, start + sweep, 18, _fade(EMBER_DEEP, a), w + 1.0)
	draw_arc(c, 13.0, start, start + sweep, 18, _fade(EMBER, a), w)
	draw_arc(c, 12.0, start + sweep * 0.3, start + sweep, 14, _fade(Color(1, 0.95, 0.6), a), maxf(w - 2.5, 1.0))
	draw_circle(Vector2.ZERO, lerpf(6.0, 0.0, minf(p * 2.0, 1.0)), _fade(WHITE_HOT, a))


## Kalpataru shockwave: double ring, hot core and thick fire rays.
func _draw_smash() -> void:
	var p := progress
	var a := 1.0 - p
	var r := lerpf(4.0, 30.0, p)
	draw_circle(Vector2.ZERO, lerpf(11.0, 0.0, minf(p * 1.6, 1.0)), _fade(WHITE_HOT, a))
	draw_arc(Vector2.ZERO, r, 0.0, TAU, 36, _fade(Color(1, 0.85, 0.3), a), lerpf(5.0, 1.0, p))
	draw_arc(Vector2.ZERO, r * 0.68, 0.0, TAU, 28, _fade(EMBER_DEEP, a * 0.9), lerpf(3.0, 1.0, p))
	for i in 12:
		var d := Vector2.from_angle(TAU * i / 12.0 + 0.2)
		var len := r * (1.25 if i % 3 == 0 else 0.9)
		var col := Color(1, 0.8, 0.25) if i % 2 == 0 else EMBER
		draw_line(d * r * 0.5, d * len, _fade(col, a), 2.0 if i % 3 == 0 else 1.0)


## Hexagonal energy shield that pops out and shimmers around Bara.
func _draw_shield() -> void:
	var p := progress
	var grow := minf(p * 3.0, 1.0)
	var a := 1.0 if p < 0.6 else 1.0 - (p - 0.6) / 0.4
	var r := lerpf(6.0, 26.0, grow) + sin(p * 30.0) * 0.6
	var pts := PackedVector2Array()
	for i in 7:
		var ang := TAU * i / 6.0 + PI / 6.0
		pts.append(Vector2(cos(ang) * r * 0.85, sin(ang) * r))
	var fill := pts.duplicate()
	fill.remove_at(6)
	draw_colored_polygon(fill, _fade(Color(0.3, 0.7, 1.0, 0.18), a))
	draw_polyline(pts, _fade(SHIELD_BLUE, a), 1.5)
	var scan := lerpf(-r, r, fmod(p * 2.0, 1.0))
	draw_line(Vector2(-r * 0.6, scan), Vector2(r * 0.6, scan), _fade(Color(0.85, 1, 1), a * 0.7), 1.0)


## Green pluses floating up.
func _draw_heal() -> void:
	var p := progress
	var a := 1.0 - p
	var xs := [-10.0, -3.0, 5.0, 11.0, 0.0]
	for i in xs.size():
		var y := 8.0 - p * 22.0 - i * 4.0
		var c := Vector2(xs[i], y)
		var s := 2.0 if i % 2 == 0 else 1.5
		draw_line(c - Vector2(s, 0), c + Vector2(s, 0), _fade(HEAL_GREEN, a), 1.0)
		draw_line(c - Vector2(0, s), c + Vector2(0, s), _fade(HEAL_GREEN, a), 1.0)


## Blue deflect arc in front of Bara.
func _draw_block() -> void:
	var p := progress
	var a := 1.0 - p
	var r := lerpf(6.0, 15.0, p)
	draw_arc(Vector2.ZERO, r, -1.1, 1.1, 14, _fade(SHIELD_BLUE, a), lerpf(3.0, 1.0, p))
	draw_arc(Vector2.ZERO, r - 3.0, -0.8, 0.8, 10, _fade(Color(0.9, 1, 1), a), 1.0)


## Red slash cross on Bara.
func _draw_hurt() -> void:
	var p := progress
	var a := 1.0 - p
	var s := lerpf(3.0, 9.0, minf(p * 2.5, 1.0))
	var col := _fade(Color(1, 0.25, 0.2), a)
	draw_line(Vector2(-s, -s), Vector2(s, s), col, 2.0)
	draw_line(Vector2(s, -s), Vector2(-s, s), col, 1.0)
	draw_circle(Vector2.ZERO, lerpf(4.0, 0.0, p), _fade(WHITE_HOT, a))
