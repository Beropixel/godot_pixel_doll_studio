@tool
extends EditorPlugin
## Doll Studio's editor side: the "Doll Studio" main screen next to 2D, 3D
## and Script (see editor/doll_studio.gd), and the DollSkin/DollSlot
## inspector extras (see editor/skin_inspector.gd). The runtime (PixelDoll and
## its resources) needs nothing registered here: its class_names are global.

const DollStudio := preload("res://addons/doll_studio/editor/doll_studio.gd")
const SkinInspector := preload("res://addons/doll_studio/editor/skin_inspector.gd")
const STYLE_SETTING := PixelDoll.STYLE_SETTING

var _studio: DollStudio
var _skin_inspector: SkinInspector


func _enter_tree() -> void:
	_register_settings()
	_studio = DollStudio.new()
	_studio.name = "DollStudio"
	_studio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	EditorInterface.get_editor_main_screen().add_child(_studio)
	_studio.hide()
	_skin_inspector = SkinInspector.new()
	add_inspector_plugin(_skin_inspector)


func _exit_tree() -> void:
	if _skin_inspector:
		remove_inspector_plugin(_skin_inspector)
		_skin_inspector = null
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


## Project Settings › Doll Studio › Default Style: the .tres dolls without a
## style use (see PixelDoll.project_style()).
func _register_settings() -> void:
	if not ProjectSettings.has_setting(STYLE_SETTING):
		ProjectSettings.set_setting(STYLE_SETTING, "")
	ProjectSettings.set_initial_value(STYLE_SETTING, "")
	ProjectSettings.add_property_info({
		"name": STYLE_SETTING,
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_FILE,
		"hint_string": "*.tres",
	})
	ProjectSettings.set_as_basic(STYLE_SETTING, true)
