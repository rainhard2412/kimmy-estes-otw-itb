extends Node
## Scene contract test: every scene loads, has the nodes its script expects
## (the "%Unique" names), and the right root type. Catches typos in
## hand-edited .tscn files before they turn into runtime errors.
##   godot --headless --path . res://tests/TestScenes.tscn

var failures := 0
var sections_done := 0
const EXPECTED_SECTIONS := 4

## scene -> unique node names it must contain
const CONTRACT := {
	"res://ui/TimingBar.tscn": ["Track", "GoodZone", "PerfectZone", "Marker", "Caption"],
	"res://minigames/circle/CircleMinigame.tscn": ["Prompt", "Circles", "Popups"],
	"res://minigames/circle/CircleTarget.tscn": ["Disc", "Ring", "Number"],
	"res://minigames/circle/GradePopup.tscn": [],
	"res://minigames/color_match/ColorMatchMinigame.tscn": ["Prompt", "Swatch", "Buttons"],
	"res://minigames/color_match/ColorButton.tscn": [],
	"res://battle/Battle.tscn": ["Camera", "Field", "PlayerUnit", "Enemies", "TargetCursor",
			"ScreenFlash", "Log", "Hint", "Banner", "TimingBar", "MinigameSlot", "SkillBar"],
	"res://battle/EnemyUnit.tscn": ["Visual", "Body", "NameLabel", "Alert", "ClickArea"],
	"res://battle/units/KapakUnit.tscn": ["Visual", "Body", "NameLabel", "Alert", "ClickArea"],
	"res://battle/units/PanahUnit.tscn": ["Visual", "Body", "NameLabel", "Alert", "ClickArea"],
	"res://battle/PlayerUnit.tscn": ["Visual", "Body", "NameLabel"],
	"res://battle/SkillButton.tscn": [],
	"res://management/Management.tscn": ["World", "Arena", "HUD", "IntegrityBar", "StatusLabel",
			"AlertLabel", "MapButton", "NodeMap"],
	"res://management/Arena.tscn": ["Ground", "Wahana", "Walkers"],
	"res://management/Walker.tscn": ["Visual", "Body"],
	"res://management/NodeMap.tscn": ["Backdrop", "Content", "Edges", "Nodes", "Title", "Message",
			"MinigameHost", "Dim"],
	"res://management/SystemNodeWidget.tscn": [],
}

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		printerr("  FAIL ", msg)

func _ready() -> void:
	await get_tree().process_frame
	test_contract(); sections_done += 1
	test_roots(); sections_done += 1
	test_enemy_scenes(); sections_done += 1
	await test_arena_sync(); sections_done += 1
	check(sections_done == EXPECTED_SECTIONS, "every test section ran to the end")
	print("\n", "ALL PASSED" if failures == 0 else "%d FAILED" % failures)
	get_tree().quit(1 if failures else 0)

func load_scene(path: String) -> PackedScene:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as PackedScene

func test_contract() -> void:
	print("Scene contract")
	for path in CONTRACT:
		var ps := load_scene(path)
		if ps == null:
			check(false, "%s exists and loads" % path)
			continue
		var root := ps.instantiate()
		var missing: Array[String] = []
		for n in CONTRACT[path]:
			if root.get_node_or_null("%" + n) == null:
				missing.append(n)
		check(missing.is_empty(), "%s has its nodes%s" % [path.get_file(), "" if missing.is_empty() else " (missing: %s)" % ", ".join(missing)])
		root.free()

func test_roots() -> void:
	print("Root types and scripts")
	var expect := {
		"res://ui/TimingBar.tscn": TimingBar,
		"res://minigames/circle/CircleMinigame.tscn": CircleMinigame,
		"res://minigames/color_match/ColorMatchMinigame.tscn": ColorMatchMinigame,
		"res://battle/EnemyUnit.tscn": EnemyUnit,
		"res://battle/units/KapakUnit.tscn": EnemyUnit,
		"res://battle/units/PanahUnit.tscn": EnemyUnit,
		"res://management/Management.tscn": Management,
		"res://management/NodeMap.tscn": NodeMap,
	}
	for path in expect:
		var ps := load_scene(path)
		if ps == null:
			check(false, "%s loads" % path)
			continue
		var root := ps.instantiate()
		check(is_instance_of(root, expect[path]), "%s root is the expected class" % path.get_file())
		root.free()
	# Every minigame scene must satisfy the Minigame contract
	for path in ["res://minigames/circle/CircleMinigame.tscn", "res://minigames/color_match/ColorMatchMinigame.tscn"]:
		var ps := load_scene(path)
		if ps != null:
			var root := ps.instantiate()
			check(root is Minigame, "%s is a Minigame" % path.get_file())
			root.free()
	# Factories hand out working scene-backed instances
	var bar := TimingBar.create()
	check(bar != null and bar.get_node_or_null("%Marker") != null, "TimingBar.create() builds the scene")
	bar.free()
	var cm := ColorMatchMinigame.create()
	check(cm != null and cm.get_node_or_null("%Buttons") != null, "ColorMatchMinigame.create() builds the scene")
	cm.free()
	var cc := CircleMinigame.create()
	check(cc != null and cc.get_node_or_null("%Circles") != null, "CircleMinigame.create() builds the scene")
	cc.free()

func test_enemy_scenes() -> void:
	print("Per-enemy scenes")
	var kapak: EnemyData = load("res://data/enemies/kapak.tres")
	var panah: EnemyData = load("res://data/enemies/panah.tres")
	check(kapak.unit_scene != null and panah.unit_scene != null, "shipped enemies point at their own unit scene")
	check(kapak.unit_scene != panah.unit_scene, "kapak and panah use different scenes")
	var plain := EnemyData.new()
	check(plain.make_unit() is EnemyUnit, "an enemy with no scene still gets the default unit")
	var u: Node = kapak.make_unit()
	check(u is EnemyUnit and u.scene_file_path == "res://battle/units/KapakUnit.tscn", "kapak spawns from KapakUnit.tscn")
	u.free()
	var pw: Node = SimEnemyData.new().make_walker()
	check(pw != null and pw.get_node_or_null("%Body") != null, "a sim enemy with no scene gets the default walker")
	pw.free()

func test_arena_sync() -> void:
	print("Arena shows the walking sim")
	var cfg := ManagementConfig.new()
	cfg.graph = load("res://data/management/wahana_graph.tres")
	cfg.random_errors_enabled = false
	cfg.rng_seed = 3
	var many: Array[SimEnemyData] = []
	for i in 3:
		many.append(load("res://data/management/enemy_kapak.tres"))
	cfg.enemies = many
	cfg.initial_spawn_delay = 0.0
	cfg.spawn_interval = 0.5
	cfg.max_alive = 3
	cfg.enemy_speed = 0.0
	cfg.wahana_speed = 0.0
	cfg.contact_distance = 1.0
	var m: Management = load("res://management/Management.tscn").instantiate()
	m.config = cfg
	m.drive_manually = true
	add_child(m)
	for i in 30:
		m.tick(0.1)
	await get_tree().process_frame
	await get_tree().process_frame
	check(m.walk.enemies.size() == 3, "the sim has 3 enemies")
	check(m._arena.walker_count() == 3, "the arena shows one node per enemy (%d)" % m._arena.walker_count())
	var first: WalkSim.Walker = m.walk.enemies[0]
	var node: Node2D = m._arena._nodes[first.id]
	check(node.position == first.pos.round(), "a walker node sits where the sim says")
	check(node.get_node("%Body") is ColorRect, "walkers use the default placeholder body")
	check((node.get_node("%Body") as ColorRect).color == cfg.enemies[0].color, "the default body takes the enemy's color")
	check(m._arena._wahana.position.round() == m.walk.wahana_pos.round(), "the WAHANA node follows the sim")
	m.walk.resolve_contact([first], true)
	await get_tree().process_frame
	await get_tree().process_frame
	check(m._arena.walker_count() == 2, "a defeated enemy's node is removed (%d left)" % m._arena.walker_count())
	check(m._arena._ring != null and m._arena._ring.scale.x > 0.0, "the contact ring is sized from the config")
	m.queue_free()
	await get_tree().process_frame
