class_name SimEnemyData
extends Resource
## An enemy as seen in the walking view. Touching the WAHANA starts its
## encounter: a (possibly multi-wave) battle built from WaveData.

@export var display_name := "Batara Kala"
## Only used when `walker_scene` is empty: tint of the default placeholder box.
@export var color := Color(0.8, 0.2, 0.2)
## The battle this enemy starts on contact. One walking enemy can mean several
## waves of fighting. Empty = a single Kapak (and a config warning).
@export var encounter: Array[WaveData] = []
## Endless mode only: relative chance of being picked to spawn.
@export_range(0.0, 100.0, 0.1, "or_greater") var weight := 1.0
## Score added when this enemy's encounter is cleared (on top of battle score).
@export var clear_score := 100
## This enemy's look in the arena: a scene that inherits management/Walker.tscn.
## Empty = the default placeholder box.
@export var walker_scene: PackedScene

const DEFAULT_WALKER := preload("res://management/Walker.tscn")


## Builds this enemy's arena node (not yet in the tree).
func make_walker() -> WalkerNode:
	var scene := walker_scene if walker_scene != null else DEFAULT_WALKER
	var w := scene.instantiate() as WalkerNode
	if w == null:
		push_error("SimEnemyData '%s': walker_scene must inherit management/Walker.tscn; using the default" % display_name)
		w = DEFAULT_WALKER.instantiate() as WalkerNode
	if walker_scene == null or w.scene_file_path == DEFAULT_WALKER.resource_path:
		w.fallback_tint = color
	return w
