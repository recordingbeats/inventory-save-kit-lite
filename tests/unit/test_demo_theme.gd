extends GutTest
## Demo theme (P9b): project-wide theme of the demo, text contrast ≥ 4.5:1 on
## its background (docs/ui-spec.md) and Nearest texture filter project-wide.

const THEME_PATH := "res://demo/ui/demo_theme.tres"

## [text type, colour item, background type, stylebox item]
const PAIRS: Array[Array] = [
	[&"Label", &"font_color", &"DemoWindow", &"panel"],
	[&"DemoTitle", &"font_color", &"DemoWindow", &"panel"],
	[&"DemoHeading", &"font_color", &"DemoWindow", &"panel"],
	[&"DemoHint", &"font_color", &"DemoWindow", &"panel"],
	[&"DemoHint", &"font_color", &"DemoScreen", &"panel"],
	[&"Button", &"font_color", &"Button", &"normal"],
	[&"Button", &"font_hover_color", &"Button", &"hover"],
	[&"Button", &"font_pressed_color", &"Button", &"pressed"],
	[&"Button", &"font_disabled_color", &"Button", &"disabled"],
	[&"ItemList", &"font_color", &"ItemList", &"panel"],
	[&"ItemList", &"font_hovered_color", &"ItemList", &"hovered"],
	[&"ItemList", &"font_selected_color", &"ItemList", &"selected"],
	[&"DemoToastLabel", &"font_color", &"DemoToast", &"panel"],
	[&"DemoToastErrorLabel", &"font_color", &"DemoToastError", &"panel"],
]

var _theme: Theme


func before_each() -> void:
	_theme = load(THEME_PATH) as Theme


func test_theme_is_project_theme() -> void:
	assert_eq(ProjectSettings.get_setting("gui/theme/custom"), THEME_PATH)


func test_texture_filter_is_nearest_project_wide() -> void:
	assert_eq(
		ProjectSettings.get_setting("rendering/textures/canvas_textures/default_texture_filter"), 0
	)


func test_text_contrast_at_least_4_5() -> void:
	for pair: Array in PAIRS:
		var fg := _theme_color(pair[0], pair[1])
		var box := _theme_box(pair[2], pair[3])
		assert_not_null(box, "%s/%s missing" % [pair[2], pair[3]])
		if box == null:
			continue
		var ratio := contrast(fg, box.bg_color)
		assert_gte(ratio, 4.5, "%s/%s on %s/%s: %.2f" % [pair[0], pair[1], pair[2], pair[3], ratio])


func test_buttons_show_keyboard_focus() -> void:
	var focus := _theme.get_stylebox(&"focus", &"Button") as StyleBoxFlat
	assert_not_null(focus)
	assert_gt(focus.border_width_top, 0)


## WCAG contrast ratio of two opaque colours.
static func contrast(a: Color, b: Color) -> float:
	var la := _luminance(a)
	var lb := _luminance(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _luminance(c: Color) -> float:
	var lin := func(v: float) -> float:
		return v / 12.92 if v <= 0.04045 else pow((v + 0.055) / 1.055, 2.4)
	return 0.2126 * lin.call(c.r) + 0.7152 * lin.call(c.g) + 0.0722 * lin.call(c.b)


func _theme_color(type: StringName, item: StringName) -> Color:
	var t := type
	while not _theme.has_color(item, t) and _theme.get_type_variation_base(t) != &"":
		t = _theme.get_type_variation_base(t)
	return _theme.get_color(item, t)


func _theme_box(type: StringName, item: StringName) -> StyleBoxFlat:
	var t := type
	while not _theme.has_stylebox(item, t) and _theme.get_type_variation_base(t) != &"":
		t = _theme.get_type_variation_base(t)
	return _theme.get_stylebox(item, t) as StyleBoxFlat
