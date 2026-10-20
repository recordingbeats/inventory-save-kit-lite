class_name ISKItemDatabase
extends Resource
## All item definitions of a game, looked up by [member ISKItemDefinition.id].
##
## Required to load saves: save files contain item IDs, never resource paths.
## If two items share an ID, the first one wins; [method validate] reports it.

## The known items. After changing the array in place call [method rebuild_index].
@export var items: Array[ISKItemDefinition] = []:
	set(value):
		items = value
		_index_dirty = true

var _index: Dictionary = {}
var _index_dirty: bool = true


## Returns the item with [param id] or [code]null[/code] if it is unknown.
func get_item(id: StringName) -> ISKItemDefinition:
	if _index_dirty or _index.size() > items.size():
		rebuild_index()
	var found: ISKItemDefinition = _index.get(id)
	if found != null and found.id == id:
		return found
	# Cache may be stale after in-place edits of items; rebuild once.
	rebuild_index()
	return _index.get(id)


## Returns [code]true[/code] if an item with [param id] exists.
func has_item(id: StringName) -> bool:
	return get_item(id) != null


## Rebuilds the ID lookup. Call it after editing [member items] in place.
func rebuild_index() -> void:
	_index.clear()
	for item: ISKItemDefinition in items:
		if item != null and not _index.has(item.id):
			_index[item.id] = item
	_index_dirty = false


## Returns a list of problems (null entries, empty or duplicate IDs, invalid
## items); empty means the database is valid.
func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	var seen: Dictionary = {}
	for i: int in items.size():
		var item: ISKItemDefinition = items[i]
		if item == null:
			errors.append("items[%d] is null" % i)
			continue
		if seen.has(item.id) and not String(item.id).strip_edges().is_empty():
			errors.append(
				"duplicate item id '%s' at items[%d] and items[%d]" % [item.id, seen[item.id], i]
			)
		else:
			seen[item.id] = i
		for problem: String in item.validate():
			errors.append("items[%d]: %s" % [i, problem])
	return errors


## Returns a JSON-compatible dictionary with all definitions.
func to_dict() -> Dictionary:
	var out: Array[Dictionary] = []
	for item: ISKItemDefinition in items:
		if item != null:
			out.append(item.to_dict())
	return {"items": out}


## Builds a database from [method to_dict] output. Returns [code]null[/code] if
## [param d] is malformed, an entry is invalid or IDs are duplicated.
static func from_dict(d: Dictionary) -> ISKItemDatabase:
	var raw: Variant = d.get("items")
	if not raw is Array:
		return null
	var defs: Array[ISKItemDefinition] = []
	for entry: Variant in raw:
		if not entry is Dictionary:
			return null
		var def := ISKItemDefinition.from_dict(entry)
		if def == null:
			return null
		defs.append(def)
	var db := ISKItemDatabase.new()
	db.items = defs
	if not db.validate().is_empty():
		return null
	return db
