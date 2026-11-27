class_name SimEnemyData
extends Resource
## An enemy as seen in the walking view. Touching the WAHANA starts its
## encounter: a (possibly multi-wave) battle built from WaveData.

@export var display_name := "Batara Kala"
@export var color := Color(0.8, 0.2, 0.2)
## The battle this enemy starts on contact. One walking enemy can mean several
## waves of fighting. Empty = a single Kapak (and a config warning).
@export var encounter: Array[WaveData] = []
## Endless mode only: relative chance of being picked to spawn.
@export_range(0.0, 100.0, 0.1, "or_greater") var weight := 1.0
## Score added when this enemy's encounter is cleared (on top of battle score).
@export var clear_score := 100
