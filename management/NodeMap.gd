class_name NodeMap
extends Control
## Fullscreen, blurred overlay that shows the WAHANA's systems as connected
## nodes. Drag the empty background to pan (clamped so nodes can't be lost).
## It only displays and reports clicks: repairs are run by whoever owns it
## (see Management), which hands a minigame to host_minigame().
##
## Look and layout: edit management/NodeMap.tscn in the editor. Scene contract
## (unique names): %Backdrop (the blur; its shader is on the material)
## %Content (moves when panned) > %Edges (EdgeLayer) + %Nodes (widgets go here)
## %Title  %Message  %MinigameHost > %Dim (repair minigames are added here)
## Each system is one management/SystemNodeWidget.tscn.
## State colors: ui/wahana_theme.tres (NodeOK = green, NodeError = amber with a
## countdown, NodeFailed = red and draining, NodeOffline = grey: a system it
## depends on is down).

signal node_pressed(id: String)
signal opened
## Player closed the map (Tab / button). NOT emitted by suspend().
signal closed

const PAN_MARGIN := 24.0
const MESSAGE_SECONDS := 2.5
const WIDGET_SCENE := preload("res://management/SystemNodeWidget.tscn")

var sim: SystemSim
var pan := Vector2.ZERO

var _graph_bounds := Rect2()
var _widgets := {}               # id -> SystemNodeWidget
var _message_until := 0
var _dragging := false

@onready var _content: Control = %Content
@onready var _edges: EdgeLayer = %Edges
@onready var _nodes_parent: Control = %Nodes
@onready var _message: Label = %Message
@onready var _host: Control = %MinigameHost
@onready var _dim: Control = %Dim


func _ready() -> void:
	hide()


## Connect to a running sim and build one widget per system.
func bind(s: SystemSim) -> void:
	sim = s
	_edges.sim = s
	for w in _widgets.values():
		_nodes_parent.remove_child(w)
		w.queue_free()
	_widgets.clear()
	for n in sim.nodes:
		var w: SystemNodeWidget = WIDGET_SCENE.instantiate()
		_nodes_parent.add_child(w)
		w.setup(n.id, n.map_position)
		w.pressed.connect(func() -> void: node_pressed.emit(n.id))
		_widgets[n.id] = w
	var node_size := Vector2(76, 26)
	if not _widgets.is_empty():
		node_size = _widgets.values()[0].size
	_edges.node_half_size = node_size / 2.0
	_graph_bounds = sim.config.graph.bounds(node_size) if sim.config.graph != null else Rect2()
	center_view()
	_refresh()


# ------------------------------------------------------------------ open / close

func is_open() -> bool:
	return visible

func open() -> void:
	if visible or sim == null:
		return
	show()
	_refresh()
	opened.emit()

func close() -> void:
	if not visible:
		return
	_dragging = false
	hide()
	closed.emit()

func toggle() -> void:
	if visible:
		close()
	else:
		open()

## Hide without telling anyone the player closed it (a battle took over).
func suspend() -> void:
	_dragging = false
	hide()

## Show again after suspend().
func resume() -> void:
	show()
	_refresh()


# ------------------------------------------------------------------ panning

func center_view() -> void:
	set_pan(size / 2.0 - _graph_bounds.get_center())

func set_pan(p: Vector2) -> void:
	pan = clamp_pan(p, _graph_bounds, size, PAN_MARGIN)
	_content.position = pan

## Keeps the node area on screen. If it is bigger than the screen, you can pan
## until its edge is `margin` inside the screen edge. If it is smaller, it
## stays centered on that axis. Pure function, so it is easy to test.
static func clamp_pan(offset: Vector2, bounds: Rect2, view: Vector2, margin: float) -> Vector2:
	var out := offset
	for axis in 2:
		var lo := view[axis] - margin - bounds.end[axis]
		var hi := margin - bounds.position[axis]
		out[axis] = clampf(offset[axis], lo, hi) if lo <= hi else (lo + hi) / 2.0
	return out

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		set_pan(pan + event.relative)
		accept_event()


# ------------------------------------------------------------------ repair host

func host_minigame(mg: Control) -> void:
	clear_minigame()
	_dim.show()   # blocks clicks on everything behind the minigame
	if mg.size == Vector2.ZERO:
		mg.size = Vector2(160, 90)
	mg.position = ((size - mg.size) / 2.0).round()
	_host.add_child(mg)

func clear_minigame() -> void:
	_dim.hide()
	for c in _host.get_children():
		if c != _dim:
			_host.remove_child(c)
			c.queue_free()

func has_minigame() -> bool:
	return _host.get_child_count() > 1

func show_message(text: String) -> void:
	_message.text = text
	_message_until = Time.get_ticks_msec() + int(MESSAGE_SECONDS * 1000.0)


# ------------------------------------------------------------------ drawing

func _process(_delta: float) -> void:
	if visible and sim != null:
		_refresh()
		if _message.text != "" and Time.get_ticks_msec() > _message_until:
			_message.text = ""

func _refresh() -> void:
	if sim == null:
		return
	_edges.queue_redraw()
	for n in sim.nodes:
		var w: SystemNodeWidget = _widgets.get(n.id)
		if w == null:
			continue
		var st := sim.state_of(n.id)
		var blocked := sim.is_blocked(n.id)
		var look := SystemNodeWidget.Look.OK
		var line := "OK"
		if st == SystemSim.State.ERROR:
			look = SystemNodeWidget.Look.ERROR
			line = "ERROR %ds" % ceili(sim.countdown_of(n.id))
		elif st == SystemSim.State.FAILED:
			look = SystemNodeWidget.Look.FAILED
			line = "GAGAL!"
		elif blocked:
			look = SystemNodeWidget.Look.OFFLINE
			line = "OFFLINE"
		if st != SystemSim.State.HEALTHY and blocked:
			line += " (terkunci)"
		w.show_state(look, n.display_name, line)
