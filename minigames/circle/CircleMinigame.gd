class_name CircleMinigame
extends Minigame
## OSU!-style circle minigame. Mouse click on a circle as its ring closes in
## on it (Z hits the oldest circle). Every knob lives in CircleMinigameConfig.
##
## Usage (same contract as every Minigame):
##     var mg := CircleMinigame.new()
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

const POP_TIME := 0.5
const RING_START_SCALE := 3.0
const FONT_SIZE := 8

var config: CircleMinigameConfig = CircleMinigameConfig.new()
var circles: Array[Circle] = []   # every circle spawned so far, in spawn order
var grades: Array[int] = []       # indexed by circle index
var elapsed := 0.0

var _spawned := 0
var _resolved := 0
var _rng := RandomNumberGenerator.new()
var _pops: Array = []             # {pos, grade, age}: little "PERFECT!" labels


func start(cfg: Resource = null) -> void:
	config = cfg as CircleMinigameConfig
	if config == null:
		config = CircleMinigameConfig.new()
	for w in config.get_warnings():
		push_warning("CircleMinigame: %s" % w)
	if size == Vector2.ZERO:
		size = get_viewport_rect().size if is_inside_tree() else Vector2(320, 180)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	circles.clear()
	_pops.clear()
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
	queue_redraw()


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
	_pops.append({"pos": c.pos, "grade": grade, "age": 0.0})
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


# ------------------------------------------------------------------ drawing

func _process(delta: float) -> void:
	if running:
		tick(delta)
	for p in _pops:
		p["age"] += delta
	_pops = _pops.filter(func(p: Dictionary) -> bool: return p["age"] < POP_TIME)
	queue_redraw()


func _draw() -> void:
	if not running and _pops.is_empty():
		return
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.35))
	draw_string(font, Vector2(0, 9), "Klik lingkaran pas ringnya menutup! (Z = terlama)",
		HORIZONTAL_ALIGNMENT_CENTER, size.x, FONT_SIZE, Color(1, 1, 1, 0.8))
	var ideal := config.approach_time()
	var late_after := ideal + config.good_win()
	for c in circles:
		if not c.alive:
			continue
		var age := age_of(c)
		var ring_t := clampf(age / ideal, 0.0, 1.0)
		var ring_r := config.radius() * lerpf(RING_START_SCALE, 1.0, ring_t)
		var fill := Color(0.95, 0.75, 0.2, 0.85)
		if age > late_after:
			fill = Color(0.9, 0.3, 0.25, 0.7)   # too late: it is about to expire
		draw_circle(c.pos, config.radius(), fill)
		draw_arc(c.pos, config.radius(), 0.0, TAU, 24, Color.WHITE, 1.0)
		draw_arc(c.pos, ring_r, 0.0, TAU, 32, Color(1, 1, 1, 0.9), 1.0)
		draw_string(font, c.pos + Vector2(-8, 3), str(c.index + 1),
			HORIZONTAL_ALIGNMENT_CENTER, 16, FONT_SIZE, Color.BLACK)
	for p in _pops:
		var col := Color.WHITE
		var text := ""
		match p["grade"]:
			TimingBar.Result.PERFECT:
				col = Color(0.3, 1.0, 0.45)
				text = "PERFECT"
			TimingBar.Result.GOOD:
				col = Color(0.95, 0.85, 0.3)
				text = "GOOD"
			_:
				col = Color(1.0, 0.4, 0.4)
				text = "MISS"
		col.a = 1.0 - p["age"] / POP_TIME
		draw_string(font, p["pos"] + Vector2(-20, -p["age"] * 16.0 - 4), text,
			HORIZONTAL_ALIGNMENT_CENTER, 40, FONT_SIZE, col)
