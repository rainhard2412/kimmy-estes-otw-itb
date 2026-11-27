class_name Arena
extends Node2D
## The top-down arena: shows a WalkSim. It owns no game logic; every frame it
## moves the WAHANA node and one Walker node per living enemy to where WalkSim
## says they are.
##
## Look: edit management/Arena.tscn. Scene contract (unique names):
##   %Ground   (anything: the floor art; size it to the arena, 320x180)
##   %Wahana   (Node2D, the player's robot; origin = its center)
##   %Walkers  (Node2D, enemy nodes are added here)
## %Wahana's art can be a Sprite2D / AnimatedSprite2D. If it has a node named
## %Facing (Node2D), the script points it at the nearest enemy.
## The contact-range circle is a node too: %ContactRing (Sprite2D, optional).
## It is scaled so its edge sits at the contact distance from the config.

var walk: WalkSim
var _nodes := {}   # walker id -> WalkerNode
var _t := 0.0

@onready var _wahana: Node2D = %Wahana
@onready var _walkers: Node2D = %Walkers
@onready var _ring: Sprite2D = get_node_or_null("%ContactRing") as Sprite2D
@onready var _facing: Node2D = get_node_or_null("%Facing")


## Connect to a running WalkSim.
func bind(w: WalkSim) -> void:
	walk = w
	if _ring != null and _ring.texture != null:
		var diameter := w.config.contact_distance * 2.0
		_ring.scale = Vector2(diameter, diameter) / _ring.texture.get_size()


func _process(delta: float) -> void:
	if walk == null:
		return
	_t += delta
	_wahana.position = walk.wahana_pos.round()
	# a little walking bob while moving
	_wahana.position.y += roundf(sin(_t * 14.0)) if walk.moving else 0.0
	if _facing != null:
		var target := walk.nearest_enemy()
		if target != null:
			_facing.rotation = (target.pos - walk.wahana_pos).angle()
	_sync_walkers()


## One node per enemy in the sim: create new, move existing, free the gone.
func _sync_walkers() -> void:
	var live := {}
	for e in walk.enemies:
		live[e.id] = true
		var node: WalkerNode = _nodes.get(e.id)
		if node == null:
			node = e.data.make_walker()
			_walkers.add_child(node)
			_nodes[e.id] = node
		node.position = e.pos.round()
	for id in _nodes.keys():
		if not live.has(id):
			_nodes[id].queue_free()
			_nodes.erase(id)


func walker_count() -> int:
	return _nodes.size()
