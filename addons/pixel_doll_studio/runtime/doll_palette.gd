@tool
class_name DollPalette
extends Resource
## The three shades a PixelDoll paints its skin's recolored texels in (see
## DollSkin.recolor_key), light to dark, picked by each texel's brightness:
## e.g. a team's colors. A .tres per palette, or one built in code
## (from_shades); dolls sharing one share their materials.

@export var light := Color(1.0, 1.0, 1.0):
	set(value):
		light = value
		emit_changed()
@export var mid := Color(0.5, 0.5, 0.5):
	set(value):
		mid = value
		emit_changed()
@export var dark := Color(0.2, 0.2, 0.2):
	set(value):
		dark = value
		emit_changed()


static func from_shades(light_shade: Color, mid_shade: Color, dark_shade: Color) -> DollPalette:
	var palette := DollPalette.new()
	palette.light = light_shade
	palette.mid = mid_shade
	palette.dark = dark_shade
	return palette
