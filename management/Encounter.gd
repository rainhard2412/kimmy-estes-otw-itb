class_name Encounter
extends RefCounted
## Turns the enemies that touched the WAHANA into one battle (a wave list).
##
## Each walking enemy carries its own encounter (a list of waves). When several
## touch at the same moment their waves are merged by position: everyone's wave
## 1 fights together, then everyone's wave 2, and so on. A merged wave never
## holds more than MAX_PER_WAVE enemies (the battlefield is only 320px wide);
## extra enemies spill into the next wave instead of being dropped.

const MAX_PER_WAVE := 4


## `datas` = Array of SimEnemyData. Never returns an empty list.
static func build(datas: Array) -> Array[WaveData]:
	var merged: Array[Dictionary] = []   # one per wave index
	for d in datas:
		var waves := _waves_of(d)
		for i in waves.size():
			while merged.size() <= i:
				merged.append({"enemies": [], "intro": "", "hint": "", "cannon": false})
			var m: Dictionary = merged[i]
			for e in waves[i].enemies:
				if e != null:
					m["enemies"].append(e)
			if m["intro"] == "":
				m["intro"] = waves[i].intro_text
			if m["hint"] == "":
				m["hint"] = waves[i].hint_text
			m["cannon"] = m["cannon"] or waves[i].cannon_help

	var out: Array[WaveData] = []
	for m in merged:
		var all: Array = m["enemies"]
		var first := true
		var at := 0
		while at < all.size():
			var w := WaveData.new()
			var chunk: Array[EnemyData] = []
			for k in range(at, mini(at + MAX_PER_WAVE, all.size())):
				chunk.append(all[k])
			w.enemies = chunk
			if first:
				w.intro_text = m["intro"]
				w.hint_text = m["hint"]
				w.cannon_help = m["cannon"]
			out.append(w)
			first = false
			at += MAX_PER_WAVE
	if out.is_empty():
		out.append(_fallback_wave())
	return out


static func _waves_of(d: SimEnemyData) -> Array[WaveData]:
	if d == null or d.encounter.is_empty():
		return [_fallback_wave()] as Array[WaveData]
	return d.encounter


static func _fallback_wave() -> WaveData:
	var w := WaveData.new()
	var list: Array[EnemyData] = [Waves.KAPAK]
	w.enemies = list
	return w
