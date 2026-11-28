class_name PlayerUnit
extends BattleUnit
## Bara (the WAHANA) on the battlefield. Poses: idle, attack, hurt, block,
## defend, heal, or any pose name a skill asks for (see battle/BattleUnit.gd).
##
## For melee skills he really runs up to the enemy: BattleManager calls
## strike_in() (dash + pose, awaits the moment of impact) and strike_out()
## (dash home). Tune the distances and timings in MELEE below.
##
## Look: edit battle/PlayerUnit.tscn. Scene contract (unique names):
##   %Visual (Node2D holding the art; flash acts on it)  %Body (the art)
##   %NameLabel (Label, shows "Bara\nhp/max")
## Optional, for your own animations: %Anim (AnimationPlayer) or %Sprite (AnimatedSprite2D)

## Per-pose melee timing. reach = how far left of the enemy's hit point Bara's
## node stops (his fist/foot should just touch the enemy); dash_in / dash_out =
## travel seconds; impact = seconds after the pose starts at which the hit connects.
const MELEE := {
	&"attack": {"reach": 48.0, "dash_in": 0.14, "impact": 0.10, "dash_out": 0.22},
	&"kick": {"reach": 52.0, "dash_in": 0.16, "impact": 0.14, "dash_out": 0.24},
	&"smash": {"reach": 44.0, "dash_in": 0.20, "impact": 0.20, "dash_out": 0.32},
}
const MELEE_DEFAULT := {"reach": 48.0, "dash_in": 0.14, "impact": 0.10, "dash_out": 0.22}
## How many fading copies the dash leaves behind.
const AFTERIMAGES := 4

@onready var _label: Label = %NameLabel

## Where Bara stands when he is not mid-dash; captured on the first strike.
var _home := Vector2.INF
var _dash_tween: Tween


func set_hp(hp: int, max_hp: int) -> void:
	_label.text = "Bara\n%d/%d" % [hp, max_hp]


func flash() -> void:
	_visual.modulate = Color(3, 3, 3)
	create_tween().tween_property(_visual, "modulate", Color.WHITE, 0.15)


## Settings for `pose`, falling back to the plain punch's.
static func melee_timing(pose: StringName) -> Dictionary:
	return MELEE.get(pose, MELEE_DEFAULT)


## Runs up to `target_global` and plays `pose`, then awaits the moment the hit
## connects, so the caller can deal the damage and spawn effects right then.
## Returns the pose time still left to play after the impact.
## `strike_out()` must follow, or Bara stays next to the enemy.
func strike_in(target_global: Vector2, pose: StringName, pace := 1.0) -> float:
	var p := maxf(pace, 0.01)
	var t: Dictionary = melee_timing(pose)
	if _home == Vector2.INF:
		_home = position
	# Stop `reach` pixels short of the target, on the side Bara came from.
	var stop_global := target_global - Vector2(t["reach"], 0.0)
	var stop := position + (stop_global - global_position)
	stop.y = _home.y

	_kill_dash()
	_dash_tween = create_tween()
	_dash_tween.tween_property(self, "position", stop, t["dash_in"] * p) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# The name/HP label stays readable at home instead of riding along.
	_dash_tween.parallel().tween_property(_label, "modulate:a", 0.0, 0.06 * p)
	var sprite := get_node_or_null("Visual/Sprite2D") as Sprite2D
	if sprite != null:
		# Afterimages are spawned on the parent so they stay where they were drawn.
		for i in AFTERIMAGES:
			_dash_tween.parallel().tween_callback(BattleFx.afterimage.bind(get_parent(), sprite, p)) \
				.set_delay(t["dash_in"] * p * (float(i) / AFTERIMAGES))
	await _dash_tween.finished

	var length := play_pose(pose)
	var impact: float = minf(t["impact"], length if length > 0.0 else t["impact"])
	if impact > 0.0:
		await get_tree().create_timer(impact * p).timeout
	return maxf(length - impact, 0.0)


## Dash back to the resting spot. Awaitable.
func strike_out(pace := 1.0, after := 0.0) -> void:
	if _home == Vector2.INF:
		return
	var p := maxf(pace, 0.01)
	var t: Dictionary = melee_timing(current_pose)
	_kill_dash()
	_dash_tween = create_tween()
	if after > 0.0:
		_dash_tween.tween_interval(after * p)
	_dash_tween.tween_property(self, "position", _home, t["dash_out"] * p) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_dash_tween.tween_property(_label, "modulate:a", 1.0, 0.1 * p)
	await _dash_tween.finished


## Global point where hits against Bara land (used by effects).
func hit_point() -> Vector2:
	return _visual.global_position + Vector2(14, 20)


func _kill_dash() -> void:
	if _dash_tween != null and _dash_tween.is_valid():
		_dash_tween.kill()
