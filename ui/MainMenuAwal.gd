extends Control
## Main menu.
##
## Flow:
##   IDLE      animated starfield + logo, START pulses, icon buttons react to hover
##   MODE      mode cards pop in under the logo
##   SHIP_IN   chosen card flashes, logo fades away, the ship flies in
##   READY     "click / press SPACE to launch" — ESC goes back to the mode cards
##   LAUNCHING ship charges up, then jumps to hyperspace -> battle scene

const BATTLE_SCENE := "res://battle/Battle.tscn"

const TIPS := [
	"TIP: Tekan X tepat di zona hijau untuk PERFECT BLOCK.",
	"TIP: Perfect Block bikin musuh kaget — kamu dapat 2 aksi!",
	"TIP: Skill dengan cooldown tetap terkunci selama beberapa giliran.",
	"TIP: Di Story Mode kamu tidak akan game over. Haikal selalu siap membantu.",
	"TIP: Di Endless Mode, bertahanlah selama mungkin dan cetak skor tertinggi!",
]

const CARD_IDLE := Color(0.72, 0.72, 0.8)
const CARD_FOCUS := Color(1.15, 1.15, 1.2)

enum Phase { IDLE, MODE, SHIP_IN, READY, LAUNCHING }

@export_group("Art (opsional)")
## Ganti artwork background dari Inspector.
@export var background_texture: Texture2D
## Artwork karakter di sisi kanan (PNG transparan).
@export var character_texture: Texture2D
## Ganti logo INNERSIA dari Inspector.
@export var logo_texture: Texture2D

@export_group("Tombol Mode (opsional)")
## Gambar tombol Story Mode. Kalau diisi, teks bawaan tombol disembunyikan.
@export var story_button_texture: Texture2D
## Gambar Story Mode saat disorot mouse (opsional).
@export var story_button_hover_texture: Texture2D
## Gambar tombol Endless Mode. Kalau diisi, teks bawaan tombol disembunyikan.
@export var endless_button_texture: Texture2D
## Gambar Endless Mode saat disorot mouse (opsional).
@export var endless_button_hover_texture: Texture2D

@export_group("Pesawat (opsional)")
## Gambar pesawat (tampak belakang, PNG transparan). Kosong = pesawat bawaan.
@export var ship_texture: Texture2D

@onready var _background: TextureRect = $Background
@onready var _shade: ColorRect = $BackgroundShade
@onready var _starfield := $Starfield as MenuStarfield
@onready var _character: TextureRect = $CharacterArt
@onready var _judul: TextureRect = $Judul
@onready var _top_right: VBoxContainer = $TopRightMenu
@onready var _start_area: Control = $StartArea
@onready var _start_button: TextureButton = $StartArea/StartButton
@onready var _footer: Label = $Footer

@onready var _settings_button: TextureButton = $TopRightMenu/SettingsButton
@onready var _credits_button: TextureButton = $TopRightMenu/CreditsButton
@onready var _quit_button: TextureButton = $TopRightMenu/QuitButton

@onready var _ship := $Ship as MenuShip
@onready var _launch_ui: Control = $LaunchUI
@onready var _launch_mode: Label = $LaunchUI/ModeName
@onready var _launch_prompt: Label = $LaunchUI/Prompt
@onready var _launch_tip: Label = $LaunchUI/Tip

@onready var _mode_panel: Control = $ModePanel
@onready var _mode_dim: ColorRect = $ModePanel/Dim
@onready var _mode_title: Label = $ModePanel/PanelTitle
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

var _phase := Phase.IDLE
var _tweens: Dictionary = {}
var _bg_tweens: Array[Tween] = []
var _pulse_tween: Tween
var _prompt_tween: Tween

var _t := 0.0
var _mouse := Vector2.ZERO
## Camera shake strength in pixels; tweened during the launch.
var _shake := 0.0
var _judul_base_pos: Vector2
var _judul_base_scale: Vector2
var _start_base_scale: Vector2


func _ready() -> void:
	_apply_art()
	_skin_card(_story_button, story_button_texture, story_button_hover_texture)
	_skin_card(_endless_button, endless_button_texture, endless_button_hover_texture)
	_setup_start_click_mask()
	if ship_texture:
		_ship.texture = ship_texture

	_mode_panel.hide()
	_settings_panel.hide()
	_credits_panel.hide()
	_ship.hide()
	_launch_ui.hide()

	# Logo and START are scaled-down nodes with a (0, 0) pivot. Move the pivot
	# to their centre and compensate the position so they look identical but
	# zoom around their middle.
	_judul.pivot_offset = _judul.size / 2.0
	_judul.position -= _judul.pivot_offset * (Vector2.ONE - _judul.scale)
	_judul_base_pos = _judul.position
	_judul_base_scale = _judul.scale
	_start_area.pivot_offset = _start_area.size / 2.0
	_start_area.position -= _start_area.pivot_offset * (Vector2.ONE - _start_area.scale)
	_start_base_scale = _start_area.scale

	# Image buttons are mouse-driven; the panels keep keyboard support.
	for b in [_start_button, _settings_button, _credits_button, _quit_button]:
		b.focus_mode = Control.FOCUS_NONE
	_start_button.mouse_entered.connect(_on_start_hover.bind(true))
	_start_button.mouse_exited.connect(_on_start_hover.bind(false))
	for b in [_settings_button, _credits_button, _quit_button]:
		b.mouse_entered.connect(_on_icon_hover.bind(b, true))
		b.mouse_exited.connect(_on_icon_hover.bind(b, false))
	for b in [_story_button, _endless_button]:
		# Hover == focus, so mouse and keyboard share one highlight.
		b.mouse_entered.connect(_focus_card.bind(b))
		b.focus_entered.connect(_on_card_focus.bind(b, true))
		b.focus_exited.connect(_on_card_focus.bind(b, false))
	for b in [_mode_back_button, _settings_back_button, _credits_back_button]:
		b.mouse_entered.connect(_on_small_hover.bind(b, true))
		b.mouse_exited.connect(_on_small_hover.bind(b, false))

	_start_button.pressed.connect(_on_start_pressed)
	_story_button.pressed.connect(_choose_mode.bind(true))
	_endless_button.pressed.connect(_choose_mode.bind(false))
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
	for n in [_judul, _top_right, _start_area, _footer]:
		n.modulate.a = 0.0

	# Layout is only final after a frame; pivots are needed for the effects.
	await get_tree().process_frame
	_update_pivots()
	_play_intro()
	_start_background_drift()
	_start_button_pulse()


func _update_pivots() -> void:
	_background.pivot_offset = _background.size / 2.0
	_character.pivot_offset = Vector2(_character.size.x / 2.0, _character.size.y)
	_ship.pivot_offset = _ship.size / 2.0
	for c: Control in [
		_settings_button, _credits_button, _quit_button,
		_story_button, _endless_button, _mode_back_button,
		_settings_back_button, _credits_back_button,
		_settings_panel.get_node("Panel"), _credits_panel.get_node("Panel"),
	]:
		c.pivot_offset = c.size / 2.0
	# Logo / StartArea pivots are set once in _ready (their size never changes).


func _process(delta: float) -> void:
	_t += delta

	# Mouse parallax: everything leans slightly away from the cursor.
	var target := Vector2.ZERO
	if _phase != Phase.LAUNCHING and size.x > 0.0 and size.y > 0.0:
		target = (get_local_mouse_position() / size - Vector2(0.5, 0.5)) * 2.0
		target = target.clamp(-Vector2.ONE, Vector2.ONE)
	_mouse = _mouse.lerp(target, 1.0 - exp(-delta * 3.0))

	var jitter := Vector2.ZERO
	if _shake > 0.0:
		jitter = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake

	_background.position = -_mouse * 5.0 + jitter
	_starfield.parallax = -_mouse * 12.0 + jitter * 2.0
	_judul.position = _judul_base_pos - _mouse * 3.0 + Vector2(0.0, sin(_t * 1.4) * 1.5)
	var glow := 1.0 + 0.1 * sin(_t * 2.0)
	_judul.self_modulate = Color(glow, glow, glow * 1.04)


# ------------------------------------------------------------------ setup

func _apply_art() -> void:
	if background_texture:
		_background.texture = background_texture
	if character_texture:
		_character.texture = character_texture
	if logo_texture:
		_judul.texture = logo_texture
	_character.visible = _character.texture != null


## Swap a mode card's built-in look for the artwork set in the Inspector.
func _skin_card(card: Button, normal: Texture2D, hover: Texture2D) -> void:
	if normal == null:
		return
	var n := StyleBoxTexture.new()
	n.texture = normal
	var h := n
	if hover:
		h = StyleBoxTexture.new()
		h.texture = hover
	card.add_theme_stylebox_override("normal", n)
	card.add_theme_stylebox_override("disabled", n)
	card.add_theme_stylebox_override("hover", h)
	card.add_theme_stylebox_override("pressed", h)
	card.add_theme_stylebox_override("hover_pressed", h)
	card.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for child in card.get_children():
		if child is CanvasItem:
			child.hide()


## START.png is a full 1920x1080 canvas with a transparent bar in the middle.
## Restrict clicks to the opaque bar so the empty canvas is not clickable.
func _setup_start_click_mask() -> void:
	if _start_button.texture_normal == null:
		return
	var img := _start_button.texture_normal.get_image()
	if img == null:
		return
	var mask := BitMap.new()
	mask.create_from_image_alpha(img)
	_start_button.texture_click_mask = mask


func _play_intro() -> void:
	_tween_to(_fade, "color:a", 0.0, 0.9)
	_judul.scale = _judul_base_scale * 1.12
	_tween_to(_judul, "scale", _judul_base_scale, 1.4, 0.15, Tween.TRANS_EXPO)
	_tween_to(_judul, "modulate:a", 1.0, 1.0, 0.15)
	_tween_to(_top_right, "modulate:a", 1.0, 0.6, 0.7)
	_tween_to(_start_area, "modulate:a", 1.0, 0.6, 0.9)
	_tween_to(_footer, "modulate:a", 1.0, 0.6, 1.0)


func _start_background_drift() -> void:
	for t in _bg_tweens:
		t.kill()
	_bg_tweens.clear()
	_background.scale = Vector2.ONE * 1.06
	_background.rotation = 0.0

	var zoom := create_tween().set_loops()
	zoom.tween_property(_background, "scale", Vector2.ONE * 1.12, 12.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	zoom.tween_property(_background, "scale", Vector2.ONE * 1.06, 12.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	var tilt := create_tween().set_loops()
	tilt.tween_property(_background, "rotation", deg_to_rad(0.5), 9.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tilt.tween_property(_background, "rotation", deg_to_rad(-0.5), 9.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	_bg_tweens = [zoom, tilt]


func _start_button_pulse() -> void:
	if _pulse_tween:
		_pulse_tween.kill()
	_start_button.self_modulate.a = 1.0
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.tween_property(_start_button, "self_modulate:a", 0.7, 1.2) \
		.set_trans(Tween.TRANS_SINE)
	_pulse_tween.tween_property(_start_button, "self_modulate:a", 1.0, 1.2) \
		.set_trans(Tween.TRANS_SINE)


## Tween one property, replacing any tween still running on the same property.
func _tween_to(
	node: Object, prop: String, value: Variant, dur: float, delay := 0.0,
	trans := Tween.TRANS_QUAD, ease_type := Tween.EASE_OUT
) -> Tween:
	var key := "%d:%s" % [node.get_instance_id(), prop]
	var old: Tween = _tweens.get(key)
	if old and old.is_valid():
		old.kill()
	var t := create_tween()
	t.tween_property(node, prop, value, dur).set_delay(delay) \
		.set_trans(trans).set_ease(ease_type)
	_tweens[key] = t
	return t


# ------------------------------------------------------------------ hover fx

func _on_start_hover(hovered: bool) -> void:
	if _phase != Phase.IDLE:
		return
	_tween_to(_start_area, "scale", _start_base_scale * (1.07 if hovered else 1.0),
		0.2, 0.0, Tween.TRANS_BACK)
	_tween_to(_start_button, "modulate",
		Color(1.3, 1.3, 1.35) if hovered else Color.WHITE, 0.15)


func _on_icon_hover(button: TextureButton, hovered: bool) -> void:
	_tween_to(button, "scale", Vector2.ONE * (1.18 if hovered else 1.0),
		0.18, 0.0, Tween.TRANS_BACK)
	_tween_to(button, "modulate", Color(1.35, 1.35, 1.4) if hovered else Color.WHITE, 0.12)
	if button == _settings_button:
		_tween_to(button, "rotation", deg_to_rad(90.0) if hovered else 0.0,
			0.4, 0.0, Tween.TRANS_CUBIC)


func _on_small_hover(button: Control, hovered: bool) -> void:
	_tween_to(button, "scale", Vector2.ONE * (1.08 if hovered else 1.0),
		0.15, 0.0, Tween.TRANS_BACK)


func _focus_card(card: Button) -> void:
	if _phase == Phase.MODE:
		card.grab_focus()


func _on_card_focus(card: Button, focused: bool) -> void:
	if _phase != Phase.MODE:
		return
	_tween_to(card, "scale", Vector2.ONE * (1.08 if focused else 1.0),
		0.2, 0.0, Tween.TRANS_BACK)
	_tween_to(card, "modulate", CARD_FOCUS if focused else CARD_IDLE, 0.15)


func _punch(node: Control) -> void:
	node.scale = Vector2.ONE * 0.9
	_tween_to(node, "scale", Vector2.ONE, 0.25, 0.0, Tween.TRANS_BACK)


# ------------------------------------------------------------------ menu flow

func _on_start_pressed() -> void:
	if _phase != Phase.IDLE or _settings_panel.visible or _credits_panel.visible:
		return
	_phase = Phase.MODE
	_start_button.disabled = true
	_start_button.modulate = Color.WHITE
	_start_area.scale = _start_base_scale

	var t := _tween_to(_start_area, "modulate:a", 0.0, 0.15)
	t.tween_callback(func(): if _phase != Phase.IDLE: _start_area.hide())
	_tween_to(_judul, "scale", _judul_base_scale * 0.88, 0.4, 0.0, Tween.TRANS_CUBIC)
	_tween_to(_top_right, "modulate:a", 0.0, 0.2)
	_top_right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for b in [_settings_button, _credits_button, _quit_button]:
		b.disabled = true
	_open_mode_panel()


func _open_mode_panel() -> void:
	_mode_panel.show()
	_tween_to(_mode_panel, "modulate:a", 1.0, 0.01)
	_mode_dim.modulate.a = 0.0
	_tween_to(_mode_dim, "modulate:a", 1.0, 0.3)
	_mode_title.modulate.a = 0.0
	_tween_to(_mode_title, "modulate:a", 1.0, 0.3, 0.05)
	_mode_back_button.modulate.a = 0.0
	_mode_back_button.scale = Vector2.ONE
	_tween_to(_mode_back_button, "modulate:a", 1.0, 0.3, 0.3)

	var cards := [_story_button, _endless_button]
	for i in cards.size():
		var card: Button = cards[i]
		card.scale = Vector2.ONE * 0.7
		card.modulate = Color(CARD_IDLE, 0.0)
		_tween_to(card, "scale", Vector2.ONE, 0.35, 0.08 + i * 0.08, Tween.TRANS_BACK)
		_tween_to(card, "modulate", CARD_IDLE, 0.25, 0.08 + i * 0.08)

	await get_tree().create_timer(0.45).timeout
	if _phase == Phase.MODE and get_viewport().gui_get_focus_owner() == null:
		_story_button.grab_focus()


func _close_mode_panel() -> void:
	if _phase != Phase.MODE:
		return
	_phase = Phase.IDLE
	get_viewport().gui_release_focus()

	var t := _tween_to(_mode_panel, "modulate:a", 0.0, 0.2)
	t.tween_callback(func(): if _phase == Phase.IDLE: _mode_panel.hide())

	_start_area.show()
	_start_button.disabled = false
	_tween_to(_start_area, "modulate:a", 1.0, 0.25, 0.1)
	_tween_to(_judul, "scale", _judul_base_scale, 0.4, 0.0, Tween.TRANS_CUBIC)
	_tween_to(_top_right, "modulate:a", 1.0, 0.25)
	_top_right.mouse_filter = Control.MOUSE_FILTER_PASS
	for b in [_settings_button, _credits_button, _quit_button]:
		b.disabled = false


func _open_panel(panel: Control) -> void:
	if _phase != Phase.IDLE:
		return
	panel.show()
	panel.modulate.a = 0.0
	_tween_to(panel, "modulate:a", 1.0, 0.15)
	var box: Control = panel.get_node("Panel")
	box.scale = Vector2.ONE * 0.85
	_tween_to(box, "scale", Vector2.ONE, 0.25, 0.0, Tween.TRANS_BACK)
	var back: Button = panel.get_node("Panel/BackButton")
	back.grab_focus()


func _close_panel(panel: Control) -> void:
	panel.hide()
	get_viewport().gui_release_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()


# ------------------------------------------------------------------ launch

## Mode picked: the card flashes, logo fades away, the ship flies in.
func _choose_mode(story: bool) -> void:
	if _phase != Phase.MODE:
		return
	_phase = Phase.SHIP_IN
	GameState.story_mode = story
	get_viewport().gui_release_focus()

	var chosen := _story_button if story else _endless_button
	var other := _endless_button if story else _story_button

	var punch := _tween_to(chosen, "scale", Vector2.ONE * 1.16, 0.08)
	punch.tween_property(chosen, "scale", Vector2.ONE * 1.04, 0.2) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var glow := _tween_to(chosen, "modulate", Color(1.8, 1.8, 1.9), 0.06)
	glow.tween_property(chosen, "modulate", CARD_FOCUS, 0.25)
	_tween_to(other, "modulate", Color(0.5, 0.5, 0.6, 0.0), 0.25)
	_tween_to(other, "scale", Vector2.ONE * 0.9, 0.25)

	await get_tree().create_timer(0.35).timeout

	_tween_to(_mode_panel, "modulate:a", 0.0, 0.3)
	# Title dissolves forward, as if the camera flies through it.
	_tween_to(_judul, "scale", _judul_base_scale * 1.35, 0.7, 0.0, Tween.TRANS_CUBIC, Tween.EASE_IN)
	_tween_to(_judul, "modulate:a", 0.0, 0.55, 0.1)
	_tween_to(_footer, "modulate:a", 0.0, 0.3)
	_tween_to(_starfield, "speed", 0.16, 1.2)

	await get_tree().create_timer(0.3).timeout
	_mode_panel.hide()
	await _ship_fly_in()

	_launch_mode.text = "STORY MODE" if story else "ENDLESS MODE"
	_launch_tip.text = TIPS.pick_random()
	_launch_ui.show()
	_launch_ui.modulate.a = 0.0
	_tween_to(_launch_ui, "modulate:a", 1.0, 0.35)
	if _prompt_tween:
		_prompt_tween.kill()
	_launch_prompt.modulate.a = 1.0
	_prompt_tween = create_tween().set_loops()
	_prompt_tween.tween_property(_launch_prompt, "modulate:a", 0.35, 0.7).set_trans(Tween.TRANS_SINE)
	_prompt_tween.tween_property(_launch_prompt, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)
	_phase = Phase.READY


func _ship_rest_position() -> Vector2:
	return size * Vector2(0.5, 0.6) - _ship.size * 0.5


func _ship_fly_in() -> void:
	var rest := _ship_rest_position()
	_ship.show()
	_ship.modulate.a = 1.0
	_ship.position = rest + Vector2(0.0, size.y * 0.75)
	_ship.scale = Vector2.ONE * 1.7
	_ship.thrust = 0.9
	_ship.shake = 0.0
	_ship.bob = 0.0

	var t := _tween_to(_ship, "position", rest, 0.9, 0.0, Tween.TRANS_EXPO)
	_tween_to(_ship, "scale", Vector2.ONE, 0.9, 0.0, Tween.TRANS_EXPO)
	_tween_to(_ship, "thrust", 0.35, 1.0, 0.3)
	_tween_to(_ship, "bob", 1.0, 0.8, 0.6)
	await t.finished


## READY -> back to the mode cards.
func _cancel_launch() -> void:
	if _phase != Phase.READY:
		return
	_phase = Phase.SHIP_IN
	if _prompt_tween:
		_prompt_tween.kill()
	var hide_ui := _tween_to(_launch_ui, "modulate:a", 0.0, 0.2)
	hide_ui.tween_callback(_launch_ui.hide)

	var away := _tween_to(_ship, "position", _ship_rest_position() + Vector2(0.0, size.y * 0.75),
		0.5, 0.0, Tween.TRANS_CUBIC, Tween.EASE_IN)
	_tween_to(_ship, "scale", Vector2.ONE * 1.7, 0.5, 0.0, Tween.TRANS_CUBIC, Tween.EASE_IN)
	_tween_to(_starfield, "speed", _starfield.idle_speed, 0.8)
	_tween_to(_judul, "scale", _judul_base_scale * 0.88, 0.5, 0.15, Tween.TRANS_CUBIC)
	_tween_to(_judul, "modulate:a", 1.0, 0.4, 0.15)
	_tween_to(_footer, "modulate:a", 1.0, 0.4, 0.15)
	await away.finished

	_ship.hide()
	_phase = Phase.MODE
	_open_mode_panel()


## The ship charges, then jumps to hyperspace straight into the screen.
func _launch() -> void:
	if _phase != Phase.READY:
		return
	_phase = Phase.LAUNCHING
	if _prompt_tween:
		_prompt_tween.kill()
	_tween_to(_launch_ui, "modulate:a", 0.0, 0.2)
	for t in _bg_tweens:
		t.kill()

	# 1) Charge up: engines flare, everything trembles, the stars hold still.
	const CHARGE := 0.7
	_tween_to(_ship, "thrust", 1.6, CHARGE, 0.0, Tween.TRANS_QUAD, Tween.EASE_IN)
	_tween_to(_ship, "shake", 1.3, CHARGE, 0.0, Tween.TRANS_QUAD, Tween.EASE_IN)
	_tween_to(_ship, "bob", 0.0, 0.3)
	_tween_to(_ship, "scale", Vector2.ONE * 1.08, CHARGE)
	_tween_to(_ship, "position", _ship_rest_position() + Vector2(0.0, 4.0), CHARGE)
	_tween_to(self, "_shake", 0.8, CHARGE, 0.0, Tween.TRANS_QUAD, Tween.EASE_IN)
	_tween_to(_starfield, "speed", 0.01, CHARGE)
	await get_tree().create_timer(CHARGE).timeout

	# 2) Jump: ship rockets toward the vanishing point, stars stretch into streaks.
	const JUMP := 1.4
	var vanish := size * _starfield.vanishing_point - _ship.size * 0.5
	_tween_to(_ship, "position", vanish, 0.9, 0.0, Tween.TRANS_QUART)
	_tween_to(_ship, "scale", Vector2.ONE * 0.03, 0.9, 0.0, Tween.TRANS_QUART)
	_tween_to(_ship, "shake", 0.0, 0.2)
	_tween_to(_ship, "thrust", 2.4, 0.15)
	_tween_to(_ship, "modulate:a", 0.0, 0.3, 0.6)

	_tween_to(_starfield, "speed", 6.0, JUMP, 0.0, Tween.TRANS_CUBIC, Tween.EASE_IN)
	_tween_to(_starfield, "warp", 1.0, 0.6)
	_tween_to(_background, "scale", Vector2.ONE * 2.6, JUMP, 0.0, Tween.TRANS_EXPO, Tween.EASE_IN)
	# Darken (not fade) — nothing is drawn behind the background.
	_tween_to(_background, "modulate", Color(0.08, 0.08, 0.16), 1.0, 0.1)
	_tween_to(_shade, "color:a", 0.6, 1.0)
	_tween_to(self, "_shake", 2.2, JUMP, 0.0, Tween.TRANS_QUAD, Tween.EASE_IN)

	# Small flash on departure, then a full white-out at the end of the jump.
	var pop := _tween_to(_flash, "color:a", 0.35, 0.05)
	pop.tween_property(_flash, "color:a", 0.0, 0.25)
	pop.tween_interval(JUMP - 0.55)
	pop.tween_property(_flash, "color:a", 1.0, 0.25)
	await pop.finished

	_shake = 0.0
	await get_tree().create_timer(0.1).timeout
	await SceneManager.change_scene(BATTLE_SCENE)


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

func _input(event: InputEvent) -> void:
	# The launch prompt accepts a click anywhere, so catch it before the GUI.
	if _phase != Phase.READY:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_cancel_launch()
	elif event.is_action_pressed("ui_accept") or (
		event is InputEventMouseButton and event.pressed
		and event.button_index == MOUSE_BUTTON_LEFT
	):
		get_viewport().set_input_as_handled()
		_launch()


func _unhandled_input(event: InputEvent) -> void:
	match _phase:
		Phase.IDLE:
			if event.is_action_pressed("ui_cancel"):
				if _settings_panel.visible:
					_close_panel(_settings_panel)
				elif _credits_panel.visible:
					_close_panel(_credits_panel)
				else:
					return
				get_viewport().set_input_as_handled()
			elif event.is_action_pressed("ui_accept"):
				if _settings_panel.visible or _credits_panel.visible:
					return
				_on_start_pressed()
				get_viewport().set_input_as_handled()
		Phase.MODE:
			if event.is_action_pressed("ui_cancel"):
				_close_mode_panel()
				get_viewport().set_input_as_handled()
