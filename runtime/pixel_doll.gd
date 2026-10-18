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
## its skin changes (see DollSkin), once it's visible.

const TOON_SHADER := preload("res://addons/doll_studio/runtime/shaders/toon.gdshader")
const DEFAULT_STYLE := preload("res://addons/doll_studio/runtime/default_style.tres")
## Project setting: the .tres of the style dolls without one use (see
## project_style()).
const STYLE_SETTING := "doll_studio/default_style"
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


## The style for dolls given none: the .tres named by the doll_studio/
## default_style project setting, else the addon's default_style.tres.
static func project_style() -> DollStyle:
	var path: String = ProjectSettings.get_setting(STYLE_SETTING, "")
	if not path.is_empty() and ResourceLoader.exists(path):
		var project_wide := load(path) as DollStyle
		if project_wide:
			return project_wide
	return DEFAULT_STYLE


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


## Swaps in the skin's character, with the pieces in its slots and the clips
## of its rig, keeping the clip it was playing.
func _build() -> void:
	_needs_build = false
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
		var skeleton := _character.find_child("Skeleton3D", true, false) as Skeleton3D
		for slot in skin.slots:
			_hold(skeleton, slot)
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
	piece.transform = slot.offset * piece.transform
	attachment.add_child(piece)


func _apply_facing() -> void:
	scale.x = -absf(scale.x) if flipped else absf(scale.x)
	_apply_materials()


## Turns the character, frames it (feet the style's feet_offset px under the
## center) and restyles its surfaces.
func _apply_style() -> void:
	if not is_node_ready():
		return
	if _character:
		_character.rotation = Vector3(0.0, deg_to_rad(90.0 - _style.turn_degrees), 0.0)
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


func _on_skin_changed() -> void:
	_needs_build = true


func _disconnect_changed(resource: Resource) -> void:
	if not resource:
		return
	for callback: Callable in [_apply_style, _apply_materials]:
		if resource.changed.is_connected(callback):
			resource.changed.disconnect(callback)
