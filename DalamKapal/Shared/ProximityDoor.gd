class_name ProximityDoor
extends Node2D
## A door that opens on its own as someone walks up to it.
##
## Reusable: the three textures, the detection distances and the collision size are all
## exported, so this one script serves every door in the ship. Nothing here is specific
## to the ventilation room.
##
## How it decides which state to show, using the closest body in range:
##   distance > near_distance      -> CLOSED   (closed_texture)
##   half_distance < d <= near_dist -> HALF     (half_texture)
##   distance <= half_distance     -> OPEN     (open_texture, collision off)
##
## Detection uses a single Area2D sized to near_distance, so bodies are only tracked
## while they are nearby. Which bodies count is set by detect_layers.

signal state_changed(state: State)
## Fires the moment the door becomes fully open, i.e. walkable.
signal opened
## Fires when the door shuts completely.
signal closed

enum State { CLOSED, HALF, OPEN }

@export_group("Textures")
@export var closed_texture: Texture2D:
	set(value):
		closed_texture = value
		_refresh_texture()
@export var half_texture: Texture2D:
	set(value):
		half_texture = value
		_refresh_texture()
@export var open_texture: Texture2D:
	set(value):
		open_texture = value
		_refresh_texture()

@export_group("Detection")
## Within this distance the door opens half way. Also the size of the detection area.
@export var near_distance := 56.0:
	set(value):
		near_distance = maxf(value, 1.0)
		_refresh_detector()
## Within this distance the door opens fully and lets the body pass.
@export var half_distance := 26.0:
	set(value):
		half_distance = maxf(value, 0.0)
## Physics layers the door reacts to. Layer 1 by default, same as the player.
@export_flags_2d_physics var detect_layers := 1:
	set(value):
		detect_layers = value
		_refresh_detector()

@export_group("Blocking")
## Size of the wall the door puts up while it is not fully open.
@export var block_size := Vector2(64, 16):
	set(value):
		block_size = value
		_refresh_block()
## Where that wall sits relative to the door's origin.
@export var block_offset := Vector2.ZERO:
	set(value):
		block_offset = value
		_refresh_block()
## False leaves the door permanently passable, for decorative doors.
@export var blocks_when_closed := true:
	set(value):
		blocks_when_closed = value
		_apply_state()

@export_group("Behaviour")
## Seconds the door waits before shutting once everyone has walked away.
@export var close_delay := 0.35
## Locked doors stay shut no matter who approaches.
@export var locked := false:
	set(value):
		locked = value
		if is_node_ready():
			_evaluate(true)

var state := State.CLOSED

var _sprite: Sprite2D
var _detector: Area2D
var _detector_shape: CollisionShape2D
var _blocker: StaticBody2D
var _blocker_shape: CollisionShape2D
var _clear_time := 0.0


func _ready() -> void:
	_build_nodes()
	_refresh_detector()
	_refresh_block()
	_apply_state()


func _process(delta: float) -> void:
	# A short grace period stops the door flickering when someone brushes past the edge.
	if state != State.CLOSED and _closest_distance() < 0.0:
		_clear_time += delta
		if _clear_time < close_delay:
			return
	else:
		_clear_time = 0.0
	_evaluate(false)


## True while the door is fully open, so a body can walk through.
func is_passable() -> bool:
	return state == State.OPEN


## Distance to the nearest tracked body, or -1.0 when nothing is in range.
func _closest_distance() -> float:
	var best := -1.0
	for body in _detector.get_overlapping_bodies():
		var d := global_position.distance_to((body as Node2D).global_position)
		if best < 0.0 or d < best:
			best = d
	return best


func _evaluate(force: bool) -> void:
	var want := State.CLOSED
	if not locked:
		var d := _closest_distance()
		if d >= 0.0:
			want = State.OPEN if d <= half_distance else State.HALF
	if want == state and not force:
		return
	state = want
	_apply_state()
	state_changed.emit(state)
	if state == State.OPEN:
		opened.emit()
	elif state == State.CLOSED:
		closed.emit()


func _apply_state() -> void:
	if not is_instance_valid(_sprite):
		return
	_refresh_texture()
	# Only a fully open door is walkable.
	_blocker.process_mode = (Node.PROCESS_MODE_DISABLED if state == State.OPEN
		else Node.PROCESS_MODE_INHERIT)
	_blocker_shape.disabled = state == State.OPEN or not blocks_when_closed


func _refresh_texture() -> void:
	if not is_instance_valid(_sprite):
		return
	match state:
		State.OPEN:
			_sprite.texture = open_texture
		State.HALF:
			_sprite.texture = half_texture
		_:
			_sprite.texture = closed_texture


func _refresh_detector() -> void:
	if not is_instance_valid(_detector):
		return
	_detector.collision_mask = detect_layers
	(_detector_shape.shape as CircleShape2D).radius = near_distance


func _refresh_block() -> void:
	if not is_instance_valid(_blocker_shape):
		return
	(_blocker_shape.shape as RectangleShape2D).size = block_size
	_blocker_shape.position = block_offset


## Builds the child nodes in code, so a door only needs this one script attached.
func _build_nodes() -> void:
	_sprite = Sprite2D.new()
	_sprite.name = "Panels"
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	add_child(_sprite)

	_blocker = StaticBody2D.new()
	_blocker.name = "Blocker"
	_blocker_shape = CollisionShape2D.new()
	_blocker_shape.shape = RectangleShape2D.new()
	_blocker.add_child(_blocker_shape)
	add_child(_blocker)

	_detector = Area2D.new()
	_detector.name = "Detector"
	_detector.collision_layer = 0
	_detector.monitorable = false
	_detector_shape = CollisionShape2D.new()
	_detector_shape.shape = CircleShape2D.new()
	_detector.add_child(_detector_shape)
	add_child(_detector)
