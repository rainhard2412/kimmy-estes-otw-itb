class_name WaveData
extends Resource
## One wave of enemies inside a battle.

@export var enemies: Array[EnemyData] = []
@export var intro_text := ""
## Tutorial line shown while the player acts (empty = no hint).
@export var hint_text := ""
## When true, Reyhan's cannon fires mid-wave and wipes two enemies.
@export var cannon_help := false
