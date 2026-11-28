extends Node2D
## Turn-based battle with waves.
##
## Flow:  next wave -> PLAYER_TURN (1-2 actions) -> ENEMY_TURN -> PLAYER_TURN ...
##        wave cleared -> next wave ... last wave cleared -> WIN
##
## Look and layout live in battle/Battle.tscn (edit them in the editor):
##   %Camera (shakes)  %Field > %PlayerUnit, %Enemies (EnemySlot markers decide
##   where each enemy stands)  %TargetCursor
##   HUD: %Log  %Hint  %Banner  %TimingBar  %MinigameSlot (where the circle
##   minigame appears)  %SkillBar (one SkillButton per skill is added here)
##   %ScreenFlash
## Each enemy's own look is its `unit_scene` (battle/units/).
##
## To use from a story script:
##     var battle := preload("res://battle/Battle.tscn").instantiate()
##     battle.waves = Waves.ch1_final()
##     add_child(battle)
##     var result: Dictionary = await battle.battle_finished   # {won, score}

enum State { BUSY, PLAYER_TURN, ENEMY_TURN, WIN, LOSE }
enum Preset { CH1_DREAM, CH1_FINAL }

signal battle_finished(result: Dictionary)

@export var skills: Array[SkillData] = [
	preload("res://data/skills/pukulan_dasar.tres"),
	preload("res://data/skills/tendangan_bara.tres"),
	preload("res://data/skills/perisai_kalpataru.tres"),
	preload("res://data/skills/hantaman_kalpataru.tres"),
]
## Used only when `waves` is left empty (e.g. running this scene with F6).
@export var preset := Preset.CH1_FINAL
@export var player_max_hp := 30
## Multiplier for every pause. Tests set this near 0 to run battles instantly.
@export var pace := 1.0
## Debug/test: if >= 0, Perfect Block checks resolve instantly with this
## TimingBar.Result instead of showing the bar.
@export var auto_block := -1
## Debug/test: if >= 0, skip the circle minigame and pretend exactly this many
## circles were missed (the rest PERFECT).
@export var auto_circle_misses := -1
## Most extra cooldown turns penalties can add to one skill use.
@export var max_extra_cooldown := 3

var waves: Array[WaveData] = []

var state := State.BUSY
var player_hp := 0
var score := 0
var cooldowns: Array[int] = []
var defending := false
var actions_left := 0
var bonus_actions := 0
var cannon_fired := false

## The circle minigame while one is playing (null otherwise). Tests drive it.
var active_minigame: CircleMinigame = null

var _enemies: Array[EnemyUnit] = []
var _target := 0
var _wave_index := -1
var _wave_round := 0
var _used_this_turn: Array[int] = []

# --- nodes (all come from Battle.tscn) ---
@onready var _camera: Camera2D = %Camera
@onready var _player: PlayerUnit = %PlayerUnit
@onready var _enemy_parent: Node2D = %Enemies
@onready var _cursor: Node2D = %TargetCursor
@onready var _log: Label = %Log
@onready var _hint: Label = %Hint
@onready var _banner: Label = %Banner
@onready var _bar: TimingBar = %TimingBar
@onready var _minigame_slot: Control = %MinigameSlot
@onready var _skill_bar: Container = %SkillBar
@onready var _flash_rect: ColorRect = %ScreenFlash
var _buttons: Array[Button] = []

const SKILL_BUTTON := preload("res://battle/SkillButton.tscn")
## Enemies stand on the EnemySlot markers in Battle.tscn. If a wave has more
## enemies than slots, the extras continue to the right at this spacing.
const EXTRA_SLOT_SPACING := 44.0
const COLOR_DIALOGUE := Color(1.0, 0.85, 0.4)


func _ready() -> void:
	if waves.is_empty():
		waves = Waves.ch1_dream() if preset == Preset.CH1_DREAM else Waves.ch1_final()
	player_hp = player_max_hp
	for sk in skills:
		for w in sk.get_warnings():
			push_warning("Skill '%s': %s" % [sk.display_name, w])
	cooldowns.resize(skills.size())
	cooldowns.fill(0)
	_setup_ui()
	_refresh()
	_next_wave()


# ------------------------------------------------------------------ setup

func _setup_ui() -> void:
	_bar.action = "defend"
	_bar.caption = "pencet X pas di hijau!"
	# One SkillButton per skill. Layout (widths, spacing) is the HBoxContainer's.
	for i in skills.size():
		var b: Button = SKILL_BUTTON.instantiate()
		b.pressed.connect(use_skill.bind(i))
		_skill_bar.add_child(b)
		_buttons.append(b)


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if state == State.WIN or state == State.LOSE:
		# Standalone test run (F6): Z restarts. In a story, the caller decides.
		if event.is_action_pressed("attack") and battle_finished.get_connections().is_empty():
			get_tree().reload_current_scene()
		return
	if state != State.PLAYER_TURN:
		return
	if event.is_action_pressed("attack") or event.is_action_pressed("skill_1"):
		use_skill(0)
	elif event.is_action_pressed("skill_2"):
		use_skill(1)
	elif event.is_action_pressed("skill_3"):
		use_skill(2)
	elif event.is_action_pressed("skill_4"):
		use_skill(3)
	elif event.is_action_pressed("move_left"):
		_cycle_target(-1)
	elif event.is_action_pressed("move_right"):
		_cycle_target(1)


func _cycle_target(step: int) -> void:
	if _enemies.is_empty():
		return
	_target = wrapi(_target + step, 0, _enemies.size())
	_refresh()


func _on_enemy_clicked(unit: EnemyUnit) -> void:
	var i := _enemies.find(unit)
	if i >= 0 and state == State.PLAYER_TURN:
		_target = i
		_refresh()


# ------------------------------------------------------------------ waves

func _next_wave() -> void:
	state = State.BUSY
	_wave_index += 1
	if _wave_index >= waves.size():
		_end(true)
		return
	var w := waves[_wave_index]
	_wave_round = 0
	cannon_fired = false
	_hint.text = ""
	_spawn(w.enemies)
	if w.intro_text != "":
		await _show_banner(w.intro_text, 1.0)
	_start_player_turn()


func _spawn(list: Array[EnemyData]) -> void:
	_enemies.clear()
	_target = 0
	for i in list.size():
		var u := list[i].make_unit()
		u.position = _slot_position(i)
		u.clicked.connect(_on_enemy_clicked)
		_enemy_parent.add_child(u)
		_enemies.append(u)
	_log_text("Batara Kala muncul! (%d)" % list.size())
	_refresh()


## Where enemy number `i` stands: its EnemySlot marker, or further right.
func _slot_position(i: int) -> Vector2:
	var slots: Array[Node] = _enemy_parent.get_children().filter(func(n: Node) -> bool: return n is Marker2D)
	if i < slots.size():
		return (slots[i] as Marker2D).position
	var last: Vector2 = (slots[-1] as Marker2D).position if not slots.is_empty() else Vector2(180, 62)
	return last + Vector2(EXTRA_SLOT_SPACING * (i - slots.size() + 1), 0.0)


func _current_wave() -> WaveData:
	return waves[_wave_index]


# ------------------------------------------------------------------ player turn

func _start_player_turn() -> void:
	var w := _current_wave()
	if w.cannon_help and not cannon_fired and _wave_round >= 1 and _enemies.size() > 1:
		await _cannon_help()
		if _enemies.is_empty():
			_next_wave()
			return
	actions_left = 1 + mini(bonus_actions, 1)
	if bonus_actions > 0:
		_log_text("Musuh kaget! Serang 2x!")
	bonus_actions = 0
	_used_this_turn.clear()
	_hint.text = w.hint_text
	state = State.PLAYER_TURN
	_refresh()


## Public so tests and UI buttons can drive the battle.
func use_skill(i: int) -> void:
	if state != State.PLAYER_TURN or i < 0 or i >= skills.size() or cooldowns[i] > 0:
		return
	state = State.BUSY
	_refresh()
	var s := skills[i]
	_used_this_turn.append(i)

	# 1. Optional circle minigame (skills without circle_config skip this).
	var mg_result: Dictionary = {}
	if s.uses_minigame():
		_hint.text = ""
		mg_result = await _play_circle_minigame(s)

	# 2. Resolve: penalties first (they may weaken or fizzle), then the skill's
	#    own numbers, then its custom extra effects.
	var pose_time := _play_skill_pose(s)   # before the numbers land, so the enemy's hurt pose follows it
	var ctx := _resolve_skill(s, mg_result)
	cooldowns[i] = s.cooldown + ctx.extra_cooldown
	_log_text("Bara: %s! %s" % [s.display_name, ", ".join(ctx.log_parts)])
	_refresh()
	await _wait(maxf(0.5, pose_time))   # never cut a long animation short
	await _remove_dead()

	if _enemies.is_empty():
		_next_wave()
		return
	actions_left -= 1
	if actions_left > 0:
		state = State.PLAYER_TURN
		_refresh()
		return
	_tick_cooldowns()
	_enemy_turn()


## Bara's pose for a skill: the skill's own `pose`, else defend / heal / attack.
func _play_skill_pose(s: SkillData) -> float:
	var pose := s.pose
	if pose == &"":
		if s.defends:
			pose = BattleUnit.DEFEND
		elif s.heal > 0 and s.damage <= 0:
			pose = BattleUnit.HEAL
		else:
			pose = BattleUnit.ATTACK
	return _player.play_pose(pose)


## Applies a skill to the battle and returns the context (log text, extra
## cooldown, ...). Order matters: the minigame multiplier and penalty effects
## run first so Weaken/Fizzle affect the skill's own damage and healing.
func _resolve_skill(s: SkillData, mg_result: Dictionary) -> SkillContext:
	var ctx := SkillContext.new()
	ctx.battle = self
	ctx.skill = s
	ctx.target = _enemies[_target] if not _enemies.is_empty() else null
	ctx.minigame_result = mg_result
	ctx.penalty_points = int(mg_result.get("penalty_points", 0))
	ctx.max_extra_cooldown = max_extra_cooldown

	if not mg_result.is_empty():
		ctx.scale_output(float(mg_result.get("multiplier", 1.0)))
		ctx.say("%d meleset" % ctx.penalty_points if ctx.penalty_points > 0 else "sempurna!")
	for t in s.crossed_thresholds(ctx.penalty_points):
		t.effect.apply(ctx)

	var out := ctx.output_multiplier
	if s.damage > 0 and out > 0.0:
		ctx.deal_damage(maxi(roundi(s.damage * out), 1))
	if s.heal > 0 and out > 0.0:
		ctx.heal_player(maxi(roundi(s.heal * out), 1))
	if s.defends:
		ctx.set_defending()
	if not ctx.fizzled:
		for e in s.extra_effects:
			if e != null:
				e.apply(ctx)
	return ctx


## Mounts the circle minigame over the field and waits for it to finish.
## `auto_circle_misses >= 0` skips it and fakes a result (for tests/demos).
func _play_circle_minigame(s: SkillData) -> Dictionary:
	var cfg := s.circle_config
	if auto_circle_misses >= 0:
		var g: Array[int] = []
		for k in cfg.count():
			g.append(TimingBar.Result.MISS if k < auto_circle_misses else TimingBar.Result.PERFECT)
		return CircleMinigame.build_result(g, cfg)
	var mg := CircleMinigame.create()
	_minigame_slot.add_child(mg)
	mg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	active_minigame = mg
	mg.start(cfg)
	var result: Dictionary = await mg.finished
	active_minigame = null
	await _wait(0.4)   # let the last PERFECT/MISS label show
	mg.queue_free()
	return result


## Living enemies, for SkillEffects (a copy, safe to loop over).
func enemies() -> Array[EnemyUnit]:
	return _enemies.duplicate()


## A skill used this turn stays at its full cooldown; everything else ticks.
## So "cooldown 2" = locked for the next 2 player turns.
func _tick_cooldowns() -> void:
	for j in cooldowns.size():
		if j not in _used_this_turn:
			cooldowns[j] = maxi(cooldowns[j] - 1, 0)


func _remove_dead() -> void:
	var dead: Array[EnemyUnit] = []
	for e in _enemies:
		if not e.is_alive():
			dead.append(e)
	if dead.is_empty():
		return
	for e in dead:
		score += e.data.score
		_enemies.erase(e)
		e.die()
	_target = clampi(_target, 0, maxi(_enemies.size() - 1, 0))
	_refresh()
	await _wait(0.3)


# ------------------------------------------------------------------ enemy turn

func _enemy_turn() -> void:
	state = State.ENEMY_TURN
	_hint.text = ""
	_refresh()
	for e: EnemyUnit in _enemies.duplicate():
		if not is_instance_valid(e) or not e.is_alive():
			continue
		await _wait(0.4)
		var dmg: int = e.data.attack_damage
		var result: int = TimingBar.Result.MISS
		if e.data.telegraphs:
			_log_text("%s %s" % [e.data.label(), e.data.windup_text])
			e.set_telegraph(true)
			result = await _block_check()
			e.set_telegraph(false)

		match result:
			TimingBar.Result.PERFECT:
				dmg = 0
				bonus_actions = 1
				score += 50
				_log_text("%s kaget! Bara bisa serang 2x!" % e.data.label())
				await _show_banner("PERFECT BLOCK!", 0.7)
			TimingBar.Result.GOOD:
				dmg = ceili(dmg / 2.0)
		if defending and dmg > 0:
			dmg = ceili(dmg / 2.0)

		# Poses: a perfect block stuns the attacker; otherwise it attacks and Bara
		# blocks (partial block / defend skill) or is hurt.
		var pose_time := 0.0
		if result == TimingBar.Result.PERFECT:
			pose_time = maxf(e.play_pose(BattleUnit.STUNNED), _player.play_pose(BattleUnit.BLOCK))
		else:
			pose_time = e.play_pose(BattleUnit.ATTACK)
			pose_time = maxf(pose_time, _player.play_pose(
					BattleUnit.BLOCK if (result == TimingBar.Result.GOOD or defending) else BattleUnit.HURT))

		if dmg > 0:
			player_hp = maxi(player_hp - dmg, 0)
			_log_text("%s: %s! %d damage%s" % [
				e.data.label(), e.data.attack_name, dmg,
				" (ditahan)" if result == TimingBar.Result.GOOD or defending else ""])
			_shake(3.0)
			_player.flash()
		_refresh()
		await _wait(maxf(0.6, pose_time))

		if player_hp <= 0:
			if GameState.story_mode:
				# No game over in story mode: Haikal covers, full HP.
				await _say("Haikal", "bara, mundur! tak cover!")
				player_hp = player_max_hp
				_refresh()
				break
			_end(false)
			return

	defending = false
	_wave_round += 1
	_start_player_turn()


func _block_check() -> int:
	if auto_block >= 0:
		return auto_block
	_bar.start()
	return await _bar.resolved


# ------------------------------------------------------------------ events

## Reyhan fires the warship cannon: wipes up to 2 enemies, never the one the
## player is currently targeting, and always leaves at least one to finish.
func _cannon_help() -> void:
	cannon_fired = true
	state = State.BUSY
	await _say("Reyhan", "BAR, AWAS! TAK BANTU!")
	var keep := _enemies[_target]
	var victims: Array[EnemyUnit] = []
	for e in _enemies:
		if e != keep and victims.size() < mini(2, _enemies.size() - 1):
			victims.append(e)
	_flash_screen()
	_shake(8.0, 0.5)
	for v in victims:
		v.take_damage(v.hp)
	await _wait(0.6)
	await _remove_dead()
	_target = maxi(_enemies.find(keep), 0)
	_refresh()


func _end(won: bool) -> void:
	state = State.WIN if won else State.LOSE
	_hint.text = ""
	_refresh()
	_log_text("Skor: %d" % score)
	if battle_finished.get_connections().is_empty():
		_hint.text = "Z: main lagi"
	await _show_banner("MENANG!" if won else "KALAH...", 1.0, false)
	battle_finished.emit({"won": won, "score": score})


# ------------------------------------------------------------------ view

func _refresh() -> void:
	_player.set_hp(player_hp, player_max_hp)
	var my_turn := state == State.PLAYER_TURN
	for i in _buttons.size():
		var cd := cooldowns[i]
		_buttons[i].text = "%d %s%s%s" % [i + 1, skills[i].display_name,
			" (o)" if skills[i].uses_minigame() else "", "\n(CD %d)" % cd if cd > 0 else ""]
		_buttons[i].disabled = not my_turn or cd > 0
	_cursor.visible = my_turn and not _enemies.is_empty()
	if _cursor.visible:
		_cursor.position = _enemies[_target].center_top() + Vector2(0, -31)


func _log_text(t: String) -> void:
	_log.remove_theme_color_override("font_color")
	_log.text = t


func _say(speaker: String, line: String) -> void:
	_log.add_theme_color_override("font_color", COLOR_DIALOGUE)
	_log.text = '%s: "%s"' % [speaker, line]
	await _wait(1.4)


func _show_banner(text: String, seconds: float, auto_hide := true) -> void:
	_banner.text = text
	_banner.show()
	await _wait(seconds)
	if auto_hide:
		_banner.hide()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds * pace).timeout


func _shake(strength: float, duration := 0.2) -> void:
	var t := create_tween()
	var steps := int(duration / 0.04)
	for k in steps:
		t.tween_property(_camera, "offset",
			Vector2(randf_range(-strength, strength), randf_range(-strength, strength)), 0.04)
	t.tween_property(_camera, "offset", Vector2.ZERO, 0.04)


func _flash_screen() -> void:
	_flash_rect.modulate.a = 1.0
	create_tween().tween_property(_flash_rect, "modulate:a", 0.0, 0.4)
