class_name PenaltyThreshold
extends Resource
## "When this many circles were missed, apply this effect."
## Effects are cumulative: crossing threshold 4 also applies threshold 2's.

@export_range(1, 50, 1, "or_greater") var at_penalty_points := 2
@export var effect: SkillEffect
