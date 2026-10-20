class_name ISKInventoryGrid
extends GridContainer
## Shows an [ISKInventory] as a grid of [ISKSlotView]s (one per slot).
##
## Rebuilds the slot views when the slot count changes (shrinking
## [member ISKInventory.slot_count] only emits [signal Resource.changed]) and
## refreshes single views on [signal ISKInventory.slot_changed]. Drag & drop
## works between any grids, also across inventories. Keyboard: arrow keys move
## the focus between slots (Godot focus neighbours), [code]ui_accept[/code]
## activates a slot. Set [member GridContainer.columns] for the layout; looks
## come from the theme (see [ISKSlotView]).

## Emitted when a slot is double-clicked or activated with
## [code]ui_accept[/code].
signal slot_activated(index: int)

## The inventory to show; [code]null[/code] shows nothing.
@export var inventory: ISKInventory:
	set(value):
		if inventory == value:
			return
		_disconnect_inventory()
		inventory = value
		_connect_inventory()
		_rebuild()

## Mark the last activated slot as selected.
@export var select_on_activate: bool = true

## Index of the selected slot, -1 = none.
var selected_index: int = -1:
	set(value):
		selected_index = value
		_restyle_all()

var _views: Array[ISKSlotView] = []
var _dragged: ISKItemStack = null


func _ready() -> void:
	_rebuild()


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			_dragged = _drag_stack(get_viewport().gui_get_drag_data())
			_restyle_all()
		NOTIFICATION_DRAG_END:
			_dragged = null
			_restyle_all()


## Returns the view of slot [param index], or [code]null[/code].
func get_slot_view(index: int) -> ISKSlotView:
	return _views[index] if index >= 0 and index < _views.size() else null


## Number of slot views currently shown.
func get_slot_view_count() -> int:
	return _views.size()


## Virtual: adjusts [param view] after a refresh and when a drag starts or ends.
## [param dragged] is the stack being dragged (any grid) or [code]null[/code].
## Default: selected look for [member selected_index]. Subclasses (equipment
## grid in the full edition) add their own states here.
func _style_slot(view: ISKSlotView, _dragged_stack: ISKItemStack) -> void:
	view.selected = view.index == selected_index


func _connect_inventory() -> void:
	if inventory == null:
		return
	inventory.changed.connect(_on_inventory_changed)
	inventory.slot_changed.connect(_on_slot_changed)


func _disconnect_inventory() -> void:
	if inventory == null:
		return
	if inventory.changed.is_connected(_on_inventory_changed):
		inventory.changed.disconnect(_on_inventory_changed)
	if inventory.slot_changed.is_connected(_on_slot_changed):
		inventory.slot_changed.disconnect(_on_slot_changed)


func _on_inventory_changed() -> void:
	if inventory == null or _views.size() != inventory.slot_count:
		_rebuild()


func _on_slot_changed(index: int) -> void:
	var view: ISKSlotView = get_slot_view(index)
	if view == null:
		_rebuild()
		return
	view.refresh()
	_style_slot(view, _dragged)


func _rebuild() -> void:
	for view: ISKSlotView in _views:
		view.hide()
		view.queue_free()
	_views.clear()
	if inventory == null:
		return
	if selected_index >= inventory.slot_count:
		selected_index = -1
	for i: int in inventory.slot_count:
		var view := ISKSlotView.new()
		view.name = "Slot%d" % i
		view.inventory = inventory
		view.index = i
		view.slot_activated.connect(_on_slot_activated)
		add_child(view)
		_views.append(view)
		_style_slot(view, _dragged)


func _restyle_all() -> void:
	for view: ISKSlotView in _views:
		_style_slot(view, _dragged)


func _on_slot_activated(index: int) -> void:
	if select_on_activate:
		selected_index = index
	slot_activated.emit(index)


static func _drag_stack(data: Variant) -> ISKItemStack:
	if not data is Dictionary:
		return null
	var d: Dictionary = data
	if d.get("type") != ISKSlotView.DRAG_TYPE or not d.get("inventory") is ISKInventory:
		return null
	var from_inventory: ISKInventory = d["inventory"]
	return from_inventory.get_slot(int(d.get("index", -1)))
