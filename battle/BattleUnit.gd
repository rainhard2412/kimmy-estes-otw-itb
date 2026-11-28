class_name BattleUnit
extends Node2D
## Shared by everything that fights on the battlefield: Bara/the WAHANA
## (PlayerUnit) and every enemy (EnemyUnit). It adds "poses": named animations
## that the battle plays at the right moments. You never touch code for this:
## you add an animation with the right NAME in the editor.
##
## HOW TO ADD ANIMATIONS (in the unit's own scene, e.g. battle/units/KapakUnit.tscn
## for the Kapak enemy, battle/PlayerUnit.tscn for Bara)
##   Option A, AnimationPlayer (works with a plain Sprite2D):
##     1. Add an AnimationPlayer child, name it  Anim  and tick
##        "Access as Unique Name" (right-click the node), so it shows as %Anim.
##     2. Create animations with the pose names below. To change the picture,
##        key the Sprite2D's `texture` property (and/or position, scale,
##        rotation, anything).
##   Option B, AnimatedSprite2D:
##     1. Add an AnimatedSprite2D named  Sprite  with "Access as Unique Name"
##        (%Sprite) and a SpriteFrames resource.
##     2. Create animations with the pose names below.
##   Anything you don't make still works: it gets a small built-in motion on
##   %Visual (lunge, shake, ...) so placeholders move. Make `fallback_motion`
##   false to turn that off once all your art is in.
##
## POSE NAMES (exact, lowercase)
##   idle      the resting pose, plays at the start and after any pose ends.
##             Set it to LOOP. Provide one if your other poses change the texture,
##             otherwise the unit stays on the last frame of the previous pose.
##   attack    this unit hits (an enemy's attack; Bara using a damage skill)
##   hurt      this unit got hit
##   block     Bara blocked a hit (GOOD / PERFECT block)
##   defend    Bara uses a defend skill      heal   Bara uses a heal-only skill
##   windup    an archer pulls its bow; HOLDS its last frame until the shot
##   stunned   an enemy flinches after a PERFECT block
##   die       an enemy is defeated; plays, then it fades out and is removed
## Bara's skills can name any pose of their own: see SkillData.pose.
##
## For sound effects or particles, connect to `pose_played` (one signal for
## every pose, from any unit).

signal pose_played(pose: StringName)

const IDLE := &"idle"
const ATTACK := &"attack"
const HURT := &"hurt"
const BLOCK := &"block"
const WINDUP := &"windup"
const STUNNED := &"stunned"
const DIE := &"die"
const DEFEND := &"defend"
const HEAL := &"heal"
## These poses stay on their last frame instead of returning to idle.
const HOLD: Array[StringName] = [WINDUP, DIE]

## Length in seconds of each built-in motion.
const MOTION_LENGTH := {
	&"idle": 0.1, &"attack": 0.3, &"hurt": 0.2, &"block": 0.3, &"windup": 0.15,
	&"stunned": 0.4, &"die": 0.3, &"defend": 0.3, &"heal": 0.3,
}

## true = poses without art get a small built-in motion on %Visual.
@export var fallback_motion := true
## How far (pixels) the built-in motions move the unit, e.g. the attack lunge.
## The direction comes from the unit type: Bara lunges right, enemies left.
@export var lunge_distance := 14.0

## The pose most recently started ("" before any).
var current_pose: StringName = &""

var _anim: AnimationPlayer
var _sprite_anim: AnimatedSprite2D
var _tween: Tween

@onready var _visual: Node2D = %Visual


func _ready() -> void:
	play_pose(IDLE)


## True if this unit has its OWN animation for `pose` (not the built-in motion).
func has_art(pose: StringName) -> bool:
	_bind()
	return _art_length(pose) >= 0.0


## How long `pose` takes in seconds: your animation's length, or the built-in
## motion's. 0.0 if the unit can't show that pose at all.
func pose_length(pose: StringName) -> float:
	_bind()
	var length := _art_length(pose)
	if length >= 0.0:
		return length
	if fallback_motion and MOTION_LENGTH.has(pose):
		return float(MOTION_LENGTH[pose])
	return 0.0


## Play a pose. Returns its length in seconds, or 0.0 if the unit has no such
## pose (then nothing happens, and that is not an error). Poses return to idle
## by themselves when they finish, except the HOLD ones.
func play_pose(pose: StringName) -> float:
	_bind()
	if pose == IDLE and current_pose == IDLE:
		return pose_length(IDLE)
	var length := _art_length(pose)
	if length >= 0.0:
		_kill_motion()
		_start_art(pose)
	elif fallback_motion and MOTION_LENGTH.has(pose):
		length = _play_motion(pose)
	else:
		return 0.0
	current_pose = pose
	pose_played.emit(pose)
	return length


# ------------------------------------------------------------------ your animations

# Looks the animation nodes up (again, until found). Connects "finished" once.
func _bind() -> void:
	if _anim == null:
		_anim = get_node_or_null("%Anim") as AnimationPlayer
		if _anim != null:
			_anim.animation_finished.connect(_on_anim_finished)
	if _sprite_anim == null:
		_sprite_anim = get_node_or_null("%Sprite") as AnimatedSprite2D
		if _sprite_anim != null:
			_sprite_anim.animation_finished.connect(_on_sprite_finished)


# Length of the artist's animation for `pose`, or -1.0 if there is none.
func _art_length(pose: StringName) -> float:
	if _anim != null and _anim.has_animation(pose):
		return _anim.get_animation(pose).length
	if _sprite_anim != null and _sprite_anim.sprite_frames != null \
			and _sprite_anim.sprite_frames.has_animation(pose):
		var frames := _sprite_anim.sprite_frames
		return frames.get_frame_count(pose) / maxf(frames.get_animation_speed(pose), 0.01)
	return -1.0


func _start_art(pose: StringName) -> void:
	if _anim != null and _anim.has_animation(pose):
		if _anim.current_animation == pose:
			_anim.stop()   # play() would just continue a pose that is already running
		_anim.play(pose)
	else:
		if _sprite_anim.animation == pose:
			_sprite_anim.stop()
		_sprite_anim.play(pose)


func _on_anim_finished(anim_name: StringName) -> void:
	_back_to_idle(anim_name)


func _on_sprite_finished() -> void:
	_back_to_idle(current_pose)


func _back_to_idle(finished: StringName) -> void:
	# Ignore idle itself, the hold poses, and a stale signal from a pose that
	# was already replaced by a newer one.
	if finished == IDLE or finished in HOLD or finished != current_pose:
		return
	play_pose(IDLE)


# ------------------------------------------------------------------ built-in motion

func _play_motion(pose: StringName) -> float:
	var length: float = MOTION_LENGTH[pose]
	_kill_motion()
	if _visual == null:
		return length
	var l := _lunge()
	_tween = create_tween()
	match pose:
		ATTACK:
			_tween.tween_property(_visual, "position", l, 0.1)
			_tween.tween_property(_visual, "position", Vector2.ZERO, 0.2)
		HURT:
			_tween.tween_property(_visual, "position", -l * 0.3, 0.05)
			_tween.tween_property(_visual, "position", l * 0.15, 0.05)
			_tween.tween_property(_visual, "position", Vector2.ZERO, 0.1)
		BLOCK, DEFEND:
			_tween.tween_property(_visual, "position", -l * 0.2, 0.08)
			_tween.tween_interval(0.12)
			_tween.tween_property(_visual, "position", Vector2.ZERO, 0.1)
		WINDUP:
			_tween.tween_property(_visual, "position", -l * 0.35, 0.15)
		STUNNED:
			_tween.tween_property(_visual, "position", l * 0.2, 0.1)
			_tween.tween_property(_visual, "position", -l * 0.2, 0.1)
			_tween.tween_property(_visual, "position", l * 0.2, 0.1)
			_tween.tween_property(_visual, "position", Vector2.ZERO, 0.1)
		DIE:
			_tween.set_parallel(true)
			_tween.tween_property(_visual, "rotation", 0.6, 0.3)
			_tween.tween_property(_visual, "position:y", 8.0, 0.3)
		HEAL:
			_tween.tween_property(_visual, "position", Vector2(0, -6), 0.15)
			_tween.tween_property(_visual, "position", Vector2.ZERO, 0.15)
		_:   # IDLE: settle back to the resting spot
			_tween.set_parallel(true)
			_tween.tween_property(_visual, "position", Vector2.ZERO, 0.1)
			_tween.tween_property(_visual, "rotation", 0.0, 0.1)
	if pose != IDLE and not (pose in HOLD):
		_tween.finished.connect(_motion_done.bind(pose))
	return length


## The attack direction for the built-in motions (overridden by EnemyUnit).
func _lunge() -> Vector2:
	return Vector2(lunge_distance, 0.0)


func _motion_done(pose: StringName) -> void:
	if current_pose == pose:
		play_pose(IDLE)


func _kill_motion() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
