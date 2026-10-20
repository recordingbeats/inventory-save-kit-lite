extends GutTest
## Scripted play test of the lite demo world: walk over pickups, save, change the
## world, load → same state. Uses its own save manager and directory.

const SCENE := "res://demo/lite/main_lite.tscn"


## Records warnings instead of printing them (the test log must stay warning-free).
class QuietManager:
	extends ISKSaveManager
	var warnings: PackedStringArray = []

	func _warn(message: String) -> void:
		warnings.append(message)


var world: ISKDemoWorld
var manager: QuietManager


func before_each() -> void:
	manager = QuietManager.new()
	manager.save_dir = "user://isk_test_demo_lite_%d" % Time.get_ticks_usec()
	add_child_autofree(manager)
	world = (load(SCENE) as PackedScene).instantiate() as ISKDemoWorld
	world.save_manager = manager
	add_child_autofree(world)
	await wait_physics_frames(2)


func after_each() -> void:
	var dir := manager.save_dir
	if DirAccess.dir_exists_absolute(dir):
		for f: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f))
		DirAccess.remove_absolute(dir)


## Walks the player onto the placed pickup [param pickup_id].
func walk_to_pickup(pickup_id: String) -> void:
	world.player.walk_to(world.get_pickup(pickup_id).position)
	await wait_until(func() -> bool: return not world.player.is_walking_to(), 10.0)
	await wait_physics_frames(3)


func test_pickup_save_load_restores_the_same_state() -> void:
	await walk_to_pickup("coins")
	await walk_to_pickup("dagger")
	assert_eq(world.bag.count_of(&"gold_coin"), 12, "coins picked up")
	assert_eq(world.bag.count_of(&"dagger"), 1, "dagger picked up")
	assert_false(world.get_pickup("coins").is_active(), "coins gone from the world")
	var before := world.snapshot()
	assert_eq(world.save_to("slot_1"), OK)

	await walk_to_pickup("arrows")
	var coin_slot := _slot_of(&"gold_coin")
	assert_eq(world.drop_from_bag(coin_slot, 5), 5)
	assert_eq(world.bag.count_of(&"gold_coin"), 7)
	assert_ne(world.snapshot(), before, "world changed after saving")

	assert_eq(world.load_from("slot_1"), OK)
	await wait_physics_frames(2)
	assert_eq(world.snapshot(), before, "load restores bag, pickups, drops and position")
	assert_true(world.get_pickup("arrows").is_active(), "arrows back in the world")
	assert_eq(world.active_pickup_count(), 4)
	assert_eq(manager.warnings, PackedStringArray())


func test_dropped_items_are_saved_and_can_be_picked_up_again() -> void:
	await walk_to_pickup("coins")
	world.player.facing = Vector2.RIGHT
	assert_eq(world.drop_from_bag(_slot_of(&"gold_coin")), 12)
	assert_eq(world.bag.count_of(&"gold_coin"), 0)
	assert_eq(world.save_to("slot_1"), OK)
	var saved := world.snapshot()
	assert_eq((saved["drops"] as Array).size(), 1, "drop is part of the world state")

	world.new_game()
	assert_eq(world.load_from("slot_1"), OK)
	await wait_physics_frames(2)
	assert_eq(world.snapshot(), saved)
	# walk away and back: the drop is picked up again
	world.player.walk_to(world.player.position + Vector2(-30, 0))
	await wait_until(func() -> bool: return not world.player.is_walking_to(), 5.0)
	world.player.walk_to(world.player.position + Vector2(44, 0))
	await wait_until(func() -> bool: return not world.player.is_walking_to(), 5.0)
	await wait_physics_frames(3)
	assert_eq(world.bag.count_of(&"gold_coin"), 12)


func test_potion_boosts_speed_and_is_consumed() -> void:
	await walk_to_pickup("stamina_potions")
	var base := world.player.get_speed()
	assert_true(world.use_slot(_slot_of(&"stamina_potion")))
	assert_eq(world.bag.count_of(&"stamina_potion"), 1)
	assert_gt(world.player.get_speed(), base)


func test_new_game_resets_the_world() -> void:
	await walk_to_pickup("coins")
	world.new_game()
	assert_eq(world.bag.count_of(&"gold_coin"), 0)
	assert_true(world.get_pickup("coins").is_active())
	assert_eq(world.player.position, (world.get_node(^"Start") as Node2D).position)


func test_placeholder_ui_and_inventory_toggle() -> void:
	assert_not_null(world.ui, "lite demo UI (save indicator) instanced")
	assert_not_null(world.get_node_or_null(^"PlaceholderUI"), "lite keeps the placeholder bag grid")
	watch_signals(world)
	world.toggle_inventory()
	assert_true(world.inventory_open)
	assert_false(world.player.input_enabled, "player stops while the inventory is open")
	assert_signal_emitted_with_parameters(world, "inventory_toggled", [true])


func test_lite_ui_shows_saves_of_the_world_manager() -> void:
	var indicator: Control = world.ui.get("indicator")
	assert_not_null(indicator)
	assert_eq(world.save_to("slot_1"), OK)
	assert_eq(indicator.call(&"get_message"), "Game saved")
	assert_eq(world.load_from("slot_1"), OK)
	assert_eq(indicator.call(&"get_message"), "Game loaded")


func test_tab_closes_the_bag_while_a_slot_has_focus() -> void:
	world.set_inventory_open(true)
	var grid: ISKInventoryGrid = world.get(&"_placeholder_grid")
	await wait_process_frames(1)
	grid.get_slot_view(0).grab_focus()
	var tab := InputEventKey.new()
	tab.keycode = KEY_TAB
	tab.physical_keycode = KEY_TAB
	tab.pressed = true
	get_viewport().push_input(tab)
	assert_false(world.inventory_open, "Tab closes the bag instead of moving focus")


func _slot_of(item_id: StringName) -> int:
	for i in world.bag.slot_count:
		var stack := world.bag.get_slot(i)
		if stack != null and stack.item.id == item_id:
			return i
	return -1
