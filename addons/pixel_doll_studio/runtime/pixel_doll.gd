@tool
class_name PixelDoll
extends Sprite2D
## A rigged 3D character drawn as pixel art: its skin's character and the
## pieces on its bones (see DollSkin), rendered by its own 96x64 SubViewport
## (wide enough for a body lying down) and shown with a 1px outline
## (outline.gdshader). Its surfaces are flattened and lit in flat bands, its
## recolored texels painted in its palette (toon.gdshader), and parts in
## front get inner lines (inner_lines.gdshader). It plays its skin's clips
## (see DollRig) in steps, re-rendering only on a new pose (see
## DollStyle.frames_per_second). A Sprite2D, so its owner shakes, flips and
## tints it like any sprite; an AnimationPlayer outside can start its clips
## through an animation track on Viewport/AnimationPlayer. It rebuilds when
## its skin changes (see DollSkin), once it's visible; when only slot offsets
## changed, it just moves the pieces. It looks one of 8 ways on screen (see
## direction), the model turned, not mirrored.

## Where it looks on screen, clockwise from right; down is towards the camera.
enum Direction { RIGHT, DOWN_RIGHT, DOWN, DOWN_LEFT, LEFT, UP_LEFT, UP, UP_RIGHT }

const TOON_SHADER := preload("res://addons/pixel_doll_studio/runtime/shaders/toon.gdshader")
const DEFAULT_STYLE := preload("res://addons/pixel_doll_studio/runtime/default_style.tres")
## Project setting: the .tres of the style dolls without one use (see
## project_style()).
const STYLE_SETTING := "pixel_doll_studio/default_style"
## The skin's character, where its AnimationPlayer's root_node points.
const CHARACTER_NODE := &"Character"
## How far the camera stands back from what it looks at.
const CAMERA_DISTANCE := 10.0

## One per style, skin, source material, palette, facing and recoloring,
## shared by every doll that matches.
static var _materials: Dictionary[String, ShaderMaterial] = {}

## How it's drawn; without one, the project's style (see project_style()).
@export var style: DollStyle:
	set(value):
		style = value
		_use_style(value if value else project_style())
@export var skin: DollSkin:
	set(value):
		if skin and skin.changed.is_connected(_on_skin_changed):
			skin.changed.disconnect(_on_skin_changed)
		skin = value
		if skin:
			skin.changed.connect(_on_skin_changed)
		if is_node_ready():
			_build()
## Faces left instead of right: the render is mirrored, and so is the light,
## so it's still lit from where it faces.
@export var flipped: bool = false:
	set(value):
		flipped = value
		if is_node_ready():
			_apply_facing()
## Turns the model to look this way: unlike `flipped`, LEFT shows its other
## side. The style's turn_degrees bends it towards the camera as much as it
## looks sideways, so RIGHT and LEFT keep the style's 3/4 view; UP shows its
## back.
@export var direction := Direction.RIGHT:
	set(value):
		direction = value
		_turn_character()
## The shades its skin's recolored texels take; without one they keep their
## own colors.
@export var palette: DollPalette:
	set(value):
		_disconnect_changed(palette)
		palette = value
		if palette:
			palette.changed.connect(_apply_materials)
		_apply_materials()

var _character: Node3D
var _skeleton: Skeleton3D
## Each piece held, with its slot and the piece scene's own root transform.
var _pieces: Array[Dictionary] = []
## What the character was built from (see _skin_signature()).
var _built_signature := ""
## The style in effect: `style`, else the project's.
var _style: DollStyle
## Time since the last pose shown.
var _step_time := 0.0
## Its skin changed: rebuild once it's visible (see _process).
var _needs_build := false

## Plays its clips, in steps (see _process).
@onready var animation_player: AnimationPlayer = $Viewport/AnimationPlayer
@onready var _viewport: SubViewport = $Viewport
@onready var _camera: Camera3D = $Viewport/Camera3D
@onready var _inner_lines: MeshInstance3D = $Viewport/Camera3D/InnerLines


## The style for dolls given none: the .tres named by the pixel_doll_studio/
## default_style project setting, else the addon's default_style.tres.
static func project_style() -> DollStyle:
	var path: String = ProjectSettings.get_setting(STYLE_SETTING, "")
	if not path.is_empty() and ResourceLoader.exists(path):
		var project_wide := load(path) as DollStyle
		if project_wide:
			return project_wide
	return DEFAULT_STYLE


## The Direction closest to `vector`, e.g. a velocity on screen (+y down).
static func direction_of(vector: Vector2) -> Direction:
	return wrapi(roundi(vector.angle() / (PI / 4.0)), 0, 8) as Direction


func _ready() -> void:
	if not _style:
		_use_style(project_style())
	_build()
	_apply_facing()


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	if _needs_build:
		_build()
	if not animation_player.is_playing():
		return
	_step_time += delta
	var step: float = 1.0 / _style.frames_per_second
	if _step_time < step:
		return
	var steps := floorf(_step_time / step)
	animation_player.advance(steps * step)
	_step_time -= steps * step
	_request_render()


## Shows `clip` (a name in its skin's rig) frozen at `time`, e.g. to scrub
## through it; play it again with animation_player.play().
func pose(clip: StringName, time: float) -> void:
	if not animation_player.has_animation(clip):
		return
	animation_player.play(clip)
	animation_player.seek(time, true)
	animation_player.pause()
	_request_render()


## Takes `source`'s current bone poses, e.g. a skeleton being posed in the
## editor, and shows them. Stop its own clips first, or they overwrite the
## pose. The skeletons must share a rig (same bones, same order).
func match_pose(source: Skeleton3D) -> void:
	if not _skeleton or not source or source.get_bone_count() != _skeleton.get_bone_count():
		return
	for bone in source.get_bone_count():
		_skeleton.set_bone_pose_position(bone, source.get_bone_pose_position(bone))
		_skeleton.set_bone_pose_rotation(bone, source.get_bone_pose_rotation(bone))
		_skeleton.set_bone_pose_scale(bone, source.get_bone_pose_scale(bone))
	_request_render()


## Swaps in the skin's character, with the pieces in its slots and the clips
## of its rig, keeping the clip it was playing.
func _build() -> void:
	_needs_build = false
	_built_signature = _skin_signature()
	_pieces.clear()
	_skeleton = null
	var clip := animation_player.current_animation
	var position_in_clip := animation_player.current_animation_position if clip else 0.0
	_apply_rig()
	if _character:
		_viewport.remove_child(_character)
		_character.queue_free()
		_character = null
	var has_character := skin != null and skin.character != null
	if has_character:
		_character = skin.character.instantiate() as Node3D
		_character.name = CHARACTER_NODE
		if skin.mirrored:
			_character.scale.x = -1.0
		_viewport.add_child(_character)
		_skeleton = _character.find_child("Skeleton3D", true, false) as Skeleton3D
		for slot in skin.slots:
			_hold(_skeleton, slot)
		for mesh_name in skin.hidden_meshes:
			var hidden_mesh := _character.find_child(mesh_name, true, false) as Node3D
			if hidden_mesh:
				hidden_mesh.visible = false
			else:
				push_error("%s has no mesh named %s to hide" % [skin.resource_path, mesh_name])
	# Without a character its tracks have nothing to animate.
	animation_player.active = has_character
	if has_character:
		animation_player.clear_caches()
	if clip and has_character and animation_player.has_animation(clip):
		animation_player.play(clip)
		animation_player.seek(position_in_clip, true)
	_apply_style()


func _apply_rig() -> void:
	for library_name in animation_player.get_animation_library_list():
		animation_player.remove_animation_library(library_name)
	if skin and skin.rig:
		for library_name in skin.rig.animations:
			animation_player.add_animation_library(library_name, skin.rig.animations[library_name])


func _hold(skeleton: Skeleton3D, slot: DollSlot) -> void:
	if not slot or not slot.piece:
		return
	var attachment := BoneAttachment3D.new()
	skeleton.add_child(attachment)
	attachment.bone_name = slot.bone
	var piece := slot.piece.instantiate() as Node3D
	var base := piece.transform
	piece.transform = slot.offset * base
	attachment.add_child(piece)
	_pieces.push_back({piece = piece, slot = slot, base = base})


func _apply_facing() -> void:
	scale.x = -absf(scale.x) if flipped else absf(scale.x)
	_apply_materials()


## Turns the character, frames it (feet the style's feet_offset px under the
## center) and restyles its surfaces.
func _apply_style() -> void:
	if not is_node_ready():
		return
	_turn_character()
	var pitch := deg_to_rad(_style.pitch_degrees)
	_camera.size = _style.camera_size
	# A point dh above the feet shows dh * cos(pitch) higher on screen.
	var center_height: float = _style.feet_offset * _style.camera_size / _viewport.size.y / cos(pitch)
	_camera.transform = Transform3D(Basis.from_euler(Vector3(-pitch, 0.0, 0.0)), Vector3(0.0, center_height, 0.0)) \
			.translated_local(Vector3(0.0, 0.0, CAMERA_DISTANCE))
	var lines := (_inner_lines.mesh as QuadMesh).material as ShaderMaterial
	lines.set_shader_parameter(&"depth_threshold", _style.inner_line_threshold)
	lines.set_shader_parameter(&"line_brightness", _style.inner_line_brightness)
	_apply_materials()


## Turns the character (built facing +Z, the camera) to look `direction`,
## bent towards the camera by the style's turn_degrees times how much the
## direction looks sideways.
func _turn_character() -> void:
	if not _character:
		return
	var heading: float = direction * 45.0
	var bent := heading + _style.turn_degrees * cos(deg_to_rad(heading))
	_character.rotation = Vector3(0.0, deg_to_rad(90.0 - bent), 0.0)
	_request_render()


func _apply_materials() -> void:
	if not is_node_ready():
		return
	if _character:
		for node in _character.find_children("*", "MeshInstance3D", true, false):
			var mesh_instance := node as MeshInstance3D
			var source := mesh_instance.mesh.surface_get_material(0) as BaseMaterial3D
			mesh_instance.material_override = _get_material(source,
					palette != null and skin.recolored_meshes.has(StringName(mesh_instance.name)))
	_request_render()


## A toon version of `source`, its texture and color (shared by every
## instance of its model or piece).
func _get_material(source: BaseMaterial3D, recolored: bool) -> ShaderMaterial:
	var key := "%d:%d:%d:%d:%d:%d" % [_style.get_instance_id(), skin.get_instance_id(),
			source.get_instance_id() if source else 0, palette.get_instance_id() if recolored else 0,
			int(flipped), int(recolored)]
	var toon: ShaderMaterial = _materials.get(key)
	if not toon:
		toon = ShaderMaterial.new()
		toon.shader = TOON_SHADER
		_materials[key] = toon
	var light: Vector3 = _style.light_direction
	if flipped:
		light.x = -light.x
	toon.set_shader_parameter(&"albedo_texture", source.albedo_texture if source else null)
	toon.set_shader_parameter(&"albedo_color", source.albedo_color if source else Color.WHITE)
	toon.set_shader_parameter(&"light_direction", light)
	toon.set_shader_parameter(&"light_bands", _style.light_bands)
	toon.set_shader_parameter(&"shadow_brightness", _style.shadow_brightness)
	toon.set_shader_parameter(&"highlight_brightness", _style.highlight_brightness)
	toon.set_shader_parameter(&"shadow_tint", _style.shadow_tint)
	toon.set_shader_parameter(&"highlight_tint", _style.highlight_tint)
	toon.set_shader_parameter(&"albedo_steps", _style.albedo_steps)
	toon.set_shader_parameter(&"recolored", recolored)
	if recolored:
		toon.set_shader_parameter(&"recolor_key", skin.recolor_key)
		toon.set_shader_parameter(&"palette_light", palette.light)
		toon.set_shader_parameter(&"palette_mid", palette.mid)
		toon.set_shader_parameter(&"palette_dark", palette.dark)
	return toon


func _use_style(new_style: DollStyle) -> void:
	_disconnect_changed(_style)
	_style = new_style
	_style.changed.connect(_apply_style)
	_apply_style()


func _request_render() -> void:
	if is_node_ready():
		_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


## Everything about its skin but the slot offsets: when it's unchanged,
## moving the pieces is enough.
func _skin_signature() -> String:
	if not skin:
		return ""
	var parts := PackedStringArray([str(skin.character.get_instance_id() if skin.character else 0),
			str(skin.rig.get_instance_id() if skin.rig else 0), str(skin.mirrored), str(skin.hidden_meshes),
			str(skin.recolored_meshes), str(skin.recolor_key)])
	for slot in skin.slots:
		parts.push_back("%s@%s" % [slot.piece.get_instance_id() if slot and slot.piece else 0, slot.bone if slot else &""])
	return "|".join(parts)


func _move_pieces() -> void:
	for held in _pieces:
		var piece: Node3D = held.piece
		if is_instance_valid(piece):
			piece.transform = (held.slot as DollSlot).offset * (held.base as Transform3D)
	_request_render()


func _on_skin_changed() -> void:
	if not _needs_build and is_node_ready() and _skin_signature() == _built_signature:
		_move_pieces()
	else:
		_needs_build = true


func _disconnect_changed(resource: Resource) -> void:
	if not resource:
		return
	for callback: Callable in [_apply_style, _apply_materials]:
		if resource.changed.is_connected(callback):
			resource.changed.disconnect(callback)
