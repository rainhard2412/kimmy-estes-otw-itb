class_name SystemSim
extends RefCounted
## The WAHANA's systems: errors, countdowns, dependencies, integrity.
## Pure logic with no UI. Drive it with tick(delta), so it is easy to test,
## pause (just stop ticking) and script.
##
## Life of a system:   HEALTHY --error--> ERROR --countdown hits 0--> FAILED
##                          ^                |                          |
##                          +------------ repair() ---------------------+
##
## "Offline" is separate from state: a system is blocked while any system it
## DEPENDS_ON is not online (so blocking is transitive). A blocked system can
## still be in ERROR/FAILED, but cannot be repaired until its parents are.

enum State { HEALTHY, ERROR, FAILED }

signal state_changed(id: String, state: int)
## Fired for every new error, random or scripted.
signal error_triggered(id: String, scripted: bool)
signal repaired(id: String)
signal integrity_changed(value: float)
## Emitted once, when integrity first reaches 0.
signal integrity_depleted

## A frame hitch can't fast-forward the sim by more than this many seconds.
const MAX_TICK := 10.0
## Long ticks are simulated in steps of at most this size, so error chances stay
## accurate no matter the frame rate.
const MAX_STEP := 0.25

var config: ManagementConfig
var integrity := 0.0
var elapsed := 0.0
var nodes: Array[SystemNodeData] = []
var edges: Array[NodeEdge] = []
var rng := RandomNumberGenerator.new()
## Runtime switch for random errors (story code can turn them off and on).
var random_errors_enabled := true

var _state := {}       # id -> State
var _countdown := {}   # id -> seconds until FAILED (only while ERROR)
var _grace := {}       # id -> seconds before it may randomly break again
var _gap := 0.0        # seconds before the next random error is allowed
var _depleted := false


func _init(cfg: ManagementConfig) -> void:
	config = cfg
	integrity = cfg.integrity_max
	random_errors_enabled = cfg.random_errors_enabled
	if cfg.rng_seed != 0:
		rng.seed = cfg.rng_seed
	else:
		rng.randomize()
	if cfg.graph != null:
		var v := cfg.graph.validated()
		nodes = v["nodes"]
		edges = v["edges"]
	for n in nodes:
		_state[n.id] = State.HEALTHY
		_grace[n.id] = 0.0
	# No random error in the first moments of a session.
	_gap = maxf(cfg.min_error_gap, 0.0)


# ------------------------------------------------------------------ queries

func has_node(id: String) -> bool:
	return _state.has(id)

func data_of(id: String) -> SystemNodeData:
	for n in nodes:
		if n.id == id:
			return n
	return null

func state_of(id: String) -> int:
	return _state.get(id, State.HEALTHY)

func countdown_of(id: String) -> float:
	return _countdown.get(id, 0.0)

func is_depleted() -> bool:
	return _depleted

## Systems this one depends on (direct parents only).
func parents_of(id: String) -> Array[String]:
	var out: Array[String] = []
	for e in edges:
		if e.type == NodeEdge.Type.DEPENDS_ON and e.from_id == id:
			out.append(e.to_id)
	return out

## True if any system this one depends on (directly or not) is not online.
func is_blocked(id: String) -> bool:
	for p in parents_of(id):
		if not is_online(p):
			return true
	return false

## Working: healthy and not blocked. This is THE hook other systems (battle,
## story) should ask: sim.is_online("lengan").
func is_online(id: String) -> bool:
	return has_node(id) and state_of(id) == State.HEALTHY and not is_blocked(id)

func can_repair(id: String) -> bool:
	return has_node(id) and state_of(id) != State.HEALTHY and not is_blocked(id)

## The first parent that is stopping `id` from being repaired, or "".
func blocker_of(id: String) -> String:
	for p in parents_of(id):
		if not is_online(p):
			return p
	return ""

func broken_ids() -> Array[String]:
	var out: Array[String] = []
	for n in nodes:
		if _state[n.id] != State.HEALTHY:
			out.append(n.id)
	return out

func broken_count() -> int:
	return broken_ids().size()

## Product of `key` over every system that is currently down (ERROR or FAILED),
## using SystemNodeData.down_modifiers. 1.0 (or `default`) if none apply.
## Example: get_modifier("player_damage_mult"). Battle does not read this yet.
func get_modifier(key: String, default := 1.0) -> float:
	var result := default
	for n in nodes:
		if _state[n.id] != State.HEALTHY and n.down_modifiers.has(key):
			var v = n.down_modifiers[key]
			if v is float or v is int:
				result *= float(v)
	return result


# ------------------------------------------------------------------ actions

## Scripted error: ignores the random gap, the concurrent cap and repair grace.
## Returns false if the system doesn't exist or is already broken.
func trigger_error(id: String, scripted := true) -> bool:
	if not has_node(id) or _state[id] != State.HEALTHY or _depleted:
		return false
	_state[id] = State.ERROR
	_countdown[id] = maxf(data_of(id).error_countdown, 1.0)
	state_changed.emit(id, State.ERROR)
	error_triggered.emit(id, scripted)
	return true

## Errors several systems at once (a Qliphoth-meltdown style surge). Returns how
## many actually broke.
func trigger_surge(ids: Array) -> int:
	var count := 0
	for id in ids:
		if trigger_error(str(id)):
			count += 1
	return count

## Fix a system. Returns false if it isn't broken or is still blocked.
func repair(id: String) -> bool:
	if not can_repair(id) or _depleted:
		return false
	_state[id] = State.HEALTHY
	_countdown.erase(id)
	_grace[id] = maxf(config.repair_grace, 0.0)
	state_changed.emit(id, State.HEALTHY)
	repaired.emit(id)
	return true

func restore_integrity(amount: float) -> void:
	if _depleted or amount <= 0.0:
		return
	integrity = minf(integrity + amount, config.integrity_max)
	integrity_changed.emit(integrity)

func damage_integrity(amount: float) -> void:
	if amount > 0.0:
		_set_integrity(integrity - amount)


# ------------------------------------------------------------------ simulation

func tick(delta: float) -> void:
	if _depleted or delta <= 0.0:
		return
	var remaining := minf(delta, MAX_TICK)
	while remaining > 0.0 and not _depleted:
		var dt := minf(remaining, MAX_STEP)
		remaining -= dt
		_step(dt)


func _step(dt: float) -> void:
	elapsed += dt
	_gap = maxf(_gap - dt, 0.0)
	var drain := 0.0
	for n in nodes:
		var id := n.id
		_grace[id] = maxf(_grace[id] - dt, 0.0)
		match _state[id]:
			State.ERROR:
				_countdown[id] -= dt
				if _countdown[id] <= 0.0:
					_countdown.erase(id)
					_state[id] = State.FAILED
					state_changed.emit(id, State.FAILED)
			State.FAILED:
				drain += n.drain_per_sec * dt
	if drain > 0.0:
		_set_integrity(integrity - drain)
	if _depleted:
		return
	_random_errors(dt)


func _set_integrity(value: float) -> void:
	var v := clampf(value, 0.0, config.integrity_max)
	if v != integrity:
		integrity = v
		integrity_changed.emit(integrity)
	if integrity <= 0.0 and not _depleted:
		_depleted = true
		integrity_depleted.emit()


func _random_errors(dt: float) -> void:
	if not random_errors_enabled or _gap > 0.0:
		return
	if broken_count() >= maxi(config.max_concurrent_errors, 1):
		return
	var hit: Array[String] = []
	for n in nodes:
		var id := n.id
		if _state[id] != State.HEALTHY or _grace[id] > 0.0 or not is_online(id):
			continue
		var rate := n.error_chance_per_sec + _spread_bonus(id)
		if rate > 0.0 and rng.randf() < 1.0 - exp(-rate * dt):
			hit.append(id)
	if hit.is_empty():
		return
	trigger_error(hit[rng.randi() % hit.size()], false)
	_gap = maxf(config.min_error_gap, 0.0)


## Extra error chance per second from broken systems that SPREAD_TO this one.
func _spread_bonus(id: String) -> float:
	var bonus := 0.0
	for e in edges:
		if e.type == NodeEdge.Type.SPREADS_TO and e.to_id == id and _state[e.from_id] != State.HEALTHY:
			bonus += e.spread_bonus
	return bonus
