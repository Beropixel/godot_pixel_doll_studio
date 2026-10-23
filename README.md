# Doll Studio

A Godot 4 plugin that draws rigged 3D characters as live pixel art.

A `PixelDoll` node (a `Sprite2D`) renders a skinned 3D model in its own 96×64 viewport with flat light bands, palette recoloring, a 1 px outline, inner lines and stepped animation, so it reads like a hand-drawn sprite while keeping every clip, pose and piece of equipment of the 3D rig.

- **Skins** (`DollSkin`): a character scene with a `Skeleton3D`, pieces worn on its bones (`DollSlot`), hidden and recolored meshes.
- **Rigs** (`DollRig`): the animation libraries a skeleton's skins share.
- **Palettes** (`DollPalette`): three shades that replace a skin's key color, e.g. team colors.
- **Styles** (`DollStyle`): camera, light bands, tints, inner lines and poses per second, shared by every doll.
- **8 directions**: the model turns to look any of 8 ways on screen; `flipped` mirrors it.
- **Editor**: a *Doll Studio* main screen to preview skins, clips, palettes and styles; a 3D workbench to fit pieces with the native gizmos and key clips in the Animation panel, with a live pixel preview; a skin inspector with a bone picker and mesh checklists. English and Brazilian Portuguese UI.

Requires Godot 4.7 or later.

## Install

Copy `addons/doll_studio/` into your project's `addons/` folder, then enable **Doll Studio** in **Project › Project Settings › Plugins**.

To pin a version from another project, download the tag's archive:

```
https://github.com/Beropixel/godot_doll_studio/archive/refs/tags/<version>.zip
```

and take `godot_doll_studio-<version>/addons/doll_studio/` from it.

## Guide

[addons/doll_studio/TUTORIAL.md](addons/doll_studio/TUTORIAL.md) (Brazilian Portuguese) walks through skins, slots, palettes, styles, the workbench, clips, directions and using dolls in a game.

## Translations

The editor UI is written in English and follows the editor's language. Translations live in `addons/doll_studio/translations/`: copy `doll_studio.pot` to `<locale>.po` and fill in each `msgstr`.

## Releases

Versions follow `addons/doll_studio/plugin.cfg`; each release is a tag with that version, without a `v` prefix (e.g. `0.1.0`).
