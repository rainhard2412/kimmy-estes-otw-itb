class_name SystemNodeData
extends Resource
## One WAHANA component/system the player has to maintain.
## Add a node to the game by adding one of these to a NodeGraphData.

@export var id := ""
@export var display_name := ""
## Where the node sits on the (pannable) node map, in map pixels.
@export var map_position := Vector2(160, 90)

@export_group("Errors")
## Chance per second of randomly going into error while healthy.
@export_range(0.0, 1.0, 0.001, "or_greater") var error_chance_per_sec := 0.02
## Seconds from the error appearing to the system failing.
@export_range(1.0, 600.0, 0.5, "or_greater") var error_countdown := 25.0
## WAHANA Integrity lost per second while this system is FAILED.
@export_range(0.0, 100.0, 0.1, "or_greater") var drain_per_sec := 2.0

@export_group("Repair")
## A scene whose root extends Minigame. Empty = the placeholder color-match.
@export var repair_scene: PackedScene
## Passed to the repair minigame's start(). Empty = that minigame's defaults.
@export var repair_config: Resource

@export_group("Effects")
## Free-form numbers other systems can read while this node is down, e.g.
## {"player_damage_mult": 0.8}. Read with SystemSim.get_modifier(). Nothing in
## battle reads them yet.
@export var down_modifiers: Dictionary = {}
