# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

SO FLUFFY is a Godot 4 (4.2, Forward+) editor plugin that renders shell fur. The repo is a Godot project that hosts the addon plus demo scenes. Only `addons/so_fluffy/` is shipped: `.gitattributes` marks everything else `export-ignore` so Asset Library downloads contain the addon alone. Anything the addon needs at runtime must live inside `addons/so_fluffy/` and be referenced by `res://addons/so_fluffy/...` paths.

## Running

There is no build step, test suite, or linter. `godot` is not on PATH; the binary is at `/Applications/Godot.app/Contents/MacOS/Godot`.

```sh
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
$GODOT --path . --editor                      # open the editor
$GODOT --path .                               # run main scene (demos/lod_test.tscn)
$GODOT --path . res://demos/hedgehog.tscn     # run a specific demo scene
$GODOT --path . --headless --check-only --script addons/so_fluffy/so_fluffy.gd   # parse-check a script
```

The installed Godot is a 4.8 dev build while `project.godot` still declares 4.2. The `.uid` sidecar files that Godot 4.4+ generates are committed; keep each one next to its script or shader when moving or renaming files, and commit the new one when adding a file. Check `git status` after editor sessions, since the newer editor may rewrite scene files.

`project.godot` turns on GDScript warnings for untyped/inferred declarations and unsafe access. The existing addon code is largely untyped and already emits these warnings; prefer typed declarations in new code.

## Architecture

The whole addon is three files:

- `so_fluffy_plugin.gd` registers the custom `Fur` node type (a plain `Node`) backed by `so_fluffy.gd`.
- `so_fluffy.gd` is a `@tool` script. It runs in the editor as well as at runtime, so every code path must tolerate `mesh == null` and editor-only state (`Engine.is_editor_hint()`).
- `so_fluffy.gdshader` does all the rendering. `shell_material.tres` is the template ShaderMaterial that gets duplicated per shell.

### Shells are a material chain, not geometry

A `Fur` node grows fur on its **parent**, which must be a `GeometryInstance3D`. No mesh is duplicated. `create_materials()` duplicates the template material `number_of_shells` times and links the copies through `next_pass`. Each copy gets a uniform `h` in [0, 1]; the vertex shader extrudes the geometry along the growth direction by `height * h`, and the fragment shader discards every pixel that is not inside a strand cross-section at that height.

The chain head is attached in one of two ways:

- `target_surfaces` empty: appended to the end of the parent's `material_overlay` chain.
- `target_surfaces` set (MeshInstance3D only): appended to the end of each listed surface override material's `next_pass` chain.

Fur materials are tagged with the meta key `is_fur`. `remove_fur_material()` relies on that tag to cut the fur chain off without destroying user materials that precede it. Keep the tag on any material the addon creates.

### Property setters drive everything

Every exported property has a setter. Appearance and growth properties call `setup_materials()`, which pushes all uniforms to every shell. Structural properties (`number_of_shells`, `target_surfaces`, `preview_in_editor`) do a full `clear_materials()` / `create_materials()` / `setup_materials()` rebuild. Adding a new fur parameter means touching three places: the `@export` var with a setter, `configure_material_for_level()`, and the matching `uniform` in the shader. Optional textures follow a `use_<name>` bool uniform convention so the shader can skip the sample. The README (duplicated byte-for-byte at `addons/so_fluffy/README.md`) documents every parameter, so update both copies.

`_validate_property()` hides dependent inspector fields (emission, physics, LOD). Setters that toggle those sections must call `notify_property_list_changed()`.

### LOD

`shells` always holds the full chain. `_process()` computes `lod` from the camera distance to the parent's AABB. When `lod` changes, `apply_lod()` rewires `next_pass` pointers to skip shells so that only `lod_shell_count` evenly spaced shells are rendered. `h` values are not recomputed, so the fur keeps its length. Strand thickness is scaled by an empirical power function of the shell count to keep visual density constant.

### Physics

`_physics_process()` runs two independent damped springs driven by the parent's frame-to-frame translation and Euler rotation. Results are written per shell as `physics_pos_offset` and `physics_rot_offset`, scaled by `pow(h, stiffness)` so tips move more than roots. Physics uniforms are written every tick and deliberately bypass `setup_materials()`.

### Shader details that are easy to miss

- Strand placement hashes `floor(UV * density * 1024)`. Fur density therefore follows UV0 density, and models need evenly spaced UVs.
- Vertex color green (`COLOR.g`) scales strand length per vertex. Meshes with black vertex colors grow no fur.
- The heightmap is sampled at the undisplaced UV; turbulence and jitter only move the strand lookup.
- Lighting is a custom half-Lambert `light()` function, and culling is disabled with normals flipped on back faces.

## Other directories

- `demos/` holds the showcase scenes listed in the README. `demos/support_files/` has their helper scripts and the third-party bee model.
- `baa/` is an in-progress sheep-shearing demo on the `baa` branch. `vertex_position_mapper.gd` raycasts the mouse against the mesh, converts the hit to a UV via barycentric weights, and moves a brush sprite inside a SubViewport (`DrawViewport.gd`). That viewport's texture is intended to feed the fur `heightmap_texture`, so painting black shears the fur.
- `screenshots/` has a `.gdignore`, so Godot does not import it.

`.tscn` and `.tres` files are text, but Godot rewrites them on save and reorders properties. Expect noisy diffs in scenes after opening them in the editor.
