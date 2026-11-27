class_name Minigame
extends Control
## Base class for every minigame (circle, color-match, future ones).
##
## Contract (what callers rely on, so any minigame can be swapped for another):
##     var mg: Minigame = SomeMinigame.new()
##     parent.add_child(mg)
##     mg.start(config)                      # config: any Resource, or null
##     var result: Dictionary = await mg.finished
##
## `result` always has `success: bool`; each minigame adds its own keys.
## Minigames advance only in _process / _input, never with SceneTreeTimers, so
## set_frozen(true) pauses them completely and keeps their progress.

signal finished(result: Dictionary)

var running := false


## Override. Call super.start(config) first, then set up your own state.
func start(_config: Resource = null) -> void:
	running = true
	show()


## Freeze / resume with progress kept (e.g. while a battle plays on top).
func set_frozen(on: bool) -> void:
	process_mode = Node.PROCESS_MODE_DISABLED if on else Node.PROCESS_MODE_INHERIT


## Player gave up (or the caller is shutting down). Ends with success = false.
func cancel() -> void:
	_finish({"success": false, "cancelled": true})


## Call exactly once when the minigame is over. Safe to call twice: ignored.
func _finish(result: Dictionary) -> void:
	if not running:
		return
	running = false
	finished.emit(result)
