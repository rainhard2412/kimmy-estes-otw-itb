class_name DialogueBox
extends CanvasLayer
## Kotak dialog di bawah layar: foto karakter, nama, dan teks yang diketik.
##
## Pakai:
##     await $DialogueBox.play([
##         {"name": "REHAN", "text": "Halo!", "portrait": tex, "color": Color.ORANGE},
##         {"name": "BARA", "text": "Hmm...", "thought": true},   # bicara dalam hati
##     ])
##
## Key opsional per baris: "portrait" (Texture2D), "color" (warna nama/foto
## placeholder), "thought" (true = suara hati). Key lain bebas dipakai oleh
## scene lewat sinyal `line_started`.
## Lanjut dengan Spasi / Enter / E / klik kiri.

signal line_started(index: int, line: Dictionary)
signal finished

## Kecepatan mengetik (huruf per detik).
@export var chars_per_second := 45.0
@export var style_normal: StyleBox
@export var style_thought: StyleBox

const THOUGHT_TEXT := Color(0.78, 0.76, 0.98)

@onready var _box: Control = $Box
@onready var _frame: Panel = $Box/Frame
@onready var _portrait_frame: Control = $Box/PortraitFrame
@onready var _placeholder: ColorRect = $Box/PortraitFrame/Placeholder
@onready var _initial: Label = $Box/PortraitFrame/Placeholder/Initial
@onready var _portrait: TextureRect = $Box/PortraitFrame/Portrait
@onready var _name_tag: Control = $Box/NameTag
@onready var _name: Label = $Box/NameTag/Name
@onready var _text: RichTextLabel = $Box/Text
@onready var _next: Label = $Box/Next

var _lines: Array = []
var _index := -1
var _active := false
var _type_tween: Tween
var _next_tween: Tween
var _box_rest_y := 0.0


func _ready() -> void:
	_box.hide()
	_box_rest_y = _box.position.y
	# The default font has no italic face: fake one with a skew.
	var italic := FontVariation.new()
	italic.base_font = ThemeDB.fallback_font
	italic.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.22, 1), Vector2.ZERO)
	_text.add_theme_font_override("italics_font", italic)


func is_active() -> bool:
	return _active


func play(lines: Array) -> void:
	if lines.is_empty():
		return
	_lines = lines
	_index = -1
	_active = true
	_box.show()
	_box.modulate.a = 0.0
	_box.position.y = _box_rest_y + 10.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_box, "modulate:a", 1.0, 0.2)
	t.tween_property(_box, "position:y", _box_rest_y, 0.25) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_show_next()
	await finished


func _show_next() -> void:
	_index += 1
	if _index >= _lines.size():
		_close()
		return
	var line: Dictionary = _lines[_index]
	var thought: bool = line.get("thought", false)
	var speaker: String = line.get("name", "")
	var color: Color = line.get("color", Color(0.7, 0.75, 0.9))

	_frame.add_theme_stylebox_override("panel", style_thought if thought else style_normal)

	_name_tag.visible = speaker != ""
	_name.text = speaker + ("  (dalam hati)" if thought else "")
	_name.add_theme_color_override("font_color", color.lightened(0.35))

	var tex: Texture2D = line.get("portrait")
	_portrait.texture = tex
	_portrait.visible = tex != null
	_placeholder.visible = tex == null
	_placeholder.color = color.darkened(0.45)
	_initial.text = speaker.left(1)
	_portrait_frame.modulate = Color(0.75, 0.75, 0.85) if thought else Color.WHITE

	var body: String = line.get("text", "")
	if thought:
		_text.text = "[i][color=#%s](%s)[/color][/i]" % [THOUGHT_TEXT.to_html(false), body]
	else:
		_text.text = body

	_set_next_visible(false)
	if _type_tween:
		_type_tween.kill()
	_text.visible_ratio = 0.0
	var dur := maxf(_text.get_total_character_count() / chars_per_second, 0.05)
	_type_tween = create_tween()
	_type_tween.tween_property(_text, "visible_ratio", 1.0, dur)
	_type_tween.tween_callback(_set_next_visible.bind(true))

	# Little pop on each new line.
	_portrait_frame.scale = Vector2.ONE * 0.9
	create_tween().tween_property(_portrait_frame, "scale", Vector2.ONE, 0.18) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

	line_started.emit(_index, line)


func _advance() -> void:
	if _type_tween and _type_tween.is_running():
		_type_tween.kill()
		_text.visible_ratio = 1.0
		_set_next_visible(true)
	else:
		_show_next()


func _close() -> void:
	_active = false
	_set_next_visible(false)
	var t := create_tween().set_parallel(true)
	t.tween_property(_box, "modulate:a", 0.0, 0.18)
	t.tween_property(_box, "position:y", _box_rest_y + 10.0, 0.18)
	await t.finished
	_box.hide()
	_box.position.y = _box_rest_y
	finished.emit()


func _set_next_visible(on: bool) -> void:
	if _next_tween:
		_next_tween.kill()
	_next.visible = on
	if on:
		_next.position.y = _next.position.y
		_next_tween = create_tween().set_loops()
		_next_tween.tween_property(_next, "modulate:a", 0.25, 0.45)
		_next_tween.tween_property(_next, "modulate:a", 1.0, 0.45)


func _input(event: InputEvent) -> void:
	if not _active:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("interact") or (
		event is InputEventMouseButton and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		get_viewport().set_input_as_handled()
		_advance()
