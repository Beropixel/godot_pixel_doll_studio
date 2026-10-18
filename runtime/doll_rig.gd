@tool
class_name DollRig
extends Resource
## A skeleton's clips: the animation libraries every DollSkin built on it
## plays (see DollSkin.rig). One .tres per rig, shared by its skins.

## By library name ("" for the default library), e.g. an imported
## AnimationLibrary and one with clips made for the game.
@export var animations: Dictionary[StringName, AnimationLibrary] = {}
