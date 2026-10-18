@tool
extends EditorPlugin
## Doll Studio's editor side: the "Doll Studio" main screen next to 2D, 3D
## and Script (see editor/doll_studio.gd). The runtime (PixelDoll and its
## resources) needs nothing registered here: its class_names are global.

const DollStudio := preload("res://addons/doll_studio/editor/doll_studio.gd")

var _studio: DollStudio


func _enter_tree() -> void:
	_studio = DollStudio.new()
	_studio.name = "DollStudio"
	_studio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	EditorInterface.get_editor_main_screen().add_child(_studio)
	_studio.hide()


func _exit_tree() -> void:
	if _studio:
		_studio.queue_free()
		_studio = null


func _has_main_screen() -> bool:
	return true


func _make_visible(shown: bool) -> void:
	if _studio:
		_studio.visible = shown


func _get_plugin_name() -> String:
	return "Doll Studio"


func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_editor_theme().get_icon(&"Skeleton3D", &"EditorIcons")
