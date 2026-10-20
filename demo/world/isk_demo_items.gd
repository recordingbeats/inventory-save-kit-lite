class_name ISKDemoItems
extends RefCounted
## Item database of the demo, built in code from the Kenney icons in [code]demo/art/items[/code].
##
## Item [member ISKItemDefinition.properties] used by the demo:
## [code]speed[/code] (walk speed bonus while equipped), [code]light[/code] (light
## radius while equipped), [code]boost[/code] (speed bonus for a few seconds when used).

const ICON_DIR := "res://demo/art/items/"

## Equipment slot tags of the full demo, in slot order.
const SLOT_TAGS: Array[StringName] = [&"weapon", &"shield", &"trinket"]


## Returns a new database with all demo items.
static func build() -> ISKItemDatabase:
	var db := ISKItemDatabase.new()
	var items: Array[ISKItemDefinition] = [
		make(&"gold_coin", "Gold Coin", "Shiny and heavy in numbers.", 99, 0.02),
		make(&"wood_log", "Wood Log", "Good for a campfire.", 10, 1.0),
		make(&"arrow", "Arrow", "Pointy end first.", 50, 0.05),
		make(&"health_potion", "Health Potion", "Restores your spirit.", 5, 0.3, [&"consumable"]),
		make(
			&"stamina_potion",
			"Stamina Potion",
			"Run faster for a few seconds.",
			5,
			0.3,
			[&"consumable"],
			{"boost": 80.0}
		),
		make(&"dagger", "Dagger", "Light blade, quick feet.", 1, 0.8, [&"weapon"], {"speed": 30.0}),
		make(
			&"broadsword",
			"Broadsword",
			"Heavy, slows you down.",
			1,
			3.5,
			[&"weapon"],
			{"speed": -20.0}
		),
		make(
			&"frost_staff",
			"Frost Staff",
			"Glows with a cold light.",
			1,
			1.5,
			[&"weapon"],
			{"light": 1.0}
		),
		make(&"buckler", "Buckler", "Small round shield.", 1, 2.0, [&"shield"]),
		make(
			&"iron_key",
			"Lucky Key",
			"Nobody knows the door. Feels lucky.",
			1,
			0.1,
			[&"trinket"],
			{"speed": 15.0}
		),
	]
	db.items = items
	return db


## Returns one item definition with the icon [code]<id>.png[/code].
static func make(
	id: StringName,
	display_name: String,
	description: String,
	max_stack: int,
	weight: float,
	tags: Array[StringName] = [],
	properties: Dictionary = {}
) -> ISKItemDefinition:
	var item := ISKItemDefinition.new()
	item.id = id
	item.display_name = display_name
	item.description = description
	item.max_stack = max_stack
	item.weight = weight
	item.tags = tags
	item.properties = properties
	item.icon = load(ICON_DIR + String(id) + ".png") as Texture2D
	return item
