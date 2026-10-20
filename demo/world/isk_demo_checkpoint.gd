class_name ISKDemoCheckpoint
extends Area2D
## A place that triggers [signal ISKDemoWorld.checkpoint_reached] (full demo:
## autosave). Fires once per visit.

## Emitted when the player enters.
signal reached(checkpoint: ISKDemoCheckpoint)

## Name shown in the notice and passed to the signal.
@export var checkpoint_name: String = "Checkpoint"


func _init() -> void:
	monitorable = false
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(16, 16)
	shape.shape = rect
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is ISKDemoPlayer:
		reached.emit(self)
