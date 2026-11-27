extends Node
## Circle minigame + skill effect tests. Run:
##   godot --headless --path . res://tests/TestCircle.tscn

const BattleScene := preload("res://battle/Battle.tscn")
const HANTAMAN := preload("res://data/skills/hantaman_kalpataru.tres")

var failures := 0
var sections_done := 0
const EXPECTED_SECTIONS := 11

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)

func _ready() -> void:
	await get_tree().process_frame
	# A script error aborts a section silently, so count sections that finish.
	test_config_safety(); sections_done += 1
	test_grading(); sections_done += 1
	test_build_result(); sections_done += 1
	test_play_perfect(); sections_done += 1
	test_play_all_miss_expire(); sections_done += 1
	test_click_rules(); sections_done += 1
	test_positions_inside_area(); sections_done += 1
	test_thresholds(); sections_done += 1
	test_skill_warnings(); sections_done += 1
	await test_battle_integration(); sections_done += 1
	await test_safeguards(); sections_done += 1
	check(sections_done == EXPECTED_SECTIONS, "every test section ran to the end")
	print("\n", "ALL PASSED" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(1 if failures else 0)

func new_game(cfg: CircleMinigameConfig) -> CircleMinigame:
	var mg := CircleMinigame.create()
	mg.size = Vector2(320, 104)
	add_child(mg)
	mg.start(cfg)
	return mg

func make_cfg(count := 3, life := 1.0, interval := 0.5, ring := 0.5) -> CircleMinigameConfig:
	var c := CircleMinigameConfig.new()
	c.circle_count = count
	c.circle_lifetime = life
	c.spawn_interval = interval
	c.approach_ring_time = ring
	c.rng_seed = 7
	return c

# ---------------------------------------------------------------- config

func test_config_safety() -> void:
	print("Config clamps bad values")
	var c := CircleMinigameConfig.new()
	c.circle_count = 0
	c.circle_lifetime = -3.0
	c.spawn_interval = 0.0
	c.circle_radius = 0.0
	c.approach_ring_time = 99.0
	check(c.count() == 1, "circle_count 0 -> 1")
	check(c.lifetime() >= 0.1, "negative lifetime is clamped")
	check(c.interval() >= 0.05, "zero interval is clamped (no spawn flood)")
	check(c.radius() >= 4.0, "zero radius is clamped")
	check(c.approach_time() <= c.lifetime(), "ring time never exceeds lifetime")
	check(c.get_warnings().size() >= 2, "bad config produces warnings")
	c.min_multiplier = 2.0
	c.max_multiplier = 1.0
	check(c.multiplier_for(1.0) == 2.0, "max < min falls back to min")

# ---------------------------------------------------------------- grading

func test_grading() -> void:
	print("Grading")
	var mg := new_game(make_cfg())
	var ideal := mg.config.approach_time()
	check(mg.evaluate(ideal) == TimingBar.Result.PERFECT, "ideal moment = PERFECT")
	check(mg.evaluate(ideal + 0.10) == TimingBar.Result.PERFECT, "+0.10s still PERFECT")
	check(mg.evaluate(ideal - 0.10) == TimingBar.Result.PERFECT, "-0.10s still PERFECT")
	check(mg.evaluate(ideal + 0.25) == TimingBar.Result.GOOD, "+0.25s = GOOD")
	check(mg.evaluate(ideal - 0.25) == TimingBar.Result.GOOD, "-0.25s (early) = GOOD")
	check(mg.evaluate(ideal + 0.40) == TimingBar.Result.MISS, "+0.40s = MISS")
	check(mg.evaluate(0.0) == TimingBar.Result.MISS, "instant click = MISS")
	mg.queue_free()

func test_build_result() -> void:
	print("Result building")
	var c := make_cfg(5)
	var all_perfect: Array[int] = [2, 2, 2, 2, 2]
	var r := CircleMinigame.build_result(all_perfect, c)
	check(r["misses"] == 0 and r["penalty_points"] == 0, "perfect run: 0 penalty points")
	check(is_equal_approx(r["multiplier"], 1.5), "perfect run: max multiplier 1.5")
	var all_miss: Array[int] = [0, 0, 0, 0, 0]
	r = CircleMinigame.build_result(all_miss, c)
	check(r["penalty_points"] == 5, "5 misses = 5 penalty points")
	check(is_equal_approx(r["multiplier"], 1.0), "all misses: min multiplier 1.0 (no double punishment)")
	check(r["success"] == false, "all misses = success false")
	var mixed: Array[int] = [2, 1, 0, 0, 1]
	r = CircleMinigame.build_result(mixed, c)
	check(r["perfects"] == 1 and r["goods"] == 2 and r["misses"] == 2, "counts: 1 perfect, 2 good, 2 miss")
	check(r["penalty_points"] == 2, "2 misses = 2 penalty points")
	check(r["multiplier"] > 1.0 and r["multiplier"] < 1.5, "mixed run sits between min and max")
	var empty: Array[int] = []
	r = CircleMinigame.build_result(empty, c)
	check(r.has("multiplier"), "empty grade list does not crash")

# ---------------------------------------------------------------- playing

func test_play_perfect() -> void:
	print("Playing a perfect run")
	var c := make_cfg(3, 1.0, 0.5, 0.5)
	var mg := new_game(c)
	var result := {}
	mg.finished.connect(func(r: Dictionary) -> void: result.merge(r))
	check(mg.circles.size() == 1, "first circle spawns immediately")
	# Step in small increments, clicking each circle right at its ideal moment.
	var safety := 0
	while result.is_empty() and safety < 2000:
		mg.tick(0.01)
		safety += 1
		for ci in mg.circles:
			if ci.alive and absf(mg.age_of(ci) - c.approach_time()) < 0.0051:
				mg.click(ci.pos)
	check(not result.is_empty(), "minigame finished")
	check(result.get("perfects", 0) == 3, "3 perfects (got %s)" % result.get("perfects"))
	check(result.get("penalty_points", -1) == 0, "no penalty points")
	check(mg.circles.size() == 3, "exactly circle_count circles spawned")
	mg.queue_free()

func test_play_all_miss_expire() -> void:
	print("Doing nothing")
	var c := make_cfg(4, 0.5, 0.2, 0.3)
	var mg := new_game(c)
	var result := {}
	mg.finished.connect(func(r: Dictionary) -> void: result.merge(r))
	for k in 400:
		mg.tick(0.01)
	check(not result.is_empty(), "finishes by itself (circles expire)")
	check(result.get("misses", 0) == 4, "all 4 circles missed")
	check(result.get("penalty_points", -1) == 4, "penalty points = 4")
	check(result.get("success", true) == false, "not a success")
	mg.tick(5.0)
	check(true, "ticking after finish is harmless")
	mg.queue_free()

func test_click_rules() -> void:
	print("Click rules")
	var c := make_cfg(2, 1.0, 0.5, 0.5)
	var mg := new_game(c)
	mg.tick(0.5)
	check(mg.click(Vector2(-500, -500)) == false, "clicking empty space does nothing")
	check(mg.alive_count() >= 1, "empty click did not consume a circle")
	var first := mg.circles[0]
	check(mg.click(first.pos) == true, "clicking a circle hits it")
	check(mg.grades[0] == TimingBar.Result.PERFECT, "clicked on time = PERFECT")
	check(mg.click(first.pos) == false, "cannot hit the same circle twice")
	mg.queue_free()
	var mg2 := new_game(make_cfg(1, 1.0, 0.5, 0.5))
	check(mg2.click_oldest() == true, "Z hits the oldest circle")
	check(mg2.grades[0] == TimingBar.Result.MISS, "clicking instantly (too early) = MISS")
	mg2.queue_free()
	var mg3 := new_game(make_cfg(1))
	mg3.running = false
	check(mg3.click(Vector2.ZERO) == false and mg3.click_oldest() == false, "inputs are ignored once finished")
	mg3.queue_free()

func test_positions_inside_area() -> void:
	print("Circle placement")
	var c := make_cfg(40, 5.0, 0.05, 0.5)
	c.play_area_margin = 10.0
	var mg := new_game(c)
	mg.tick(40 * 0.05 + 0.01)
	var ok := true
	var inset := c.play_area_margin + c.radius()
	for ci in mg.circles:
		if ci.pos.x < inset - 0.01 or ci.pos.x > mg.size.x - inset + 0.01 \
				or ci.pos.y < inset - 0.01 or ci.pos.y > mg.size.y - inset + 0.01:
			ok = false
	check(mg.circles.size() == 40, "40 circles spawned")
	check(ok, "every circle respects the margin")
	mg.queue_free()
	# Same seed -> same layout
	var a := new_game(make_cfg(5))
	a.tick(3.0)
	var b := new_game(make_cfg(5))
	b.tick(3.0)
	check(a.circles[2].pos == b.circles[2].pos, "same rng_seed gives the same layout")
	a.queue_free()
	b.queue_free()
	# A tiny play area must not crash
	var tiny := CircleMinigame.create()
	tiny.size = Vector2(10, 10)
	add_child(tiny)
	tiny.start(make_cfg(2))
	tiny.tick(2.0)
	check(tiny.circles.size() >= 1, "tiny play area does not crash")
	tiny.queue_free()

# ---------------------------------------------------------------- thresholds

func test_thresholds() -> void:
	print("Penalty thresholds")
	check(HANTAMAN.crossed_thresholds(0).size() == 0, "0 misses: nothing applies")
	check(HANTAMAN.crossed_thresholds(1).size() == 0, "1 miss: below first threshold")
	check(HANTAMAN.crossed_thresholds(2).size() == 1, "2 misses: weaken only")
	check(HANTAMAN.crossed_thresholds(3).size() == 1, "3 misses: still just weaken")
	var at4 := HANTAMAN.crossed_thresholds(4)
	check(at4.size() == 2, "4 misses: cumulative (weaken + backlash)")
	check(at4[0].effect is WeakenEffect and at4[1].effect is BacklashEffect, "applied lowest threshold first")
	var s := SkillData.new()
	var bad := PenaltyThreshold.new()
	bad.at_penalty_points = 0
	bad.effect = WeakenEffect.new()
	var empty := PenaltyThreshold.new()
	empty.at_penalty_points = 1
	s.penalty_thresholds = [bad, empty, null]
	check(s.crossed_thresholds(0).size() == 0, "threshold 0 never triggers on a perfect run")
	check(s.crossed_thresholds(5).size() == 0, "null/empty thresholds are ignored")

func test_skill_warnings() -> void:
	print("Design-time warnings")
	check(HANTAMAN.get_warnings().is_empty(), "demo skill has no warnings")
	var s := SkillData.new()
	s.circle_config = make_cfg(3)
	var t := PenaltyThreshold.new()
	t.at_penalty_points = 9
	t.effect = FizzleEffect.new()
	s.penalty_thresholds = [t]
	check(s.get_warnings().size() == 1, "unreachable threshold (9 > 3 circles) warns")
	var s2 := SkillData.new()
	s2.penalty_thresholds = [t]
	check(s2.get_warnings().size() >= 1, "penalties without a minigame warn")

# ---------------------------------------------------------------- battle

func make_battle(skills: Array[SkillData], hp := 999, enemy_hp := 999) -> Node:
	var e := EnemyData.new()
	e.max_hp = enemy_hp
	e.attack_damage = 1
	var w := WaveData.new()
	var enemy_list: Array[EnemyData] = [e]
	w.enemies = enemy_list
	var wave_list: Array[WaveData] = [w]
	var b := BattleScene.instantiate()
	b.waves = wave_list
	b.skills = skills
	b.pace = 0.01
	b.player_max_hp = hp
	add_child(b)
	return b

func wait_turn(b: Node) -> void:
	var frames := 0
	while b.state != b.State.PLAYER_TURN and frames < 3000:
		await get_tree().process_frame
		frames += 1

func test_battle_integration() -> void:
	print("Battle integration")
	var skills: Array[SkillData] = [HANTAMAN, preload("res://data/skills/pukulan_dasar.tres")]

	var b := make_battle(skills)
	await wait_turn(b)
	b.auto_circle_misses = 0          # perfect run: 20 * 1.5
	b.use_skill(0)
	await wait_turn(b)
	check(b._enemies[0].hp == 999 - 30, "perfect run: 20 dmg x1.5 = 30 (hp %d)" % b._enemies[0].hp)
	check(b.cooldowns[0] == 3, "cooldown 3 after use")
	b.queue_free()

	b = make_battle(skills)
	await wait_turn(b)
	b.auto_circle_misses = 2          # weaken 40% applied on top of the multiplier
	b.use_skill(0)
	await wait_turn(b)
	var dealt: int = 999 - b._enemies[0].hp
	check(dealt > 0 and dealt < 20, "2 misses: weakened damage (%d)" % dealt)
	check(b.player_hp >= 998, "2 misses: no backlash yet")
	b.queue_free()

	b = make_battle(skills)
	await wait_turn(b)
	b.auto_circle_misses = 4          # weaken + backlash 4
	var hp_before: int = b.player_hp
	b.use_skill(0)
	await wait_turn(b)
	check(b.player_hp <= hp_before - 4 + 1, "4 misses: backlash hurt Bara (hp %d)" % b.player_hp)
	b.queue_free()

	# Skills without a minigame are untouched by all of this.
	b = make_battle(skills)
	await wait_turn(b)
	b.use_skill(1)
	await wait_turn(b)
	check(b._enemies[0].hp == 999 - 6, "Pukulan Dasar (no minigame) still deals 6")
	b.queue_free()

	# Real minigame mounted by the battle, driven through tick().
	b = make_battle(skills)
	await wait_turn(b)
	b.use_skill(0)
	await get_tree().process_frame
	check(b.active_minigame != null, "battle mounts the circle minigame")
	check(b.state == b.State.BUSY, "battle waits (BUSY) while the minigame plays")
	check(b.cooldowns[0] == 0, "cooldown is not charged until the skill resolves")
	var mg: CircleMinigame = b.active_minigame
	mg.set_frozen(true)
	var t0 := mg.elapsed
	await get_tree().create_timer(0.1).timeout
	check(mg.elapsed == t0, "a frozen minigame does not advance")
	mg.set_frozen(false)
	for k in 800:
		if b.active_minigame == null:
			break
		mg.tick(0.02)
	await wait_turn(b)
	check(b.cooldowns[0] >= 3, "skill resolved after the minigame")
	b.queue_free()

# ---------------------------------------------------------------- safeguards

func test_safeguards() -> void:
	print("Safeguards")
	# Direct check on the helper: the battle's own enemy turn would muddy HP.
	var probe := make_battle([HANTAMAN] as Array[SkillData], 10)
	await wait_turn(probe)
	var pctx := SkillContext.new()
	pctx.battle = probe
	check(pctx.damage_player(9999) == 9 and probe.player_hp == 1, "backlash stops at 1 HP (hp %d)" % probe.player_hp)
	check(pctx.damage_player(5) == 0 and probe.player_hp == 1, "at 1 HP further backlash does nothing")
	check(pctx.damage_player(-5) == 0, "negative backlash does nothing")
	check(pctx.add_cooldown(2) == 2 and pctx.add_cooldown(9) == 1, "add_cooldown stops at the cap of 3")
	probe.queue_free()
	var back := BacklashEffect.new()
	back.damage = 9999
	var t := PenaltyThreshold.new()
	t.at_penalty_points = 1
	t.effect = back
	var s := SkillData.new()
	s.display_name = "Berbahaya"
	s.damage = 5
	s.circle_config = make_cfg(3)
	s.penalty_thresholds = [t]
	var skills: Array[SkillData] = [s]
	var b := make_battle(skills, 10)
	await wait_turn(b)
	b.auto_circle_misses = 3
	b.use_skill(0)
	await wait_turn(b)
	check(b.player_hp >= 1, "huge backlash can never kill Bara (hp %d)" % b.player_hp)
	check(b.state != b.State.LOSE, "battle is not lost to backlash")
	b.queue_free()

	var cd := ExtraCooldownEffect.new()
	cd.turns = 100
	var t2 := PenaltyThreshold.new()
	t2.at_penalty_points = 1
	t2.effect = cd
	var s2 := SkillData.new()
	s2.damage = 1
	s2.cooldown = 1
	s2.circle_config = make_cfg(3)
	s2.penalty_thresholds = [t2]
	var skills2: Array[SkillData] = [s2]
	b = make_battle(skills2)
	await wait_turn(b)
	b.auto_circle_misses = 3
	b.use_skill(0)
	for k in 5:
		await get_tree().process_frame
	check(b.cooldowns[0] == 1 + 3, "extra cooldown capped at 3 (+ base 1), got %d" % b.cooldowns[0])
	b.queue_free()

	var fz := FizzleEffect.new()
	var t3 := PenaltyThreshold.new()
	t3.at_penalty_points = 1
	t3.effect = fz
	var s3 := SkillData.new()
	s3.damage = 50
	s3.heal = 50
	s3.circle_config = make_cfg(3)
	s3.penalty_thresholds = [t3]
	var skills3: Array[SkillData] = [s3]
	b = make_battle(skills3)
	await wait_turn(b)
	b.player_hp = 500
	b.auto_circle_misses = 1
	b.use_skill(0)
	await wait_turn(b)
	check(b._enemies[0].hp == 999, "fizzle: no damage")
	check(b.player_hp <= 500, "fizzle: no healing")
	b.queue_free()

	# A custom effect: proves new behavior needs no core changes.
	var custom := CustomTestEffect.new()
	var s4 := SkillData.new()
	s4.damage = 3
	s4.extra_effects = [custom]
	var skills4: Array[SkillData] = [s4]
	b = make_battle(skills4)
	await wait_turn(b)
	b.use_skill(0)
	await wait_turn(b)
	check(custom.ran, "custom extra effect ran")
	check(b._enemies[0].hp == 999 - 3 - 7, "custom effect used the context helper (hp %d)" % b._enemies[0].hp)
	b.queue_free()

class CustomTestEffect extends SkillEffect:
	var ran := false
	func apply(ctx: SkillContext) -> void:
		ran = true
		ctx.deal_damage(7)
