# CLAUDE.md - Pixel Doll Studio

A Godot 4 editor plugin and runtime that draws rigged 3D characters as live pixel art. Games ("host projects") install it from this repository's tags.

## Repository layout
- `addons/pixel_doll_studio/` is the plugin, laid out for the Asset Library. Only this folder ships: `.gitattributes` export-ignores everything else (README, `docs/`, these files).
  - `runtime/`: what games use at runtime. `PixelDoll` (node, `pixel_doll.tscn`), `DollSkin`, `DollSlot`, `DollRig`, `DollPalette`, `DollStyle`, the default style and the shaders. Only these scripts have a `class_name`, and all of them are `@tool` (the editor previews dolls). Runtime code never touches editor APIs (`EditorInterface`, `editor/` scripts) and knows nothing of any game.
  - `editor/`: the main screen, the workbench, the inspector plugin and the workbench preview. No `class_name` here: load these scripts with `preload` constants (`const Workbench := preload(...)`), so they don't pollute a game's global classes.
  - `translations/`: `pixel_doll_studio.pot` and one `<locale>.po` per language.
- `docs/tutorial.md` and `docs/images/`: the user guide, shown on GitHub only.
- There is no `project.godot` here: test the plugin in a host project (see Testing).

## Compatibility
- **Engine:** Godot 4.7 or later (see the README). Prefer APIs valid for 4.7; if a later version changes one used here, keep 4.7 working or raise the minimum in the README and `plugin.cfg`'s description.
- **Public surface:** these are what games depend on, so changing one is a breaking change:
  - the folder `addons/pixel_doll_studio/` and every `res://` path in it;
  - the class names, and their exported properties and public methods;
  - the project setting `pixel_doll_studio/default_style`;
  - the scene structure games animate, e.g. `Viewport/AnimationPlayer` in `pixel_doll.tscn`.
- **Moving or renaming files:** keep each script's `.uid` file next to it and never regenerate uids. Scenes and resources in games reference the plugin by uid as well as by path.

## Versioning and releases
- The version lives in `plugin.cfg`, and each release is a git tag with exactly that version, **without** a `v` prefix (`0.2.0`). Host projects download `https://github.com/Beropixel/godot_pixel_doll_studio/archive/refs/tags/<version>.zip` and take `godot_pixel_doll_studio-<version>/addons/pixel_doll_studio/` from it.
- **Versions:** bump the patch for fixes, the minor for features and, until 1.0, also for breaking changes (e.g. 0.2.0 renamed the folder and setting). Say what breaks in the commit message.
- **Releasing:**
  1. Bump `plugin.cfg`'s version.
  2. Update the README and tutorial.
  3. Commit, tag and push with `--tags`.
  4. In each host project, bump the pinned version and reinstall the addon.
  5. Changes to `docs/` or the README alone need no tag.

## Session rules
- **Never commit, push or tag:** the developer runs every git command themselves. Don't issue `git add`, `git commit`, `git push` or `git tag`. Give the commands to run instead, one per block.
- **Language:** commit messages and docs are in English; chat in Brazilian Portuguese.
- **Diffs, not files:** give localized replacements rather than whole files.
- **Scenes and resources:** never print full `.tscn`/`.tres` contents in chat. Edit them with targeted replacements.
- **Engine output:** report errors and warnings only, not full logs.
- **No re-reads:** don't re-read a file after a successful edit.

## GDScript
Follows the official [GDScript style guide](https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html).
- **Warnings are errors:** host projects may compile this folder with every default-on GDScript warning set to Error (a directory rule for `res://addons/pixel_doll_studio` under **Project Settings › Debug › GDScript**), so code with one can break a game. Fix the cause (e.g. rename a parameter that shadows a member); never silence it.
- **Strict typing:** type every variable, parameter and return value, and use `:=` where the type is obvious.
- **Naming:**
  - snake_case for files, folders, functions, variables and signals;
  - PascalCase for `class_name`s, node names and enums;
  - CONSTANT_CASE for constants, enum members and preloaded scenes/resources (`const DOLL_SCENE := preload(...)`);
  - a preloaded *script* is PascalCase (`const SkinInspector := preload(...)`);
  - a script with a `class_name` is named after it (`DollSkin` → `doll_skin.gd`).
- **File structure order:**
  1. `@tool`, `@icon`, `@static_unload`
  2. `class_name`
  3. `extends`
  4. `##` doc comment
  5. signals
  6. enums
  7. constants
  8. static variables
  9. `@export` variables
  10. remaining regular variables
  11. `@onready` variables
  12. `_static_init()`
  13. remaining static methods
  14. overridden built-in virtual methods: `_init()`, `_enter_tree()`, `_ready()`, `_process()`, `_physics_process()`, then the rest
  15. overridden custom methods
  16. remaining methods
  17. inner classes

  Within each group, public members come before private (`_`-prefixed) ones; signal callbacks (`_on_*`) are private.
- **Node references:** prefer `@onready var` with node paths or `%UniqueName` over `get_node()` with string paths.
- **Tweens:** await their signals instead of polling timers.
- **Resources:** a resource emits `changed` from its setters, and a container resource re-emits its contents' changes (see `DollSkin._follow`), so previews update live. Keep this when adding properties.
- **Comments:** `##` doc comments say what a class, member or method does and why, in full sentences, matching the existing ones. Keep inline comments rare.

## Editor UI and translations
- **English source strings:** every user-visible string goes through auto-translation (control text, tooltips, items) or `tr()` (formatted text such as `tr("%s (missing)") % name`).
- **Names stay untranslated:** resource, clip, bone and mesh names are never translated. Set `auto_translate_mode = AUTO_TRANSLATE_MODE_DISABLED` on controls listing them, and keep values in item metadata rather than parsing item text.
- **New or changed strings:** add the msgid to `pixel_doll_studio.pot` and translate it in every `.po` (today `pt_BR.po`). The `.po` files are loaded into the editor's own `godot.editor` domain (see `plugin.gd`), so they follow the editor's language.
- **Colliding msgids:** when the editor already translates the same English text differently, give the message a context (`tr("All", &"directions")` + `msgctxt`).
- **Plugin name:** "Pixel Doll Studio" is a name and isn't translated.
- **No helper text:** don't add on-screen hints or instructions without asking. Show state with visuals (highlights, previews, empty-state notices) and keep explanations in tooltips.

## Testing
- **Host project:** test in a Godot 4.7 host project with skins, palettes and a style of its own, and with warnings set to Error for this folder. To try uncommitted changes there:
  1. Copy (or `rsync`) `addons/pixel_doll_studio/` over the host's installed copy. Don't commit it there.
  2. Reinstall the host's pinned version afterwards.
- **In the host, after a change:**
  - `godot --headless --editor --path <host> --quit-after 300`: the plugin loads with no errors, and the class cache picks up path changes.
  - Run the host's own tests, if it has them. Every script of this folder must compile, and dolls must load and play.
- **File structure order:** nothing checks it automatically here. Follow it by hand on every script you touch.
- **Path case:** nothing here catches a `res://` path with the wrong letter case, and macOS and Windows hide it. Keep paths lowercase and spelled exactly like the files.
- **Visual changes:** render dolls with a `-s` SceneTree script (not `--headless`, which doesn't draw), save PNGs and look at them before and after.
- **Tutorial images:** `docs/images/` are pixel figures rendered from skins built on KayKit Adventurers (by Kay Lousberg, CC0) and editor screenshots taken in English. Keep the KayKit credit in the tutorial when updating them.
