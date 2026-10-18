@tool
class_name DollSkin
extends Resource
## How a PixelDoll looks: a rigged 3D character and the pieces it wears on
## its bones (see DollSlot), which of its meshes it hides and which take the
## doll's palette (see DollPalette). One .tres per skin.

## English name, translated where it's shown.
@export var display_name: String = ""
## A scene with a Skeleton3D inside, e.g. an imported .glb.
@export var character: PackedScene
## The clips it plays, made for its character's skeleton.
@export var rig: DollRig
## Mirrors the model, e.g. so the arm holding a shield faces the camera once
## the doll is turned (see DollStyle.turn_degrees).
@export var mirrored: bool = false
@export var slots: Array[DollSlot] = []
## The character's meshes (by node name) it doesn't draw, e.g. the helm a
## slot's piece replaces.
@export var hidden_meshes: Array[StringName] = []
## Meshes (by node name, in the character or any piece) whose texels near
## recolor_key take the doll's palette.
@export var recolored_meshes: Array[StringName] = []
## The hue the palette replaces on recolored_meshes.
@export var recolor_key: Color = Color(0.8, 0.1, 0.15)
