extends Node
## Pose / animation tests. Run:
##   godot --headless --path . res://tests/TestPoses.tscn

const BattleScene := preload("res://battle/Battle.tscn")

var failures := 0
var reached_end_of_art := false
var reached_end_of_battle := false
var sections_done := 0
const EXPECTED_SECTIONS := 4

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)

func _ready() -> void:
	await get_tree().process_frame
	await test_art_poses(); sections_done += 1
	await test_builtin_motion(); sections_done += 1
	await test_enemy_poses(); sections_done += 1
	await test_battle_wiring(); sections_done += 1
	# A script error inside an awaited section does not stop the caller, so also
	# require that the last check of each section was reached.
	check(sections_done == EXPECTED_SECTIONS, "every test section ran to the end")
	check(reached_end_of_art and reached_end_of_battle, "the last checks of the long sections were reached")
	print("\n", "ALL PASSED" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(1 if failures else 0)

func wait_s(sec: float) -> void:
	await get_tree().create_timer(sec).timeout

## A PlayerUnit with an AnimationPlayer that has idle (loop) + attack (0.2s).
func unit_with_art() -> PlayerUnit:
	var u: PlayerUnit = load("res://battle/PlayerUnit.tscn").instantiate()
	var ap := AnimationPlayer.new()
	ap.name = "Anim"
	u.add_child(ap)
	ap.owner = u
	ap.unique_name_in_owner = true
	var lib := AnimationLibrary.new()
	var idle := Animation.new()
	idle.length = 0.5
	idle.loop_mode = Animation.LOOP_LINEAR
	lib.add_animation(&"idle", idle)
	var atk := Animation.new()
	atk.length = 0.2
	var tr := atk.add_track(Animation.TYPE_VALUE)
	atk.track_set_path(tr, ^"Visual/Body:modulate")
	atk.track_insert_key(tr, 0.0, Color.WHITE)
	atk.track_insert_key(tr, 0.2, Color.RED)
	lib.add_animation(&"attack", atk)
	var hold := Animation.new()
	hold.length = 0.1
	lib.add_animation(&"windup", hold)
	ap.add_animation_library(&"", lib)
	return u

func test_art_poses() -> void:
	print("Poses from the artist's AnimationPlayer")
	var u := unit_with_art()
	add_child(u)
	await get_tree().process_frame
	var played: Array[StringName] = []
	u.pose_played.connect(func(p: StringName) -> void: played.append(p))
	check(u.current_pose == &"idle", "starts in idle")
	check(u.has_art(&"attack"), "has_art sees the AnimationPlayer's attack")
	check(not u.has_art(&"hurt"), "has_art is false for a pose that was not made")
	check(is_equal_approx(u.pose_length(&"attack"), 0.2), "pose_length reports the animation's length")
	var len := u.play_pose(&"attack")
	check(is_equal_approx(len, 0.2), "play_pose returns the length")
	check(u.get_node("%Anim").current_animation == "attack", "the AnimationPlayer is playing attack")
	check(played == [&"attack"], "pose_played fired once")
	await wait_s(0.45)
	check(u.current_pose == &"idle", "returns to idle by itself after the pose ends")
	check(u.get_node("%Anim").current_animation == "idle", "and the idle animation is playing again")
	# the same pose twice in a row restarts it
	u.play_pose(&"attack")
	await wait_s(0.1)
	u.play_pose(&"attack")
	check(u.get_node("%Anim").current_animation_position < 0.08, "playing the same pose again restarts it")
	await wait_s(0.3)
	# a held pose stays until something replaces it
	u.play_pose(&"windup")
	await wait_s(0.3)
	check(u.current_pose == &"windup", "windup holds instead of returning to idle")
	u.play_pose(&"idle")
	check(u.current_pose == &"idle", "idle replaces a held pose")
	reached_end_of_art = true
	u.queue_free()
	await get_tree().process_frame

func test_builtin_motion() -> void:
	print("Built-in motion when there is no art")
	var u: PlayerUnit = load("res://battle/PlayerUnit.tscn").instantiate()
	add_child(u)
	await get_tree().process_frame
	check(not u.has_art(&"attack"), "a plain unit has no art poses")
	var len := u.play_pose(&"attack")
	check(len > 0.0, "attack still returns a length (the built-in motion)")
	await wait_s(0.1)
	check(u.get_node("%Visual").position.x > 0.0, "Bara's attack lunges to the right")
	await wait_s(0.4)
	check(u.current_pose == &"idle", "built-in motion returns to idle")
	check(u.get_node("%Visual").position.is_zero_approx(), "and Visual is back at its resting spot")
	check(u.play_pose(&"no_such_pose") == 0.0, "an unknown pose returns 0.0 and does nothing")
	check(u.current_pose == &"idle", "an unknown pose does not change the current pose")
	u.fallback_motion = false
	check(u.play_pose(&"hurt") == 0.0, "with fallback_motion off, a pose without art does nothing")
	u.fallback_motion = true
	# a new pose interrupts a running motion cleanly
	u.play_pose(&"attack")
	await wait_s(0.05)
	u.play_pose(&"hurt")
	await wait_s(0.5)
	check(u.get_node("%Visual").position.is_zero_approx(), "interrupting a motion still ends at the resting spot")
	u.queue_free()
	await get_tree().process_frame

func test_enemy_poses() -> void:
	print("Enemy poses")
	var kapak: EnemyData = load("res://data/enemies/kapak.tres")
	var e: EnemyUnit = kapak.make_unit()
	add_child(e)
	await get_tree().process_frame
	check(e is BattleUnit, "EnemyUnit is a BattleUnit")
	e.play_pose(&"attack")
	await wait_s(0.1)
	check(e.get_node("%Visual").position.x < 0.0, "an enemy's attack lunges to the LEFT, toward Bara")
	await wait_s(0.4)
	e.take_damage(1)
	check(e.current_pose == &"hurt", "taking damage plays hurt")
	await wait_s(0.4)
	e.set_telegraph(true)
	check(e.current_pose == &"windup", "telegraph on = windup pose")
	await wait_s(0.4)
	check(e.current_pose == &"windup", "windup is held until switched off")
	e.set_telegraph(false)
	check(e.current_pose == &"idle", "telegraph off = back to idle")
	e.take_damage(e.hp)   # lethal: no hurt pose, die plays from die()
	check(e.current_pose != &"hurt", "a lethal hit does not play hurt")
	e.die()
	check(e.current_pose == &"die", "die() plays the die pose")
	await wait_s(0.9)
	check(not is_instance_valid(e), "the enemy is removed after dying")

func test_battle_wiring() -> void:
	print("Battle plays the poses")
	var tough := EnemyData.new()
	tough.max_hp = 500
	tough.attack_damage = 1
	var w := WaveData.new()
	var el: Array[EnemyData] = [tough]
	w.enemies = el
	var wl: Array[WaveData] = [w]
	var b: Node = BattleScene.instantiate()
	b.waves = wl
	b.pace = 0.05
	b.auto_block = TimingBar.Result.MISS
	add_child(b)
	var bara: PlayerUnit = b.get_node("%PlayerUnit")
	var log: Array[StringName] = []
	bara.pose_played.connect(func(p: StringName) -> void: log.append(p))
	while b.state != b.State.PLAYER_TURN:
		await get_tree().process_frame
	b.use_skill(0)   # Pukulan: damage skill
	await get_tree().process_frame
	check(log.size() > 0 and log[0] == &"attack", "a damage skill plays Bara's attack pose")
	while b.state != b.State.PLAYER_TURN:
		await get_tree().process_frame
	check(&"hurt" in log, "an unblocked enemy attack plays Bara's hurt pose")
	log.clear()
	b.use_skill(2)   # Perisai: defend + heal
	await get_tree().process_frame
	check(log.size() > 0 and log[0] == &"defend", "a defend skill plays the defend pose")
	while b.state != b.State.PLAYER_TURN:
		await get_tree().process_frame
	check(&"block" in log, "a defended enemy attack plays Bara's block pose")
	# skill with its own pose name
	var custom := SkillData.new()
	custom.display_name = "Tebasan"
	custom.damage = 1
	custom.pose = &"slash"
	b.skills[0] = custom
	log.clear()
	b.cooldowns[0] = 0
	b.use_skill(0)
	await get_tree().process_frame
	check(true, "a skill with its own pose name does not crash when the unit has no such pose")
	b.queue_free()
	await get_tree().process_frame
	# perfect block stuns the attacker
	var archer: EnemyData = load("res://data/enemies/panah.tres")
	var w2 := WaveData.new()
	var el2: Array[EnemyData] = [archer]
	w2.enemies = el2
	var wl2: Array[WaveData] = [w2]
	var b2: Node = BattleScene.instantiate()
	b2.waves = wl2
	b2.pace = 0.05
	b2.auto_block = TimingBar.Result.PERFECT
	add_child(b2)
	while b2.state != b2.State.PLAYER_TURN:
		await get_tree().process_frame
	var enemy_poses: Array[StringName] = []
	var arch_unit: EnemyUnit = b2._enemies[0]
	arch_unit.pose_played.connect(func(p: StringName) -> void: enemy_poses.append(p))
	b2.use_skill(0)
	while b2.state != b2.State.PLAYER_TURN:
		await get_tree().process_frame
	check(&"windup" in enemy_poses, "an archer winds up before shooting")
	check(&"stunned" in enemy_poses, "a PERFECT block stuns the archer")
	check(not (&"attack" in enemy_poses), "a PERFECT-blocked archer does not play its attack")
	reached_end_of_battle = true
	b2.queue_free()
