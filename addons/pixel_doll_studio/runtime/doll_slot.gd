@tool
class_name DollSlot
extends Resource
## A piece a DollSkin's character wears on one of its bones: a weapon in a
## hand, a helm on the head… Any scene works, an imported model or one built
## from primitives. Changing it emits `changed`, and so does its skin.

## The Skeleton3D bone it follows.
@export var bone: StringName:
	set(value):
		bone = value
		emit_changed()
@export var piece: PackedScene:
	set(value):
		piece = value
		emit_changed()
## Where the piece sits in the bone's space; the identity puts the piece's
## own origin on the bone.
@export var offset := Transform3D.IDENTITY:
	set(value):
		offset = value
		emit_changed()
