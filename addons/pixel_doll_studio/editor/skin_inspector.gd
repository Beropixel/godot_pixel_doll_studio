@tool
extends EditorInspectorPlugin
## Inspector extras for DollSkin and DollSlot: a skin opens with its doll
## playing its idle clip and a button to fit it on the workbench (see
## doll_workbench.gd), and its mesh lists are checklists of its meshes (see
## mesh_checklist.gd); a slot's `bone` is picked from the skin's skeleton
## (see bone_picker.gd).

const BonePicker := preload("res://addons/pixel_doll_studio/editor/bone_picker.gd")
const MeshChecklist := preload("res://addons/pixel_doll_studio/editor/mesh_checklist.gd")
## The DollSkin properties shown as mesh checklists.
const MESH_LISTS: Array[String] = ["hidden_meshes", "recolored_meshes"]
const DollWorkbench := preload("res://addons/pixel_doll_studio/editor/doll_workbench.gd")
const DOLL_SCENE := preload("res://addons/pixel_doll_studio/runtime/pixel_doll.tscn")
const THUMBNAIL_ZOOM := 2


func _can_handle(object: Object) -> bool:
	return object is DollSkin or object is DollSlot


func _parse_begin(object: Object) -> void:
	var skin := object as DollSkin
	if not skin:
		return
	var header := VBoxContainer.new()
	if skin.character:
		header.add_child(Thumbnail.new(skin))
	var open_button := Button.new()
	open_button.text = "Open in Workbench"
	open_button.tooltip_text = "Fit the pieces and make clips in the 3D editor."
	open_button.disabled = skin.resource_path.is_empty()
	open_button.pressed.connect(DollWorkbench.open.bind(skin))
	header.add_child(open_button)
	add_custom_control(header)


func _parse_property(object: Object, _type: Variant.Type, name: String, _hint_type: PropertyHint,
		_hint_string: String, _usage_flags: int, _wide: bool) -> bool:
	if object is DollSlot and name == "bone":
		add_property_editor(name, BonePicker.new())
		return true
	if object is DollSkin and name in MESH_LISTS:
		add_property_editor(name, MeshChecklist.new())
		return true
	return false


## The skin's doll at THUMBNAIL_ZOOM, playing its idle clip on a loop (the
## rig's first clip named like "idle", else its first clip).
class Thumbnail extends SubViewportContainer:
	var _doll: PixelDoll
	var _clip: StringName

	func _init(skin: DollSkin) -> void:
		custom_minimum_size = Vector2(96, 64) * THUMBNAIL_ZOOM
		stretch = true
		var viewport := SubViewport.new()
		viewport.transparent_bg = true
		viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
		add_child(viewport)
		_doll = DOLL_SCENE.instantiate()
		_doll.skin = skin
		_doll.scale = Vector2(THUMBNAIL_ZOOM, THUMBNAIL_ZOOM)
		_doll.position = custom_minimum_size * 0.5
		viewport.add_child(_doll)
		_clip = _idle_clip(skin)

	func _process(_delta: float) -> void:
		if _clip != &"" and _doll.is_node_ready() and not _doll.animation_player.is_playing():
			_doll.animation_player.play(_clip)

	func _idle_clip(skin: DollSkin) -> StringName:
		if not skin.rig:
			return &""
		var first := &""
		for library_name in skin.rig.animations:
			for animation_name in skin.rig.animations[library_name].get_animation_list():
				var clip := StringName(String(animation_name) if library_name.is_empty() else "%s/%s" % [library_name, animation_name])
				if first == &"":
					first = clip
				if String(animation_name).to_lower().contains("idle"):
					return clip
		return first
