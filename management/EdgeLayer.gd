class_name EdgeLayer
extends Control
## Draws the arrows between connected systems on the node map. They are
## computed from the graph (so adding an edge to wahana_graph.tres needs no
## scene work), but the look is yours: colors and widths are exports, and the
## layer sits behind the node widgets in management/NodeMap.tscn.

## "A DEPENDS_ON B" arrow while B is online / while B is down.
@export var depends_ok := Color(0.55, 0.75, 1.0)
@export var depends_broken := Color(0.8, 0.2, 0.2)
## "A SPREADS_TO B" arrow while A is broken / while it is healthy.
@export var spreads_active := Color(1.0, 0.6, 0.25)
@export var spreads_idle := Color(1.0, 0.6, 0.25, 0.35)
@export var line_width := 1.0
@export var arrow_length := 6.0
## Half the size of one node box, so arrows start and end at the box edge.
@export var node_half_size := Vector2(38, 13)

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
			_arrow(b.map_position, a.map_position, depends_ok if live else depends_broken, false)
		else:
			var hot := sim.state_of(e.from_id) != SystemSim.State.HEALTHY
			_arrow(a.map_position, b.map_position, spreads_active if hot else spreads_idle, true)


func _arrow(from: Vector2, to: Vector2, color: Color, dashed: bool) -> void:
	var dir := (to - from).normalized()
	if dir == Vector2.ZERO:
		return
	var inset := _box_exit(dir)
	var tip := to - dir * inset
	var start := from + dir * inset
	if dashed:
		draw_dashed_line(start, tip, color, line_width, 3.0)
	else:
		draw_line(start, tip, color, line_width)
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([
		tip, tip - dir * arrow_length + side * arrow_length * 0.5,
		tip - dir * arrow_length - side * arrow_length * 0.5]), color)


# Distance from a box center to its edge along `dir`.
func _box_exit(dir: Vector2) -> float:
	var tx := node_half_size.x / maxf(absf(dir.x), 0.0001)
	var ty := node_half_size.y / maxf(absf(dir.y), 0.0001)
	return minf(tx, ty)
