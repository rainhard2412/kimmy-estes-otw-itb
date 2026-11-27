class_name ManagementConfig
extends Resource
## Every number of one management-sim session. Make one .tres per chapter.

enum Mode {
	CHAPTER,   ## `enemies` spawn once, in order; win when all are defeated
	ENDLESS,   ## endless weighted-random spawns; only ends by losing
}

@export var mode: Mode = Mode.CHAPTER
@export var graph: NodeGraphData
## CHAPTER: the exact enemies of this chapter, in spawn order (its size is the
## chapter's enemy total). ENDLESS: the weighted pool spawns are picked from.
@export var enemies: Array[SimEnemyData] = []

@export_group("WAHANA")
@export_range(1.0, 1000.0, 1.0, "or_greater") var integrity_max := 100.0
@export_range(0.0, 200.0, 0.5, "or_greater") var wahana_speed := 0.0
## true = losing a battle never ends the session (Haikal covers, Bara gets full
## HP, as in the story). false = a lost battle ends it. Endless uses false.
@export var story_mode := true

@export_group("Enemies")
@export_range(0.0, 200.0, 0.5, "or_greater") var enemy_speed := 20.0
## Enemy centers closer than this to the WAHANA count as contact.
@export_range(1.0, 100.0, 0.5, "or_greater") var contact_distance := 14.0
## Seconds between spawns.
@export_range(0.1, 120.0, 0.1, "or_greater") var spawn_interval := 6.0
## Seconds before the first spawn.
@export_range(0.0, 60.0, 0.1, "or_greater") var initial_spawn_delay := 2.0
## However far the ramp goes, never spawn faster than this.
@export_range(0.1, 60.0, 0.1, "or_greater") var min_spawn_interval := 1.5
## ENDLESS: spawning speeds up by this fraction every minute (0 = flat rate).
## interval = spawn_interval / (1 + ramp * minutes), never below min_spawn_interval.
@export_range(0.0, 10.0, 0.05, "or_greater") var spawn_rate_ramp := 0.0
## Most enemies walking in the arena at once.
@export_range(1, 50, 1, "or_greater") var max_alive := 3
## Enemies spawn at least this far from the WAHANA.
@export_range(0.0, 400.0, 1.0, "or_greater") var min_spawn_distance := 90.0
## Most enemies that join one battle when several touch the WAHANA together.
@export_range(1, 6, 1, "or_greater") var max_group_size := 2

@export_group("Random errors")
@export var random_errors_enabled := true
## Minimum seconds between two random errors (scripted ones ignore this).
@export_range(0.0, 120.0, 0.5, "or_greater") var min_error_gap := 8.0
## Random errors stop while this many systems are already broken (scripted ones ignore this).
@export_range(1, 50, 1, "or_greater") var max_concurrent_errors := 3
## After a repair, a system can't randomly break again for this many seconds.
@export_range(0.0, 120.0, 0.5, "or_greater") var repair_grace := 10.0

@export_group("Arena / debug")
@export var arena_size := Vector2(320, 180)
## 0 = random. Any other number = reproducible runs.
@export var rng_seed := 0


func alive_cap() -> int:
	return maxi(max_alive, 1)

func group_cap() -> int:
	return maxi(max_group_size, 1)

func total_enemies() -> int:
	return enemies.size()

func interval_at(elapsed_seconds: float) -> float:
	var base := maxf(spawn_interval, 0.1)
	var minutes := maxf(elapsed_seconds, 0.0) / 60.0
	var scaled := base / (1.0 + maxf(spawn_rate_ramp, 0.0) * minutes)
	return maxf(scaled, minf(maxf(min_spawn_interval, 0.1), base))

func get_warnings() -> PackedStringArray:
	var w: PackedStringArray = []
	if graph == null:
		w.append("no graph: the node map will be empty")
	else:
		w.append_array(graph.get_warnings())
	if enemies.is_empty():
		w.append("no enemies: a chapter would end instantly, endless would never spawn")
	for e in enemies:
		if e == null:
			w.append("enemies has an empty slot")
		elif e.encounter.is_empty():
			w.append("enemy '%s' has no encounter: it will fight a single Kapak" % e.display_name)
	return w
