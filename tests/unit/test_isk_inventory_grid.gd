extends "res://tests/unit/isk_inventory_fixture.gd"
## ISKInventoryGrid: rebuild on changed, targeted refresh on slot_changed.

const THEME := preload("res://addons/inventory_save_kit/ui/theme/isk_default_theme.tres")

var _grid: ISKInventoryGrid


func before_each() -> void:
	super()
	_grid = ISKInventoryGrid.new()
	_grid.theme = THEME
	_grid.columns = 2
	add_child_autofree(_grid)
	_grid.inventory = _inv


func test_one_view_per_slot() -> void:
	assert_eq(_grid.get_slot_view_count(), 4)
	assert_eq(_grid.get_slot_view(3).index, 3)
	assert_null(_grid.get_slot_view(4))


func test_shrinking_rebuilds_on_changed() -> void:
	_inv.add_item(_sword)
	_inv.slot_count = 2
	assert_eq(_grid.get_slot_view_count(), 2)
	_inv.slot_count = 6
	assert_eq(_grid.get_slot_view_count(), 6)


func test_slot_changed_refreshes_only_that_view() -> void:
	var first := _grid.get_slot_view(0)
	_inv.add_item(_potion, 4)
	assert_same(_grid.get_slot_view(0), first)
	assert_eq(first.get_item_stack().count, 4)
	var label := first.find_children("*", "Label", true, false)[0] as Label
	assert_eq(label.text, "4")


func test_inventory_swap_and_null() -> void:
	var other := QuietInventory.new()
	other.slot_count = 3
	_grid.inventory = other
	assert_eq(_grid.get_slot_view_count(), 3)
	_inv.slot_count = 1
	assert_eq(_grid.get_slot_view_count(), 3)
	_grid.inventory = null
	assert_eq(_grid.get_slot_view_count(), 0)


func test_activation_selects_and_forwards() -> void:
	_inv.add_item(_potion)
	watch_signals(_grid)
	_grid.get_slot_view(0).slot_activated.emit(0)
	assert_signal_emitted_with_parameters(_grid, "slot_activated", [0])
	assert_eq(_grid.selected_index, 0)
	assert_true(_grid.get_slot_view(0).selected)
	assert_false(_grid.get_slot_view(1).selected)


func test_drag_between_grids() -> void:
	var chest := QuietInventory.new()
	chest.slot_count = 2
	var other := ISKInventoryGrid.new()
	add_child_autofree(other)
	other.inventory = chest
	_inv.add_item(_potion, 5)
	var data: Variant = _grid.get_slot_view(0)._get_drag_data(Vector2.ZERO)
	other.get_slot_view(1)._drop_data(Vector2.ZERO, data)
	assert_eq(chest.get_slot(1).count, 5)
	assert_null(_grid.get_slot_view(0).get_item_stack())
