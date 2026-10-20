class_name ISKDemoPlayer
extends CharacterBody2D
## Top-down player of the demo: walks with the arrow keys/WASD or towards a
## scripted target ([method walk_to]), shows the equipped weapon and a light.

## Emitted when a [method walk_to] target is reached.
signal arrived

const SHEET := "res://demo/art/tilesets/tiny_dungeon_packed.png"
## Knight tile in the Tiny Dungeon sheet.
const BODY_REGION := Rect2(0, 112, 16, 16)

## Walk speed without equipment, in pixels per second.
@export var base_speed: float = 70.0
## Area the player may walk in (world pixels).
@export var bounds := Rect2(8, 8, 464, 272)

## Speed bonus of the equipment (set by the world).
var speed_bonus: float = 0.0
## Temporary speed bonus (stamina potion).
var boost: float = 0.0
## Seconds left of [member boost].
var boost_time: float = 0.0
## Last non-zero walk direction (drops land in front of the player).
var facing := Vector2.DOWN
## False while the inventory is open or a script walks.
var input_enabled: bool = true

var _target := Vector2.ZERO
var _walking_to: bool = false
var _body := Sprite2D.new()
var _held := Sprite2D.new()
var _light := PointLight2D.new()


func _init() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	# layer 1 is seen by pickups/checkpoints; the open meadow has no walls to hit
	collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 5.0
	shape.shape = circle
	add_child(shape)
	var atlas := AtlasTexture.new()
	atlas.atlas = load(SHEET) as Texture2D
	atlas.region = BODY_REGION
	_body.texture = atlas
	add_child(_body)
	_held.position = Vector2(8, 2)
	_held.scale = Vector2(0.75, 0.75)
	_held.visible = false
	add_child(_held)
	_light.texture = _light_texture()
	_light.color = Color(0.75, 0.9, 1.0)
	_light.energy = 0.8
	_light.enabled = false
	add_child(_light)
	var camera := Camera2D.new()
	camera.zoom = Vector2(3, 3)
	camera.position_smoothing_enabled = true
	add_child(camera)


func _ready() -> void:
	var camera := get_child(get_child_count() - 1) as Camera2D
	camera.limit_left = int(bounds.position.x - 8)
	camera.limit_top = int(bounds.position.y - 8)
	camera.limit_right = int(bounds.end.x + 8)
	camera.limit_bottom = int(bounds.end.y + 8)


## Current walk speed including equipment and boost.
func get_speed() -> float:
	return maxf(20.0, base_speed + speed_bonus + boost)


## Walks to [param target] (world pixels); [signal arrived] follows.
func walk_to(target: Vector2) -> void:
	_target = target
	_walking_to = true


## True while a [method walk_to] target is not reached yet.
func is_walking_to() -> bool:
	return _walking_to


## Stops a scripted walk.
func stop() -> void:
	_walking_to = false
	velocity = Vector2.ZERO


## Starts a temporary speed bonus.
func start_boost(amount: float, seconds: float) -> void:
	boost = amount
	boost_time = seconds


## Shows the equipment effects: [param weapon_icon] in the hand (null = none),
## light on/off.
func show_equipment(weapon_icon: Texture2D, light_radius: float) -> void:
	_held.texture = weapon_icon
	_held.visible = weapon_icon != null
	_light.enabled = light_radius > 0.0
	_light.texture_scale = maxf(light_radius, 0.01)


## True if the light of the equipment is on.
func is_light_on() -> bool:
	return _light.enabled


func _physics_process(delta: float) -> void:
	if boost_time > 0.0:
		boost_time -= delta
		if boost_time <= 0.0:
			boost = 0.0
	var direction := Vector2.ZERO
	if _walking_to:
		var to_target := _target - position
		if to_target.length() <= get_speed() * delta:
			position = _target
			stop()
			arrived.emit()
			return
		direction = to_target.normalized()
	elif input_enabled:
		direction = Input.get_vector(&"ui_left", &"ui_right", &"ui_up", &"ui_down")
	if direction != Vector2.ZERO:
		facing = direction.normalized()
		_body.flip_h = direction.x < 0.0
	velocity = direction * get_speed()
	move_and_slide()
	position = position.clamp(bounds.position, bounds.end)


static func _light_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 128
	texture.height = 128
	return texture
