class_name Management
extends Node
## The management-simulator mode. Standalone: give it a ManagementConfig, wait
## for `finished`.
##
##     var m := preload("res://management/Management.tscn").instantiate()
##     m.config = preload("res://data/management/chapter_demo.tres")
##     add_child(m)
##     var result: Dictionary = await m.finished
##     # won, reason ("cleared" / "integrity" / "battle"), score, defeated,
##     # total, elapsed, mode
##
## What the player sees: the WAHANA walking around a top-down arena (it walks
## to the nearest enemy by itself). Tab opens a fullscreen blurred map of the
## WAHANA's systems; errors appear there at random (or when story code calls
## trigger_error()), and clicking an errored node plays its repair minigame.
## Enemies keep coming while the map is open.
##
## When an enemy touches the WAHANA the whole sim pauses (errors stop, the map
## closes, an open repair minigame freezes with its progress kept) and the
## turn-based battle plays on top. Afterwards everything resumes.
##
## Story hooks:  sim.trigger_error(id)  sim.trigger_surge([ids])
##               sim.is_online(id)      sim.get_modifier(key)

signal finished(result: Dictionary)
signal contact_started(enemy_count: int)
signal contact_ended(won: bool)

@export var config: ManagementConfig
## Start by itself when added to the tree. Turn off to call start() yourself.
@export var autostart := true
## Tests: skip _process and advance time with tick() instead.
@export var drive_manually := false
## Passed to every battle (tests set this near 0).
@export var battle_pace := 1.0
## Passed to every battle: >= 0 resolves Perfect Block checks without the bar.
@export var battle_auto_block := -1

const BattleScene := preload("res://battle/Battle.tscn")

var sim: SystemSim
var walk: WalkSim
var map: NodeMap
var score := 0
var elapsed := 0.0
var active_battle: Node = null
var is_paused := false
var is_finished := false

var _repairing := ""
var _mg: Minigame = null
var _previous_story_mode := true
var _started := false

var _world := Node2D.new()
var _arena := ArenaView.new()
var _hud := CanvasLayer.new()
var _map_layer := CanvasLayer.new()
var _integrity_bar := ProgressBar.new()
var _status := Label.new()
var _alert := Label.new()
var _map_button := Button.new()
var _toast := ""
var _toast_until := 0


func _ready() -> void:
	if autostart and config != null:
		start(config)


func start(cfg: ManagementConfig = null) -> void:
	if _started:
		return
	if cfg != null:
		config = cfg
	if config == null:
		push_error("Management: no config")
		return
	_started = true
	for w in config.get_warnings():
		push_warning("ManagementConfig: %s" % w)

	_previous_story_mode = GameState.story_mode
	GameState.story_mode = config.story_mode

	sim = SystemSim.new(config)
	walk = WalkSim.new(config)
	sim.integrity_depleted.connect(_on_integrity_depleted)
	sim.error_triggered.connect(_on_error_triggered)
	sim.repaired.connect(func(id: String) -> void: _say("%s diperbaiki" % _name_of(id)))

	add_child(_world)
	_arena.walk = walk
	_world.add_child(_arena)

	_hud.layer = 5
	add_child(_hud)
	_build_hud()

	_map_layer.layer = 10
	add_child(_map_layer)
	map = NodeMap.new()
	_map_layer.add_child(map)
	map.bind(sim)
	map.node_pressed.connect(request_repair)
	_update_hud()


func _exit_tree() -> void:
	# Never leave a changed global behind.
	if _started:
		GameState.story_mode = _previous_story_mode


# ------------------------------------------------------------------ main loop

func _process(delta: float) -> void:
	if not drive_manually:
		tick(delta)


## Advance the whole sim by `delta` seconds. Does nothing while paused (a
## battle is playing) or finished.
func tick(delta: float) -> void:
	if not _started or is_paused or is_finished or delta <= 0.0:
		return
	elapsed += delta
	var touching := walk.tick(delta)
	sim.tick(delta)
	_update_hud()
	if is_finished:
		return   # integrity ran out during sim.tick
	if not touching.is_empty():
		_run_contact(touching)


# ------------------------------------------------------------------ contact / battle

func _run_contact(group: Array) -> void:
	# Pause FIRST (synchronously), before the first await.
	is_paused = true
	contact_started.emit(group.size())
	var map_was_open := map.is_open()
	map.suspend()
	if _mg != null:
		_mg.set_frozen(true)
	_world.visible = false
	_hud.visible = false

	var datas: Array = []
	for w in group:
		datas.append(w.data)
	var battle: Node = BattleScene.instantiate()
	battle.waves = Encounter.build(datas)
	battle.pace = battle_pace
	battle.auto_block = battle_auto_block
	active_battle = battle
	add_child(battle)
	var result: Dictionary = await battle.battle_finished
	var won: bool = result.get("won", false)
	battle.queue_free()
	active_battle = null
	if is_finished:
		return   # finished externally while fighting (e.g. abort())

	score += int(result.get("score", 0))
	if won:
		for w in group:
			score += w.data.clear_score
	walk.resolve_contact(group, won)
	contact_ended.emit(won)

	_world.visible = true
	_hud.visible = true
	if _mg != null:
		_mg.set_frozen(false)
	if map_was_open:
		map.resume()
	is_paused = false
	_update_hud()

	if not won:
		_finish(false, "battle")
	elif walk.is_cleared():
		_finish(true, "cleared")


# ------------------------------------------------------------------ repairs

## Called when a node is clicked. One repair at a time.
func request_repair(id: String) -> void:
	if is_paused or is_finished or _repairing != "" or not sim.has_node(id):
		return
	if sim.state_of(id) == SystemSim.State.HEALTHY:
		map.show_message("%s baik-baik saja." % _name_of(id))
		return
	if not sim.can_repair(id):
		map.show_message("%s terkunci: perbaiki %s dulu." % [_name_of(id), _name_of(sim.blocker_of(id))])
		return

	var data := sim.data_of(id)
	var mg: Minigame = null
	if data.repair_scene != null:
		mg = data.repair_scene.instantiate() as Minigame
		if mg == null:
			push_error("Management: repair_scene of '%s' is not a Minigame; using color-match" % id)
	if mg == null:
		mg = ColorMatchMinigame.new()

	_repairing = id
	_mg = mg
	map.host_minigame(mg)
	mg.start(data.repair_config)
	var result: Dictionary = await mg.finished
	if _mg != mg:
		return
	_mg = null
	_repairing = ""
	map.clear_minigame()
	if is_finished or result.get("cancelled", false):
		return
	if result.get("success", false):
		if not sim.repair(id):
			# e.g. a dependency broke while the minigame was open
			map.show_message("%s belum bisa diperbaiki sekarang." % _name_of(id))
	else:
		map.show_message("Perbaikan %s gagal." % _name_of(id))


func cancel_repair() -> void:
	if _mg != null and _mg.running:
		_mg.cancel()   # emits finished, which cleans up in request_repair()


func is_repairing() -> bool:
	return _repairing != ""


# ------------------------------------------------------------------ input / map

func _unhandled_input(event: InputEvent) -> void:
	if is_paused or is_finished or not _started:
		return
	if event.is_action_pressed("toggle_map"):
		toggle_map()
		get_viewport().set_input_as_handled()
	elif OS.is_debug_build() and event is InputEventKey and event.pressed and not event.echo:
		# Debug helpers so scripted errors can be tried without waiting.
		if event.keycode == KEY_F1:
			_debug_error(1)
		elif event.keycode == KEY_F2:
			_debug_error(3)


func toggle_map() -> void:
	if is_paused or is_finished:
		return
	if map.is_open():
		cancel_repair()   # closing the map abandons the repair attempt
	map.toggle()


func _debug_error(count: int) -> void:
	var healthy: Array = []
	for n in sim.nodes:
		if sim.state_of(n.id) == SystemSim.State.HEALTHY:
			healthy.append(n.id)
	healthy.shuffle()
	sim.trigger_surge(healthy.slice(0, count))


# ------------------------------------------------------------------ ending

func _on_integrity_depleted() -> void:
	_finish(false, "integrity")


func _on_error_triggered(id: String, _scripted: bool) -> void:
	_say("ERROR: %s!" % _name_of(id))


## Stop the session from outside (e.g. story script skips it). Reports a loss
## with reason "aborted".
func abort() -> void:
	_finish(false, "aborted")


func _finish(won: bool, reason: String) -> void:
	if is_finished:
		return
	is_finished = true
	cancel_repair()
	map.suspend()
	GameState.story_mode = _previous_story_mode
	if score > GameState.high_score and config.mode == ManagementConfig.Mode.ENDLESS:
		GameState.high_score = score
	finished.emit({
		"won": won,
		"reason": reason,
		"score": score,
		"defeated": walk.defeated_count,
		"total": walk.total(),
		"elapsed": elapsed,
		"mode": config.mode,
	})


# ------------------------------------------------------------------ HUD

func _build_hud() -> void:
	_integrity_bar.position = Vector2(6, 4)
	_integrity_bar.size = Vector2(110, 8)
	_integrity_bar.max_value = config.integrity_max
	_integrity_bar.value = config.integrity_max
	_integrity_bar.show_percentage = false
	_hud.add_child(_integrity_bar)

	for l: Label in [_status, _alert]:
		l.add_theme_font_size_override("font_size", 8)
		l.add_theme_constant_override("outline_size", 3)
		l.add_theme_color_override("font_outline_color", Color.BLACK)
		_hud.add_child(l)
	_status.position = Vector2(6, 14)
	_alert.position = Vector2(6, 164)
	_alert.size = Vector2(240, 12)

	_map_button.text = "Sistem [Tab]"
	_map_button.size = Vector2(70, 16)
	_map_button.position = Vector2(244, 160)
	_map_button.focus_mode = Control.FOCUS_NONE
	_map_button.add_theme_font_size_override("font_size", 8)
	_map_button.pressed.connect(toggle_map)
	_hud.add_child(_map_button)


func _update_hud() -> void:
	if not _started:
		return
	_integrity_bar.value = sim.integrity
	if config.mode == ManagementConfig.Mode.CHAPTER:
		_status.text = "Integritas WAHANA   Musuh: %d/%d" % [walk.defeated_count, walk.total()]
	else:
		_status.text = "Integritas WAHANA   Skor: %d   Musuh: %d" % [score, walk.defeated_count]
	var broken := sim.broken_count()
	if Time.get_ticks_msec() < _toast_until:
		_alert.text = _toast
		_alert.modulate = Color(1, 0.85, 0.4)
	elif broken > 0:
		_alert.text = "! %d sistem bermasalah" % broken
		# flash so it is noticed from the corner of the eye
		_alert.modulate = Color(1, 0.4, 0.4) if floori(Time.get_ticks_msec() / 400.0) % 2 == 0 else Color.WHITE
	else:
		_alert.text = ""


func _say(text: String) -> void:
	_toast = text
	_toast_until = Time.get_ticks_msec() + 2500


func _name_of(id: String) -> String:
	var d := sim.data_of(id) if sim != null else null
	return d.display_name if d != null and d.display_name != "" else id
