@tool
extends Node3D
## Doll Studio's workbench (doll_workbench.tscn): builds a DollSkin in the 3D
## editor to fit its pieces and make its clips with Godot's own tools. Move
## or rotate a piece (Character/…/Slot*/Piece*) with the 3D gizmos and its
## DollSlot.offset follows; pose the skeleton and key it in the Animation
## panel on the AnimationPlayer, which holds the skin's rig (imported .glb
## libraries are read-only). Saving the scene saves the skin and the rig's
## .tres libraries instead: what it builds, and the skin picked, never go
## into the scene file. Open it on a skin with open().

const WORKBENCH_SCENE := "res://addons/doll_studio/editor/doll_workbench.tscn"
const CHARACTER_NODE := &"Character"
const PLAYER_NODE := &"AnimationPlayer"

## The skin being worked on; picked here or by open(), never saved with the
## scene.
@export var skin: DollSkin:
	set(value):
		skin = value
		if is_node_ready():
			_rebuild()
@export_tool_button("Save Skin and Clips", "Save") var save_action := _save_resources

var _character: Node3D
var _player: AnimationPlayer
## Each piece built, with the slot it fills and the piece scene's own root
## transform (DollSlot.offset goes on top of it).
var _pieces: Array[Dictionary] = []
var _skin_changed := false
## The nodes it built and their owners, put back after a save.
var _owners_before_save: Dictionary[Node, Node] = {}


## Opens the workbench in the 3D editor on `skin`.
static func open(skin_to_open: DollSkin) -> void:
	EditorInterface.open_scene_from_path(WORKBENCH_SCENE)
	var workbench := EditorInterface.get_edited_scene_root()
	if workbench and workbench.scene_file_path == WORKBENCH_SCENE:
		workbench.set(&"skin", skin_to_open)
		EditorInterface.set_main_screen_editor("3D")


func _ready() -> void:
	_rebuild()


func _process(_delta: float) -> void:
	for built in _pieces:
		var piece: Node3D = built.piece
		if is_instance_valid(piece) and piece.transform != built.last:
			built.last = piece.transform
			(built.slot as DollSlot).offset = piece.transform * (built.base as Transform3D).affine_inverse()
			_skin_changed = true


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_EDITOR_PRE_SAVE:
			_save_resources()
			_hide_from_save()
		NOTIFICATION_EDITOR_POST_SAVE:
			_restore_after_save()


func _validate_property(property: Dictionary) -> void:
	if property.name == "skin":
		property.usage = PROPERTY_USAGE_EDITOR


## Builds the skin's character (unmirrored, facing +Z), its pieces and an
## AnimationPlayer with its rig, owned by the edited scene so they show in
## the Scene dock and the Animation panel.
func _rebuild() -> void:
	for node: Node in [_character, _player]:
		if is_instance_valid(node):
			remove_child(node)
			node.queue_free()
	_character = null
	_player = null
	_pieces.clear()
	_skin_changed = false
	if not skin or not skin.character:
		return
	var scene_root := _scene_root()
	_character = skin.character.instantiate() as Node3D
	_character.name = CHARACTER_NODE
	add_child(_character)
	_own(_character, scene_root)
	if scene_root:
		scene_root.set_editable_instance(_character, true)
	for mesh_name in skin.hidden_meshes:
		var hidden_mesh := _character.find_child(mesh_name, true, false) as Node3D
		if hidden_mesh:
			hidden_mesh.visible = false
	var skeleton := _character.find_child("Skeleton3D", true, false) as Skeleton3D
	for i in skin.slots.size():
		_add_piece(skeleton, skin.slots[i], i, scene_root)
	_player = AnimationPlayer.new()
	_player.name = PLAYER_NODE
	add_child(_player)
	_player.root_node = _player.get_path_to(_character)
	if skin.rig:
		for library_name in skin.rig.animations:
			_player.add_animation_library(library_name, skin.rig.animations[library_name])
	_own(_player, scene_root)


func _add_piece(skeleton: Skeleton3D, slot: DollSlot, index: int, scene_root: Node) -> void:
	if not skeleton or not slot or not slot.piece:
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = "Slot%d_%s" % [index, String(slot.bone).validate_node_name()]
	skeleton.add_child(attachment)
	attachment.bone_name = slot.bone
	var piece := slot.piece.instantiate() as Node3D
	piece.name = "Piece%d" % index
	var base := piece.transform
	piece.transform = slot.offset * base
	attachment.add_child(piece)
	_own(attachment, scene_root)
	_own(piece, scene_root)
	_pieces.push_back({piece = piece, slot = slot, base = base, last = piece.transform})


## Saves the skin when a piece moved, and the rig's libraries that are
## project .tres files (keys added in the Animation panel live there).
func _save_resources() -> void:
	if not skin:
		return
	if _skin_changed and skin.resource_path.get_extension() == "tres":
		ResourceSaver.save(skin)
		_skin_changed = false
	if skin.rig:
		for library: AnimationLibrary in skin.rig.animations.values():
			if library and library.resource_path.get_extension() == "tres":
				ResourceSaver.save(library)


## Unowns what it built, so the scene file keeps only the workbench itself.
func _hide_from_save() -> void:
	_owners_before_save.clear()
	var scene_root := _scene_root()
	if scene_root and is_instance_valid(_character):
		scene_root.set_editable_instance(_character, false)
	for node: Node in [_character, _player]:
		if is_instance_valid(node):
			_collect_owned(node, scene_root)
	for node in _owners_before_save:
		node.owner = null


func _restore_after_save() -> void:
	for node in _owners_before_save:
		if is_instance_valid(node):
			node.owner = _owners_before_save[node]
	_owners_before_save.clear()
	var scene_root := _scene_root()
	if scene_root and is_instance_valid(_character):
		scene_root.set_editable_instance(_character, true)


## Only the nodes it owns to the scene: an instanced model keeps its own.
func _collect_owned(node: Node, scene_root: Node) -> void:
	if scene_root and node.owner == scene_root:
		_owners_before_save[node] = node.owner
	for child in node.get_children():
		_collect_owned(child, scene_root)


func _own(node: Node, scene_root: Node) -> void:
	if scene_root:
		node.owner = scene_root


## The scene open in the editor when it's this workbench, else null (e.g.
## running outside the editor).
func _scene_root() -> Node:
	if not Engine.is_editor_hint():
		return null
	var edited := get_tree().edited_scene_root
	return edited if edited == self else null
