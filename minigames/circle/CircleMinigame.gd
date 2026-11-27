class_name CircleMinigame
extends Minigame
## OSU!-style circle minigame. Mouse click on a circle as its ring closes in
## on it (Z hits the oldest circle). Every knob lives in CircleMinigameConfig.
##
## Look: edit minigames/circle/CircleMinigame.tscn, CircleTarget.tscn (the
## circle that is repeated) and GradePopup.tscn (the PERFECT/GOOD/MISS text).
## Scene contract (unique names): %Prompt (Label), %Circles (Control that holds
## the circle nodes), %Popups (Control that holds the grade texts), %Dim.
## The root's size is the play area (circles stay inside it).
##
## Usage (same contract as every Minigame):
##     var mg := CircleMinigame.create()
##     mg.position = Vector2(0, 26); mg.size = Vector2(320, 106)   # play area
##     parent.add_child(mg)
##     mg.start(my_config)
##     var r: Dictionary = await mg.finished
##     # r: success, grades[], perfects, goods, misses, penalty_points,
##     #    score (0..1), multiplier (min..max_multiplier from config)
##
## Rules
##  - A circle's ideal hit moment is `approach_ring_time` after it spawns.
##    |hit - ideal| <= perfect_window -> PERFECT, <= good_window -> GOOD,
##    otherwise MISS (too early or too late). Clicking empty space does nothing.
##  - A circle that outlives `circle_lifetime` is a MISS.
##  - Time only advances in tick(), driven by _process, so freezing pauses it.
##  - tick(), click() and click_oldest() are public so tests (or a replay) can
##    drive it without real input.

signal circle_resolved(index: int, grade: int)

class Circle:
	var index := 0
	var pos := Vector2.ZERO
	var spawn_time := 0.0
	var alive := true
	var node: CircleTarget   # the scene node that draws this circle

const TARGET_SCENE := preload("res://minigames/circle/CircleTarget.tscn")
const POPUP_SCENE := preload("res://minigames/circle/GradePopup.tscn")

var config: CircleMinigameConfig = CircleMinigameConfig.new()
var circles: Array[Circle] = []   # every circle spawned so far, in spawn order
var grades: Array[int] = []       # indexed by circle index
var elapsed := 0.0

var _spawned := 0
var _resolved := 0
var _rng := RandomNumberGenerator.new()

@onready var _circle_layer: Control = %Circles
@onready var _popup_layer: Control = %Popups


## Builds the minigame from its scene (minigames/circle/CircleMinigame.tscn).
static func create() -> CircleMinigame:
	return (load("res://minigames/circle/CircleMinigame.tscn") as PackedScene).instantiate() as CircleMinigame


func start(cfg: Resource = null) -> void:
	config = cfg as CircleMinigameConfig
	if config == null:
		config = CircleMinigameConfig.new()
	for w in config.get_warnings():
		push_warning("CircleMinigame: %s" % w)
	if size == Vector2.ZERO:
		size = get_viewport_rect().size if is_inside_tree() else Vector2(320, 180)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_clear_nodes()
	circles.clear()
	grades.clear()
	grades.resize(config.count())
	grades.fill(TimingBar.Result.MISS)
	elapsed = 0.0
	_spawned = 0
	_resolved = 0
	if config.rng_seed != 0:
		_rng.seed = config.rng_seed
	else:
		_rng.randomize()
	super.start(cfg)
	tick(0.0)   # first circle appears immediately


# ------------------------------------------------------------------ simulation

func tick(delta: float) -> void:
	if not running:
		return
	elapsed += maxf(delta, 0.0)
	while _spawned < config.count() and elapsed >= _spawned * config.interval():
		_spawn_circle()
	for c in circles:
		if c.alive and age_of(c) >= config.lifetime():
			_resolve(c, TimingBar.Result.MISS)
			if not running:
				return


func age_of(c: Circle) -> float:
	return elapsed - c.spawn_time


## Pure grading function. `age` = seconds since the circle spawned.
func evaluate(age: float) -> int:
	var d := absf(age - config.approach_time())
	if d <= config.perfect_win():
		return TimingBar.Result.PERFECT
	if d <= config.good_win():
		return TimingBar.Result.GOOD
	return TimingBar.Result.MISS


## Click at a position in this control's local coordinates. If circles
## overlap, the oldest one is hit. Returns true if a circle was hit.
func click(local_pos: Vector2) -> bool:
	if not running:
		return false
	for c in circles:
		if c.alive and c.pos.distance_to(local_pos) <= config.radius():
			_resolve(c, evaluate(age_of(c)))
			return true
	return false


## Keyboard path: hit the oldest living circle.
func click_oldest() -> bool:
	if not running:
		return false
	for c in circles:
		if c.alive:
			_resolve(c, evaluate(age_of(c)))
			return true
	return false


func alive_count() -> int:
	var n := 0
	for c in circles:
		if c.alive:
			n += 1
	return n


func _spawn_circle() -> void:
	var c := Circle.new()
	c.index = _spawned
	# Scheduled (not actual) time, so a lag spike eats lifetime instead of
	# shifting the whole rhythm.
	c.spawn_time = _spawned * config.interval()
	c.pos = _pick_position()
	c.node = TARGET_SCENE.instantiate()
	_circle_layer.add_child(c.node)
	c.node.setup(c.index, c.pos, config.radius())
	circles.append(c)
	_spawned += 1


func _pick_position() -> Vector2:
	var inset := maxf(config.play_area_margin, 0.0) + config.radius()
	var best := size / 2.0
	for attempt in 12:
		# If the area is too small for the margin, fall back to the middle.
		var x := _rng.randf_range(inset, size.x - inset) if size.x - inset > inset else size.x / 2.0
		var y := _rng.randf_range(inset, size.y - inset) if size.y - inset > inset else size.y / 2.0
		best = Vector2(x, y)
		var clear := true
		for other in circles:
			if other.alive and other.pos.distance_to(best) < config.radius() * 2.0:
				clear = false
				break
		if clear:
			break
	return best


func _resolve(c: Circle, grade: int) -> void:
	if not c.alive:
		return
	c.alive = false
	grades[c.index] = grade
	_resolved += 1
	if c.node != null:
		c.node.queue_free()
		c.node = null
	var pop: GradePopup = POPUP_SCENE.instantiate()
	_popup_layer.add_child(pop)
	pop.show_grade(grade, c.pos)
	circle_resolved.emit(c.index, grade)
	if _resolved >= config.count():
		_finish(build_result(grades, config))


## Turns a list of grades into the result dictionary. Static so a battle (or a
## test) can build the exact same result without playing the minigame.
static func build_result(grade_list: Array[int], cfg: CircleMinigameConfig) -> Dictionary:
	var perfects := 0
	var goods := 0
	var misses := 0
	for g in grade_list:
		match g:
			TimingBar.Result.PERFECT: perfects += 1
			TimingBar.Result.GOOD: goods += 1
			_: misses += 1
	var total := maxi(grade_list.size(), 1)
	var score := (perfects + 0.5 * goods) / float(total)
	return {
		# "success" = not a total failure (at least one circle was hit).
		"success": misses < total,
		"grades": grade_list.duplicate(),
		"perfects": perfects,
		"goods": goods,
		"misses": misses,
		# One point per missed circle. Can never exceed the circle count.
		"penalty_points": clampi(misses, 0, total),
		"score": score,
		"multiplier": cfg.multiplier_for(score),
	}


# ------------------------------------------------------------------ input

func _input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if click(get_local_mouse_position()):
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("attack"):
		if click_oldest():
			get_viewport().set_input_as_handled()


# ------------------------------------------------------------------ visuals

func _process(delta: float) -> void:
	if not running:
		return
	tick(delta)
	var ideal := config.approach_time()
	var late_after := ideal + config.good_win()
	for c in circles:
		if c.alive and c.node != null:
			c.node.show_progress(age_of(c), ideal, late_after)


func _clear_nodes() -> void:
	for layer: Control in [_circle_layer, _popup_layer]:
		for child in layer.get_children():
			layer.remove_child(child)
			child.queue_free()
