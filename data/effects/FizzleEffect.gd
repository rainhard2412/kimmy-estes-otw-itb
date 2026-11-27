class_name FizzleEffect
extends SkillEffect
## The skill does nothing at all (no damage, no heal, no extra effects).
## Backlash and cooldown penalties still apply.

func apply(ctx: SkillContext) -> void:
	ctx.fizzle()
