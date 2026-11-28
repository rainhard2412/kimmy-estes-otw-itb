extends Node2D
## Chapter 1 — opening cutscene in Bara's cabin, then free movement.
##
## Cutscene: eyes slowly blink awake -> door is slammed open -> eyes snap
## open -> camera zooms out from Bara and reveals Rehan in the corner ->
## dialogue -> gameplay.
##
## Asset belum ada: karakter pakai kotak placeholder, ruangan pakai
## RoomPlaceholder, suara dobrakan dibuat otomatis. Semua bisa diganti dari
## Inspector (lihat grup "Asset" di bawah) tanpa mengubah kode.

const REHAN_COLOR := Color(0.95, 0.55, 0.25)
const BARA_COLOR := Color(0.35, 0.55, 0.95)

@export_group("Asset (opsional)")
## Foto Bara di kotak dialog.
@export var bara_portrait: Texture2D
## Foto Rehan di kotak dialog.
@export var rehan_portrait: Texture2D
## Suara dobrakan pintu. Kosong = suara buatan sementara.
@export var door_sound: AudioStream

@export_group("Cutscene")
## Matikan untuk langsung main (berguna saat menguji map).
@export var play_cutscene := true
## Zoom kamera saat menyorot Bara dari dekat.
@export var closeup_zoom := 6.0
## Zoom kamera saat gameplay.
@export var gameplay_zoom := 1.5

@onready var _room: RoomPlaceholder = $Room
@onready var _bara: Chapter1Player = $Actors/Bara
@onready var _rehan: Node2D = $Actors/Rehan
@onready var _rehan_visual: ActorVisual = $Actors/Rehan/Visual
@onready var _camera: Camera2D = $Camera2D
@onready var _door_sfx: AudioStreamPlayer = $DoorSfx
@onready var _dialogue: DialogueBox = $DialogueBox
@onready var _eyes: ColorRect = $EyeLayer/Eyes
@onready var _objective: Control = $HUD/Objective

var _eye_mat: ShaderMaterial
var _following := false
var _shake := 0.0
var _bara_stand_pos: Vector2
var _rehan_corner_pos: Vector2


func _ready() -> void:
	_eye_mat = _eyes.material
	_door_sfx.stream = door_sound if door_sound else _make_door_sfx()
	_objective.hide()
	_bara_stand_pos = _bara.position
	_rehan_corner_pos = _rehan.position
	_dialogue.line_started.connect(_on_line_started)

	if play_cutscene:
		_run_cutscene()
	else:
		_eyes.hide()
		_start_gameplay()


func _process(delta: float) -> void:
	_camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake if _shake > 0.0 else Vector2.ZERO
	if _following:
		_camera.global_position = _camera.global_position.lerp(
			_bara.global_position + Vector2(0, -8), 1.0 - exp(-delta * 6.0))


# ------------------------------------------------------------------ cutscene

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout


func _eyes_to(open: float, dur: float, trans := Tween.TRANS_SINE) -> void:
	var t := create_tween()
	t.tween_property(_eye_mat, "shader_parameter/open", open, dur) \
		.set_trans(trans).set_ease(Tween.EASE_IN_OUT)
	await t.finished


func _run_cutscene() -> void:
	# Bara asleep in bed, camera right on his face.
	_bara.can_move = false
	_bara.position = _room.bed_rect.position + Vector2(28, _room.bed_rect.size.y * 0.5)
	_bara.visual.rotation = -PI / 2.0
	_bara.visual.eyes_closed = true
	_bara.get_node("Collision").disabled = true
	_rehan.hide()

	_camera.zoom = Vector2.ONE * closeup_zoom
	_camera.global_position = _bara.global_position + Vector2(-10, 0)
	_eye_mat.set_shader_parameter("open", 0.0)
	_eye_mat.set_shader_parameter("blur", 4.0)
	_eyes.show()

	await _wait(1.2)

	# Slow, heavy blinks.
	await _eyes_to(0.16, 1.3)
	await _wait(0.35)
	await _eyes_to(0.0, 0.7)
	await _wait(0.8)
	await _eyes_to(0.38, 1.1)
	_tween(_eye_mat, "shader_parameter/blur", 2.5, 0.8)
	await _wait(0.25)
	await _eyes_to(0.04, 0.55)
	await _wait(0.45)

	# BRAKK! Door gets kicked open.
	_door_sfx.play()
	_shake = 4.0
	_tween(self, "_shake", 0.0, 0.5)
	_tween(_room, "door_open", 1.0, 0.08)
	_rehan.show()
	_rehan.position = _room.door_rect.get_center() + Vector2(0, 10)
	_tween(_rehan, "position", _rehan_corner_pos, 0.45, Tween.TRANS_QUAD)

	# Eyes snap open in shock.
	_bara.visual.eyes_closed = false
	_tween(_eye_mat, "shader_parameter/blur", 0.0, 0.7)
	await _eyes_to(1.0, 0.3, Tween.TRANS_EXPO)
	_bara.visual.label = "!"
	_hop(_bara.visual, 3.0)
	await _wait(0.8)
	_bara.visual.label = ""
	_eyes.hide()

	# Zoom out: reveal the room and Rehan in the corner.
	var room_center := _room.position + _room.room_size * 0.5
	var view := get_viewport_rect().size
	var fit := minf(view.x / _room.room_size.x, view.y / _room.room_size.y)
	_tween(_camera, "zoom", Vector2.ONE * fit, 1.8, Tween.TRANS_CUBIC)
	await _tween(_camera, "global_position", room_center, 1.8, Tween.TRANS_CUBIC).finished
	await _wait(0.3)

	_rehan_visual.facing = (_bara.global_position - _rehan.global_position).normalized()
	_hop(_rehan_visual, 3.0)
	_rehan_visual.label = "!!"

	await _dialogue.play([
		{"name": "REHAN", "color": REHAN_COLOR, "portrait": rehan_portrait,
			"text": "BAR BANGUN BAR......"},
		{"name": "REHAN", "color": REHAN_COLOR, "portrait": rehan_portrait,
			"text": "Ngapain masih tidur, itu loh ventilasi kapal kotor banget, mambu pesing, bersihin sana!"},
		{"name": "BARA", "color": BARA_COLOR, "portrait": bara_portrait,
			"text": "Iya iya, aku bersihin sekarang.", "action": "get_up"},
		{"name": "BARA", "color": BARA_COLOR, "portrait": bara_portrait, "thought": true,
			"text": "Mimpi apa aku barusan..."},
	])

	_start_gameplay()


func _on_line_started(_index: int, line: Dictionary) -> void:
	_rehan_visual.label = ""
	if line.get("action") == "get_up":
		_bara_get_up()


func _bara_get_up() -> void:
	var t := create_tween().set_parallel(true)
	t.tween_property(_bara.visual, "rotation", 0.0, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(_bara, "position", _bara_stand_pos, 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hop(_bara.visual, 4.0)
	_bara.visual.facing = (_rehan.global_position - _bara_stand_pos).normalized()


func _start_gameplay() -> void:
	_bara.position = _bara_stand_pos
	_bara.visual.rotation = 0.0
	_bara.visual.eyes_closed = false
	_bara.get_node("Collision").disabled = false
	_rehan.show()
	_rehan.position = _rehan_corner_pos
	_room.door_open = 1.0

	await _tween(_camera, "zoom", Vector2.ONE * gameplay_zoom, 0.6, Tween.TRANS_CUBIC).finished
	_camera.limit_left = int(_room.position.x)
	_camera.limit_top = int(_room.position.y)
	_camera.limit_right = int(_room.position.x + _room.room_size.x)
	_camera.limit_bottom = int(_room.position.y + _room.room_size.y)
	_following = true
	_bara.can_move = true

	_objective.show()
	_objective.modulate.a = 0.0
	_objective.position.x = -40.0
	var t := create_tween().set_parallel(true)
	t.tween_property(_objective, "modulate:a", 1.0, 0.4)
	t.tween_property(_objective, "position:x", 0.0, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ helpers

func _tween(node: Object, prop: String, value: Variant, dur: float, trans := Tween.TRANS_QUAD) -> Tween:
	var t := create_tween()
	t.tween_property(node, prop, value, dur).set_trans(trans).set_ease(Tween.EASE_IN_OUT)
	return t


func _hop(node: Node2D, height: float) -> void:
	var base := node.position
	var t := create_tween()
	t.tween_property(node, "position", base + Vector2(0, -height), 0.1).set_ease(Tween.EASE_OUT)
	t.tween_property(node, "position", base, 0.14).set_ease(Tween.EASE_IN)


## Temporary "BRAKK!" — a low thud plus a short rattle, synthesized at load.
func _make_door_sfx() -> AudioStreamWAV:
	const RATE := 22050
	const LENGTH := 0.7
	var n := int(RATE * LENGTH)
	var data := PackedByteArray()
	data.resize(n * 2)
	var lp := 0.0
	for i in n:
		var t := float(i) / RATE
		lp = lerpf(lp, randf_range(-1.0, 1.0), 0.35)  # darker noise
		var s := 0.0
		s += sin(TAU * 55.0 * t) * exp(-t * 9.0) * 0.9           # body thud
		s += lp * exp(-t * 22.0) * 1.2                            # crack
		var t2 := t - 0.11                                         # door hits the wall
		if t2 > 0.0:
			s += sin(TAU * 80.0 * t2) * exp(-t2 * 14.0) * 0.5
			s += lp * exp(-t2 * 30.0) * 0.6
		var t3 := t - 0.2                                          # rattle
		if t3 > 0.0:
			s += lp * exp(-t3 * 10.0) * 0.25 * absf(sin(TAU * 18.0 * t3))
		data.encode_s16(i * 2, int(clampf(s * 0.8, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = data
	return wav
