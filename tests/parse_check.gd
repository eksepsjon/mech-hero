extends Node
## Loads every script in the project (with autoloads active) so compile errors surface.
## Run: godot --headless res://tests/parse_check.tscn


func _ready() -> void:
	var failed := 0
	for path in _scripts("res://"):
		var s = load(path)
		if s == null or not (s as Script).can_instantiate():
			print("FAIL ", path)
			failed += 1
	print("parse_check: %d failure(s)" % failed)
	get_tree().quit(1 if failed > 0 else 0)


func _scripts(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		if not d.begins_with("."):
			out.append_array(_scripts(dir.path_join(d)))
	return out
