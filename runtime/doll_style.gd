@tool
class_name DollStyle
extends Resource
## How a PixelDoll is drawn: its camera, its colors and light bands, its
## inner lines and how many poses a second it shows. Dolls share one
## (default_style.tres unless given another), so tuning it restyles them all
## at once.

## How far the doll turns from its side profile towards the camera.
@export_range(0.0, 90.0, 1.0, "suffix:°") var turn_degrees: float = 30.0:
	set(value):
		turn_degrees = value
		emit_changed()
## How far the camera looks down on the doll.
@export_range(0.0, 60.0, 1.0, "suffix:°") var pitch_degrees: float = 20.0:
	set(value):
		pitch_degrees = value
		emit_changed()
## World units the render's 64 px of height span: the bigger, the smaller
## the doll.
@export_range(1.0, 8.0, 0.05) var camera_size: float = 3.4:
	set(value):
		camera_size = value
		emit_changed()
## Pixels from the render's center down to the doll's feet.
@export_range(0, 32) var feet_offset: int = 24:
	set(value):
		feet_offset = value
		emit_changed()
## Poses a second: its animations play in steps, like a hand-drawn sprite.
@export_range(1, 60) var frames_per_second: int = 12:
	set(value):
		frames_per_second = value
		emit_changed()
## In view space (+x right, +y up, +z towards the camera), on the left
## side (facing right); mirrored for the right one, so each is lit from where
## it faces.
@export var light_direction := Vector3(0.3, 0.6, 0.75):
	set(value):
		light_direction = value
		emit_changed()
@export_range(2, 6) var light_bands: int = 2:
	set(value):
		light_bands = value
		emit_changed()
## How bright the darkest band is.
@export_range(0.0, 1.0, 0.01) var shadow_brightness: float = 0.8:
	set(value):
		shadow_brightness = value
		emit_changed()
## How bright the brightest band is (over 1 brightens the texture).
@export_range(0.5, 2.0, 0.01) var highlight_brightness: float = 1.1:
	set(value):
		highlight_brightness = value
		emit_changed()
## Shadows take this tint, highlights highlight_tint: pixel art ramps shift
## hue, not just brightness.
@export var shadow_tint := Color(0.9, 0.9, 1.0):
	set(value):
		shadow_tint = value
		emit_changed()
@export var highlight_tint := Color(1.0, 0.97, 0.88):
	set(value):
		highlight_tint = value
		emit_changed()
## Flat tones kept from each of the model's texture gradients; 0 keeps the
## gradients.
@export_range(0, 8) var albedo_steps: int = 2:
	set(value):
		albedo_steps = value
		emit_changed()
## How much closer than a pixel its neighbor must be (in world units) to draw
## an inner line on it, between parts in front and behind.
@export_range(0.0, 2.0, 0.01) var inner_line_threshold: float = 0.08:
	set(value):
		inner_line_threshold = value
		emit_changed()
## What a pixel on an inner line keeps of its color; 1 hides the lines.
@export_range(0.0, 1.0, 0.01) var inner_line_brightness: float = 0.3:
	set(value):
		inner_line_brightness = value
		emit_changed()
