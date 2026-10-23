@tool
extends EditorPlugin
## Doll Studio's editor side: the "Doll Studio" main screen next to 2D, 3D
## and Script (see editor/doll_studio.gd), the DollSkin/DollSlot inspector
## extras (see editor/skin_inspector.gd) and the workbench's pixel preview,
## at the 3D editor's side while the workbench is open (see
## editor/workbench_preview.gd). Its UI is in English, translated by the .po
## files in translations/ (added to the editor's own translation domain, so
## they follow the editor's language). The runtime (PixelDoll and
## its resources) needs nothing registered here: its class_names are global.

const DollStudio := preload("res://addons/doll_studio/editor/doll_studio.gd")
const SkinInspector := preload("res://addons/doll_studio/editor/skin_inspector.gd")
const WorkbenchPreview := preload("res://addons/doll_studio/editor/workbench_preview.gd")
const DollWorkbench := preload("res://addons/doll_studio/editor/doll_workbench.gd")
const STYLE_SETTING := PixelDoll.STYLE_SETTING
const TRANSLATIONS_DIR := "res://addons/doll_studio/translations/"
## Where the editor looks up the text of its controls, the plugin's included.
const EDITOR_DOMAIN := &"godot.editor"

var _studio: DollStudio
var _skin_inspector: SkinInspector
var _workbench_preview: WorkbenchPreview
var _translations: Array[Translation] = []


func _enter_tree() -> void:
	_register_settings()
	_add_translations()
	_studio = DollStudio.new()
	_studio.name = "DollStudio"
	_studio.size_flags_vertical = Control.SIZE_EXPAND_FILL
	EditorInterface.get_editor_main_screen().add_child(_studio)
	_studio.hide()
	_skin_inspector = SkinInspector.new()
	add_inspector_plugin(_skin_inspector)
	_workbench_preview = WorkbenchPreview.new()
	add_control_to_container(CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT, _workbench_preview)
	scene_changed.connect(_on_scene_changed)
	_on_scene_changed(EditorInterface.get_edited_scene_root())


func _exit_tree() -> void:
	if _workbench_preview:
		remove_control_from_container(CONTAINER_SPATIAL_EDITOR_SIDE_RIGHT, _workbench_preview)
		_workbench_preview.queue_free()
		_workbench_preview = null
	if _skin_inspector:
		remove_inspector_plugin(_skin_inspector)
		_skin_inspector = null
	if _studio:
		_studio.queue_free()
		_studio = null
	_remove_translations()


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


## Loads translations/*.po into the editor's domain, before the UI is built.
func _add_translations() -> void:
	var domain := TranslationServer.get_or_add_domain(EDITOR_DOMAIN)
	for file in ResourceLoader.list_directory(TRANSLATIONS_DIR):
		if file.get_extension() != "po":
			continue
		var translation := load(TRANSLATIONS_DIR + file) as Translation
		if translation:
			domain.add_translation(translation)
			_translations.push_back(translation)
		else:
			push_error("Doll Studio couldn't load the translation %s" % file)


func _remove_translations() -> void:
	var domain := TranslationServer.get_or_add_domain(EDITOR_DOMAIN)
	for translation in _translations:
		domain.remove_translation(translation)
	_translations.clear()


func _on_scene_changed(scene_root: Node) -> void:
	var is_workbench := scene_root != null and scene_root.scene_file_path == DollWorkbench.WORKBENCH_SCENE
	_workbench_preview.follow(scene_root as Node3D if is_workbench else null)
