class_name WeakenEffect
extends SkillEffect
## Reduces the skill's whole output (damage and healing) by a percentage.

@export_range(0, 100, 1) var percent := 25

func apply(ctx: SkillContext) -> void:
	var p := clampi(percent, 0, 100)
	ctx.scale_output(1.0 - p / 100.0)
	ctx.say("tenaga -%d%%" % p)
