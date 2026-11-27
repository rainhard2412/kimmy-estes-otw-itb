class_name EnemyData
extends Resource
## One kind of Batara Kala. Tune these values in the Inspector.

@export var display_name := ""
## Short label drawn above the unit (the full name is too wide at 320x180).
@export var short_name := ""
@export var max_hp := 20
@export var attack_name := "Tebas"
@export var attack_damage := 5
## Only used when `unit_scene` is empty: tint of the default placeholder box.
@export var color := Color.RED
@export var score := 100
## Ranged enemies telegraph their shot, which opens a Perfect Block window.
@export var telegraphs := false
@export var windup_text := "menarik busur..."
## This enemy's look on the battlefield: a scene that inherits
## battle/EnemyUnit.tscn (see battle/units/). Empty = the default placeholder.
@export var unit_scene: PackedScene

const DEFAULT_UNIT := preload("res://battle/EnemyUnit.tscn")


func label() -> String:
	return short_name if short_name != "" else display_name


## Builds this enemy's battlefield node (not yet in the tree).
func make_unit() -> EnemyUnit:
	var scene := unit_scene if unit_scene != null else DEFAULT_UNIT
	var u := scene.instantiate() as EnemyUnit
	if u == null:
		push_error("EnemyData '%s': unit_scene must inherit battle/EnemyUnit.tscn; using the default" % display_name)
		u = DEFAULT_UNIT.instantiate() as EnemyUnit
		u.fallback_tint = color
	elif unit_scene == null:
		u.fallback_tint = color
	return u.setup(self)
