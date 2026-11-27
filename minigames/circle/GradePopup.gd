class_name GradePopup
extends Label
## The little "PERFECT / GOOD / MISS" text that floats up from a hit circle,
## then removes itself.
##
## Look: edit minigames/circle/GradePopup.tscn (font, outline) and the exports
## below (texts, colors, how far it rises, how long it lives).

@export var perfect_text := "PERFECT"
@export var good_text := "GOOD"
@export var miss_text := "MISS"
@export var perfect_color := Color(0.3, 1.0, 0.45)
@export var good_color := Color(0.95, 0.85, 0.3)
@export var miss_color := Color(1.0, 0.4, 0.4)
@export var rise_pixels := 16.0
@export var lifetime := 0.5


## `grade` is a TimingBar.Result. `center` is in the parent's coordinates.
func show_grade(grade: int, center: Vector2) -> void:
	var col := miss_color
	text = miss_text
	match grade:
		TimingBar.Result.PERFECT:
			col = perfect_color
			text = perfect_text
		TimingBar.Result.GOOD:
			col = good_color
			text = good_text
	add_theme_color_override("font_color", col)
	position = center + Vector2(-custom_minimum_size.x / 2.0, -14.0)
	var t := create_tween().set_parallel(true)
	t.tween_property(self, "position:y", position.y - rise_pixels, lifetime)
	t.tween_property(self, "modulate:a", 0.0, lifetime)
	t.chain().tween_callback(queue_free)
