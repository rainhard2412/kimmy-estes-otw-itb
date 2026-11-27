class_name SkillContext
extends RefCounted
## Everything a SkillEffect is allowed to see and do while a skill resolves.
## The helpers below are the safe way to change the battle.

const DEFAULT_MAX_EXTRA_COOLDOWN := 3

# --- inputs (read-only by convention) ---
var battle: Node                      # BattleManager; use helpers, not its internals
var skill: SkillData
var target: EnemyUnit                 # the enemy under the cursor, may be null
var minigame_result: Dictionary = {}  # empty if the skill has no minigame
var penalty_points := 0
var max_extra_cooldown := DEFAULT_MAX_EXTRA_COOLDOWN

# --- outputs the battle reads after all effects ran ---
var output_multiplier := 1.0          # scales the skill's own damage/heal
var fizzled := false
var extra_cooldown := 0
var log_parts: PackedStringArray = []


func say(text: String) -> void:
	log_parts.append(text)


func scale_output(factor: float) -> void:
	output_multiplier = maxf(output_multiplier * maxf(factor, 0.0), 0.0)


func fizzle() -> void:
	if not fizzled:
		fizzled = true
		say("gagal total!")


## Damage an enemy (defaults to the current target). Returns damage dealt.
## Does nothing once the skill has fizzled.
func deal_damage(amount: int, unit: EnemyUnit = null) -> int:
	var t := unit if unit != null else target
	if fizzled or amount <= 0 or t == null or not is_instance_valid(t) or not t.is_alive():
		return 0
	t.take_damage(amount)
	say("%d damage ke %s" % [amount, t.data.label()])
	return amount


## Heal Bara, capped at max HP. Returns the amount actually healed.
func heal_player(amount: int) -> int:
	if fizzled or amount <= 0:
		return 0
	var healed := mini(amount, battle.player_max_hp - battle.player_hp)
	battle.player_hp += healed
	say("+%d HP" % healed)
	return healed


## Hurt Bara. Never brings him below 1 HP, so a minigame can't kill the
## player. Returns the damage actually taken. Works even after a fizzle.
func damage_player(amount: int) -> int:
	if amount <= 0 or battle.player_hp <= 1:
		return 0
	var taken := mini(amount, battle.player_hp - 1)
	battle.player_hp -= taken
	return taken


## Add cooldown turns to this skill, capped at max_extra_cooldown in total.
## Returns the amount actually added.
func add_cooldown(turns: int) -> int:
	var before := extra_cooldown
	extra_cooldown = mini(extra_cooldown + maxi(turns, 0), max_extra_cooldown)
	return extra_cooldown - before


func set_defending() -> void:
	if not fizzled:
		battle.defending = true
		say("bertahan")


func living_enemies() -> Array[EnemyUnit]:
	return battle.enemies()
