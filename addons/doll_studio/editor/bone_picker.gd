@tool
extends EditorProperty
## A DollSlot's `bone`, picked from the skeleton of the skin being inspected
## (its character's Skeleton3D). A bone the skeleton lacks stays listed,
## marked missing.

## A bone the skeleton lacks, translated.
const MISSING_FORMAT := "%s (missing)"

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
	# Bone names, never translated.
	_picker.auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED
	_picker.item_selected.connect(_on_item_selected)
	add_child(_picker)
	add_focusable(_picker)


func _update_property() -> void:
	var current := String(get_edited_object().get(get_edited_property()))
	var skin := _inspected_skin()
	var bones := bones_of(skin.character) if skin else PackedStringArray()
	_picker.clear()
	for bone in bones:
		_add_bone(bone, bone)
	if current != "" and not bones.has(current):
		_add_bone(current, tr(MISSING_FORMAT) % current)
	for i in _picker.item_count:
		if _picker.get_item_metadata(i) == current:
			_picker.select(i)
			return
	_picker.select(-1)


func _add_bone(bone: String, text: String) -> void:
	_picker.add_item(text)
	_picker.set_item_metadata(_picker.item_count - 1, bone)


## The skin whose slot this is: the object the Inspector edits, or its
## `skin` (e.g. an army kind showing its skin inline).
func _inspected_skin() -> DollSkin:
	var edited := EditorInterface.get_inspector().get_edited_object()
	if edited is DollSkin:
		return edited
	return edited.get(&"skin") as DollSkin if edited else null


func _on_item_selected(index: int) -> void:
	emit_changed(get_edited_property(), StringName(_picker.get_item_metadata(index)))
