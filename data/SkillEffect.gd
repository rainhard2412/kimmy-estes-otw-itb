class_name SkillEffect
extends Resource
## Base class for anything a skill can do beyond plain numbers.
##
## To add a new behavior: make a script that `extends SkillEffect`, give it a
## class_name and @export fields, and override apply(). Then drop it into a
## skill's `extra_effects` (always runs) or into a PenaltyThreshold (runs when
## that many circles were missed). No core code needs to change.
##
## Effects must act through the SkillContext helpers: they hold the safety
## rules (Bara can't be killed by backlash, cooldown caps, ...). Touching the
## battle directly bypasses those rules, so that is on the effect's author.

func apply(_ctx: SkillContext) -> void:
	pass
