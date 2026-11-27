class_name Waves
extends RefCounted
## Wave sets, built in code so battles stay easy to re-arrange per chapter.

const KAPAK := preload("res://data/enemies/kapak.tres")
const PANAH := preload("res://data/enemies/panah.tres")

static func _wave(enemies: Array[EnemyData], intro := "", hint := "", cannon := false) -> WaveData:
	var w := WaveData.new()
	w.enemies = enemies
	w.intro_text = intro
	w.hint_text = hint
	w.cannon_help = cannon
	return w

## Chapter 1 opening: the dream. One axe enemy, teaches the attack key.
static func ch1_dream() -> Array[WaveData]:
	var a: Array[EnemyData] = [KAPAK]
	var out: Array[WaveData] = [_wave(a, "", "pencet Z buat nyerang")]
	return out

## Chapter 1 final fight: three escalating waves, cannon help in the last one.
static func ch1_final() -> Array[WaveData]:
	var w1: Array[EnemyData] = [KAPAK]
	var w2: Array[EnemyData] = [PANAH, PANAH]
	var w3: Array[EnemyData] = [KAPAK, KAPAK, PANAH]
	var out: Array[WaveData] = [
		_wave(w1, "GELOMBANG 1", "pencet Z buat nyerang"),
		_wave(w2, "GELOMBANG 2", "musuh jauh! pencet X pas di hijau buat PERFECT BLOCK"),
		_wave(w3, "GELOMBANG 3", "", true),
	]
	return out
