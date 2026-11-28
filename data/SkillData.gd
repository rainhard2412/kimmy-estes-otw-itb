class_name SkillData
extends Resource

@export var display_name := ""
@export var damage := 0
@export var heal := 0
@export var cooldown := 0      # turns locked after use
@export var defends := false   # halves the next incoming hit
## The pose Bara plays when using this skill (a name from his AnimationPlayer /
## AnimatedSprite2D, see battle/BattleUnit.gd). Empty = automatic: `defend` for
## defend skills, `heal` for heal-only skills, otherwise `attack`.
@export var pose: StringName = &""

@export_group("Circle minigame")
## If set, using this skill first plays the circle minigame. Leave empty for a
## normal instant skill.
@export var circle_config: CircleMinigameConfig
## Each missed circle is one penalty point. Crossed thresholds all apply.
@export var penalty_thresholds: Array[PenaltyThreshold] = []

@export_group("Custom behavior")
## Extra effects that always run after damage/heal/defend (unless fizzled).
@export var extra_effects: Array[SkillEffect] = []


func uses_minigame() -> bool:
	return circle_config != null


## Thresholds reached with `points` penalty points, lowest first. Entries with
## no effect or a threshold below 1 are ignored (a perfect run must never
## trigger a penalty). Ties keep their order in the array.
func crossed_thresholds(points: int) -> Array[PenaltyThreshold]:
	var picked: Array[Array] = []   # [threshold, original_index]
	for idx in penalty_thresholds.size():
		var t := penalty_thresholds[idx]
		if t != null and t.effect != null and t.at_penalty_points >= 1 and t.at_penalty_points <= points:
			picked.append([t, idx])
	picked.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0].at_penalty_points != b[0].at_penalty_points:
			return a[0].at_penalty_points < b[0].at_penalty_points
		return a[1] < b[1])
	var out: Array[PenaltyThreshold] = []
	for p in picked:
		out.append(p[0])
	return out


## Design-time problems (shown with push_warning when a battle starts).
func get_warnings() -> PackedStringArray:
	var w: PackedStringArray = []
	if circle_config == null and not penalty_thresholds.is_empty():
		w.append("has penalty_thresholds but no circle_config: penalties can never trigger")
	for t in penalty_thresholds:
		if t == null or t.effect == null:
			w.append("a penalty threshold has no effect")
		elif circle_config != null and t.at_penalty_points > circle_config.count():
			w.append("threshold %d is above circle_count %d: unreachable" % [t.at_penalty_points, circle_config.count()])
	for e in extra_effects:
		if e == null:
			w.append("extra_effects contains an empty slot")
	return w
