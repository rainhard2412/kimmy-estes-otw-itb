class_name CircleMinigameConfig
extends Resource
## Every knob of the OSU!-style circle minigame. Edit in the Inspector, or
## make one .tres per skill. Use the safe accessors (count(), lifetime(), ...)
## in code: they clamp bad values so a typo can never hang or crash a battle.

@export_group("Circles")
## How many circles appear in total.
@export_range(1, 50, 1, "or_greater") var circle_count := 5
## Seconds each circle stays alive (its hit window). It misses when this runs out.
@export_range(0.1, 10.0, 0.05, "or_greater") var circle_lifetime := 1.2
## Seconds between one circle spawning and the next.
@export_range(0.05, 5.0, 0.05, "or_greater") var spawn_interval := 0.6
## Circle size in pixels (at the 320x180 game resolution).
@export_range(4.0, 60.0, 1.0, "or_greater") var circle_radius := 14.0
## Keep circles at least this far from the play area edge.
@export_range(0.0, 100.0, 1.0, "or_greater") var play_area_margin := 8.0
## Seconds for the shrinking ring to reach the circle = the ideal hit moment.
## Clamped to circle_lifetime.
@export_range(0.05, 10.0, 0.05, "or_greater") var approach_ring_time := 0.9

@export_group("Grading")
## Hit within +/- this many seconds of the ideal moment = PERFECT.
@export_range(0.0, 2.0, 0.01, "or_greater") var perfect_window := 0.12
## Hit within +/- this many seconds = GOOD. Anything further = MISS.
@export_range(0.0, 2.0, 0.01, "or_greater") var good_window := 0.30
## Skill output multiplier: all MISS gives min, all PERFECT gives max.
## Misses are punished by penalty points, so min stays 1.0 by default.
@export_range(0.0, 5.0, 0.05, "or_greater") var min_multiplier := 1.0
@export_range(0.0, 5.0, 0.05, "or_greater") var max_multiplier := 1.5

@export_group("Debug")
## 0 = random every time. Any other number = same layout every time.
@export var rng_seed := 0


func count() -> int:
	return maxi(circle_count, 1)

func lifetime() -> float:
	return maxf(circle_lifetime, 0.1)

func interval() -> float:
	return maxf(spawn_interval, 0.05)

func radius() -> float:
	return maxf(circle_radius, 4.0)

func approach_time() -> float:
	return clampf(approach_ring_time, 0.05, lifetime())

func perfect_win() -> float:
	return maxf(perfect_window, 0.0)

func good_win() -> float:
	return maxf(good_window, perfect_win())

## Linear blend between min and max multiplier; `score` is 0..1.
func multiplier_for(score: float) -> float:
	var lo := maxf(min_multiplier, 0.0)
	var hi := maxf(max_multiplier, lo)
	return lerpf(lo, hi, clampf(score, 0.0, 1.0))

func get_warnings() -> PackedStringArray:
	var w: PackedStringArray = []
	if circle_count < 1:
		w.append("circle_count < 1: using 1")
	if approach_ring_time > circle_lifetime:
		w.append("approach_ring_time is longer than circle_lifetime: clamped, circles would expire before the ring arrives")
	if good_window < perfect_window:
		w.append("good_window < perfect_window: GOOD zone is empty")
	if max_multiplier < min_multiplier:
		w.append("max_multiplier < min_multiplier: using min for both")
	return w
