extends GutTest
## Doc test: the GDScript examples of the README run, so they cannot go stale.
##
## Every ```gdscript block of README.md (and README-LITE.md in the repo; the lite
## package ships it as README.md) is checked:
## - a block that starts with `extends` is a whole script and must compile;
## - any other block is a snippet: it is wrapped into a function and run.
##   A line `print(<expr>)  # <text>` becomes a check that str(<expr>) == <text>.
##   `ISKSave` is a fresh save manager with a temporary `save_dir`, so the
##   examples never touch the real autoload or the player's saves.
## Markers in the HTML comment right above a block:
## `<!-- doctest: skip -->` ignores the block, `<!-- doctest: continue -->`
## runs it after the previous snippet(s) of the same chain.

const READMES: PackedStringArray = ["res://README.md", "res://README-LITE.md"]
const PLUGIN := "res://addons/inventory_save_kit/plugin.gd"
const CHECK_RE := "^(\\s*)print\\((.*)\\)\\s*#\\s*(.+?)\\s*$"

var _dirs: PackedStringArray = []


func after_each() -> void:
	for dir: String in _dirs:
		if not DirAccess.dir_exists_absolute(dir):
			continue
		for f: String in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f))
		DirAccess.remove_absolute(dir)
	_dirs.clear()


## Returns the blocks of [param path] as {line, code, mode} with mode
## "script", "snippet", "continue" or "skip".
static func extract_blocks(text: String) -> Array[Dictionary]:
	var blocks: Array[Dictionary] = []
	var lines := text.split("\n")
	var marker := ""
	var i := 0
	while i < lines.size():
		var line := lines[i].strip_edges()
		if line.begins_with("<!-- doctest:"):
			marker = line.trim_prefix("<!-- doctest:").trim_suffix("-->").strip_edges()
		elif line == "```gdscript":
			var start := i + 1
			var code := PackedStringArray()
			i += 1
			while i < lines.size() and lines[i].strip_edges() != "```":
				code.append(lines[i])
				i += 1
			var body := "\n".join(code)
			var mode := "snippet"
			if marker == "skip":
				mode = "skip"
			elif (
				body.strip_edges().begins_with("extends")
				or body.strip_edges().begins_with("class_name")
			):
				mode = "script"
			elif marker == "continue":
				mode = "continue"
			blocks.append({"line": start, "code": body, "mode": mode})
			marker = ""
		elif line != "":
			marker = ""
		i += 1
	return blocks


## Wraps snippet [param code] into a script with
## `func run(__save: Node, __t: GutTest)`; `ISKSave` becomes `__save`.
static func wrap_snippet(code: String) -> String:
	var re := RegEx.create_from_string(CHECK_RE)
	var save_re := RegEx.create_from_string("\\bISKSave\\b")
	var out := PackedStringArray(["extends RefCounted", ""])
	out.append("func run(__save: Node, __t: GutTest) -> void:")
	for line: String in code.split("\n"):
		var m := re.search(line)
		if m:
			var expected := JSON.stringify(m.get_string(3))
			line = "%s__t.assert_eq(str(%s), %s)" % [m.get_string(1), m.get_string(2), expected]
		line = save_re.sub(line, "__save", true)
		out.append("\t" + line if line.strip_edges() != "" else "")
	out.append("\tpass")
	return "\n".join(out) + "\n"


func _readmes() -> PackedStringArray:
	var found := PackedStringArray()
	for path: String in READMES:
		if FileAccess.file_exists(path):
			found.append(path)
	return found


func test_readme_exists_and_has_examples() -> void:
	assert_true(FileAccess.file_exists(READMES[0]), "README.md ships with the project")
	var blocks := extract_blocks(FileAccess.get_file_as_string(READMES[0]))
	assert_gt(blocks.size(), 3, "README.md has GDScript examples")


func test_readme_examples() -> void:
	for path: String in _readmes():
		var chain := ""
		for block: Dictionary in extract_blocks(FileAccess.get_file_as_string(path)):
			var where := "%s:%d" % [path.get_file(), block.line]
			match block.mode:
				"skip":
					continue
				"script":
					_check_compiles(block.code, where)
				"snippet", "continue":
					chain = block.code if block.mode == "snippet" else chain + "\n" + block.code
					_run_snippet(chain, where)


func _compile(source: String, where: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = source
	var err := script.reload()
	assert_eq(err, OK, "%s compiles" % where)
	return script if err == OK else null


func _check_compiles(code: String, where: String) -> void:
	_compile(code, where)


func _run_snippet(code: String, where: String) -> void:
	var script := _compile(wrap_snippet(code), where)
	if script == null:
		return
	var manager_script: GDScript = load(load(PLUGIN).get_autoload_path())
	var manager: Node = manager_script.new()
	manager.save_dir = "user://isk_doctest_%d" % Time.get_ticks_usec()
	_dirs.append(manager.save_dir)
	add_child_autofree(manager)
	var before: int = get_assert_count()
	script.new().run(manager, self)
	gut.p("%s: %d checks" % [where, get_assert_count() - before])
	pass_test("%s ran" % where)
