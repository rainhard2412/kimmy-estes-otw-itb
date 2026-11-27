class_name TimingBar
extends Control
## Reusable timing minigame: a marker sweeps across a bar, press `action`
## inside the green zone. Used by Perfect Block, and later the vent minigame.
##
## Usage:
##     bar.start()
##     var result: int = await bar.resolved   # TimingBar.Result

signal resolved(result: int)

enum Result { MISS, GOOD, PERFECT }

@export var action := "defend"
@export var caption := "pencet X pas hijau!"
## Seconds for the marker to cross the whole bar once.
@export var pass_time := 0.5
## Zone centers / widths are fractions of the bar (0..1).
@export var zone_center := 0.75
@export var perfect_width := 0.14
@export var good_width := 0.32
## true = marker bounces back and forth until pressed (vent minigame);
## false = one pass, no press counts as MISS (Perfect Block).
@export var ping_pong := false

const COLOR_BG := Color(0.1, 0.1, 0.14)
const COLOR_GOOD := Color(0.85, 0.75, 0.2)
const COLOR_PERFECT := Color(0.2, 0.85, 0.35)
const COLOR_MARKER := Color.WHITE

var _t := 0.0
var _dir := 1.0
var _active := false
var _caption := Label.new()

func _ready() -> void:
	if size == Vector2.ZERO:
		size = Vector2(160, 10)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.add_theme_font_size_override("font_size", 8)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.size = Vector2(size.x, 12)
	_caption.position = Vector2(0, -13)
	add_child(_caption)
	hide()

func start() -> void:
	_t = 0.0
	_dir = 1.0
	_caption.text = caption
	_active = true
	show()
	queue_redraw()

func is_active() -> bool:
	return _active

func _process(delta: float) -> void:
	if not _active:
		return
	_t += delta / pass_time * _dir
	if _t >= 1.0:
		if ping_pong:
			_t = 1.0
			_dir = -1.0
		else:
			_finish(Result.MISS)
			return
	elif _t <= 0.0:
		_t = 0.0
		_dir = 1.0
	queue_redraw()

func _unhandled_input(event: InputEvent) -> void:
	if _active and event.is_action_pressed(action):
		get_viewport().set_input_as_handled()
		_finish(evaluate(_t))

## Pure scoring function, kept separate so it is easy to test and tune.
func evaluate(pos: float) -> int:
	var d := absf(pos - zone_center)
	if d <= perfect_width / 2.0:
		return Result.PERFECT
	if d <= good_width / 2.0:
		return Result.GOOD
	return Result.MISS

func _finish(result: int) -> void:
	_active = false
	hide()
	resolved.emit(result)

func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BG)
	draw_rect(Rect2((zone_center - good_width / 2.0) * w, 0, good_width * w, h), COLOR_GOOD)
	draw_rect(Rect2((zone_center - perfect_width / 2.0) * w, 0, perfect_width * w, h), COLOR_PERFECT)
	draw_rect(Rect2(_t * w - 1, -2, 2, h + 4), COLOR_MARKER)
