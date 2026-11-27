class_name ExtraCooldownEffect
extends SkillEffect
## Adds turns to this skill's cooldown (total extra is capped by the battle).

@export_range(0, 10, 1, "or_greater") var turns := 1

func apply(ctx: SkillContext) -> void:
	var added := ctx.add_cooldown(turns)
	if added > 0:
		ctx.say("cooldown +%d" % added)
