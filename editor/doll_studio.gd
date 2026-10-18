@tool
extends VBoxContainer
## The Doll Studio main screen: previews a DollSkin as a PixelDoll, in a
## palette and a style, facing right, left or both, and plays or scrubs its
## rig's clips; Workbench opens the skin in the 3D editor (see
## doll_workbench.gd). The style picked is edited in the side inspector and restyles
## every doll using it. Skins, palettes and styles are found by scanning the
## project's .tres files, again whenever the file system changes.

const DOLL_SCENE := preload("res://addons/doll_studio/runtime/pixel_doll.tscn")
const DollWorkbench := preload("res://addons/doll_studio/editor/doll_workbench.gd")
## Script classes the scan collects, by the .tres header's script_class.
const SKIN_CLASS := "DollSkin"
const PALETTE_CLASS := "DollPalette"
const STYLE_CLASS := "DollStyle"
const DEFAULT_STYLE_PATH := "res://addons/doll_studio/runtime/default_style.tres"
## A doll's render, in its own pixels (see pixel_doll.tscn).
const DOLL_SIZE := Vector2(96, 64)
## How see-through the onion skin's previous pose is.
const ONION_ALPHA := 0.35
const DEFAULT_BACKGROUND := Color("#4f6b46")
## The facing picker's items: which way each shown doll faces (flipped).
const FACINGS: Array[Array] = [[false], [true], [false, true]]

## .tres paths found by the scan, by script class.
var _paths: Dictionary[String, PackedStringArray] = {}
var _dolls: Array[PixelDoll] = []
## One per doll, showing the pose a step before while paused.
var _onions: Array[PixelDoll] = []
var _playing := true

var _skin_picker := OptionButton.new()
var _palette_picker := OptionButton.new()
var _facing_picker := OptionButton.new()
var _clip_picker := OptionButton.new()
var _style_picker := OptionButton.new()
var _viewport := SubViewport.new()
var _background := ColorRect.new()
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


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout_dolls()


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
	_inspector = EditorInspector.create_default_inspector()
	_inspector.custom_minimum_size.x = 300.0
	split.add_child(_inspector)

	var transport := HBoxContainer.new()
	add_child(transport)
	_play_button.flat = true
	_play_button.tooltip_text = "Play or pause the clip."
	_play_button.pressed.connect(_on_play_pressed)
	transport.add_child(_play_button)
	transport.add_child(_make_icon_button(&"PlayStartBackwards", "Previous pose", _on_step.bind(-1)))
	_timeline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timeline.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_timeline.step = 0.0
	_timeline.value_changed.connect(_on_timeline_changed)
	transport.add_child(_timeline)
	transport.add_child(_make_icon_button(&"PlayStart", "Next pose", _on_step.bind(1)))
	_time_label.custom_minimum_size.x = 110.0
	transport.add_child(_time_label)
	_loop_check.text = "Loop"
	_loop_check.button_pressed = true
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


## Finds the project's skins, palettes and styles and refills the pickers,
## keeping what each had selected when it's still there.
func _rescan() -> void:
	_paths = {SKIN_CLASS: PackedStringArray(), PALETTE_CLASS: PackedStringArray(), STYLE_CLASS: PackedStringArray()}
	_scan_dir(EditorInterface.get_resource_filesystem().get_filesystem())
	_refill(_skin_picker, _paths[SKIN_CLASS], false)
	_refill(_palette_picker, _paths[PALETTE_CLASS], true)
	_refill(_style_picker, _paths[STYLE_CLASS], false, DEFAULT_STYLE_PATH)
	_rebuild_dolls()


func _scan_dir(dir: EditorFileSystemDirectory) -> void:
	if not dir:
		return
	for i in dir.get_file_count():
		var path := dir.get_file_path(i)
		if path.get_extension() == "tres":
			var script_class := _read_script_class(path)
			if _paths.has(script_class):
				_paths[script_class].push_back(path)
	for i in dir.get_subdir_count():
		_scan_dir(dir.get_subdir(i))


## The script_class a .tres declares in its header line, or "".
func _read_script_class(path: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		return ""
	var header := file.get_line()
	var start := header.find("script_class=\"")
	if start == -1:
		return ""
	start += "script_class=\"".length()
	return header.substr(start, header.find("\"", start) - start)


func _refill(picker: OptionButton, paths: PackedStringArray, with_none: bool, preferred := "") -> void:
	var kept := _selected_path(picker)
	picker.clear()
	if with_none:
		picker.add_item("None")
		picker.set_item_metadata(0, "")
	for path in paths:
		picker.add_item(path.get_file().get_basename().capitalize())
		picker.set_item_metadata(picker.item_count - 1, path)
		picker.set_item_tooltip(picker.item_count - 1, path)
	for wanted in [kept, preferred]:
		for i in picker.item_count:
			if wanted != "" and picker.get_item_metadata(i) == wanted:
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


## Fills the clip picker from the skin's rig, keeping the clip shown when the
## new rig has it too.
func _refill_clips(skin: DollSkin) -> void:
	var kept := _selected_clip()
	_clip_picker.clear()
	if not skin or not skin.rig:
		return
	for library_name in skin.rig.animations:
		for animation_name in skin.rig.animations[library_name].get_animation_list():
			_clip_picker.add_item(String(animation_name) if library_name.is_empty() else "%s/%s" % [library_name, animation_name])
	for i in _clip_picker.item_count:
		if _clip_picker.get_item_text(i) == kept:
			_clip_picker.select(i)


## A doll (and its onion skin) per facing picked, in the skin, palette and
## style picked.
func _rebuild_dolls() -> void:
	for doll in _dolls + _onions:
		doll.queue_free()
	_dolls.clear()
	_onions.clear()
	var skin := _selected_skin()
	_refill_clips(skin)
	var style := _selected_style()
	_inspector.edit(style)
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
	return doll


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


func _on_skin_selected() -> void:
	_rebuild_dolls()


func _on_palette_selected() -> void:
	for doll in _dolls + _onions:
		doll.palette = _selected_resource(_palette_picker) as DollPalette


func _on_facing_selected() -> void:
	_rebuild_dolls()


func _on_clip_selected() -> void:
	_timeline.set_value_no_signal(0.0)
	if _playing:
		_play_from(0.0)
	else:
		_pose_at(0.0)


func _on_style_selected() -> void:
	_rebuild_dolls()


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


func _on_onion_toggled(_pressed: bool) -> void:
	_update_onions()
	if not _playing:
		_pose_at(_timeline.value)


func _on_zoom_changed(_zoom: float) -> void:
	_layout_dolls()


func _on_background_changed(color: Color) -> void:
	_background.color = color
