class_name SystemNodeWidget
extends Button
## One system on the node map (a button). The map tells it which state to show;
## the colors come from ui/wahana_theme.tres (type variations NodeOK, NodeError,
## NodeFailed, NodeOffline), so restyle them there, or give each state its own
## art by editing the theme's StyleBoxes.
##
## Look: edit management/SystemNodeWidget.tscn (size, font, icon).

enum Look { OK, ERROR, FAILED, OFFLINE }

const VARIATIONS := {
	Look.OK: &"NodeOK", Look.ERROR: &"NodeError",
	Look.FAILED: &"NodeFailed", Look.OFFLINE: &"NodeOffline",
}

var system_id := ""
var _look := -1


## `id` is the SystemNodeData id; `center` is the node's spot on the map.
func setup(id: String, center: Vector2) -> void:
	system_id = id
	position = center - size / 2.0


func show_state(look: int, title: String, status: String) -> void:
	text = "%s\n%s" % [title, status]
	if look != _look:   # only touch the theme when the state really changed
		_look = look
		theme_type_variation = VARIATIONS[look]
