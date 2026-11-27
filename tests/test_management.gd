extends Node
## Management sim tests. Run:
##   godot --headless --path . res://tests/TestManagement.tscn

const GRAPH := preload("res://data/management/wahana_graph.tres")
const CHAPTER := preload("res://data/management/chapter_demo.tres")
const ENDLESS := preload("res://data/management/endless_demo.tres")
const ManagementScene := preload("res://management/Management.tscn")

var failures := 0
var sections_done := 0
const EXPECTED_SECTIONS := 12

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)

func _ready() -> void:
	await get_tree().process_frame
	test_graph_validation(); sections_done += 1
	test_dependencies(); sections_done += 1
	test_error_lifecycle(); sections_done += 1
	test_spread(); sections_done += 1
	test_random_error_limits(); sections_done += 1
	test_scripted_errors(); sections_done += 1
	test_integrity(); sections_done += 1
	test_pan_clamp(); sections_done += 1
	test_color_match(); sections_done += 1
	test_walk_and_spawn(); sections_done += 1
	test_encounter_merge(); sections_done += 1
	await test_management_flow(); sections_done += 1
	check(sections_done == EXPECTED_SECTIONS, "every test section ran to the end")
	print("\n", "ALL PASSED" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(1 if failures else 0)

# ---------------------------------------------------------------- helpers

func make_cfg(graph: NodeGraphData = GRAPH) -> ManagementConfig:
	var c := ManagementConfig.new()
	c.graph = graph
	c.rng_seed = 11
	c.random_errors_enabled = false
	return c

func make_node(id: String, chance := 0.0, countdown := 10.0, drain := 5.0) -> SystemNodeData:
	var n := SystemNodeData.new()
	n.id = id
	n.display_name = id
	n.error_chance_per_sec = chance
	n.error_countdown = countdown
	n.drain_per_sec = drain
	return n

func make_edge(a: String, type: int, b: String, bonus := 0.05) -> NodeEdge:
	var e := NodeEdge.new()
	e.from_id = a
	e.type = type as NodeEdge.Type
	e.to_id = b
	e.spread_bonus = bonus
	return e

func make_graph(nodes: Array, edges: Array = []) -> NodeGraphData:
	var g := NodeGraphData.new()
	var ns: Array[SystemNodeData] = []
	for n in nodes:
		ns.append(n)
	var es: Array[NodeEdge] = []
	for e in edges:
		es.append(e)
	g.nodes = ns
	g.edges = es
	return g

func run_ticks(sim: SystemSim, seconds: float, step := 0.1) -> void:
	var t := 0.0
	while t < seconds:
		sim.tick(step)
		t += step

# ---------------------------------------------------------------- graph

func test_graph_validation() -> void:
	print("Graph validation")
	check(GRAPH.get_warnings().is_empty(), "shipped WAHANA graph has no warnings")
	var v := GRAPH.validated()
	check(v["nodes"].size() == 6 and v["edges"].size() == 7, "6 nodes and 7 edges kept")
	var D := NodeEdge.Type.DEPENDS_ON
	var g := make_graph(
		[make_node("a"), make_node("a"), make_node(""), null, make_node("b"), make_node("c")],
		[make_edge("a", D, "ghost"), make_edge("a", D, "a"),
		 make_edge("a", D, "b"), make_edge("b", D, "a"),     # cycle: second one dropped
		 make_edge("b", D, "c"), make_edge("c", D, "a"), null])
	var v2 := g.validated()
	check(v2["nodes"].size() == 3, "duplicate/empty/null nodes dropped (kept %d)" % v2["nodes"].size())
	var kept: Array = v2["edges"]
	check(kept.size() == 2, "unknown, self and cyclic edges dropped (kept %d)" % kept.size())
	check(v2["warnings"].size() >= 6, "each problem is reported (%d warnings)" % v2["warnings"].size())
	var sim := SystemSim.new(make_cfg(g))
	run_ticks(sim, 5.0)
	check(true, "a sloppy graph still runs")
	check(NodeGraphData.new().bounds(Vector2(10, 10)) == Rect2(), "empty graph has empty bounds")
	var empty_sim := SystemSim.new(make_cfg(null))
	run_ticks(empty_sim, 5.0)
	check(empty_sim.nodes.is_empty(), "missing graph = empty sim, no crash")

func test_dependencies() -> void:
	print("Dependencies")
	var sim := SystemSim.new(make_cfg())
	check(sim.is_online("lengan"), "everything starts online")
	sim.trigger_error("daya")
	check(not sim.is_online("daya"), "errored power is not online")
	check(not sim.is_online("jaringan"), "jaringan goes offline when power is down")
	check(not sim.is_online("lengan"), "lengan is offline too (transitive)")
	check(sim.is_blocked("lengan"), "lengan is blocked")
	check(sim.state_of("lengan") == SystemSim.State.HEALTHY, "blocked is not the same as broken")
	check(sim.blocker_of("kaki") != "", "a blocker is named")
	sim.trigger_error("lengan")
	check(not sim.can_repair("lengan"), "cannot repair lengan while its parents are down")
	check(not sim.repair("lengan"), "repair() refuses a blocked system")
	check(sim.can_repair("daya"), "the root can be repaired")
	check(sim.repair("daya"), "repair the root")
	check(sim.can_repair("lengan"), "lengan can now be repaired")
	check(sim.repair("lengan"), "repair lengan")
	check(sim.is_online("lengan") and sim.is_online("daya"), "all online again")
	check(not sim.repair("daya"), "repairing a healthy system does nothing")
	check(not sim.repair("nope"), "repairing an unknown id does nothing")

func test_error_lifecycle() -> void:
	print("Error lifecycle")
	var g := make_graph([make_node("a", 0.0, 10.0, 5.0)])
	var sim := SystemSim.new(make_cfg(g))
	var log: Array = []
	sim.state_changed.connect(func(id: String, st: int) -> void: log.append(st))
	check(sim.trigger_error("a"), "trigger_error works")
	check(not sim.trigger_error("a"), "cannot error an already broken system")
	check(not sim.trigger_error("zzz"), "unknown id is refused")
	run_ticks(sim, 4.0)
	check(sim.state_of("a") == SystemSim.State.ERROR, "still ERROR before the countdown ends")
	check(absf(sim.countdown_of("a") - 6.0) < 0.2, "countdown ticks down (%.1f)" % sim.countdown_of("a"))
	check(sim.integrity == 100.0, "no integrity loss while only ERROR")
	run_ticks(sim, 7.0)
	check(sim.state_of("a") == SystemSim.State.FAILED, "FAILED when the countdown hits 0")
	var after_fail := sim.integrity
	run_ticks(sim, 2.0)
	check(sim.integrity < after_fail - 9.0, "FAILED system drains integrity (%.1f)" % sim.integrity)
	check(sim.repair("a"), "a FAILED system can still be repaired")
	var healed := sim.integrity
	run_ticks(sim, 3.0)
	check(sim.integrity == healed, "draining stops after repair")
	check(log == [SystemSim.State.ERROR, SystemSim.State.FAILED, SystemSim.State.HEALTHY], "state_changed fired in order")
	# One huge tick must not skip past the drain logic or explode.
	var big := SystemSim.new(make_cfg(g))
	big.trigger_error("a")
	big.tick(1000.0)
	check(big.integrity > 0.0, "a single giant tick is capped (hitch protection)")

func test_spread() -> void:
	print("Spreading errors")
	var S := NodeEdge.Type.SPREADS_TO
	var a := make_node("a", 0.0, 100.0, 0.0)
	var b := make_node("b", 0.0, 100.0, 0.0)
	var g := make_graph([a, b], [make_edge("a", S, "b", 0.5)])
	var cfg := make_cfg(g)
	cfg.random_errors_enabled = true
	cfg.min_error_gap = 0.0
	cfg.repair_grace = 0.0
	var sim := SystemSim.new(cfg)
	run_ticks(sim, 60.0)
	check(sim.state_of("b") == SystemSim.State.HEALTHY, "no spread while the source is healthy")
	sim.trigger_error("a")
	run_ticks(sim, 30.0)
	check(sim.state_of("b") != SystemSim.State.HEALTHY, "an unfixed error spreads to the connected system")

func test_random_error_limits() -> void:
	print("Random error limits")
	var nodes: Array = []
	for i in 6:
		nodes.append(make_node("n%d" % i, 1.0, 500.0, 0.0))
	var cfg := make_cfg(make_graph(nodes))
	cfg.random_errors_enabled = true
	cfg.max_concurrent_errors = 3
	cfg.min_error_gap = 10.0
	var sim := SystemSim.new(cfg)
	run_ticks(sim, 9.0)
	check(sim.broken_count() == 0, "no random error before the first gap passes")
	run_ticks(sim, 2.0)
	check(sim.broken_count() == 1, "first random error after the gap (%d)" % sim.broken_count())
	run_ticks(sim, 8.0)
	check(sim.broken_count() == 1, "the gap spaces errors apart")
	run_ticks(sim, 200.0)
	check(sim.broken_count() == 3, "never more than max_concurrent_errors (%d)" % sim.broken_count())
	var healthy_ids: Array = []
	for n in sim.nodes:
		if sim.state_of(n.id) == SystemSim.State.HEALTHY:
			healthy_ids.append(n.id)
	sim.trigger_surge(healthy_ids)
	check(sim.broken_count() == 6, "a scripted surge still works past the cap (%d broken)" % sim.broken_count())

func test_scripted_errors() -> void:
	print("Scripted errors")
	var nodes: Array = []
	for i in 6:
		nodes.append(make_node("n%d" % i))
	var cfg := make_cfg(make_graph(nodes))
	cfg.max_concurrent_errors = 1
	var sim := SystemSim.new(cfg)
	var events: Array = []
	sim.error_triggered.connect(func(id: String, scripted: bool) -> void: events.append(scripted))
	check(sim.trigger_surge(["n0", "n1", "n2", "bogus", "n0"]) == 3, "surge breaks 3 (ignores bogus and duplicates)")
	check(sim.broken_count() == 3, "surge ignores the concurrent cap")
	check(events.size() == 3 and events[0] == true, "surge reports scripted = true")
	sim.random_errors_enabled = true
	check(true, "random errors can be toggled at runtime")

func test_integrity() -> void:
	print("Integrity")
	var cfg := make_cfg(make_graph([make_node("a", 0.0, 1.0, 50.0)]))
	var sim := SystemSim.new(cfg)
	var depleted: Array = []
	sim.integrity_depleted.connect(func() -> void: depleted.append(true))
	sim.trigger_error("a")
	run_ticks(sim, 10.0)
	check(sim.integrity == 0.0, "integrity bottoms out at 0")
	check(depleted.size() == 1, "integrity_depleted fires exactly once")
	check(sim.is_depleted(), "sim reports depleted")
	check(not sim.repair("a"), "no repairs after the sim is over")
	sim.restore_integrity(50.0)
	check(sim.integrity == 0.0, "no restoring after depletion")
	var sim2 := SystemSim.new(cfg)
	sim2.damage_integrity(30.0)
	sim2.restore_integrity(1000.0)
	check(sim2.integrity == cfg.integrity_max, "restore is capped at max")

func test_pan_clamp() -> void:
	print("Pan clamp")
	var view := Vector2(320, 180)
	var big := Rect2(0, 0, 600, 400)
	check(NodeMap.clamp_pan(Vector2(500, 500), big, view, 24.0) == Vector2(24, 24), "cannot drag past the top-left margin")
	check(NodeMap.clamp_pan(Vector2(-9000, -9000), big, view, 24.0) == Vector2(320 - 24 - 600, 180 - 24 - 400), "cannot drag past the far edge")
	check(NodeMap.clamp_pan(Vector2(-100, -100), big, view, 24.0) == Vector2(-100, -100), "free movement inside the limits")
	var small := Rect2(100, 50, 100, 50)
	check(NodeMap.clamp_pan(Vector2(900, 900), small, view, 24.0) == NodeMap.clamp_pan(Vector2(-900, -900), small, view, 24.0), "a small map stays put (centered)")
	var centered := NodeMap.clamp_pan(Vector2.ZERO, small, view, 24.0)
	check(centered.x > -100 and centered.x < 320 - 200 + 100, "small map keeps all nodes on screen")

func test_color_match() -> void:
	print("Color-match minigame")
	var mg := ColorMatchMinigame.new()
	mg.size = Vector2(160, 90)
	add_child(mg)
	var cfg := ColorMatchConfig.new()
	cfg.rounds_needed = 3
	cfg.colors_shown = 4
	cfg.rng_seed = 5
	var result := {}
	mg.finished.connect(func(r: Dictionary) -> void: result.merge(r))
	mg.start(cfg)
	check(mg.choices.size() == 4, "4 colors shown")
	var distinct := {}
	for c in mg.choices:
		distinct[c] = true
	check(distinct.size() == 4, "all shown colors are different")
	check(mg.choices.has(mg.target), "the target is always among the choices")
	var wrong := (mg.correct_index() + 1) % 4
	check(mg.choose(mg.correct_index()) == true, "correct click counts")
	check(mg.streak == 1, "streak = 1")
	check(mg.choose((mg.correct_index() + 1) % 4) == false, "wrong click is wrong")
	check(mg.streak == 0 and mg.wrong_clicks == 1, "a wrong click resets the streak")
	check(result.is_empty(), "not finished after a wrong click")
	for i in 3:
		mg.choose(mg.correct_index())
	check(not result.is_empty() and result["success"], "3 correct in a row = success")
	check(result["wrong_clicks"] == 1, "wrong clicks are reported")
	check(mg.choose(0) == false, "clicks after finishing are ignored")
	mg.queue_free()
	var m2 := ColorMatchMinigame.new()
	add_child(m2)
	var cfg2 := ColorMatchConfig.new()
	cfg2.rounds_needed = 0
	cfg2.colors_shown = 99
	m2.start(cfg2)
	check(m2.choices.size() == ColorMatchMinigame.PALETTE.size(), "too many colors is clamped to the palette")
	check(cfg2.rounds() == 1, "0 rounds is clamped to 1")
	var cancelled := {}
	m2.finished.connect(func(r: Dictionary) -> void: cancelled.merge(r))
	m2.cancel()
	check(cancelled.get("cancelled", false) and not cancelled["success"], "cancel() ends with success = false")
	m2.queue_free()

# ---------------------------------------------------------------- walking

func test_walk_and_spawn() -> void:
	print("Walking view")
	var cfg := make_cfg()
	cfg.enemies = [load("res://data/management/enemy_kapak.tres"), load("res://data/management/enemy_panah.tres"), load("res://data/management/enemy_kapak.tres")]
	cfg.initial_spawn_delay = 1.0
	cfg.spawn_interval = 2.0
	cfg.max_alive = 2
	cfg.min_spawn_distance = 90.0
	cfg.enemy_speed = 0.0
	cfg.wahana_speed = 0.0
	var walk := WalkSim.new(cfg)
	walk.tick(0.5)
	check(walk.enemies.is_empty(), "no spawn before the initial delay")
	walk.tick(0.6)
	check(walk.enemies.size() == 1, "first enemy spawns after the delay")
	var e := walk.enemies[0]
	var a := cfg.arena_size
	var on_edge := is_zero_approx(e.pos.x) or is_zero_approx(e.pos.y) or is_equal_approx(e.pos.x, a.x) or is_equal_approx(e.pos.y, a.y)
	check(on_edge, "enemies spawn on an arena edge")
	check(e.pos.distance_to(walk.wahana_pos) >= 90.0, "spawn is at least min_spawn_distance away")
	check(e.data == cfg.enemies[0], "chapter spawns follow the configured order (1st = enemies[0])")
	for i in 40:
		walk.tick(0.5)
	check(walk.enemies.size() == 2, "max_alive caps living enemies (%d)" % walk.enemies.size())
	check(walk.spawned_count == 2, "no extra spawns while at the cap")
	var group := walk.tick(0.1)
	check(group.is_empty(), "far enemies are not in contact")
	walk.resolve_contact([walk.enemies[0]], true)
	check(walk.defeated_count == 1, "a defeated enemy is counted")
	for i in 20:
		walk.tick(0.5)
	check(walk.spawned_count == 3, "spawning resumes once there is room")
	check(walk.enemies.back().data == cfg.enemies[2], "chapter spawns follow the configured order (3rd = enemies[2])")

	# Chapter ends exactly when the whole list was spawned AND defeated
	var cfg2 := make_cfg()
	cfg2.enemies = [load("res://data/management/enemy_kapak.tres")]
	cfg2.initial_spawn_delay = 0.0
	cfg2.enemy_speed = 100.0
	cfg2.wahana_speed = 100.0
	var w2 := WalkSim.new(cfg2)
	check(not w2.is_cleared(), "not cleared at the start")
	var touching: Array[WalkSim.Walker] = []
	for i in 400:
		touching = w2.tick(0.1)
		if not touching.is_empty():
			break
	check(touching.size() == 1, "the enemy reaches the WAHANA (they walk toward each other)")
	check(not w2.is_cleared(), "not cleared while the fight is pending")
	w2.resolve_contact(touching, true)
	check(w2.is_cleared(), "cleared after the last enemy is defeated")
	check(w2.tick(1.0).is_empty() and w2.spawned_count == 1, "a cleared chapter never spawns more")

	# Losing a fight does not count the enemy as defeated
	var w3 := WalkSim.new(cfg2)
	for i in 400:
		touching = w3.tick(0.1)
		if not touching.is_empty():
			break
	w3.resolve_contact(touching, false)
	check(w3.defeated_count == 0 and not w3.is_cleared(), "a lost fight is not a defeat")

	# Contact groups are capped
	var cfg3 := make_cfg()
	var many: Array[SimEnemyData] = []
	for i in 5:
		many.append(load("res://data/management/enemy_kapak.tres"))
	cfg3.enemies = many
	cfg3.initial_spawn_delay = 0.0
	cfg3.spawn_interval = 0.1
	cfg3.min_spawn_interval = 0.1
	cfg3.max_alive = 5
	cfg3.max_group_size = 2
	cfg3.enemy_speed = 0.0
	cfg3.wahana_speed = 0.0
	cfg3.contact_distance = 1000.0
	var w4 := WalkSim.new(cfg3)
	var grp: Array[WalkSim.Walker] = []
	for i in 12:
		grp = w4.tick(0.1)
	check(w4.enemies.size() == 5 and grp.size() == 2, "a contact group holds at most max_group_size (%d)" % grp.size())

	# Speed multiplier hook: 1.0 by default, 0 freezes the WAHANA
	var cfg4 := make_cfg()
	cfg4.enemies = [load("res://data/management/enemy_kapak.tres")]
	cfg4.initial_spawn_delay = 0.0
	cfg4.enemy_speed = 0.0
	cfg4.wahana_speed = 50.0
	var w5 := WalkSim.new(cfg4)
	check(w5.speed_multiplier == 1.0, "speed multiplier defaults to 1.0")
	w5.tick(0.1)
	var start := w5.wahana_pos
	w5.speed_multiplier = 0.0
	w5.tick(0.5)
	check(w5.wahana_pos == start, "speed multiplier 0 stops the WAHANA")
	w5.speed_multiplier = 1.0
	w5.tick(0.5)
	check(w5.wahana_pos != start, "the WAHANA walks toward the enemy")
	# an idle WAHANA (no enemies) does not move
	var w6 := WalkSim.new(make_cfg())
	var p0 := w6.wahana_pos
	w6.tick(1.0)
	check(w6.wahana_pos == p0, "idle with no enemies")

	# Endless: weighted pick and ramp
	var cfg5 := make_cfg()
	cfg5.mode = ManagementConfig.Mode.ENDLESS
	cfg5.enemies = [load("res://data/management/enemy_kapak.tres"), load("res://data/management/enemy_panah.tres")]
	cfg5.spawn_interval = 10.0
	cfg5.min_spawn_interval = 2.0
	cfg5.spawn_rate_ramp = 1.0
	check(is_equal_approx(cfg5.interval_at(0.0), 10.0), "ramp: starts at spawn_interval")
	check(is_equal_approx(cfg5.interval_at(60.0), 5.0), "ramp: 1 minute at 100%/min halves it")
	check(is_equal_approx(cfg5.interval_at(6000.0), 2.0), "ramp: never faster than min_spawn_interval")
	cfg5.spawn_rate_ramp = 0.0
	check(is_equal_approx(cfg5.interval_at(6000.0), 10.0), "ramp 0 = flat rate")
	cfg5.initial_spawn_delay = 0.0
	cfg5.spawn_interval = 0.1
	cfg5.min_spawn_interval = 0.1
	cfg5.max_alive = 1000
	cfg5.enemy_speed = 0.0
	cfg5.wahana_speed = 0.0
	cfg5.contact_distance = 0.0
	var we := WalkSim.new(cfg5)
	var counts := {"Batara Kala Kapak": 0, "Batara Kala Panah": 0}
	for i in 600:
		we.tick(0.1)
	for en in we.enemies:
		counts[en.data.display_name] = counts.get(en.data.display_name, 0) + 1
	check(we.enemies.size() > 300, "endless keeps spawning (%d)" % we.enemies.size())
	check(counts["Batara Kala Kapak"] > counts["Batara Kala Panah"], "heavier weight spawns more often (%s)" % str(counts))
	check(not we.is_cleared(), "endless is never 'cleared'")
	# all weights 0 -> never spawns, never crashes
	var cfg6 := make_cfg()
	cfg6.mode = ManagementConfig.Mode.ENDLESS
	var zero_data := SimEnemyData.new()
	zero_data.weight = 0.0
	cfg6.enemies = [zero_data]
	cfg6.initial_spawn_delay = 0.0
	var w7 := WalkSim.new(cfg6)
	for i in 50:
		w7.tick(0.5)
	check(w7.enemies.is_empty(), "endless with all-zero weights spawns nothing, no crash")

func test_encounter_merge() -> void:
	print("Encounter building")
	var kapak: SimEnemyData = load("res://data/management/enemy_kapak.tres")
	var panah: SimEnemyData = load("res://data/management/enemy_panah.tres")
	var kawanan: SimEnemyData = load("res://data/management/enemy_kawanan.tres")
	var single := Encounter.build([kapak])
	check(single.size() == 1 and single[0].enemies.size() == 1, "one kapak = one wave of one")
	var multi := Encounter.build([kawanan])
	check(multi.size() == 3, "one walking enemy can carry a 3-wave battle (%d)" % multi.size())
	check(multi[2].enemies.size() == 3, "its last wave has 3 enemies")
	check(multi[0].intro_text == "GELOMBANG 1", "wave intro text is kept")
	var pair := Encounter.build([kapak, panah])
	check(pair.size() == 1 and pair[0].enemies.size() == 3, "two touching enemies fight together (3 units: kapak + 2 panah)")
	var mixed := Encounter.build([kawanan, kapak])
	check(mixed.size() == 3 and mixed[0].enemies.size() == 2, "waves merge by position (wave 1 has 2)")
	var crowd: Array = []
	for i in 3:
		crowd.append(panah)   # 3 x 2 archers = 6 > MAX_PER_WAVE
	var split := Encounter.build(crowd)
	var total := 0
	for w in split:
		total += w.enemies.size()
		check(w.enemies.size() <= Encounter.MAX_PER_WAVE, "no wave exceeds the field limit (%d)" % w.enemies.size())
	check(total == 6, "overflow spills into another wave, nobody is dropped")
	check(Encounter.build([]).size() == 1, "empty input still gives a fightable wave")
	check(Encounter.build([null]).size() == 1, "null enemy gives a fallback wave")

# ---------------------------------------------------------------- full flow

func make_management(cfg: ManagementConfig) -> Management:
	var m: Management = ManagementScene.instantiate()
	m.config = cfg
	m.drive_manually = true
	m.battle_pace = 0.01
	m.battle_auto_block = TimingBar.Result.PERFECT
	add_child(m)
	return m

func chapter_cfg() -> ManagementConfig:
	var c := make_cfg()
	c.enemies = [load("res://data/management/enemy_kapak.tres"), load("res://data/management/enemy_kapak.tres")]
	c.initial_spawn_delay = 0.0
	c.spawn_interval = 1.0
	c.enemy_speed = 120.0
	c.wahana_speed = 120.0
	c.max_alive = 1
	c.story_mode = true
	return c

func auto_fight(b: Node) -> void:
	# play whatever battle is running until it ends
	var frames := 0
	while is_instance_valid(b) and b.state != b.State.WIN and b.state != b.State.LOSE and frames < 6000:
		await get_tree().process_frame
		frames += 1
		if is_instance_valid(b) and b.state == b.State.PLAYER_TURN:
			b.use_skill(1 if b.cooldowns[1] == 0 else 0)

func test_management_flow() -> void:
	print("Management: chapter flow")
	GameState.story_mode = false
	var m := make_management(chapter_cfg())
	var result := {}
	m.finished.connect(func(r: Dictionary) -> void: result.merge(r))
	var contacts: Array = []
	m.contact_started.connect(func(n: int) -> void: contacts.append(n))
	check(GameState.story_mode == true, "story_mode is set from the config while it runs")
	# run until the first contact
	var frames := 0
	while m.active_battle == null and frames < 2000:
		m.tick(0.1)
		frames += 1
	check(m.active_battle != null, "a battle starts on contact")
	check(m.is_paused, "the sim is paused during the battle")
	var errs_before := m.sim.broken_count()
	var t_before := m.sim.elapsed
	m.tick(5.0)
	check(m.sim.elapsed == t_before, "sim time does not advance while paused")
	check(m.sim.broken_count() == errs_before, "no errors tick while paused")
	await auto_fight(m.active_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not m.is_paused, "the sim resumes after the battle")
	check(m.walk.defeated_count == 1, "the enemy counts as defeated")
	check(result.is_empty(), "chapter is not over after 1 of 2")
	frames = 0
	while m.active_battle == null and frames < 2000:
		m.tick(0.1)
		frames += 1
	await auto_fight(m.active_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	check(not result.is_empty() and result["won"] and result["reason"] == "cleared", "chapter won when all enemies are defeated")
	check(result.get("defeated", 0) == 2 and result.get("total", 0) == 2, "result reports 2/2")
	check(result.get("score", 0) > 0, "score includes battle and clear points (%s)" % result.get("score"))
	check(contacts == [1, 1], "two single-enemy contacts")
	m.queue_free()
	await get_tree().process_frame
	check(GameState.story_mode == false, "GameState.story_mode is restored when the sim is freed")

	print("Management: pause keeps the map and repair intact")
	var m2 := make_management(chapter_cfg())
	m2.sim.trigger_error("daya")
	m2.map.open()
	check(m2.map.is_open(), "map opens")
	m2.request_repair("daya")
	check(m2.is_repairing(), "clicking an errored node starts its repair minigame")
	var mg: ColorMatchMinigame = m2._mg
	mg.choose(mg.correct_index())
	check(mg.streak == 1, "made progress in the repair")
	frames = 0
	while m2.active_battle == null and frames < 2000:
		m2.tick(0.1)
		frames += 1
	check(m2.active_battle != null, "contact while the map and a repair are open")
	check(not m2.map.is_open(), "the map closes automatically on contact")
	check(mg.process_mode == Node.PROCESS_MODE_DISABLED, "the repair minigame is frozen")
	check(mg.streak == 1, "repair progress is kept")
	var cd := m2.sim.countdown_of("daya")
	m2.tick(3.0)
	check(m2.sim.countdown_of("daya") == cd, "error countdown does not tick during battle")
	await auto_fight(m2.active_battle)
	await get_tree().process_frame
	await get_tree().process_frame
	check(m2.map.is_open(), "the map reopens after the battle")
	check(mg.process_mode != Node.PROCESS_MODE_DISABLED, "the repair minigame resumes")
	check(m2.is_repairing() and mg.streak == 1, "repair still in progress with the same streak")
	for i in 2:
		mg.choose(mg.correct_index())
	await get_tree().process_frame
	check(m2.sim.state_of("daya") == SystemSim.State.HEALTHY, "finishing the repair fixes the system")
	check(not m2.is_repairing(), "repair state is cleared")
	m2.queue_free()

	print("Management: repair rules")
	var m3 := make_management(chapter_cfg())
	m3.request_repair("daya")
	check(not m3.is_repairing(), "a healthy system cannot be repaired")
	m3.sim.trigger_error("daya")
	m3.sim.trigger_error("lengan")
	m3.request_repair("lengan")
	check(not m3.is_repairing(), "a blocked system refuses repair")
	m3.request_repair("daya")
	check(m3.is_repairing(), "the root system can be repaired")
	m3.request_repair("daya")
	check(m3._mg != null, "a second click while repairing is ignored (still the same one)")
	m3.toggle_map()
	m3.toggle_map()
	await get_tree().process_frame
	check(not m3.is_repairing(), "closing the map abandons the repair")
	check(m3.sim.state_of("daya") == SystemSim.State.ERROR, "an abandoned repair does not fix anything")
	m3.queue_free()

	print("Management: losing")
	var cfg4 := chapter_cfg()
	var ng := make_graph([make_node("a", 0.0, 1.0, 60.0)])
	cfg4.graph = ng
	cfg4.enemies = [load("res://data/management/enemy_kapak.tres")]
	cfg4.initial_spawn_delay = 999.0
	var m4 := make_management(cfg4)
	var r4 := {}
	m4.finished.connect(func(r: Dictionary) -> void: r4.merge(r))
	m4.sim.trigger_error("a")
	for i in 100:
		m4.tick(0.1)
	check(not r4.is_empty() and not r4["won"] and r4["reason"] == "integrity", "integrity at 0 loses the sim")
	m4.tick(1.0)
	check(true, "ticking after the end is harmless")
	m4.queue_free()

	print("Management: endless")
	var cfg5 := chapter_cfg()
	cfg5.mode = ManagementConfig.Mode.ENDLESS
	cfg5.story_mode = false
	cfg5.enemies = [load("res://data/management/enemy_kapak.tres")]
	cfg5.initial_spawn_delay = 0.0
	var m5 := make_management(cfg5)
	var r5 := {}
	m5.finished.connect(func(r: Dictionary) -> void: r5.merge(r))
	var fights := 0
	for round_i in 3:
		frames = 0
		while m5.active_battle == null and frames < 2000:
			m5.tick(0.1)
			frames += 1
		await auto_fight(m5.active_battle)
		await get_tree().process_frame
		await get_tree().process_frame
		fights += 1
	check(r5.is_empty(), "endless keeps going after %d cleared fights" % fights)
	check(m5.walk.defeated_count == 3, "defeats keep adding up")
	check(m5.score > 0, "endless accumulates score")
	m5.abort()
	check(not r5.is_empty() and r5["reason"] == "aborted" and r5["score"] > 0, "abort() ends the session and reports the score")
	check(GameState.high_score >= r5["score"], "endless records the high score")
	m5.queue_free()
