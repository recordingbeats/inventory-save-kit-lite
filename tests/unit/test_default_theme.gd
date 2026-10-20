extends GutTest
## Default theme: loads and keeps the type variations the UI code relies on
## (ARCHITECTURE.md §3.2, docs/ui-spec.md).

const THEME_PATH := "res://addons/inventory_save_kit/ui/theme/isk_default_theme.tres"

const VARIATIONS := {
	&"ISKSlot": &"PanelContainer",
	&"ISKSlotHover": &"ISKSlot",
	&"ISKSlotSelected": &"ISKSlot",
	&"ISKSlotLocked": &"ISKSlot",
	&"ISKCountLabel": &"Label",
	&"ISKTooltipPanel": &"PanelContainer",
	&"ISKTooltipTitle": &"Label",
	&"ISKTooltipBody": &"Label",
	&"ISKTooltipMeta": &"Label",
}

var _theme: Theme


func before_each() -> void:
	_theme = load(THEME_PATH) as Theme


func test_theme_loads() -> void:
	assert_not_null(_theme)


func test_type_variations_have_expected_base() -> void:
	for variation: StringName in VARIATIONS:
		assert_eq(
			_theme.get_type_variation_base(variation), VARIATIONS[variation], String(variation)
		)


func test_slot_panels_have_stylebox() -> void:
	for variation: StringName in [
		&"ISKSlot", &"ISKSlotHover", &"ISKSlotSelected", &"ISKSlotLocked", &"ISKTooltipPanel"
	]:
		assert_true(_theme.has_stylebox(&"panel", variation), String(variation))


func test_slot_states_keep_same_outer_size() -> void:
	# Switching state must not shift the layout: equal border + content margins.
	var base: StyleBox = _theme.get_stylebox(&"panel", &"ISKSlot")
	for variation: StringName in [&"ISKSlotHover", &"ISKSlotSelected", &"ISKSlotLocked"]:
		var box: StyleBox = _theme.get_stylebox(&"panel", variation)
		assert_eq(box.get_minimum_size(), base.get_minimum_size(), String(variation))


func test_slot_constants() -> void:
	assert_eq(_theme.get_constant(&"slot_size", &"ISKSlot"), 48)
	assert_eq(_theme.get_constant(&"icon_size", &"ISKSlot"), 32)
	assert_eq(_theme.get_constant(&"drag_source_alpha_percent", &"ISKSlot"), 35)
	assert_eq(_theme.get_constant(&"icon_alpha_percent", &"ISKSlotLocked"), 40)


func test_count_label_has_outline() -> void:
	assert_gt(_theme.get_constant(&"outline_size", &"ISKCountLabel"), 0)
