extends CanvasLayer
## Demo UI of the lite demo world: only the save indicator (the lite world keeps
## its placeholder bag grid, the inventory window is full-only).
## [br]Instanced by [ISKDemoWorld] as its child ([member ISKDemoWorld.ui_scene_path]);
## binds the indicator to the world's save manager, so the capture tour's own
## manager is shown too.

## The world this UI belongs to (its parent).
var world: ISKDemoWorld

@onready var indicator: Control = %SaveIndicator


func _ready() -> void:
	world = get_parent() as ISKDemoWorld
	if world == null:
		return
	if world.save_manager != null:
		indicator.call(&"set_save_manager", world.save_manager)
	_bind_world()


## Virtual: connects the world to the full UI.
func _bind_world() -> void:
	pass
