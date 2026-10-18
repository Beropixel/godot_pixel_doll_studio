@tool
extends VBoxContainer
## The Doll Studio main screen: previews a DollSkin as a PixelDoll, in a
## palette and a style, facing right, left or both, and plays or scrubs its
## rig's clips (Space plays or pauses, ← and → step a pose, Home goes back to
## the start); Workbench opens the skin in the 3D editor (see
## doll_workbench.gd). The style picked is edited in the side inspector and
## restyles every doll using it; the addon's own style is read-only, copy it
## into a project style to tune it. Skins, palettes and styles are found by
## scanning the project's .tres files, again whenever the file system
## changes, and the preview follows edits to the skin shown. What's picked
## is remembered per project.

const DOLL_SCENE := preload("res://addons/doll_studio/runtime/pixel_doll.tscn")
const DollWorkbench := preload("res://addons/doll_studio/editor/doll_workbench.gd")
const ResourceScan := preload("res://addons/doll_studio/editor/resource_scan.gd")
## Script classes the scan collects, by the .tres header's script_class.
const SKIN_CLASS := "DollSkin"
const PALETTE_CLASS := "DollPalette"
const STYLE_CLASS := "DollStyle"
const ADDON_DIR := "res://addons/doll_studio/"
const DEFAULT_STYLE_PATH := "res://addons/doll_studio/runtime/default_style.tres"
## How see-through the onion skin's previous pose is.
const ONION_ALPHA := 0.35
const DEFAULT_BACKGROUND := Color("#4f6b46")
## The facing picker's items: which way each shown doll faces (flipped).
const FACINGS: Array[Array] = [[false], [true], [false, true]]
## Where the picks are remembered, in the editor's project metadata.
const METADATA_SECTION := "doll_studio"

## .tres paths found by the scan, by script class.
var _paths: Dictionary[String, PackedStringArray] = {}
var _dolls: Array[PixelDoll] = []
## One per doll, showing the pose a step before while paused.
var _onions: Array[PixelDoll] = []
var _playing := true
## The skin shown, followed so its clips and notice stay current.
var _watched_skin: DollSkin
## A style just created, to pick once the scan finds it.
var _pending_style_path := ""

var _skin_picker := OptionButton.new()
var _palette_picker := OptionButton.new()
var _facing_picker := OptionButton.new()
var _clip_picker := OptionButton.new()
var _style_picker := OptionButton.new()
var _viewport := SubViewport.new()
var _background := ColorRect.new()
var _notice := Label.new()
var _style_notice := VBoxContainer.new()
var _style_dialog := EditorFileDialog.new()
var _inspector: EditorInspector
var _play_button := Button.new()
var _loop_check := CheckBox.new()
var _onion_check := CheckBox.new()
var _timeline := HSlider.new()
var _time_label := Label.new()
var _zoom_spin := SpinBox.new()
var _background_picker := ColorPickerButton.new()


func _ready() -> void:
	_build_ui()
	_restore_view()
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_rescan)
	_rescan()


func _process(_delta: float) -> void:
	if not is_visible_in_tree() or _dolls.is_empty():
		return
	var player := _dolls[0].animation_player
	if _playing:
		if not player.is_playing() and _loop_check.button_pressed:
			_play_from(0.0)
		elif not player.is_playing():
			_set_playing(false)
		_timeline.set_value_no_signal(player.current_animation_position if player.current_animation else 0.0)
	_time_label.text = "%.2f / %.2f s" % [_timeline.value, _timeline.max_value]


func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if not key or not key.pressed or not is_visible_in_tree():
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		return
	match key.keycode:
		KEY_SPACE:
			if key.echo:
				return
			_on_play_pressed()
		KEY_LEFT:
			_on_step(-1)
		KEY_RIGHT:
			_on_step(1)
		KEY_HOME:
			_timeline.value = 0.0
		_:
			return
	get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var toolbar := HFlowContainer.new()
	add_child(toolbar)
	_add_labeled(toolbar, "Skin", _skin_picker, _on_skin_selected)
	var edit_skin := Button.new()
	edit_skin.text = "Edit Skin"
	edit_skin.tooltip_text = "Open the skin in the Inspector."
	edit_skin.pressed.connect(_on_edit_skin_pressed)
	toolbar.add_child(edit_skin)
	var workbench := Button.new()
	workbench.text = "Workbench"
	workbench.tooltip_text = "Fit the skin's pieces and make clips in the 3D editor."
	workbench.pressed.connect(_on_workbench_pressed)
	toolbar.add_child(workbench)
	_add_labeled(toolbar, "Palette", _palette_picker, _on_palette_selected)
	_add_labeled(toolbar, "Facing", _facing_picker, _on_facing_selected)
	for facing_name in ["Right", "Left", "Both"]:
		_facing_picker.add_item(facing_name)
	_facing_picker.select(2)
	_add_labeled(toolbar, "Clip", _clip_picker, _on_clip_selected)
	_add_labeled(toolbar, "Style", _style_picker, _on_style_selected)

	var split := HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	var preview := SubViewportContainer.new()
	preview.stretch = true
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	preview.resized.connect(_layout_dolls)
	split.add_child(preview)
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	preview.add_child(_viewport)
	_background.color = DEFAULT_BACKGROUND
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(_background)
	_notice.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE, Control.PRESET_MODE_MINSIZE, 16)
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var notice_settings := LabelSettings.new()
	notice_settings.outline_size = 4
	notice_settings.outline_color = Color.BLACK
	_notice.label_settings = notice_settings
	_viewport.add_child(_notice)

	var side := VBoxContainer.new()
	side.custom_minimum_size.x = 300.0
	split.add_child(side)
	var style_notice_text := Label.new()
	style_notice_text.text = "This is the addon's built-in style: it's read-only, so updating the addon can't undo your changes. Copy it into a project style to tune it; every doll without a style of its own will use that one."
	style_notice_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_style_notice.add_child(style_notice_text)
	var create_style := Button.new()
	create_style.text = "Create Project Style…"
	create_style.pressed.connect(_style_dialog.popup_file_dialog)
	_style_notice.add_child(create_style)
	side.add_child(_style_notice)
	_inspector = EditorInspector.create_default_inspector()
	_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side.add_child(_inspector)
	_style_dialog.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE
	_style_dialog.access = EditorFileDialog.ACCESS_RESOURCES
	_style_dialog.filters = PackedStringArray(["*.tres ; Doll Style"])
	_style_dialog.current_file = "doll_style.tres"
	_style_dialog.title = "Create Project Style"
	_style_dialog.file_selected.connect(_create_project_style)
	add_child(_style_dialog)

	var transport := HBoxContainer.new()
	add_child(transport)
	_play_button.flat = true
	_play_button.tooltip_text = "Play or pause the clip (Space)."
	_play_button.pressed.connect(_on_play_pressed)
	transport.add_child(_play_button)
	transport.add_child(_make_icon_button(&"PlayStartBackwards", "Previous pose (←)", _on_step.bind(-1)))
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_timeline.step = 0.0
	_timeline.value_changed.connect(_on_timeline_changed)
	transport.add_child(_timeline)
	transport.add_child(_make_icon_button(&"PlayStart", "Next pose (→)", _on_step.bind(1)))
	_time_label.custom_minimum_size.x = 110.0
	transport.add_child(_time_label)
	_loop_check.text = "Loop"
	_loop_check.button_pressed = true
	_loop_check.toggled.connect(_on_loop_toggled)
	transport.add_child(_loop_check)
	_onion_check.text = "Onion Skin"
	_onion_check.tooltip_text = "While paused, show the pose a step before, see-through."
	_onion_check.toggled.connect(_on_onion_toggled)
	transport.add_child(_onion_check)
	transport.add_child(_make_label("Zoom"))
	_zoom_spin.min_value = 1.0
	_zoom_spin.max_value = 8.0
	_zoom_spin.value = 4.0
	_zoom_spin.suffix = "x"
	_zoom_spin.value_changed.connect(_on_zoom_changed)
	transport.add_child(_zoom_spin)
	_background_picker.color = DEFAULT_BACKGROUND
	_background_picker.custom_minimum_size.x = 48.0
	_background_picker.tooltip_text = "Background color."
	_background_picker.color_changed.connect(_on_background_changed)
	transport.add_child(_background_picker)
	_set_playing(true)


func _add_labeled(parent: Control, text: String, picker: OptionButton, on_selected: Callable) -> void:
	parent.add_child(_make_label(text))
	picker.custom_minimum_size.x = 140.0
	picker.item_selected.connect(on_selected.unbind(1))
	parent.add_child(picker)


func _make_label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	return label


func _make_icon_button(icon_name: StringName, tooltip: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.flat = true
	button.icon = get_theme_icon(icon_name, &"EditorIcons")
	button.tooltip_text = tooltip
	button.pressed.connect(on_pressed)
	return button


## Puts the remembered view settings back (the pickers' picks come back with
## the scan, see _rescan).
func _restore_view() -> void:
	_facing_picker.select(int(_recall("facing", 2)))
	_zoom_spin.set_value_no_signal(float(_recall("zoom", 4.0)))
	_background_picker.color = _recall("background", DEFAULT_BACKGROUND)
	_background.color = _background_picker.color
	_loop_check.set_pressed_no_signal(bool(_recall("loop", true)))
	_onion_check.set_pressed_no_signal(bool(_recall("onion", false)))


func _remember(key: String, value: Variant) -> void:
	EditorInterface.get_editor_settings().set_project_metadata(METADATA_SECTION, key, value)


func _recall(key: String, default: Variant) -> Variant:
	return EditorInterface.get_editor_settings().get_project_metadata(METADATA_SECTION, key, default)


## Finds the project's skins, palettes and styles and refills the pickers,
## keeping what each had picked when it's still there (else what was
## remembered).
func _rescan() -> void:
	_paths = ResourceScan.find(PackedStringArray([SKIN_CLASS, PALETTE_CLASS, STYLE_CLASS]))
	_refill(_skin_picker, _paths[SKIN_CLASS], false, [_selected_path(_skin_picker), _recall("skin", "")])
	_refill(_palette_picker, _paths[PALETTE_CLASS], true, [_selected_path(_palette_picker), _recall("palette", "")])
	_refill(_style_picker, _paths[STYLE_CLASS], false, [_pending_style_path, _selected_path(_style_picker),
			_recall("style", ""), ProjectSettings.get_setting(PixelDoll.STYLE_SETTING, ""), DEFAULT_STYLE_PATH])
	_pending_style_path = ""
	_rebuild_dolls()


## Lists `paths` in `picker` and picks the first of `wanted` it has.
func _refill(picker: OptionButton, paths: PackedStringArray, with_none: bool, wanted: Array) -> void:
	picker.clear()
	if with_none:
		picker.add_item("None")
		picker.set_item_metadata(0, "")
	for path in paths:
		picker.add_item(path.get_file().get_basename().capitalize())
		picker.set_item_metadata(picker.item_count - 1, path)
		picker.set_item_tooltip(picker.item_count - 1, path)
	for path: String in wanted:
		for i in picker.item_count:
			if not path.is_empty() and picker.get_item_metadata(i) == path:
				picker.select(i)
				return


func _selected_path(picker: OptionButton) -> String:
	return picker.get_item_metadata(picker.selected) if picker.selected >= 0 else ""


func _selected_resource(picker: OptionButton) -> Resource:
	var path := _selected_path(picker)
	return load(path) if path != "" else null


func _selected_skin() -> DollSkin:
	return _selected_resource(_skin_picker) as DollSkin


func _selected_style() -> DollStyle:
	return _selected_resource(_style_picker) as DollStyle


func _selected_clip() -> StringName:
	return StringName(_clip_picker.get_item_text(_clip_picker.selected)) if _clip_picker.selected >= 0 else &""


## Fills the clip picker from the skin's rig, keeping the clip shown (else
## the one remembered) when the rig has it.
func _refill_clips(skin: DollSkin) -> void:
	var wanted := [String(_selected_clip()), _recall("clip", "")]
	_clip_picker.clear()
	if skin and skin.rig:
		for library_name in skin.rig.animations:
			var library := skin.rig.animations[library_name]
			if not library:
				continue
			for animation_name in library.get_animation_list():
				_clip_picker.add_item(String(animation_name) if library_name.is_empty() else "%s/%s" % [library_name, animation_name])
	for clip: String in wanted:
		for i in _clip_picker.item_count:
			if not clip.is_empty() and _clip_picker.get_item_text(i) == clip:
				_clip_picker.select(i)
				return


## A doll (and its onion skin) per facing picked, in the skin, palette and
## style picked.
func _rebuild_dolls() -> void:
	for doll in _dolls + _onions:
		doll.queue_free()
	_dolls.clear()
	_onions.clear()
	var skin := _selected_skin()
	_watch(skin)
	_refill_clips(skin)
	var style := _selected_style()
	var is_addon_style := _selected_path(_style_picker).begins_with(ADDON_DIR)
	_style_notice.visible = is_addon_style
	_inspector.visible = not is_addon_style
	_inspector.edit(null if is_addon_style else style)
	_update_notice(skin)
	if not skin:
		return
	for flipped: bool in FACINGS[maxi(_facing_picker.selected, 0)]:
		var onion := _make_doll(skin, style, flipped)
		onion.self_modulate.a = ONION_ALPHA
		_onions.push_back(onion)
		_dolls.push_back(_make_doll(skin, style, flipped))
	_layout_dolls()
	_update_onions()
	if _playing:
		_play_from(_timeline.value)
	else:
		_pose_at(_timeline.value)


func _make_doll(skin: DollSkin, style: DollStyle, flipped: bool) -> PixelDoll:
	var doll: PixelDoll = DOLL_SCENE.instantiate()
	if style:
		doll.style = style
	doll.skin = skin
	doll.palette = _selected_resource(_palette_picker) as DollPalette
	doll.flipped = flipped
	_viewport.add_child(doll)
	_viewport.move_child(_notice, -1)
	return doll


## Follows `skin`'s changes (the dolls rebuild themselves).
func _watch(skin: DollSkin) -> void:
	if _watched_skin and _watched_skin.changed.is_connected(_on_watched_skin_changed):
		_watched_skin.changed.disconnect(_on_watched_skin_changed)
	_watched_skin = skin
	if skin:
		skin.changed.connect(_on_watched_skin_changed)


## Says what's missing when there's nothing to play.
func _update_notice(skin: DollSkin) -> void:
	if _paths.get(SKIN_CLASS, PackedStringArray()).is_empty():
		_notice.text = "No DollSkin in the project yet. In the FileSystem dock, right-click a folder › Create New › Resource… › DollSkin, then set its character."
	elif not skin:
		_notice.text = ""
	elif not skin.character:
		_notice.text = "This skin has no character. Click Edit Skin and set one: a scene with a Skeleton3D, such as an imported .glb."
	elif _clip_picker.item_count == 0:
		_notice.text = "This skin has no clips to play. Click Edit Skin and give it a rig: a DollRig holding animation libraries for its skeleton."
	else:
		_notice.text = ""


## Spreads the dolls across the preview, centered, at the zoom picked.
func _layout_dolls() -> void:
	var zoom := float(_zoom_spin.value)
	var area := Vector2(_viewport.size)
	for i in _dolls.size():
		var spot := Vector2(area.x * (i + 1) / (_dolls.size() + 1), area.y * 0.5)
		for doll: PixelDoll in [_dolls[i], _onions[i]]:
			doll.scale = Vector2(-zoom if doll.flipped else zoom, zoom)
			doll.position = spot.round()


func _play_from(time: float) -> void:
	var clip := _selected_clip()
	if clip == &"":
		return
	for doll in _dolls:
		if doll.animation_player.has_animation(clip):
			doll.animation_player.play(clip)
			doll.animation_player.seek(time, true)
	_timeline.max_value = _clip_length(clip)


func _pose_at(time: float) -> void:
	var clip := _selected_clip()
	if clip == &"":
		return
	_timeline.max_value = _clip_length(clip)
	var step := _step_length()
	for doll in _dolls:
		doll.pose(clip, time)
	for onion in _onions:
		onion.pose(clip, maxf(time - step, 0.0))


func _clip_length(clip: StringName) -> float:
	if _dolls.is_empty() or not _dolls[0].animation_player.has_animation(clip):
		return 1.0
	return maxf(_dolls[0].animation_player.get_animation(clip).length, 0.001)


## One pose at the style's frames_per_second.
func _step_length() -> float:
	var style := _selected_style()
	return 1.0 / (style.frames_per_second if style else 12)


func _set_playing(playing: bool) -> void:
	_playing = playing
	_play_button.icon = get_theme_icon(&"Pause" if playing else &"Play", &"EditorIcons")
	_update_onions()


func _update_onions() -> void:
	for onion in _onions:
		onion.visible = _onion_check.button_pressed and not _playing


## Copies the style picked to `path` and makes it the project's style.
func _create_project_style(path: String) -> void:
	var source := _selected_style()
	var copy: DollStyle = source.duplicate() if source else DollStyle.new()
	var error := ResourceSaver.save(copy, path)
	if error != OK:
		push_error("Doll Studio couldn't save %s: %s" % [path, error_string(error)])
		return
	ProjectSettings.set_setting(PixelDoll.STYLE_SETTING, path)
	ProjectSettings.save()
	_pending_style_path = path
	EditorInterface.get_resource_filesystem().scan()


func _on_skin_selected() -> void:
	_remember("skin", _selected_path(_skin_picker))
	_rebuild_dolls()


func _on_palette_selected() -> void:
	_remember("palette", _selected_path(_palette_picker))
	for doll in _dolls + _onions:
		doll.palette = _selected_resource(_palette_picker) as DollPalette


func _on_facing_selected() -> void:
	_remember("facing", _facing_picker.selected)
	_rebuild_dolls()


func _on_clip_selected() -> void:
	_remember("clip", String(_selected_clip()))
	_timeline.set_value_no_signal(0.0)
	if _playing:
		_play_from(0.0)
	else:
		_pose_at(0.0)


func _on_style_selected() -> void:
	_remember("style", _selected_path(_style_picker))
	_rebuild_dolls()


func _on_watched_skin_changed() -> void:
	_refill_clips(_watched_skin)
	_update_notice(_watched_skin)


func _on_edit_skin_pressed() -> void:
	var skin := _selected_skin()
	if skin:
		EditorInterface.edit_resource(skin)


func _on_workbench_pressed() -> void:
	var skin := _selected_skin()
	if skin:
		DollWorkbench.open(skin)


func _on_play_pressed() -> void:
	_set_playing(not _playing)
	if _playing:
		_play_from(0.0 if _timeline.value >= _timeline.max_value else _timeline.value)
	else:
		_pose_at(_timeline.value)


func _on_step(direction: int) -> void:
	_set_playing(false)
	var time := wrapf(_timeline.value + direction * _step_length(), 0.0, _timeline.max_value + 0.0001)
	_timeline.set_value_no_signal(time)
	_pose_at(time)


func _on_timeline_changed(time: float) -> void:
	_set_playing(false)
	_pose_at(time)


func _on_loop_toggled(pressed: bool) -> void:
	_remember("loop", pressed)


func _on_onion_toggled(pressed: bool) -> void:
	_remember("onion", pressed)
	_update_onions()
	if not _playing:
		_pose_at(_timeline.value)


func _on_zoom_changed(zoom: float) -> void:
	_remember("zoom", zoom)
	_layout_dolls()


func _on_background_changed(color: Color) -> void:
	_remember("background", color)
	_background.color = color
