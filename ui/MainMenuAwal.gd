extends Control
## Main menu in the spirit of Honkai: Star Rail.
##
## The visual layout (INNERSIA logo, background, icon buttons, START image) is
## authored in MainMenuAwal.tscn. This script only wires the interactions:
## START -> mode picker -> flash/zoom/loading -> battle scene.

const BATTLE_SCENE := "res://battle/Battle.tscn"

const TIPS := [
	"TIP: Tekan X tepat di zona hijau untuk PERFECT BLOCK.",
	"TIP: Perfect Block bikin musuh kaget — kamu dapat 2 aksi!",
	"TIP: Skill dengan cooldown tetap terkunci selama beberapa giliran.",
	"TIP: Di Story Mode kamu tidak akan game over. Haikal selalu siap membantu.",
	"TIP: Di Endless Mode, bertahanlah selama mungkin dan cetak skor tertinggi!",
]

@export_group("Art (opsional)")
## Ganti artwork background dari Inspector.
@export var background_texture: Texture2D
## Artwork karakter di sisi kanan (PNG transparan).
@export var character_texture: Texture2D
## Ganti logo INNERSIA dari Inspector.
@export var logo_texture: Texture2D

@onready var _background: TextureRect = $Background
@onready var _character: TextureRect = $CharacterArt
@onready var _judul: TextureRect = $Judul
@onready var _top_right: VBoxContainer = $TopRightMenu
@onready var _start_area: Control = $StartArea
@onready var _start_button: TextureButton = $StartArea/StartButton
@onready var _footer: Label = $Footer

@onready var _settings_button: TextureButton = $TopRightMenu/SettingsButton
@onready var _credits_button: TextureButton = $TopRightMenu/CreditsButton
@onready var _quit_button: TextureButton = $TopRightMenu/QuitButton

@onready var _mode_panel: Control = $ModePanel
@onready var _story_button: Button = $ModePanel/StoryButton
@onready var _endless_button: Button = $ModePanel/EndlessButton
@onready var _mode_back_button: Button = $ModePanel/BackButton

@onready var _settings_panel: Control = $SettingsPanel
@onready var _settings_back_button: Button = $SettingsPanel/Panel/BackButton
@onready var _volume_slider: HSlider = $SettingsPanel/Panel/VolumeSlider
@onready var _fullscreen_check: CheckButton = $SettingsPanel/Panel/FullscreenCheck

@onready var _credits_panel: Control = $CreditsPanel
@onready var _credits_back_button: Button = $CreditsPanel/Panel/BackButton

@onready var _flash: ColorRect = $Transition/Flash
@onready var _fade: ColorRect = $Transition/Fade
@onready var _loading: Control = $Transition/Loading
@onready var _loading_bar: ColorRect = $Transition/Loading/LoadingBar
@onready var _loading_tip: Label = $Transition/Loading/Tip

var _transitioning := false
var _bg_tween: Tween
var _pulse_tween: Tween
var _menu_fade: Tween
var _hover_tweens: Dictionary = {}


func _ready() -> void:
	_apply_art()
	_setup_start_click_mask()
	_mode_panel.hide()
	_settings_panel.hide()
	_credits_panel.hide()
	_loading.hide()

	# The image buttons are mouse-driven; the mode/settings panels keep keyboard
	# support through their normal Button nodes.
	for b in [_start_button, _settings_button, _credits_button, _quit_button]:
		b.focus_mode = Control.FOCUS_NONE
		b.mouse_entered.connect(_on_hover.bind(b, true))
		b.mouse_exited.connect(_on_hover.bind(b, false))

	_start_button.pressed.connect(_on_start_pressed)
	_story_button.pressed.connect(_start_mode.bind(true))
	_endless_button.pressed.connect(_start_mode.bind(false))
	_mode_back_button.pressed.connect(_close_mode_panel)

	_settings_button.pressed.connect(_open_panel.bind(_settings_panel))
	_credits_button.pressed.connect(_open_panel.bind(_credits_panel))
	_quit_button.pressed.connect(_on_quit_pressed)
	_settings_back_button.pressed.connect(_close_panel.bind(_settings_panel))
	_credits_back_button.pressed.connect(_close_panel.bind(_credits_panel))

	_volume_slider.value_changed.connect(_on_volume_changed)
	_fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	_volume_slider.value = 100.0

	resized.connect(_update_pivots)

	_flash.color.a = 0.0
	_fade.color.a = 1.0
	create_tween().tween_property(_fade, "color:a", 0.0, 0.6)

	# Layout is only final after a frame; pivots are needed for the zoom effect.
	await get_tree().process_frame
	_update_pivots()
	_start_background_drift()
	_start_button_pulse()


func _update_pivots() -> void:
	_background.pivot_offset = _background.size / 2.0
	_character.pivot_offset = Vector2(_character.size.x / 2.0, _character.size.y)
	# StartButton keeps its authored pivot (0, 0): it is scaled down heavily,
	# so moving the pivot to its center would shift the whole image off-screen.


# ------------------------------------------------------------------ setup

func _apply_art() -> void:
	if background_texture:
		_background.texture = background_texture
	if character_texture:
		_character.texture = character_texture
	if logo_texture:
		_judul.texture = logo_texture
	_character.visible = _character.texture != null


## START.png is a full 1920x1080 canvas with a transparent bar in the middle.
## Restrict clicks to the opaque bar so the copyright line is not clickable.
func _setup_start_click_mask() -> void:
	if _start_button.texture_normal == null:
		return
	var img := _start_button.texture_normal.get_image()
	if img == null:
		return
	var mask := BitMap.new()
	mask.create_from_image_alpha(img)
	_start_button.texture_click_mask = mask


func _start_background_drift() -> void:
	if _bg_tween:
		_bg_tween.kill()
	_background.scale = Vector2.ONE
	_bg_tween = create_tween().set_loops()
	_bg_tween.tween_property(_background, "scale", Vector2(1.05, 1.05), 14.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_bg_tween.tween_property(_background, "scale", Vector2.ONE, 14.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _start_button_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	_start_button.self_modulate.a = 1.0
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_start_button, "self_modulate:a", 0.78, 1.5) \
		.set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_start_button, "self_modulate:a", 1.0, 1.5) \
		.set_trans(Tween.TRANS_SINE)


func _on_hover(button: BaseButton, hovered: bool) -> void:
	if _hover_tweens.has(button):
		_hover_tweens[button].kill()
	var t := create_tween()
	t.tween_property(
		button, "modulate", Color(1.22, 1.22, 1.22) if hovered else Color.WHITE, 0.12
	)
	_hover_tweens[button] = t


# ------------------------------------------------------------------ menu flow

func _on_start_pressed() -> void:
	if _transitioning:
		return
	_start_button.disabled = true
	_start_area.hide()
	_mode_panel.show()
	_mode_panel.modulate.a = 0.0
	create_tween().tween_property(_mode_panel, "modulate:a", 1.0, 0.22)
	_fade_menu_backdrop(0.0)
	_story_button.grab_focus()


func _close_mode_panel() -> void:
	if _transitioning:
		return
	_mode_panel.hide()
	_start_area.show()
	_start_button.disabled = false
	_fade_menu_backdrop(1.0)


func _fade_menu_backdrop(alpha: float) -> void:
	if _menu_fade:
		_menu_fade.kill()
	_menu_fade = create_tween().set_parallel(true)
	_menu_fade.tween_property(_judul, "modulate:a", alpha, 0.2)
	_menu_fade.tween_property(_top_right, "modulate:a", alpha, 0.2)


func _open_panel(panel: Control) -> void:
	if _transitioning:
		return
	panel.show()
	panel.modulate.a = 0.0
	create_tween().tween_property(panel, "modulate:a", 1.0, 0.15)
	var back: Button = panel.get_node("Panel/BackButton")
	back.grab_focus()


func _close_panel(panel: Control) -> void:
	panel.hide()


func _on_quit_pressed() -> void:
	get_tree().quit()


# ------------------------------------------------------------------ mode start

func _start_mode(story: bool) -> void:
	if _transitioning:
		return
	_transitioning = true
	GameState.story_mode = story
	if _menu_fade:
		_menu_fade.kill()
	for b in _all_buttons():
		b.disabled = true
	await _play_entry_animation()
	await SceneManager.change_scene(BATTLE_SCENE)


func _all_buttons() -> Array[BaseButton]:
	var out: Array[BaseButton] = []
	out.append(_start_button)
	out.append(_settings_button)
	out.append(_credits_button)
	out.append(_quit_button)
	out.append(_story_button)
	out.append(_endless_button)
	out.append(_mode_back_button)
	out.append(_settings_back_button)
	out.append(_credits_back_button)
	return out


## HSR-ish entrance: UI fades, white flash, background/character zoom, then a
## black loading screen before the battle scene loads.
func _play_entry_animation() -> void:
	var fade_ui := create_tween().set_parallel(true)
	fade_ui.tween_property(_mode_panel, "modulate:a", 0.0, 0.15)
	fade_ui.tween_property(_top_right, "modulate:a", 0.0, 0.15)
	fade_ui.tween_property(_judul, "modulate:a", 0.0, 0.15)
	fade_ui.tween_property(_footer, "modulate:a", 0.0, 0.15)
	await fade_ui.finished

	if _bg_tween:
		_bg_tween.kill()
	_update_pivots()

	var flash := create_tween()
	flash.tween_property(_flash, "color:a", 0.9, 0.09)
	flash.tween_property(_flash, "color:a", 0.0, 0.32)

	var zoom := create_tween().set_parallel(true)
	zoom.tween_property(_background, "scale", Vector2(1.16, 1.16), 0.6) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _character.visible:
		zoom.tween_property(_character, "scale", Vector2(1.12, 1.12), 0.6) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await get_tree().create_timer(0.34).timeout

	_loading.show()
	_loading.modulate.a = 0.0
	_loading_tip.text = TIPS.pick_random()
	_loading_bar.offset_right = _loading_bar.offset_left

	var to_black := create_tween().set_parallel(true)
	to_black.tween_property(_fade, "color:a", 1.0, 0.4)
	to_black.tween_property(_loading, "modulate:a", 1.0, 0.4)
	create_tween().tween_property(
		_loading_bar, "offset_right", _loading_bar.offset_left + 120.0, 1.2
	)

	await to_black.finished
	await get_tree().create_timer(0.9).timeout


# ------------------------------------------------------------------ settings

func _on_volume_changed(value: float) -> void:
	var linear := value / 100.0
	AudioServer.set_bus_mute(0, linear <= 0.001)
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(linear, 0.001)))


func _on_fullscreen_toggled(on: bool) -> void:
	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	)


# ------------------------------------------------------------------ input

func _unhandled_input(event: InputEvent) -> void:
	if _transitioning:
		return
	if event.is_action_pressed("ui_cancel"):
		if _settings_panel.visible:
			_close_panel(_settings_panel)
		elif _credits_panel.visible:
			_close_panel(_credits_panel)
		elif _mode_panel.visible:
			_close_mode_panel()
		else:
			return
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_accept"):
		if _settings_panel.visible or _credits_panel.visible or _mode_panel.visible:
			return
		_on_start_pressed()
		get_viewport().set_input_as_handled()
