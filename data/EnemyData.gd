class_name EnemyData
extends Resource
## One kind of Batara Kala. Tune these values in the Inspector.

@export var display_name := ""
## Short label drawn above the unit (the full name is too wide at 320x180).
@export var short_name := ""
@export var max_hp := 20
@export var attack_name := "Tebas"
@export var attack_damage := 5
@export var color := Color.RED
@export var score := 100
## Ranged enemies telegraph their shot, which opens a Perfect Block window.
@export var telegraphs := false
@export var windup_text := "menarik busur..."

func label() -> String:
	return short_name if short_name != "" else display_name
