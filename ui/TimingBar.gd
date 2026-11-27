class_name TimingBar
extends Control
## Reusable timing minigame: a marker sweeps across a bar, press `action`
## inside the green zone. Used by Perfect Block, and later the vent minigame.
##
## Look: edit ui/TimingBar.tscn in the editor (colors, art, fonts, size).
## Scene contract (unique names, keep them when restyling):
##   %Track  %GoodZone  %PerfectZone  %Marker  %Caption
## The zones are laid out from the exports below, so just resize the root
## control to change how long the bar is. Replace the ColorRects with
## TextureRects (or a NinePatchRect) for art; the script only moves/sizes them.
##
## Usage:
##     var bar := TimingBar.create()      # or instance the scene in the editor
##     parent.add_child(bar)
##     bar.start()
##     var result: int = await bar.resolved   # TimingBar.Result

signal resolved(result: int)

enum Result { MISS, GOOD, PERFECT }

@export var action := "defend"
@export var caption := "pencet X pas hijau!"
## Seconds for the marker to cross the whole bar once.
@export var pass_time := 1.1
## Zone centers / widths are fractions of the bar (0..1).
@export var zone_center := 0.75
@export var perfect_width := 0.14
@export var good_width := 0.32
## true = marker bounces back and forth until pressed (vent minigame);
## false = one pass, no press counts as MISS (Perfect Block).
@export var ping_pong := false

@onready var _good: Control = %GoodZone
@onready var _perfect: Control = %PerfectZone
@onready var _marker: Control = %Marker
@onready var _caption: Label = %Caption

var _t := 0.0
var _dir := 1.0
var _active := false


## Builds a bar from its scene (ui/TimingBar.tscn).
static func create() -> TimingBar:
	return (load("res://ui/TimingBar.tscn") as PackedScene).instantiate() as TimingBar


func _ready() -> void:
	resized.connect(_layout)
	_layout()
	hide()


## Size the zones and marker from the exports and the bar's current size.
func _layout() -> void:
	var w := size.x
	var h := size.y
	_good.position = Vector2((zone_center - good_width / 2.0) * w, 0.0)
	_good.size = Vector2(good_width * w, h)
	_perfect.position = Vector2((zone_center - perfect_width / 2.0) * w, 0.0)
	_perfect.size = Vector2(perfect_width * w, h)
	_marker.size = Vector2(_marker.size.x, h + 4.0)
	_marker.position.y = -2.0
	_caption.size.x = w
	_place_marker()


func _place_marker() -> void:
	_marker.position.x = _t * size.x - _marker.size.x / 2.0


func start() -> void:
	_t = 0.0
	_dir = 1.0
	_caption.text = caption
	_layout()   # exports may have been changed from code since _ready
	_active = true
	show()


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
	_place_marker()


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
