class_name NodeGraphData
extends Resource
## The whole node map: systems plus the connections between them.
## Edit in the Inspector, or build in code. No other code needs to change when
## you add a node or an edge.

@export var nodes: Array[SystemNodeData] = []
@export var edges: Array[NodeEdge] = []


func find_node(id: String) -> SystemNodeData:
	for n in nodes:
		if n != null and n.id == id:
			return n
	return null


## The safe subset of this graph. Problems are skipped, never crash the sim:
##   - nodes with an empty or duplicate id
##   - edges naming an unknown node, or pointing at themselves
##   - DEPENDS_ON edges that would form a cycle (two broken systems waiting on
##     each other could never be fixed)
## Returns {nodes, edges, warnings}.
func validated() -> Dictionary:
	var warnings: PackedStringArray = []
	var good_nodes: Array[SystemNodeData] = []
	var seen := {}
	for n in nodes:
		if n == null:
			warnings.append("graph has an empty node slot")
		elif n.id == "":
			warnings.append("a node has no id (%s): skipped" % n.display_name)
		elif seen.has(n.id):
			warnings.append("duplicate node id '%s': skipped" % n.id)
		else:
			seen[n.id] = true
			good_nodes.append(n)

	var good_edges: Array[NodeEdge] = []
	var parents := {}   # id -> ids it depends on
	for e in edges:
		if e == null:
			warnings.append("graph has an empty edge slot")
			continue
		if not seen.has(e.from_id) or not seen.has(e.to_id):
			warnings.append("edge %s -> %s names an unknown node: skipped" % [e.from_id, e.to_id])
			continue
		if e.from_id == e.to_id:
			warnings.append("edge on '%s' points at itself: skipped" % e.from_id)
			continue
		if e.type == NodeEdge.Type.DEPENDS_ON:
			if _reaches(parents, e.to_id, e.from_id):
				warnings.append("%s DEPENDS_ON %s would make a cycle: skipped" % [e.from_id, e.to_id])
				continue
			if not parents.has(e.from_id):
				parents[e.from_id] = []
			parents[e.from_id].append(e.to_id)
		good_edges.append(e)
	return {"nodes": good_nodes, "edges": good_edges, "warnings": warnings}


func get_warnings() -> PackedStringArray:
	return validated()["warnings"]


## Rectangle covering every node box, used for the pan limits.
## `node_size` is the size of one node widget on the map.
func bounds(node_size: Vector2) -> Rect2:
	var rect := Rect2()
	var first := true
	for n in validated()["nodes"]:
		var r := Rect2(n.map_position - node_size / 2.0, node_size)
		rect = r if first else rect.merge(r)
		first = false
	return rect


# True if `target` can be reached from `start` by following depends-on links.
func _reaches(parents: Dictionary, start: String, target: String) -> bool:
	var stack: Array = [start]
	var visited := {}
	while not stack.is_empty():
		var cur: String = stack.pop_back()
		if cur == target:
			return true
		if visited.has(cur):
			continue
		visited[cur] = true
		for p in parents.get(cur, []):
			stack.append(p)
	return false
