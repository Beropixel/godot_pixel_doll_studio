@tool
extends EditorProperty
## A DollSlot's `bone`, picked from the skeleton of the skin being inspected
## (its character's Skeleton3D). A bone the skeleton lacks stays listed,
## marked missing.

const MISSING_SUFFIX := " (missing)"

## Bone names by character scene path, read once per editor session.
static var _bones_by_character: Dictionary[String, PackedStringArray] = {}

var _picker := OptionButton.new()


static func bones_of(character: PackedScene) -> PackedStringArray:
	if not character:
		return PackedStringArray()
	if not _bones_by_character.has(character.resource_path):
		var bones := PackedStringArray()
		var instance := character.instantiate()
		var skeleton := instance.find_child("Skeleton3D", true, false) as Skeleton3D
		if skeleton:
			for i in skeleton.get_bone_count():
				bones.push_back(skeleton.get_bone_name(i))
		instance.free()
		_bones_by_character[character.resource_path] = bones
	return _bones_by_character[character.resource_path]


func _init() -> void:
	_picker.clip_text = true
	_picker.item_selected.connect(_on_item_selected)
	add_child(_picker)
	add_focusable(_picker)


func _update_property() -> void:
	var current := String(get_edited_object().get(get_edited_property()))
	var skin := _inspected_skin()
	var bones := bones_of(skin.character) if skin else PackedStringArray()
	_picker.clear()
	for bone in bones:
		_picker.add_item(bone)
	if current != "" and not bones.has(current):
		_picker.add_item(current + MISSING_SUFFIX)
	for i in _picker.item_count:
		if _picker.get_item_text(i).trim_suffix(MISSING_SUFFIX) == current:
			_picker.select(i)
			return
	_picker.select(-1)


## The skin whose slot this is: the object the Inspector edits, or its
## `skin` (e.g. an army kind showing its skin inline).
func _inspected_skin() -> DollSkin:
	var edited := EditorInterface.get_inspector().get_edited_object()
	if edited is DollSkin:
		return edited
	return edited.get(&"skin") as DollSkin if edited else null


func _on_item_selected(index: int) -> void:
	emit_changed(get_edited_property(), StringName(_picker.get_item_text(index).trim_suffix(MISSING_SUFFIX)))
