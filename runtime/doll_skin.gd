@tool
class_name DollSkin
extends Resource
## How a PixelDoll looks: a rigged 3D character and the pieces it wears on
## its bones (see DollSlot), which of its meshes it hides and which take the
## doll's palette (see DollPalette). One .tres per skin. It emits `changed`
## when any of it changes, its slots, rig and their contents included, so
## dolls showing it rebuild; assign a new `slots` array rather than editing
## it in place.

## English name, translated where it's shown.
@export var display_name: String = "":
	set(value):
		display_name = value
		emit_changed()
## A scene with a Skeleton3D inside, e.g. an imported .glb.
@export var character: PackedScene:
	set(value):
		character = value
		emit_changed()
## The clips it plays, made for its character's skeleton.
@export var rig: DollRig:
	set(value):
		_follow(rig, value)
		rig = value
		emit_changed()
## Mirrors the model, e.g. so the arm holding a shield faces the camera once
## the doll is turned (see DollStyle.turn_degrees).
@export var mirrored: bool = false:
	set(value):
		mirrored = value
		emit_changed()
@export var slots: Array[DollSlot] = []:
	set(value):
		for slot in slots:
			_follow(slot, null)
		slots = value
		for slot in slots:
			_follow(null, slot)
		emit_changed()
## The character's meshes (by node name) it doesn't draw, e.g. the helm a
## slot's piece replaces.
@export var hidden_meshes: Array[StringName] = []:
	set(value):
		hidden_meshes = value
		emit_changed()
## Meshes (by node name, in the character or any piece) whose texels near
## recolor_key take the doll's palette.
@export var recolored_meshes: Array[StringName] = []:
	set(value):
		recolored_meshes = value
		emit_changed()
## The hue the palette replaces on recolored_meshes.
@export var recolor_key: Color = Color(0.8, 0.1, 0.15):
	set(value):
		recolor_key = value
		emit_changed()


## Re-emits `changed` for `followed` instead of `unfollowed`.
func _follow(unfollowed: Resource, followed: Resource) -> void:
	if unfollowed and unfollowed.changed.is_connected(emit_changed):
		unfollowed.changed.disconnect(emit_changed)
	if followed and not followed.changed.is_connected(emit_changed):
		followed.changed.connect(emit_changed)
