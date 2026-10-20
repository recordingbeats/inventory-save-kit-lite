extends "res://tests/unit/isk_inventory_fixture.gd"
## ISKSlotView: drop logic (_can_drop_data/_drop_data), states, keyboard.

const THEME := preload("res://addons/inventory_save_kit/ui/theme/isk_default_theme.tres")

var _chest: QuietInventory


func before_each() -> void:
	super()
	_chest = QuietInventory.new()
	_chest.slot_count = 4


func _view(inventory: ISKInventory, index: int) -> ISKSlotView:
	var view := ISKSlotView.new()
	view.theme = THEME
	view.inventory = inventory
	view.index = index
	add_child_autofree(view)
	return view


func _drag(inventory: ISKInventory, index: int) -> Dictionary:
	return {"type": ISKSlotView.DRAG_TYPE, "inventory": inventory, "index": index}


func test_drop_into_empty_slot_of_other_inventory() -> void:
	_inv.add_item(_potion, 3)
	var target := _view(_chest, 2)
	assert_true(target._can_drop_data(Vector2.ZERO, _drag(_inv, 0)))
	watch_signals(target)
	target._drop_data(Vector2.ZERO, _drag(_inv, 0))
	assert_eq(_chest.get_slot(2).count, 3)
	assert_null(_inv.get_slot(0))
	assert_signal_emitted_with_parameters(target, "stack_dropped", [_inv, 0, 3])


func test_drop_inside_one_inventory_moves() -> void:
	_inv.add_item(_sword)
	var target := _view(_inv, 3)
	assert_true(target._can_drop_data(Vector2.ZERO, _drag(_inv, 0)))
	target._drop_data(Vector2.ZERO, _drag(_inv, 0))
	assert_eq(_counts(), [0, 0, 0, 1])


func test_wrong_tag_is_refused() -> void:
	var picky := PickyInventory.new()
	picky.slot_count = 2
	_inv.add_item(_potion, 2)
	var target := _view(picky, 0)
	assert_false(target._can_drop_data(Vector2.ZERO, _drag(_inv, 0)))
	target._drop_data(Vector2.ZERO, _drag(_inv, 0))
	assert_null(picky.get_slot(0))
	assert_eq(_inv.get_slot(0).count, 2)
	_inv.add_item(_sword)
	assert_true(target._can_drop_data(Vector2.ZERO, _drag(_inv, 1)))


func test_overweight_is_refused() -> void:
	_chest.max_weight = 2.0
	_inv.add_item(_sword)
	var target := _view(_chest, 0)
	assert_false(target._can_drop_data(Vector2.ZERO, _drag(_inv, 0)))
	target._drop_data(Vector2.ZERO, _drag(_inv, 0))
	assert_null(_chest.get_slot(0))
	assert_eq(_inv.get_slot(0).item, _sword)


func test_overweight_stack_moves_what_fits() -> void:
	_chest.max_weight = 1.0
	_inv.add_item(_potion, 5)
	var target := _view(_chest, 0)
	assert_eq(target.drop_amount(_drag(_inv, 0)), 2)
	target._drop_data(Vector2.ZERO, _drag(_inv, 0))
	assert_eq(_chest.get_slot(0).count, 2)
	assert_eq(_inv.get_slot(0).count, 3)


func test_stack_with_remainder_between_inventories() -> void:
	_inv.add_item(_potion, 6)
	_chest.add_item(_potion, 7)
	var target := _view(_chest, 0)
	assert_eq(target.drop_amount(_drag(_inv, 0)), 3)
	target._drop_data(Vector2.ZERO, _drag(_inv, 0))
	assert_eq(_chest.get_slot(0).count, 10)
	assert_eq(_inv.get_slot(0).count, 3)


func test_stack_with_remainder_inside_one_inventory() -> void:
	_inv.set_slot(0, ISKItemStack.new(_potion, 6))
	_inv.set_slot(1, ISKItemStack.new(_potion, 8))
	var target := _view(_inv, 1)
	assert_eq(target.drop_amount(_drag(_inv, 0)), 2)
	target._drop_data(Vector2.ZERO, _drag(_inv, 0))
	assert_eq(_counts(), [4, 10, 0, 0])


func test_full_stack_is_refused() -> void:
	_inv.add_item(_potion, 3)
	_chest.add_item(_potion, 10)
	assert_false(_view(_chest, 0)._can_drop_data(Vector2.ZERO, _drag(_inv, 0)))


func test_swap_between_inventories() -> void:
	_inv.add_item(_sword)
	_chest.add_item(_potion, 2)
	var target := _view(_chest, 0)
	assert_eq(target.drop_amount(_drag(_inv, 0)), 1)
	target._drop_data(Vector2.ZERO, _drag(_inv, 0))
	assert_eq(_chest.get_slot(0).item, _sword)
	assert_eq(_inv.get_slot(0).item, _potion)


func test_invalid_drag_data_is_refused() -> void:
	_inv.add_item(_potion)
	var target := _view(_chest, 0)
	assert_false(target._can_drop_data(Vector2.ZERO, null))
	assert_false(target._can_drop_data(Vector2.ZERO, {"type": &"other"}))
	assert_false(target._can_drop_data(Vector2.ZERO, _drag(_inv, 3)))
	assert_false(_view(_inv, 0)._can_drop_data(Vector2.ZERO, _drag(_inv, 0)))


func test_locked_slot_refuses_drop_and_drag() -> void:
	_inv.add_item(_potion, 2)
	var target := _view(_chest, 0)
	target.locked = true
	assert_false(target._can_drop_data(Vector2.ZERO, _drag(_inv, 0)))
	var source := _view(_inv, 0)
	source.locked = true
	assert_null(source._get_drag_data(Vector2.ZERO))
	assert_eq(source.get_state_variation(), &"ISKSlotLocked")
	assert_eq(source.mouse_default_cursor_shape, Control.CURSOR_FORBIDDEN)


func test_previews_match_operations() -> void:
	_inv.set_slot(0, ISKItemStack.new(_potion, 6))
	_inv.set_slot(1, ISKItemStack.new(_sword))
	_chest.set_slot(0, ISKItemStack.new(_potion, 9))
	_chest.max_weight = 6.0
	var preview: int = _inv.transfer_preview(0, _chest, -1)
	assert_eq(_inv.transfer(0, _chest, -1), preview)
	preview = _inv.transfer_preview(1, _chest, 1)
	assert_eq(_inv.transfer(1, _chest, 1), preview)
	preview = _inv.move_preview(0, 2)
	assert_gt(preview, 0)
	assert_true(_inv.move(0, 2))


func test_shows_icon_count_and_hides_single_count() -> void:
	_potion.icon = PlaceholderTexture2D.new()
	_inv.add_item(_potion, 3)
	var view := _view(_inv, 0)
	var labels: Array[Node] = view.find_children("*", "Label", true, false)
	assert_eq((labels[0] as Label).text, "3")
	_inv.remove_item(_potion, 2)
	view.refresh()
	assert_false((labels[0] as Label).visible)
	assert_eq(view.custom_minimum_size, Vector2(48, 48))


func test_drag_source_fades_icon() -> void:
	_inv.add_item(_potion, 2)
	var view := _view(_inv, 0)
	var data: Variant = view._get_drag_data(Vector2.ZERO)
	assert_eq(data, _drag(_inv, 0))
	assert_true(view.is_drag_source())
	var icon := view.find_children("*", "TextureRect", true, false)[0] as TextureRect
	assert_almost_eq(icon.modulate.a, 0.35, 0.001)
	assert_null(_view(_inv, 1)._get_drag_data(Vector2.ZERO))


func test_state_priority() -> void:
	var view := _view(_inv, 0)
	assert_eq(view.get_state_variation(), &"ISKSlot")
	view.grab_focus()
	assert_eq(view.get_state_variation(), &"ISKSlotHover")
	view.selected = true
	assert_eq(view.get_state_variation(), &"ISKSlotSelected")
	view.locked = true
	assert_eq(view.get_state_variation(), &"ISKSlotLocked")


func test_accept_and_double_click_activate() -> void:
	_inv.add_item(_potion)
	var view := _view(_inv, 0)
	watch_signals(view)
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	view._gui_input(accept)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.double_click = true
	view._gui_input(click)
	assert_signal_emit_count(view, "slot_activated", 2)
	assert_eq(view.focus_mode, Control.FOCUS_ALL)
