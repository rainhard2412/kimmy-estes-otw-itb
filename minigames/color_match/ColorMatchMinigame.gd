class_name ColorMatchMinigame
extends Minigame
## Placeholder repair minigame: a target color is shown, click the button with
## the same color. Match `rounds_needed` in a row; a wrong click resets the
## streak (not the minigame). Replace it later by pointing a node's
## `repair_scene` at any other Minigame.
##
## Config (optional): ColorMatchConfig. Result: success, wrong_clicks, rounds.

signal round_changed(streak: int)

const PALETTE: Array[Color] = [
	Color(0.9, 0.25, 0.25), Color(0.25, 0.5, 0.95), Color(0.3, 0.8, 0.4),
	Color(0.95, 0.8, 0.2), Color(0.75, 0.4, 0.9), Color(0.95, 0.55, 0.2),
]

var config: ColorMatchConfig = ColorMatchConfig.new()
var streak := 0
var wrong_clicks := 0
var target := 0                 # palette index of the color to match
var choices: Array[int] = []    # palette index per button, left to right

var _rng := RandomNumberGenerator.new()
var _buttons: Array[Button] = []
var _swatch := ColorRect.new()
var _label := Label.new()
var _built := false


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
	if size == Vector2.ZERO:
		size = Vector2(160, 90)
	_build()
	super.start(cfg)
	_new_round()


func _build() -> void:
	if _built:
		for b in _buttons:
			b.queue_free()
		_buttons.clear()
	else:
		_label.add_theme_font_size_override("font_size", 8)
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.size = Vector2(size.x, 12)
		_label.position = Vector2(0, 2)
		add_child(_label)
		_swatch.size = Vector2(36, 22)
		_swatch.position = Vector2((size.x - 36) / 2.0, 18)
		add_child(_swatch)
		_built = true
	var n := config.color_count()
	var gap := 4.0
	var bw := minf((size.x - gap * (n + 1)) / n, 36.0)
	var total := bw * n + gap * (n - 1)
	for i in n:
		var b := Button.new()
		b.size = Vector2(bw, 24)
		b.position = Vector2((size.x - total) / 2.0 + i * (bw + gap), 50)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(choose.bind(i))
		add_child(b)
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
		var st := StyleBoxFlat.new()
		st.bg_color = PALETTE[choices[i]]
		_buttons[i].add_theme_stylebox_override("normal", st)
		_buttons[i].add_theme_stylebox_override("hover", st)
		_buttons[i].add_theme_stylebox_override("pressed", st)
	_label.text = "Cocokkan warna! (%d/%d)" % [streak, config.rounds()]
	round_changed.emit(streak)


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
