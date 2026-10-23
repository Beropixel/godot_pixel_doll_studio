@tool
extends EditorProperty
## A DollSkin's mesh-name list (hidden_meshes, recolored_meshes) as
## checkboxes: one per MeshInstance3D in its character, then in each slot's
## piece. A name listed but not found stays, marked missing, so unchecking
## it cleans it up.

## A name listed but not found, translated.
const MISSING_FORMAT := "%s (missing)"

## Mesh names by scene path, read once per editor session.
static var _meshes_by_scene: Dictionary[String, PackedStringArray] = {}

var _list := VBoxContainer.new()


static func meshes_of(scene: PackedScene) -> PackedStringArray:
	if not scene:
		return PackedStringArray()
	if not _meshes_by_scene.has(scene.resource_path):
		var names := PackedStringArray()
		var instance := scene.instantiate()
		for mesh in instance.find_children("*", "MeshInstance3D", true, false):
			names.push_back(mesh.name)
		if instance is MeshInstance3D:
			names.insert(0, instance.name)
		instance.free()
		_meshes_by_scene[scene.resource_path] = names
	return _meshes_by_scene[scene.resource_path]


func _init() -> void:
	add_child(_list)
	set_bottom_editor(_list)


func _update_property() -> void:
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var skin := get_edited_object() as DollSkin
	var listed: Array = skin.get(get_edited_property())
	var found := PackedStringArray()
	_add_group(tr("Character"), meshes_of(skin.character), listed, found)
	for i in skin.slots.size():
		var slot := skin.slots[i]
		if slot and slot.piece:
			_add_group(tr("Slot %d (%s)") % [i, slot.bone], meshes_of(slot.piece), listed, found)
	var missing := PackedStringArray()
	for mesh_name: StringName in listed:
		if not found.has(String(mesh_name)):
			missing.push_back(mesh_name)
	if not missing.is_empty():
		_add_group(tr("Not found", &"meshes"), missing, listed, found, true)


func _add_group(title: String, names: PackedStringArray, listed: Array, found: PackedStringArray, missing := false) -> void:
	if names.is_empty():
		return
	var header := Label.new()
	header.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	header.text = title
	header.add_theme_color_override(&"font_color", get_theme_color(&"font_disabled_color", &"Editor"))
	_list.add_child(header)
	for mesh_name in names:
		var check := CheckBox.new()
		# Mesh names, never translated.
		check.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
		check.text = tr(MISSING_FORMAT) % mesh_name if missing else mesh_name
		check.button_pressed = listed.has(StringName(mesh_name))
		check.toggled.connect(_on_toggled.bind(StringName(mesh_name)))
		_list.add_child(check)
		found.push_back(mesh_name)


func _on_toggled(is_listed: bool, mesh_name: StringName) -> void:
	var listed: Array[StringName] = []
	listed.assign(get_edited_object().get(get_edited_property()))
	if is_listed and not listed.has(mesh_name):
		listed.push_back(mesh_name)
	elif not is_listed:
		listed.erase(mesh_name)
	emit_changed(get_edited_property(), listed)
