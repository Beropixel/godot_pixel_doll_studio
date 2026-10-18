@tool
extends RefCounted
## Finds the project's .tres files of given script classes (DollSkin,
## DollPalette…) by reading each file's header line, without loading them.


## .tres paths under res:// by script class, for each class in
## `script_classes` (an empty list when none is found).
static func find(script_classes: PackedStringArray) -> Dictionary[String, PackedStringArray]:
	var found: Dictionary[String, PackedStringArray] = {}
	for script_class in script_classes:
		found[script_class] = PackedStringArray()
	_scan_dir(EditorInterface.get_resource_filesystem().get_filesystem(), found)
	return found


## The script_class a .tres declares in its header line, or "".
static func read_script_class(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
	var header := file.get_line()
	var start := header.find("script_class=\"")
	if start == -1:
		return ""
	start += "script_class=\"".length()
	return header.substr(start, header.find("\"", start) - start)


static func _scan_dir(dir: EditorFileSystemDirectory, found: Dictionary[String, PackedStringArray]) -> void:
	if not dir:
		return
	for i in dir.get_file_count():
		var path := dir.get_file_path(i)
		if path.get_extension() == "tres":
			var script_class := read_script_class(path)
			if found.has(script_class):
				found[script_class].push_back(path)
	for i in dir.get_subdir_count():
		_scan_dir(dir.get_subdir(i), found)
