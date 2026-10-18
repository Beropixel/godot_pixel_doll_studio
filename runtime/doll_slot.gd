@tool
class_name DollSlot
extends Resource
## A piece a DollSkin's character wears on one of its bones: a weapon in a
## hand, a helm on the head, a cape on the chest… Any scene works, an
## imported model or one built from primitives.

## The Skeleton3D bone it follows.
@export var bone: StringName
@export var piece: PackedScene
## Where the piece sits in the bone's space; the identity puts the piece's
## own origin on the bone.
@export var offset := Transform3D.IDENTITY
