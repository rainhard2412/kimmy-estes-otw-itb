class_name ColorMatchMinigame
extends Minigame
## Placeholder repair minigame: a target color is shown, click the button with
## the same color. Match `rounds_needed` in a row; a wrong click resets the
## streak (not the minigame). Replace it later by pointing a node's
## `repair_scene` at any other Minigame scene.
##
## Look: edit minigames/color_match/ColorMatchMinigame.tscn and ColorButton.tscn.
## Scene contract (unique names): %Prompt (Label), %Swatch (ColorRect, shows the
## target), %Buttons (a container; one ColorButton is added per color).
## ColorButton.tscn is the button that gets repeated: restyle it once.
##
## Config (optional): ColorMatchConfig. Result: success, wrong_clicks, rounds.

signal round_changed(streak: int)

const PALETTE: Array[Color] = [
	Color(0.9, 0.25, 0.25), Color(0.25, 0.5, 0.95), Color(0.3, 0.8, 0.4),
	Color(0.95, 0.8, 0.2), Color(0.75, 0.4, 0.9), Color(0.95, 0.55, 0.2),
]
const BUTTON_SCENE := preload("res://minigames/color_match/ColorButton.tscn")

var config: ColorMatchConfig = ColorMatchConfig.new()
var streak := 0
var wrong_clicks := 0
var target := 0                 # palette index of the color to match
var choices: Array[int] = []    # palette index per button, left to right

var _rng := RandomNumberGenerator.new()
var _buttons: Array[Button] = []

@onready var _prompt: Label = %Prompt
@onready var _swatch: ColorRect = %Swatch
@onready var _button_row: Container = %Buttons


## Builds the minigame from its scene (minigames/color_match/ColorMatchMinigame.tscn).
static func create() -> ColorMatchMinigame:
	return (load("res://minigames/color_match/ColorMatchMinigame.tscn") as PackedScene).instantiate() as ColorMatchMinigame


func start(cfg: Resource = null) -> void:
	config = cfg as ColorMatchConfig
	if config == null:
		config = ColorMatchConfig.new()
	streak = 0
	wrong_clicks = 0
	if config.rng_seed != 0:
		_rng.seed = config.rng_seed
	else:
		_rng.randomize()
	_rebuild_buttons()
	super.start(cfg)
	_new_round()


## One ColorButton per color shown (the count comes from the config).
func _rebuild_buttons() -> void:
	for b in _buttons:
		_button_row.remove_child(b)
		b.queue_free()
	_buttons.clear()
	for i in config.color_count():
		var b: Button = BUTTON_SCENE.instantiate()
		b.pressed.connect(choose.bind(i))
		_button_row.add_child(b)
		_buttons.append(b)


func _new_round() -> void:
	# Pick `n` different palette colors, and one of them is the target.
	var n := config.color_count()
	var pool: Array[int] = []
	for i in PALETTE.size():
		pool.append(i)
	for i in range(pool.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp := pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	choices.clear()
	for i in n:
		choices.append(pool[i])
	target = choices[_rng.randi() % n]
	_swatch.color = PALETTE[target]
	for i in n:
		_paint(_buttons[i], PALETTE[choices[i]])
	_prompt.text = "Cocokkan warna! (%d/%d)" % [streak, config.rounds()]
	round_changed.emit(streak)


## Tint a ColorButton. Its StyleBoxes live in ColorButton.tscn, so duplicate
## them (they are shared between instances) and only change the color.
func _paint(b: Button, color: Color) -> void:
	for style_name in ["normal", "hover", "pressed", "focus"]:
		var sb := b.get_theme_stylebox(style_name)
		if sb is StyleBoxFlat:
			var own: StyleBoxFlat = sb.duplicate()
			own.bg_color = color
			b.add_theme_stylebox_override(style_name, own)


## Click button `i` (also what the buttons call). Returns true if correct.
func choose(i: int) -> bool:
	if not running or i < 0 or i >= choices.size():
		return false
	if choices[i] == target:
		streak += 1
		if streak >= config.rounds():
			_finish({"success": true, "wrong_clicks": wrong_clicks, "rounds": streak})
		else:
			_new_round()
		return true
	wrong_clicks += 1
	streak = 0
	_new_round()
	return false


## The button index holding the target color (for tests and hints).
func correct_index() -> int:
	return choices.find(target)
