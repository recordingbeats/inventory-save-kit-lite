class_name ISKDemoWorld
extends Node2D
## Playable demo world (lite and full): walk, pick up items, drop them, use
## potions, save and load one slot.
##
## The world saves itself through [member save_manager] (autoload
## [code]ISKSave[/code]): on [signal ISKSaveManager.save_started] it writes its
## state into [member ISKSaveManager.data], on
## [signal ISKSaveManager.load_finished] it reads it back. The lite world stores the
## player too; the full demo world leaves the player to its save components.
## [br][br]
## UI hooks (demo UI of P9b, [code]docs/ui-spec.md[/code] "Demo world ↔ demo UI"):
## the UI scene [member ui_scene_path] is instanced as a child of the world on
## start (if it exists), finds the world as its parent, connects to the signals
## below and calls the public methods. With [member placeholder_inventory] (lite)
## or without a UI scene a simple placeholder UI (hint, notice line, bag grid) is
## built as well.

## Emitted when the inventory window opens or closes.
signal inventory_toggled(open: bool)
## Emitted after items from a pickup went into the bag.
signal item_picked_up(item: ISKItemDefinition, amount: int)
## Emitted after items were dropped into the world.
signal item_dropped(item: ISKItemDefinition, amount: int)
## Emitted after a consumable was used.
signal item_used(item: ISKItemDefinition)
## Short message for the player (toast).
signal notice(text: String)
## Emitted after a save through the world's save manager.
signal game_saved(slot: String, err: Error)
## Emitted after a load through the world's save manager (state already applied).
signal game_loaded(slot: String, err: Error)
## Emitted when the player enters an [ISKDemoCheckpoint].
signal checkpoint_reached(checkpoint_name: String)

const GROUP := &"isk_demo_world"
## Key of the world state in [member ISKSaveManager.data].
const WORLD_KEY := "world"
## Key of the player state (lite world only).
const PLAYER_KEY := "player"
const TOWN_SHEET := "res://demo/art/tilesets/tiny_town_packed.png"
const THEME_PATH := "res://addons/inventory_save_kit/ui/theme/isk_default_theme.tres"
const TILE := 16
## Seconds a stamina potion lasts.
const BOOST_SECONDS := 5.0

## UI scene instanced on start (if the file exists).
@export_file("*.tscn") var ui_scene_path: String = "res://demo/ui/demo_ui_lite.tscn"
## Also build the placeholder UI with the bag grid (lite: the demo inventory
## window is full-only). Always built when the UI scene is missing.
@export var placeholder_inventory: bool = true
## Slot used by [method quick_save] / [method quick_load].
@export var quick_slot: String = "slot_1"
## World size in tiles (floor drawing).
@export var size_in_tiles := Vector2i(30, 18)
## Number of bag slots.
@export var bag_slots: int = 16
## Weight limit of the bag (0 = none).
@export var bag_max_weight: float = 25.0

## The player's bag.
var bag := ISKInventory.new()
## Item database of the demo ([method ISKDemoItems.build]).
var item_database: ISKItemDatabase
## Save manager; defaults to the [code]ISKSave[/code] autoload. Set it before the
## world enters the tree to use another one (tests, tour).
var save_manager: ISKSaveManager
## True while the inventory window is open.
var inventory_open: bool = false
## The UI node: the instanced [member ui_scene_path], else the placeholder.
var ui: Node

var _placed_amounts: Dictionary = {}
var _has_ui_scene: bool = false
# kept as a member: canvas draw commands only hold the RID, a local would be freed
var _floor_sheet: Texture2D = load(TOWN_SHEET)
var _placeholder_grid: ISKInventoryGrid
var _placeholder_panel: Control
var _notice_label: Label
var _notice_time: float = 0.0

@onready var player: ISKDemoPlayer = $Player
@onready var _pickups: Node2D = $Pickups
@onready var _drops: Node2D = $Drops


func _ready() -> void:
	add_to_group(GROUP)
	ensure_input_actions()
	item_database = ISKDemoItems.build()
	bag.slot_count = bag_slots
	bag.max_weight = bag_max_weight
	if save_manager == null:
		save_manager = get_node_or_null(^"/root/ISKSave") as ISKSaveManager
	if save_manager != null:
		save_manager.save_started.connect(_on_save_started)
		save_manager.load_finished.connect(_on_load_finished)
	for pickup: ISKDemoPickup in _placed_pickups():
		_init_pickup(pickup)
		_placed_amounts[pickup.pickup_id] = pickup.amount
	for child: Node in get_children():
		if child is ISKDemoCheckpoint:
			(child as ISKDemoCheckpoint).reached.connect(_on_checkpoint)
	_setup()
	_load_ui()
	queue_redraw()


func _exit_tree() -> void:
	if save_manager != null and save_manager.save_started.is_connected(_on_save_started):
		save_manager.save_started.disconnect(_on_save_started)
		save_manager.load_finished.disconnect(_on_load_finished)


## Adds the demo input actions if the project does not define them.
static func ensure_input_actions() -> void:
	var keys := {
		&"isk_demo_inventory": [KEY_I, KEY_TAB],
		&"isk_demo_menu": [KEY_ESCAPE],
		&"isk_demo_quicksave": [KEY_F5],
		&"isk_demo_quickload": [KEY_F9],
		&"isk_demo_drop": [KEY_Q],
		&"ui_left": [KEY_A],
		&"ui_right": [KEY_D],
		&"ui_up": [KEY_W],
		&"ui_down": [KEY_S],
	}
	for action: StringName in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for keycode: Key in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)


## Opens or closes the inventory window.
func toggle_inventory() -> void:
	set_inventory_open(not inventory_open)


## Opens ([code]true[/code]) or closes the inventory window; the player stops
## walking while it is open.
func set_inventory_open(open: bool) -> void:
	if open == inventory_open:
		return
	inventory_open = open
	player.input_enabled = not open
	if _placeholder_panel != null:
		_placeholder_panel.visible = open
	inventory_toggled.emit(open)


## Uses the stack in bag slot [param index]: drinks a potion. Returns false if
## nothing happened. The full demo world also equips.
func use_slot(index: int) -> bool:
	var stack := bag.get_slot(index)
	if stack == null or not stack.item.has_tag(&"consumable"):
		return false
	var item := stack.item
	bag.remove_item(item, 1)
	var boost: float = item.properties.get("boost", 0.0)
	if boost > 0.0:
		player.start_boost(boost, BOOST_SECONDS)
	item_used.emit(item)
	_notify("Used %s" % item.display_name)
	return true


## Drops [param amount] items (-1 = the whole stack) from bag slot [param index]
## in front of the player. Returns the dropped count.
func drop_from_bag(index: int, amount: int = -1) -> int:
	return drop_from(bag, index, amount)


## Like [method drop_from_bag] for any inventory of the player (full: also the
## equipment, the demo UI drops what is dragged out of its window).
func drop_from(inventory: ISKInventory, index: int, amount: int = -1) -> int:
	var stack := inventory.get_slot(index) if inventory != null else null
	if stack == null:
		return 0
	var count := stack.count if amount < 0 else mini(amount, stack.count)
	if count <= 0:
		return 0
	var item := stack.item
	var data := stack.data.duplicate(true)
	var pickup := _spawn_drop(item, count, data, player.position + player.facing * 14.0)
	pickup.blocked_body = player
	if count == stack.count:
		inventory.set_slot(index, null)
	else:
		var rest := ISKItemStack.new()
		rest.item = item
		rest.count = stack.count - count
		rest.data = data
		inventory.set_slot(index, rest)
	item_dropped.emit(item, count)
	_notify("Dropped %d× %s" % [count, item.display_name])
	return count


## Saves the game to [param slot].
func save_to(slot: String) -> Error:
	if save_manager == null:
		return ERR_UNCONFIGURED
	var err := save_manager.save_game(slot, _save_meta())
	game_saved.emit(slot, err)
	if not _has_ui_scene:  # the demo UI's save indicator reports saves itself
		_notify("Saved" if err == OK else "Save failed: %s" % error_string(err))
	return err


## Loads [param slot]; the world state is applied in the load handler.
func load_from(slot: String) -> Error:
	if save_manager == null:
		return ERR_UNCONFIGURED
	return save_manager.load_game(slot)


## Saves to [member quick_slot].
func quick_save() -> Error:
	return save_to(quick_slot)


## Loads [member quick_slot].
func quick_load() -> Error:
	return load_from(quick_slot)


## Resets bag, pickups and player to the scene's start state.
func new_game() -> void:
	bag.clear()
	_apply_world({"pickups": _placed_amounts.duplicate(), "drops": []})
	player.position = _start_position()
	_reset_player()
	_notify("New game")


## Comparable state of the world (play test: pickup → save → load = same state).
func snapshot() -> Dictionary:
	var state := _world_state()
	state["bag"] = bag.to_dict()
	state["player"] = [snappedf(player.position.x, 0.01), snappedf(player.position.y, 0.01)]
	return state


## Number of active pickups in the world (placed and dropped).
func active_pickup_count() -> int:
	var count := 0
	for pickup: ISKDemoPickup in _all_pickups():
		if pickup.is_active():
			count += 1
	return count


## Returns the placed pickup with [param pickup_id], or null.
func get_pickup(pickup_id: String) -> ISKDemoPickup:
	for pickup: ISKDemoPickup in _placed_pickups():
		if pickup.pickup_id == pickup_id:
			return pickup
	return null


## Virtual: extra setup of subclasses before the UI is loaded.
func _setup() -> void:
	pass


## Virtual: writes the player state into the save data (lite: position + bag).
func _write_player(data: Dictionary) -> void:
	data[PLAYER_KEY] = {
		"position": ISKSaveFile.vec2_to_json(player.position),
		"bag": bag.to_dict(),
	}


## Virtual: reads the player state from loaded save data.
func _read_player(data: Dictionary) -> void:
	var state: Variant = data.get(PLAYER_KEY)
	if not state is Dictionary:
		return
	var player_state: Dictionary = state
	if player_state.get("position") is Array:
		player.position = ISKSaveFile.json_to_vec2(player_state["position"])
	if player_state.get("bag") is Dictionary:
		bag.from_dict(player_state["bag"], item_database)


## Virtual: resets player effects on [method new_game].
func _reset_player() -> void:
	player.start_boost(0.0, 0.0)


## Virtual: adds panels to the placeholder UI (full: equipment).
func _add_placeholder_panels(_box: HBoxContainer) -> void:
	pass


## Virtual: reacts to a checkpoint (lite: notice only, full: autosave).
func _on_checkpoint(checkpoint: ISKDemoCheckpoint) -> void:
	checkpoint_reached.emit(checkpoint.checkpoint_name)
	_notify(checkpoint.checkpoint_name)


## Header meta of a save (shown in slot lists).
func _save_meta() -> Dictionary:
	return {"location": "Meadow", "items": _item_total()}


func _notify(text: String) -> void:
	notice.emit(text)
	if _notice_label != null:
		_notice_label.text = text
		_notice_time = 2.5


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"isk_demo_inventory"):
		toggle_inventory()
	elif event.is_action_pressed(&"isk_demo_quicksave"):
		quick_save()
	elif event.is_action_pressed(&"isk_demo_quickload"):
		quick_load()
	elif event.is_action_pressed(&"isk_demo_drop") and _placeholder_grid != null:
		if _placeholder_grid.selected_index >= 0:
			drop_from_bag(_placeholder_grid.selected_index)
	else:
		return
	get_viewport().set_input_as_handled()


# A focused bag slot would hand Tab to Godot's focus navigation before
# _unhandled_input, so the open placeholder bag takes the inventory key here.
func _input(event: InputEvent) -> void:
	if (
		inventory_open
		and _placeholder_panel != null
		and event.is_action_pressed(&"isk_demo_inventory")
	):
		set_inventory_open(false)
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if _notice_time > 0.0:
		_notice_time -= delta
		if _notice_time <= 0.0 and _notice_label != null:
			_notice_label.text = ""


func _draw() -> void:
	for y in size_in_tiles.y:
		for x in size_in_tiles.x:
			var variant := (x * 7 + y * 13) % 11
			var region := Rect2(TILE * (1 if variant == 0 else 0), 0, TILE, TILE)
			if variant == 3:
				region = Rect2(TILE * 2, 0, TILE, TILE)
			draw_texture_rect_region(_floor_sheet, Rect2(x * TILE, y * TILE, TILE, TILE), region)


func _placed_pickups() -> Array[ISKDemoPickup]:
	var result: Array[ISKDemoPickup] = []
	for child: Node in _pickups.get_children():
		if child is ISKDemoPickup:
			result.append(child)
	return result


func _all_pickups() -> Array[ISKDemoPickup]:
	var result := _placed_pickups()
	for child: Node in _drops.get_children():
		if child is ISKDemoPickup and not child.is_queued_for_deletion():
			result.append(child)
	return result


func _init_pickup(pickup: ISKDemoPickup) -> void:
	var item := item_database.get_item(pickup.item_id)
	pickup.setup(item.icon if item != null else null)
	if not pickup.touched.is_connected(_on_pickup_touched):
		pickup.touched.connect(_on_pickup_touched)


func _spawn_drop(
	item: ISKItemDefinition, count: int, data: Dictionary, at: Vector2
) -> ISKDemoPickup:
	var pickup := ISKDemoPickup.new()
	pickup.item_id = item.id
	pickup.amount = count
	pickup.stack_data = data
	pickup.position = at.clamp(player.bounds.position, player.bounds.end)
	_drops.add_child(pickup)
	_init_pickup(pickup)
	return pickup


func _on_pickup_touched(pickup: ISKDemoPickup) -> void:
	var item := item_database.get_item(pickup.item_id)
	if item == null or not pickup.is_active():
		return
	var rest := bag.add_item(item, pickup.amount, pickup.stack_data)
	var taken := pickup.amount - rest
	if taken <= 0:
		_notify("Bag is full")
		return
	if rest > 0:
		pickup.amount = rest
		_notify("Bag is full, %d left" % rest)
	elif pickup.pickup_id.is_empty():
		pickup.queue_free()
	else:
		pickup.amount = 0
		pickup.set_active(false)
	item_picked_up.emit(item, taken)
	if rest == 0:
		_notify("+%d %s" % [taken, item.display_name])


func _on_save_started(_slot: String) -> void:
	save_manager.data[WORLD_KEY] = _world_state()
	_write_player(save_manager.data)


func _on_load_finished(slot: String, err: Error) -> void:
	if err == OK or err == ERR_FILE_CORRUPT:
		var world: Variant = save_manager.data.get(WORLD_KEY)
		if world is Dictionary:
			_apply_world(world)
		_read_player(save_manager.data)
		player.stop()
	game_loaded.emit(slot, err)
	if _has_ui_scene:
		return
	if err == OK or err == ERR_FILE_CORRUPT:
		_notify("Loaded")
	else:
		_notify("Load failed: %s" % error_string(err))


## World state: amounts left on placed pickups (0 = collected) and dropped stacks.
func _world_state() -> Dictionary:
	var amounts := {}
	for pickup: ISKDemoPickup in _placed_pickups():
		amounts[pickup.pickup_id] = pickup.amount if pickup.is_active() else 0
	var drops: Array = []
	for child: Node in _drops.get_children():
		var pickup := child as ISKDemoPickup
		if pickup == null or pickup.is_queued_for_deletion():
			continue
		(
			drops
			. append(
				{
					"id": String(pickup.item_id),
					"n": pickup.amount,
					"d": pickup.stack_data,
					"position": ISKSaveFile.vec2_to_json(pickup.position),
				}
			)
		)
	return {"pickups": amounts, "drops": drops}


func _apply_world(world: Dictionary) -> void:
	var amounts: Dictionary = world.get("pickups", {}) if world.get("pickups") is Dictionary else {}
	for pickup: ISKDemoPickup in _placed_pickups():
		var amount := int(amounts.get(pickup.pickup_id, _placed_amounts[pickup.pickup_id]))
		pickup.amount = maxi(amount, 1)
		pickup.set_active(amount > 0)
		pickup.blocked_body = null
	for child: Node in _drops.get_children():
		_drops.remove_child(child)
		child.queue_free()
	var drops: Variant = world.get("drops")
	if not drops is Array:
		return
	for entry: Variant in drops:
		if not entry is Dictionary:
			continue
		var drop: Dictionary = entry
		var item := item_database.get_item(StringName(str(drop.get("id", ""))))
		var count := int(drop.get("n", 0))
		if item == null or count <= 0 or not drop.get("position") is Array:
			continue
		var data: Dictionary = drop.get("d", {}) if drop.get("d") is Dictionary else {}
		_spawn_drop(item, count, data, ISKSaveFile.json_to_vec2(drop["position"]))


func _start_position() -> Vector2:
	var start := get_node_or_null(^"Start") as Node2D
	return start.position if start != null else Vector2(64, 64)


func _item_total() -> int:
	var total := 0
	for i in bag.slot_count:
		var stack := bag.get_slot(i)
		if stack != null:
			total += stack.count
	return total


func _load_ui() -> void:
	if not ui_scene_path.is_empty() and ResourceLoader.exists(ui_scene_path):
		var packed := load(ui_scene_path) as PackedScene
		if packed != null:
			ui = packed.instantiate()
			_has_ui_scene = true
	if not _has_ui_scene or placeholder_inventory:
		var placeholder := _build_placeholder_ui()
		add_child(placeholder)
		if ui == null:
			ui = placeholder
	if _has_ui_scene:
		add_child(ui)


## Placeholder UI until the demo UI (P9b) exists: hint, notice, bag grid.
func _build_placeholder_ui() -> CanvasLayer:
	var layer := CanvasLayer.new()
	layer.name = "PlaceholderUI"
	var root := MarginContainer.new()
	root.theme = load(THEME_PATH) as Theme
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side: String in ["left", "top", "right", "bottom"]:
		root.add_theme_constant_override("margin_" + side, 12)
	layer.add_child(root)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(column)
	var hint := Label.new()
	hint.text = "WASD move · I inventory · double click use/equip · Q drop · F5 save · F9 load"
	column.add_child(hint)
	_notice_label = Label.new()
	column.add_child(_notice_label)
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ISKTooltipPanel"
	panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	panel.visible = inventory_open
	column.add_child(panel)
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	panel.add_child(box)
	_placeholder_grid = ISKInventoryGrid.new()
	_placeholder_grid.columns = 4
	_placeholder_grid.inventory = bag
	_placeholder_grid.slot_activated.connect(func(index: int) -> void: use_slot(index))
	box.add_child(_placeholder_grid)
	_add_placeholder_panels(box)
	_placeholder_panel = panel
	return layer
