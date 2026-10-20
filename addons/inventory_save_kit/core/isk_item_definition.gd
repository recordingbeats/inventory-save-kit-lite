class_name ISKItemDefinition
extends Resource
## Static description of an item type (sword, potion, ...).
##
## Create one resource per item type. Extend it for typed fields:
## [code]class_name Sword extends ISKItemDefinition[/code].
## Save files only store [member id], never resource paths, so [member id]
## must stay stable across game versions.

## Smallest allowed [member max_stack].
const MIN_STACK: int = 1
## Largest allowed [member max_stack].
const MAX_STACK: int = 9999

## Unique, stable identifier. Saves store it.
@export var id: StringName = &""
## Name shown to the player.
@export var display_name: String = ""
## Description shown to the player.
@export_multiline var description: String = ""
## Icon for slots and tooltips. Not part of [method to_dict].
@export var icon: Texture2D
## How many items fit into one stack.
@export_range(1, 9999) var max_stack: int = 1
## Weight of a single item.
@export var weight: float = 0.0
## Free tags, e.g. [code]&"weapon"[/code]; equipment slots filter by them.
@export var tags: Array[StringName] = []
## Free per-type data (damage, price, ...). Keep it JSON compatible.
@export var properties: Dictionary = {}


## Returns [code]true[/code] if this item can form stacks larger than one.
func is_stackable() -> bool:
	return max_stack > 1


## Returns [code]true[/code] if [member tags] contains [param tag].
func has_tag(tag: StringName) -> bool:
	return tags.has(tag)


## Returns a list of problems; empty means the definition is valid.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	if String(id).strip_edges().is_empty():
		errors.append("item id is empty")
	if max_stack < MIN_STACK or max_stack > MAX_STACK:
		errors.append(
			"item '%s': max_stack %d outside %d..%d" % [id, max_stack, MIN_STACK, MAX_STACK]
		)
	if weight < 0.0 or not is_finite(weight):
		errors.append("item '%s': weight must be a finite value >= 0" % id)
	return errors


## Returns a JSON-compatible dictionary of all fields except [member icon].
func to_dict() -> Dictionary:
	var tag_strings: Array[String] = []
	for tag: StringName in tags:
		tag_strings.append(String(tag))
	return {
		"id": String(id),
		"display_name": display_name,
		"description": description,
		"max_stack": max_stack,
		"weight": weight,
		"tags": tag_strings,
		"properties": properties.duplicate(true),
	}


## Builds a definition from [method to_dict] output (e.g. parsed JSON).
## Returns [code]null[/code] if [param d] is malformed or the result does not
## pass [method validate]. Missing optional keys keep their defaults.
static func from_dict(d: Dictionary) -> ISKItemDefinition:
	var raw_id: Variant = d.get("id")
	if not (raw_id is String or raw_id is StringName):
		return null
	var def := ISKItemDefinition.new()
	def.id = StringName(raw_id)
	var display: Variant = d.get("display_name", "")
	var desc: Variant = d.get("description", "")
	if not (display is String and desc is String):
		return null
	def.display_name = display
	def.description = desc
	var stack: Variant = _to_int(d.get("max_stack", 1))
	if stack == null:
		return null
	def.max_stack = stack
	var w: Variant = d.get("weight", 0.0)
	if not (w is float or w is int):
		return null
	def.weight = float(w)
	var raw_tags: Variant = d.get("tags", [])
	if not raw_tags is Array:
		return null
	for tag: Variant in raw_tags:
		if not (tag is String or tag is StringName):
			return null
		def.tags.append(StringName(tag))
	var props: Variant = d.get("properties", {})
	if not props is Dictionary:
		return null
	def.properties = (props as Dictionary).duplicate(true)
	if not def.validate().is_empty():
		return null
	return def


## Converts an int or an integral float (JSON numbers) to int, else null.
static func _to_int(value: Variant) -> Variant:
	if value is int:
		return value
	if value is float and is_finite(value) and value == floorf(value):
		return int(value)
	return null
