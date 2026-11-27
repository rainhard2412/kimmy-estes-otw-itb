class_name NodeEdge
extends Resource
## A connection between two nodes. Reads as "<from_id> <type> <to_id>":
##   lengan DEPENDS_ON jaringan  - lengan is offline and unfixable while jaringan is down
##   lengan SPREADS_TO kaki      - an unfixed error on lengan raises kaki's error chance
## To add a new connection type: add a case here and handle it in SystemSim.

enum Type { DEPENDS_ON, SPREADS_TO }

@export var from_id := ""
@export var type: Type = Type.DEPENDS_ON
@export var to_id := ""
## SPREADS_TO only: extra error chance per second added to `to_id`.
@export_range(0.0, 1.0, 0.001, "or_greater") var spread_bonus := 0.05
