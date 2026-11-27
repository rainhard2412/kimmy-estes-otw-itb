class_name BacklashEffect
extends SkillEffect
## Bara hurts himself. Can never reduce him below 1 HP.

@export_range(0, 999, 1, "or_greater") var damage := 3

func apply(ctx: SkillContext) -> void:
	var dealt := ctx.damage_player(damage)
	if dealt > 0:
		ctx.say("serangan balik %d" % dealt)
