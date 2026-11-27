extends Node
## Headless battle test (a scene, so autoloads like GameState are available).
## Run:  godot --headless --path . res://tests/TestBattle.tscn

const BattleScene := preload("res://battle/Battle.tscn")

var failures := 0

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)

func make_battle(waves: Array[WaveData], block := TimingBar.Result.MISS) -> Node:
	var b := BattleScene.instantiate()
	b.waves = waves
	b.pace = 0.01
	b.auto_block = block
	add_child(b)
	return b

## Spam a skill choice until the battle ends. Returns {won, score, turns}.
func autoplay(b: Node, max_steps := 300) -> Dictionary:
	# Lambdas capture locals by value, so mutate the dict instead of reassigning.
	var result := {}
	b.battle_finished.connect(func(r: Dictionary) -> void: result.merge(r))
	var steps := 0
	var frames := 0
	while result.is_empty() and steps < max_steps and frames < 20000:
		await get_tree().process_frame
		frames += 1
		if b.state == b.State.PLAYER_TURN:
			# Prefer the big kick when ready, else basic punch.
			b.use_skill(1 if b.cooldowns[1] == 0 else 0)
			steps += 1
	result["steps"] = steps
	return result

func _ready() -> void:
	await get_tree().process_frame
	await test_timing_bar()
	await test_cooldown()
	await test_dream()
	await test_final_story_mode()
	await test_perfect_block()
	await test_endless_can_lose()
	print("\n", "ALL PASSED" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(1 if failures else 0)

func test_timing_bar() -> void:
	print("TimingBar.evaluate")
	var bar := TimingBar.create()
	check(bar.evaluate(0.75) == TimingBar.Result.PERFECT, "center = PERFECT")
	check(bar.evaluate(0.85) == TimingBar.Result.GOOD, "near = GOOD")
	check(bar.evaluate(0.2) == TimingBar.Result.MISS, "far = MISS")
	bar.free()

func test_cooldown() -> void:
	print("Cooldown")
	var tough := EnemyData.new()
	tough.max_hp = 999
	tough.attack_damage = 1
	var w := WaveData.new()
	w.enemies = [tough]
	var b := make_battle([w])
	while b.state != b.State.PLAYER_TURN:
		await get_tree().process_frame
	b.use_skill(1)                       # kick, cooldown 2
	check(b.cooldowns[1] == 2, "kick locked for 2 after use")
	for turn in 2:
		while b.state != b.State.PLAYER_TURN:
			await get_tree().process_frame
		check(b.cooldowns[1] > 0, "kick still locked on turn %d" % (turn + 1))
		b.use_skill(1)                   # should be ignored
		check(b.state == b.State.PLAYER_TURN, "locked skill is ignored")
		b.use_skill(0)
	while b.state != b.State.PLAYER_TURN:
		await get_tree().process_frame
	check(b.cooldowns[1] == 0, "kick usable again after 2 turns")
	b.queue_free()

func test_dream() -> void:
	print("Chapter 1 dream battle")
	var b := make_battle(Waves.ch1_dream())
	var r := await autoplay(b)
	check(r.get("won", false), "dream battle is won")
	check(r.get("score", 0) == 100, "score = 100 for one kapak (got %s)" % r.get("score"))
	b.queue_free()

func test_final_story_mode() -> void:
	print("Chapter 1 final battle (story mode, never block)")
	GameState.story_mode = true
	var b := make_battle(Waves.ch1_final(), TimingBar.Result.MISS)
	var r := await autoplay(b)
	check(r.get("won", false), "won even without blocking (Haikal covers)")
	check(b.cannon_fired, "Reyhan's cannon fired in wave 3")
	check(b._wave_index == 3, "all 3 waves cleared")
	b.queue_free()

func test_perfect_block() -> void:
	print("Perfect Block")
	GameState.story_mode = true
	var waves := Waves.ch1_final()
	var w2: Array[WaveData] = [waves[1]]          # 2 archers
	var b := make_battle(w2, TimingBar.Result.PERFECT)
	while b.state != b.State.PLAYER_TURN:
		await get_tree().process_frame
	var hp_before: int = b.player_hp
	b.use_skill(0)
	while b.state != b.State.PLAYER_TURN:
		await get_tree().process_frame
	check(b.player_hp == hp_before, "perfect block = no damage")
	check(b.actions_left == 2, "perfect block grants 2 actions (got %d)" % b.actions_left)
	b.use_skill(0)
	await get_tree().process_frame
	while b.state == b.State.BUSY:
		await get_tree().process_frame
	check(b.state == b.State.PLAYER_TURN and b.actions_left == 1, "second action available")
	b.queue_free()

func test_endless_can_lose() -> void:
	print("Non-story mode can lose")
	GameState.story_mode = false
	var brute := EnemyData.new()
	brute.max_hp = 999
	brute.attack_damage = 50
	var w := WaveData.new()
	w.enemies = [brute]
	var b := make_battle([w])
	var r := await autoplay(b)
	check(r.has("won") and not r["won"], "player loses when story_mode is off")
	GameState.story_mode = true
	b.queue_free()
