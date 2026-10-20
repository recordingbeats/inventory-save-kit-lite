class_name ISKDemoPickup
extends Area2D
## An item lying in the world. The player picks it up by walking over it
## ([signal touched]); the world adds it to the bag ([method ISKInventory.add_item]).

## Emitted when a player body enters and the pickup is not blocked.
signal touched(pickup: ISKDemoPickup)

## ID of the item ([method ISKItemDatabase.get_item]).
@export var item_id: StringName = &""
## Number of items; the remainder stays when the bag is full.
@export_range(1, 999) var amount: int = 1
## Stable ID for the save file; empty for items dropped by the player.
@export var pickup_id: String = ""

## Data of the stack ([member ISKItemStack.data]) for dropped items.
var stack_data: Dictionary = {}
## Body that dropped the item; ignored until it walked away once.
var blocked_body: Node2D = null

var _sprite := Sprite2D.new()
var _age: float = 0.0


func _init() -> void:
	monitorable = false
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	add_child(_sprite)
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


## Shows [param icon] and makes the pickup active (visible, monitoring).
func setup(icon: Texture2D) -> void:
	_sprite.texture = icon
	set_active(true)


## Shows or hides the pickup; hidden pickups do not react. Monitoring stays on:
## toggling it can report stale overlaps when the pickup comes back (load).
func set_active(active: bool) -> void:
	visible = active


## True if the pickup is in the world (not collected).
func is_active() -> bool:
	return visible


func _process(delta: float) -> void:
	_age += delta
	_sprite.position.y = sin(_age * 3.0) * 1.5


func _on_body_entered(body: Node2D) -> void:
	if not visible or body == blocked_body or not body is ISKDemoPlayer:
		return
	touched.emit(self)


func _on_body_exited(body: Node2D) -> void:
	if body == blocked_body:
		blocked_body = null
