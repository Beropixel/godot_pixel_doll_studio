@tool
extends VBoxContainer
## The workbench's pixel preview: a side panel in the 3D editor, shown while
## doll_workbench.tscn is the scene open (see plugin.gd). It draws the
## workbench's skin as a PixelDoll in the project's style and copies the
## workbench skeleton's pose at the style's frames_per_second, so a pose or a
## clip in the Animation panel shows as pixel art right away, keyed or not.

const DOLL_SCENE := preload("res://addons/doll_studio/runtime/pixel_doll.tscn")
const ResourceScan := preload("res://addons/doll_studio/editor/resource_scan.gd")
const PALETTE_CLASS := "DollPalette"
## A doll's render, in its own pixels (see pixel_doll.tscn).
const DOLL_SIZE := Vector2(96, 64)
const BACKGROUND := Color("#4f6b46")
## Where its picks are remembered, in the editor's project metadata.
const METADATA_SECTION := "doll_studio"

var _workbench: Node3D
var _doll: PixelDoll
## Time since the last pose copied.
var _step_time := 0.0
var _viewport := SubViewport.new()
var _view := SubViewportContainer.new()
var _palette_picker := OptionButton.new()
var _flip_check := CheckBox.new()
var _direction_picker := OptionButton.new()
var _zoom_spin := SpinBox.new()


func _ready() -> void:
	var title := Label.new()
	title.text = "Pixel Preview"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)
	_view.stretch = true
	add_child(_view)
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	_viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	_view.add_child(_viewport)
	var background := ColorRect.new()
	background.color = BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_viewport.add_child(background)
	_doll = DOLL_SCENE.instantiate()
	_viewport.add_child(_doll)

	var options := HBoxContainer.new()
	add_child(options)
	_flip_check.text = "Flip"
	_flip_check.tooltip_text = "Face left."
	_flip_check.button_pressed = bool(_recall("workbench_flip", false))
	_flip_check.toggled.connect(_on_flip_toggled)
	options.add_child(_flip_check)
	var zoom_label := Label.new()
	zoom_label.text = "Zoom"
	options.add_child(zoom_label)
	_zoom_spin.min_value = 1.0
	_zoom_spin.max_value = 6.0
	_zoom_spin.value = float(_recall("workbench_zoom", 3.0))
	_zoom_spin.suffix = "x"
	_zoom_spin.value_changed.connect(_on_zoom_changed)
	options.add_child(_zoom_spin)
	for direction_name: String in PixelDoll.Direction.keys():
		_direction_picker.add_item(direction_name.capitalize())
	_direction_picker.select(int(_recall("workbench_direction", PixelDoll.Direction.RIGHT)))
	_direction_picker.tooltip_text = "Where it looks (the model turns)."
	_direction_picker.item_selected.connect(_on_direction_selected)
	add_child(_direction_picker)
	_palette_picker.tooltip_text = "The palette its recolored meshes take."
	_palette_picker.item_selected.connect(_on_palette_selected)
	add_child(_palette_picker)
	EditorInterface.get_resource_filesystem().filesystem_changed.connect(_refill_palettes)
	_refill_palettes()
	_layout()


func _process(delta: float) -> void:
	if not is_visible_in_tree() or not is_instance_valid(_workbench):
		return
	var skin := _workbench.get(&"skin") as DollSkin
	if _doll.skin != skin:
		_doll.skin = skin
	_step_time += delta
	var step := 1.0 / PixelDoll.project_style().frames_per_second
	if _step_time < step:
		return
	_step_time = fmod(_step_time, step)
	var character := _workbench.get_node_or_null(^"Character")
	if character:
		_doll.match_pose(character.find_child("Skeleton3D", true, false) as Skeleton3D)


## Shows `workbench`'s skin and pose, or hides when it's null.
func follow(workbench: Node3D) -> void:
	_workbench = workbench
	visible = workbench != null


func _layout() -> void:
	var zoom := float(_zoom_spin.value)
	_view.custom_minimum_size = DOLL_SIZE * zoom
	_doll.flipped = _flip_check.button_pressed
	_doll.direction = maxi(_direction_picker.selected, 0) as PixelDoll.Direction
	_doll.scale = Vector2(-zoom if _doll.flipped else zoom, zoom)
	_doll.position = DOLL_SIZE * zoom * 0.5


func _refill_palettes() -> void:
	var wanted := _selected_palette_path() if _palette_picker.item_count > 0 else String(_recall("workbench_palette", ""))
	_palette_picker.clear()
	_palette_picker.add_item("No Palette")
	_palette_picker.set_item_metadata(0, "")
	for path in ResourceScan.find(PackedStringArray([PALETTE_CLASS]))[PALETTE_CLASS]:
		_palette_picker.add_item(path.get_file().get_basename().capitalize())
		_palette_picker.set_item_metadata(_palette_picker.item_count - 1, path)
		if path == wanted:
			_palette_picker.select(_palette_picker.item_count - 1)
	_apply_palette()


func _selected_palette_path() -> String:
	return _palette_picker.get_item_metadata(_palette_picker.selected) if _palette_picker.selected >= 0 else ""


func _apply_palette() -> void:
	var path := _selected_palette_path()
	_doll.palette = load(path) as DollPalette if not path.is_empty() else null


func _remember(key: String, value: Variant) -> void:
	EditorInterface.get_editor_settings().set_project_metadata(METADATA_SECTION, key, value)


func _recall(key: String, default: Variant) -> Variant:
	return EditorInterface.get_editor_settings().get_project_metadata(METADATA_SECTION, key, default)


func _on_flip_toggled(pressed: bool) -> void:
	_remember("workbench_flip", pressed)
	_layout()


func _on_direction_selected(index: int) -> void:
	_remember("workbench_direction", index)
	_layout()


func _on_zoom_changed(zoom: float) -> void:
	_remember("workbench_zoom", zoom)
	_layout()


func _on_palette_selected(_index: int) -> void:
	_remember("workbench_palette", _selected_palette_path())
	_apply_palette()
