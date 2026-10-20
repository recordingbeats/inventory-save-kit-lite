class_name ISKSlotView
extends PanelContainer
## Shows one slot of an [ISKInventory]: icon, count and state, with drag & drop.
##
## Dragging a slot onto another slot calls [method ISKInventory.move] inside one
## inventory and [method ISKInventory.transfer] between inventories (bags,
## equipment, chests). [method _can_drop_data] refuses drops that would move
## nothing (wrong tag, weight limit, full stack), so Godot shows the forbidden
## cursor. Keyboard: the slot is focusable (focus looks like hover),
## [code]ui_accept[/code] or a double click emits [signal slot_activated].
## [br]Full edition: filled slots show an item tooltip and a right click splits
## the stack (amount dialog; Shift + right click = half). The view finds these
## full-only scripts by file presence ([constant TOOLTIP_PATH],
## [constant SPLIT_PATH]), so the lite edition simply has neither.
## [br]All looks come from the theme type variations [code]ISKSlot[/code],
## [code]ISKSlotHover[/code], [code]ISKSlotSelected[/code],
## [code]ISKSlotLocked[/code] and [code]ISKCountLabel[/code]
## (see [code]docs/ui-spec.md[/code]); the view never sets colours, sizes or a
## texture filter itself.

## Emitted on double click or [code]ui_accept[/code] (e.g. "use" or "equip").
signal slot_activated(index: int)
## Emitted on the target slot after a drop moved [param moved] items into it
## from slot [param from_index] of [param from_inventory].
signal stack_dropped(from_inventory: ISKInventory, from_index: int, moved: int)

## Key that marks drag data created by an [ISKSlotView].
const DRAG_TYPE := &"isk_slot"
## Tooltip script of the full edition; slots show no tooltip without it.
const TOOLTIP_PATH := "res://addons/inventory_save_kit/ui/isk_tooltip.gd"
## Split dialog script of the full edition; right click does nothing without it.
const SPLIT_PATH := "res://addons/inventory_save_kit/ui/isk_split_dialog.gd"

static var _edition_scripts: Dictionary = {}

## The inventory this view shows a slot of.
var inventory: ISKInventory:
	set(value):
		inventory = value
		refresh()

## Slot index in [member inventory].
var index: int = -1:
	set(value):
		index = value
		refresh()

## Selected look (activated slot, slot picked for split, equipment in use).
var selected: bool = false:
	set(value):
		selected = value
		_update_look()

## Locked slot: dimmed icon, forbidden cursor, no drag and no drop.
var locked: bool = false:
	set(value):
		locked = value
		_update_look()

var _icon: TextureRect
var _count: Label
var _hovered: bool = false
var _drop_valid: bool = false
var _drag_source: bool = false


func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_icon, false, Node.INTERNAL_MODE_FRONT)
	_count = Label.new()
	_count.theme_type_variation = &"ISKCountLabel"
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_count, false, Node.INTERNAL_MODE_FRONT)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(_update_look)
	focus_exited.connect(_update_look)
	_update_look()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_THEME_CHANGED:
			var side: int = get_theme_constant(&"slot_size", &"ISKSlot")
			custom_minimum_size = Vector2(side, side)
			_update_look()
		NOTIFICATION_DRAG_END:
			_drag_source = false
			_drop_valid = false
			_update_look()


## Returns the stack shown by this view, or [code]null[/code] if empty.
func get_item_stack() -> ISKItemStack:
	return inventory.get_slot(index) if inventory != null else null


## Re-reads icon and count from [member inventory]. The grid calls it on
## [signal ISKInventory.slot_changed].
func refresh() -> void:
	var stack: ISKItemStack = get_item_stack()
	_icon.texture = stack.item.icon if stack != null else null
	_count.text = str(stack.count) if stack != null and stack.count > 1 else ""
	_count.visible = _count.text != ""
	# Godot only asks _make_custom_tooltip when the tooltip text is not empty
	var has_tooltip: bool = stack != null and edition_script(TOOLTIP_PATH) != null
	tooltip_text = item_label(stack.item) if has_tooltip else ""
	_update_look()


## Name of the theme type variation for the current state (priority
## locked > selected > hover; the drag source only fades the icon).
func get_state_variation() -> StringName:
	if locked:
		return &"ISKSlotLocked"
	if selected:
		return &"ISKSlotSelected"
	if _hovered or _drop_valid or has_focus():
		return &"ISKSlotHover"
	return &"ISKSlot"


## Returns [code]true[/code] while this slot's stack is being dragged.
func is_drag_source() -> bool:
	return _drag_source


## Right click action: splits the stack (full edition) – [param half] splits half
## at once, else the amount dialog opens. Returns [code]true[/code] if it split
## or opened the dialog, [code]false[/code] if refused (locked, empty, single
## item, no free slot) or in the lite edition.
func request_split(half: bool) -> bool:
	var script: Script = edition_script(SPLIT_PATH)
	if locked or script == null or get_item_stack() == null:
		return false
	return script.call(&"handle_right_click", self, half)


## Name shown for [param item]: its display name, or its ID if the name is empty.
static func item_label(item: ISKItemDefinition) -> String:
	return item.display_name if item.display_name != "" else String(item.id)


## Returns the full-edition script at [param path], or [code]null[/code] if the
## edition does not ship it (cached).
static func edition_script(path: String) -> Script:
	if not _edition_scripts.has(path):
		_edition_scripts[path] = load(path) as Script if ResourceLoader.exists(path) else null
	return _edition_scripts[path]


func _make_custom_tooltip(_for_text: String) -> Object:
	var script: Script = edition_script(TOOLTIP_PATH)
	if script == null:
		return null
	return script.call(&"for_stack", get_item_stack())


func _get_drag_data(_at_position: Vector2) -> Variant:
	var stack: ISKItemStack = get_item_stack()
	if locked or stack == null:
		return null
	if get_viewport() != null and get_viewport().gui_is_dragging():
		set_drag_preview(_make_drag_preview(stack))
	_drag_source = true
	_update_look()
	return {"type": DRAG_TYPE, "inventory": inventory, "index": index}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	_drop_valid = drop_amount(data) > 0
	_update_look()
	return _drop_valid


func _drop_data(_at_position: Vector2, data: Variant) -> void:
	_drop_valid = false
	var moved: int = drop_amount(data)
	if moved > 0:
		var from_inventory: ISKInventory = data["inventory"]
		var from_index: int = data["index"]
		if from_inventory == inventory:
			moved = moved if from_inventory.move(from_index, index) else 0
		else:
			moved = from_inventory.transfer(from_index, inventory, index)
		if moved > 0:
			stack_dropped.emit(from_inventory, from_index, moved)
	_update_look()


## How many items a drop of [param data] (from [method _get_drag_data]) would
## move into this slot; 0 = refused. Changes nothing.
func drop_amount(data: Variant) -> int:
	if locked or inventory == null or not _is_slot_drag(data):
		return 0
	var from_inventory: ISKInventory = data["inventory"]
	var from_index: int = data["index"]
	if from_inventory == inventory:
		return inventory.move_preview(from_index, index)
	return from_inventory.transfer_preview(from_index, inventory, index)


func _gui_input(event: InputEvent) -> void:
	if locked or get_item_stack() == null:
		return
	var double_click: bool = (
		event is InputEventMouseButton
		and (event as InputEventMouseButton).double_click
		and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	)
	if double_click or event.is_action_pressed(&"ui_accept"):
		slot_activated.emit(index)
		accept_event()
		return
	var mouse := event as InputEventMouseButton
	if mouse != null and mouse.pressed and mouse.button_index == MOUSE_BUTTON_RIGHT:
		if request_split(mouse.shift_pressed):
			accept_event()


func _set_hovered(value: bool) -> void:
	_hovered = value
	if not value:
		_drop_valid = false
	_update_look()


func _update_look() -> void:
	theme_type_variation = get_state_variation()
	mouse_default_cursor_shape = (Control.CURSOR_FORBIDDEN if locked else Control.CURSOR_ARROW)
	var alpha: float = 1.0
	if locked:
		alpha = get_theme_constant(&"icon_alpha_percent", &"ISKSlotLocked") / 100.0
	elif _drag_source:
		alpha = get_theme_constant(&"drag_source_alpha_percent", &"ISKSlot") / 100.0
	_icon.modulate.a = alpha


func _make_drag_preview(stack: ISKItemStack) -> Control:
	var side: int = get_theme_constant(&"icon_size", &"ISKSlot")
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon := TextureRect.new()
	icon.texture = stack.item.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size = Vector2(side, side)
	icon.position = -icon.size / 2.0
	root.add_child(icon)
	if stack.count > 1:
		var count := Label.new()
		count.theme_type_variation = &"ISKCountLabel"
		count.text = str(stack.count)
		count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		count.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		count.size = icon.size
		count.position = icon.position
		root.add_child(count)
	return root


static func _is_slot_drag(data: Variant) -> bool:
	if not data is Dictionary:
		return false
	var d: Dictionary = data
	return (
		d.get("type") == DRAG_TYPE and d.get("inventory") is ISKInventory and d.get("index") is int
	)
