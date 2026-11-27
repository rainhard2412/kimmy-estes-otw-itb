class_name WalkSim
extends RefCounted
## The top-down walking view, as pure logic (no drawing). The WAHANA walks by
## itself toward the nearest enemy; enemies march straight at the WAHANA.
## tick() returns the enemies that touched the WAHANA this step (the caller
## starts a battle, then calls resolve_contact()).

class Walker:
	var id := 0
	var data: SimEnemyData
	var pos := Vector2.ZERO

var config: ManagementConfig
var rng := RandomNumberGenerator.new()
var wahana_pos := Vector2.ZERO
var enemies: Array[Walker] = []
var elapsed := 0.0
var spawned_count := 0
var defeated_count := 0
## True while the WAHANA walked this step (for the little walking bob).
var moving := false
## Hook for later: scales the WAHANA's walking speed (e.g. a broken leg).
## Nothing sets this yet, so it stays 1.0.
var speed_multiplier := 1.0

var _spawn_timer := 0.0
var _next_id := 1

const ARENA_MARGIN := 8.0


func _init(cfg: ManagementConfig) -> void:
	config = cfg
	wahana_pos = cfg.arena_size / 2.0
	_spawn_timer = maxf(cfg.initial_spawn_delay, 0.0)
	if cfg.rng_seed != 0:
		rng.seed = cfg.rng_seed + 1
	else:
		rng.randomize()


# ------------------------------------------------------------------ queries

func total() -> int:
	return config.total_enemies()

func remaining() -> int:
	return maxi(total() - defeated_count, 0)

func is_chapter() -> bool:
	return config.mode == ManagementConfig.Mode.CHAPTER

## Chapter won: every enemy of the list has spawned and been defeated.
func is_cleared() -> bool:
	return is_chapter() and spawned_count >= total() and enemies.is_empty() and defeated_count >= total()

func nearest_enemy() -> Walker:
	var best: Walker = null
	var best_d := INF
	for e in enemies:
		var d := e.pos.distance_to(wahana_pos)
		if d < best_d:
			best = e
			best_d = d
	return best


# ------------------------------------------------------------------ simulation

## Advance the walking view. Returns the group of enemies in contact (nearest
## first, at most max_group_size), or an empty array.
func tick(delta: float) -> Array[Walker]:
	var touching: Array[Walker] = []
	if delta <= 0.0:
		return touching
	delta = minf(delta, 1.0)
	elapsed += delta
	_try_spawn(delta)
	_move(delta)
	return _contacts()


## Remove the enemies of a finished contact. `won` counts them as defeated.
func resolve_contact(group: Array, won: bool) -> void:
	for w in group:
		enemies.erase(w)
		if won:
			defeated_count += 1


func _can_spawn_more() -> bool:
	if is_chapter():
		return spawned_count < total()
	return _total_weight() > 0.0


func _total_weight() -> float:
	var t := 0.0
	for e in config.enemies:
		if e != null:
			t += maxf(e.weight, 0.0)
	return t


func _try_spawn(dt: float) -> void:
	if not _can_spawn_more() or enemies.size() >= config.alive_cap():
		return   # the timer only runs while there is room
	_spawn_timer -= dt
	if _spawn_timer > 0.0:
		return
	var w := Walker.new()
	w.id = _next_id
	_next_id += 1
	w.data = _pick_data()
	w.pos = _spawn_position()
	enemies.append(w)
	spawned_count += 1
	_spawn_timer = config.interval_at(elapsed)


func _pick_data() -> SimEnemyData:
	if is_chapter():
		var d := config.enemies[spawned_count]
		return d if d != null else SimEnemyData.new()
	var roll := rng.randf() * _total_weight()
	for e in config.enemies:
		if e == null:
			continue
		roll -= maxf(e.weight, 0.0)
		if roll <= 0.0:
			return e
	# Float rounding can leave a sliver: fall back to the last usable entry.
	for i in range(config.enemies.size() - 1, -1, -1):
		if config.enemies[i] != null and config.enemies[i].weight > 0.0:
			return config.enemies[i]
	return SimEnemyData.new()


## A random point on one of the four arena edges, at least min_spawn_distance
## from the WAHANA. If that is impossible (tiny arena) the farthest point tried wins.
func _spawn_position() -> Vector2:
	var a := config.arena_size
	var best := Vector2.ZERO
	var best_d := -1.0
	for i in 24:
		var p: Vector2
		match rng.randi() % 4:
			0: p = Vector2(rng.randf() * a.x, 0.0)
			1: p = Vector2(rng.randf() * a.x, a.y)
			2: p = Vector2(0.0, rng.randf() * a.y)
			_: p = Vector2(a.x, rng.randf() * a.y)
		var d := p.distance_to(wahana_pos)
		if d >= config.min_spawn_distance:
			return p
		if d > best_d:
			best = p
			best_d = d
	return best


func _move(dt: float) -> void:
	for e in enemies:
		e.pos = e.pos.move_toward(wahana_pos, maxf(config.enemy_speed, 0.0) * dt)
	moving = false
	var target := nearest_enemy()
	if target != null:
		var before := wahana_pos
		var step := maxf(config.wahana_speed, 0.0) * maxf(speed_multiplier, 0.0) * dt
		wahana_pos = wahana_pos.move_toward(target.pos, step)
		var a := config.arena_size
		wahana_pos = wahana_pos.clamp(Vector2(ARENA_MARGIN, ARENA_MARGIN), a - Vector2(ARENA_MARGIN, ARENA_MARGIN))
		moving = wahana_pos != before


func _contacts() -> Array[Walker]:
	var close: Array[Walker] = []
	for e in enemies:
		if e.pos.distance_to(wahana_pos) <= config.contact_distance:
			close.append(e)
	close.sort_custom(func(a: Walker, b: Walker) -> bool:
		return a.pos.distance_to(wahana_pos) < b.pos.distance_to(wahana_pos))
	if close.size() > config.group_cap():
		close.resize(config.group_cap())
	return close
