class_name NodeMap
extends Control
## Fullscreen, blurred overlay that shows the WAHANA's systems as connected
## nodes. Drag the empty background to pan (clamped so nodes can't be lost).
## It only displays and reports clicks: repairs are run by whoever owns it
## (see Management), which hands a minigame to host_minigame().
##
## Colors: green = OK, amber = ERROR (countdown), red = FAILED (draining),
## grey = offline because a system it depends on is down.

signal node_pressed(id: String)
signal opened
## Player closed the map (Tab / button). NOT emitted by suspend().
signal closed

const NODE_SIZE := Vector2(76, 26)
const PAN_MARGIN := 24.0
const MESSAGE_SECONDS := 2.5

const COL_OK := Color(0.2, 0.55, 0.3)
const COL_ERROR := Color(0.85, 0.6, 0.1)
const COL_FAILED := Color(0.8, 0.2, 0.2)
const COL_OFFLINE := Color(0.35, 0.37, 0.42)
const COL_DEPENDS := Color(0.55, 0.75, 1.0)
const COL_SPREADS := Color(1.0, 0.6, 0.25)

## Draws the connection lines under the node widgets.
class EdgeLayer extends Control:
	var sim: SystemSim

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		if sim == null:
			return
		for e in sim.edges:
			var a := sim.data_of(e.from_id)
			var b := sim.data_of(e.to_id)
			if a == null or b == null:
				continue
			if e.type == NodeEdge.Type.DEPENDS_ON:
				# "A depends on B": support flows B -> A.
				var live := sim.is_online(e.to_id)
				_arrow(b.map_position, a.map_position, COL_DEPENDS if live else COL_FAILED, false)
			else:
				var hot := sim.state_of(e.from_id) != SystemSim.State.HEALTHY
				var col := COL_SPREADS if hot else Color(COL_SPREADS, 0.35)
				_arrow(a.map_position, b.map_position, col, true)

	func _arrow(from: Vector2, to: Vector2, color: Color, dashed: bool) -> void:
		var dir := (to - from).normalized()
		if dir == Vector2.ZERO:
			return
		var tip := to - dir * _box_exit(dir)
		var start := from + dir * _box_exit(dir)
		if dashed:
			draw_dashed_line(start, tip, color, 1.0, 3.0)
		else:
			draw_line(start, tip, color, 1.0)
		var side := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([tip, tip - dir * 6.0 + side * 3.0, tip - dir * 6.0 - side * 3.0]), color)

	# Distance from a box center to its edge along `dir`.
	func _box_exit(dir: Vector2) -> float:
		var half := NODE_SIZE / 2.0
		var tx := half.x / maxf(absf(dir.x), 0.0001)
		var ty := half.y / maxf(absf(dir.y), 0.0001)
		return minf(tx, ty)

var sim: SystemSim
var pan := Vector2.ZERO

var _graph_bounds := Rect2()
var _backdrop := ColorRect.new()
var _content := Control.new()    # moves with pan
var _edges := EdgeLayer.new()
var _widgets := {}               # id -> Button
var _last_style := {}            # id -> cached style key, avoids restyling every frame
var _styles := {}                # style key -> StyleBoxFlat
var _title := Label.new()
var _message := Label.new()
var _message_until := 0
var _host := Control.new()       # holds the repair minigame (not panned)
var _dragging := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	hide()

	var mat := ShaderMaterial.new()
	mat.shader = preload("res://management/blur.gdshader")
	_backdrop.material = mat
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_content)
	_content.add_child(_edges)

	_title.text = "SISTEM WAHANA   (seret untuk geser, Tab untuk tutup)"
	_title.position = Vector2(6, 2)
	_title.add_theme_font_size_override("font_size", 8)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_title)

	_message.position = Vector2(6, 166)
	_message.size = Vector2(308, 12)
	_message.add_theme_font_size_override("font_size", 8)
	_message.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	_message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_message)

	_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_host)


## Connect to a running sim and build one widget per system.
func bind(s: SystemSim) -> void:
	sim = s
	_edges.sim = s
	for w in _widgets.values():
		w.queue_free()
	_widgets.clear()
	_last_style.clear()
	for n in sim.nodes:
		var b := Button.new()
		b.size = NODE_SIZE
		b.position = n.map_position - NODE_SIZE / 2.0
		b.focus_mode = Control.FOCUS_NONE
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 8)
		b.pressed.connect(func() -> void: node_pressed.emit(n.id))
		_content.add_child(b)
		_widgets[n.id] = b
	_graph_bounds = sim.config.graph.bounds(NODE_SIZE) if sim.config.graph != null else Rect2()
	_edges.size = Vector2(2000, 2000)
	_edges.position = Vector2.ZERO
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
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP   # nothing behind it is clickable
	_host.add_child(dim)
	if mg.size == Vector2.ZERO:
		mg.size = Vector2(160, 90)
	mg.position = ((size - mg.size) / 2.0).round()
	_host.add_child(mg)

func clear_minigame() -> void:
	for c in _host.get_children():
		c.queue_free()
		_host.remove_child(c)

func has_minigame() -> bool:
	return _host.get_child_count() > 0

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
		var b: Button = _widgets.get(n.id)
		if b == null:
			continue
		var st := sim.state_of(n.id)
		var blocked := sim.is_blocked(n.id)
		var key := "ok"
		var line := "OK"
		if st == SystemSim.State.ERROR:
			key = "error"
			line = "ERROR %ds" % ceili(sim.countdown_of(n.id))
		elif st == SystemSim.State.FAILED:
			key = "failed"
			line = "GAGAL!"
		elif blocked:
			key = "offline"
			line = "OFFLINE"
		if st != SystemSim.State.HEALTHY and blocked:
			line += " (terkunci)"
		b.text = "%s\n%s" % [n.display_name, line]
		if _last_style.get(n.id, "") != key:
			_last_style[n.id] = key
			var sb := _style_for(key)
			for s in ["normal", "hover", "pressed", "disabled"]:
				b.add_theme_stylebox_override(s, sb)

func _style_for(key: String) -> StyleBoxFlat:
	if not _styles.has(key):
		var sb := StyleBoxFlat.new()
		sb.bg_color = {"ok": COL_OK, "error": COL_ERROR, "failed": COL_FAILED, "offline": COL_OFFLINE}[key]
		sb.set_border_width_all(1)
		sb.border_color = Color(1, 1, 1, 0.5)
		sb.set_corner_radius_all(2)
		_styles[key] = sb
	return _styles[key]
