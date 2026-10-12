# W tools: scatter tools and Godot editor tooling (7 Oct 2026)

Follows `desk_research.md` (section D lists the precedents briefly; this goes deeper). Local engine files are cited by path; online claims by URL. "Unverified" means I found no source and it needs a test.

---

## 1. Scatter tools in depth

| Tool | Parameters that matter | Presets | Regeneration | Exclusion | Stability | Cache / bake | Editor UX |
|---|---|---|---|---|---|---|---|
| **Houdini Scatter → Attribute Randomize → Copy to Points** | Scatter: Force Total Count or Density, Density Attribute, Relax Iterations, Scale Radii By, Max Relax Radius; it can output a unique id attribute ([Scatter](https://www.sidefx.com/docs/houdini/nodes/sop/scatter.html)). Randomize: distribution, min/max, Operation (set/add/multiply), Global Seed ([Attribute Randomize](https://www.sidefx.com/docs/houdini/nodes/sop/attribrandomize.html)). Copy to Points reads `pscale`, `orient`, `N`, `up`, `scale`; a Piece Attribute picks a variant per point; Pack and Instance shares geometry ([Copy to Points](https://www.sidefx.com/docs/houdini/nodes/sop/copytopoints.html)) | Parameter presets saved from the gear menu ([parms](https://www.sidefx.com/docs/houdini/network/parms.html)) | Cooks when anything upstream changes | Groups, or density painted to 0 | Seed Attribute: "An explicit attribute allows for consistent generation when deleting geometry by using a consistent ID." ([Attribute Randomize](https://www.sidefx.com/docs/houdini/nodes/sop/attribrandomize.html)) | File Cache: writes once, then loads from disk instead of cooking upstream; a Version number keeps variants ([File Cache](https://www.sidefx.com/docs/houdini/nodes/sop/filecache.html)) | Parameters per node; the display flag shows any stage |
| **Unreal PCG** | Graph nodes: Difference (subtract exclusion data, modes Minimum / Clamped / Binary), Self Pruning, Mutate Seed (per point, from position plus node and component seed), Transform Points (min/max, Absolute, Recompute Seed), Static Mesh Spawner (weighted entries), Density Filter ([node reference](https://dev.epicgames.com/documentation/en-us/unreal-engine/procedural-content-generation-framework-node-reference-in-unreal-engine)) | Graph Instances with overridable Graph Parameters, "similar to Material Instances" ([overview](https://dev.epicgames.com/documentation/en-us/unreal-engine/procedural-content-generation-overview)) | Generation Trigger: On Load, On Demand, At Runtime ([enum](https://dev.epicgames.com/documentation/en-us/unreal-engine/python-api/class/PCGComponentGenerationTrigger)); Generate / Cleanup; components track external dependencies unless `only_track_itself` ([PCGComponent](https://dev.epicgames.com/documentation/en-us/unreal-engine/python-api/class/PCGComponent)) | Difference node with volumes or splines | Component `seed`; per-point seeds mutated from position, so points don't reshuffle when others change | Partitioned generation splits output over a grid ([generation modes](https://dev.epicgames.com/documentation/en-us/unreal-engine/using-pcg-generation-modes-in-unreal-engine)) | Generate button; per-node Debug (D key), enable/disable (E), Inspect shows the points ([overview](https://dev.epicgames.com/documentation/en-us/unreal-engine/procedural-content-generation-overview)) |
| **Unreal Procedural Foliage Spawner** | Spawner asset: `random_seed`, `tile_size`, `num_unique_tiles`, foliage types ([API](https://dev.epicgames.com/documentation/en-us/unreal-engine/python-api/class/ProceduralFoliageSpawner)). Foliage types: Collision and Shade Radius, Num Steps, Initial Seed Density, Average Spread Distance, Spread Variance, Max Age, Overlap Priority, Can Grow In Shade, Procedural Scale ([guide](https://dev.epicgames.com/documentation/en-us/unreal-engine/procedural-foliage-tool-in-unreal-engine)) | The spawner is a separate asset, shared by every volume that points at it | Resimulate button only | Procedural Foliage Blocking Volume | Fixed seed, a growth simulation | Results become foliage instances in the level | Volume plus a button |
| **Unity terrain trees** | Brush Size, Tree Density, height and width ranges, Lock Width to Height, Random Tree Rotation, Color Variation; Mass Place with "keep existing"; Shift erases ([trees](https://docs.unity3d.com/Manual/terrain-Trees-Landing.html)) | Tree prototypes on the terrain | Manual painting | Erase | Stored, not regenerated | `TerrainData.treeInstances`, part of the TerrainData asset ([API](https://docs.unity3d.com/ScriptReference/TerrainData-treeInstances.html)) | Brush |
| **Unity Polybrush (Scatter Prefabs)** | Brush radius, falloff, strength; Use Pivot, Hit Surface is Parent, Avoid Overlap ([Polybrush](https://docs.unity3d.com/Packages/com.unity.polybrush@1.1/manual/modes_prefab.html)) | Prefab palettes saved as assets | Painting | Ctrl erases | – | Ordinary scene objects | Brush |
| **ProtonScatter (Godot)** | Modifier stack (desk research D); `global_seed`; per-modifier `override_global_seed` + `custom_seed`; items with `proportion`, source from scene or disk | A whole scatter node saved as `.tscn` | Setters, deferred signals, transform notifications (section 2) | ScatterShape with `negative` | Same seed and inputs give the same result; no per-point seed | ScatterCache writes transforms to a `.res` | Gizmo: yellow inclusive, red exclusive shapes; box handles with undo |
| **Spatial Gardener (Godot)** | Plants Per 100 Units, Random Scale Range, Random Offset Range Y, Random Jitter Fraction, Random Rotations, Allowed Slope Range ([in depth](https://raw.githubusercontent.com/dreadpon/godot_spatial_gardener/master/reference/TUTORIAL_IN_DEPTH.md)) | `.tres` per plant and brush in a work directory; JSON import/export | Painting | Erase brush | Stored transforms | Octree data per plant | Paint, Erase, Single, and Reapply ("updates individual transforms of already placed plants") |

Vegetation Studio spawns by rules with texture and polygon masks ([80.lv](https://80.lv/articles/vegetation-studio-for-unity/)); I found no primary docs on its storage.

**What this means for the W tools:**
- **Presets are separate shared assets** (PCG Graph Instances, the Foliage Spawner asset, Gardener's `.tres`). ProtonScatter's whole-node `.tscn` is the exception, and harder to share.
- **Stable variety needs a seed per element** (Houdini id, PCG Mutate Seed), not one RNG stream.
- **Exclusion is a subtraction step** (PCG Difference, Blocking Volumes, `negative` shapes).
- **Regeneration is explicit** (Generate, Resimulate) or on load. **Caching sits behind a toggle** (File Cache's Load from Disk, ScatterCache).

---

## 2. Godot 4.4/4.5 editor tooling

This repo's engine is 4.5.3-rc (`engine/godot/version.py`).

**`@export_tool_button`** (new in 4.4, [dev 3 post](https://godotengine.org/article/dev-snapshot-godot-4-4-dev-3/)):
- Exports a Callable as an Inspector button, stored without `PROPERTY_USAGE_STORAGE`.
- The docs advise using EditorUndoRedoManager for the action, and warn against lambdas in RefCounted members (leaks) ([@GDScript](https://docs.godotengine.org/en/4.5/classes/class_@gdscript.html)).
- Only built-in editor icons can be used ([exports](https://docs.godotengine.org/en/4.5/tutorials/scripting/gdscript/gdscript_exports.html)).
- 105 scripts under `project/ramon` already use it.

**EditorInspectorPlugin** ([class](https://docs.godotengine.org/en/4.5/classes/class_editorinspectorplugin.html)):
- `_can_handle`, `_parse_begin/_category/_group/_property/_end`, `add_custom_control`.
- Needs an EditorPlugin (`add_inspector_plugin`), and `project.godot` enables no editor plugins today, so that is a shared-file change to ask about.
- Without it, a read-only text readout does the job: `@export_custom(PROPERTY_HINT_MULTILINE_TEXT, "", PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY)`.

**Resource presets (.tres):**
- "This signal is not emitted automatically for properties of custom resources," so each setter calls `emit_changed()` ([Resource](https://docs.godotengine.org/en/4.5/classes/class_resource.html)). The preset script must be `@tool` too ([running code in the editor](https://docs.godotengine.org/en/4.5/tutorials/plugins/running_code_in_the_editor.html)).
- Resources are cached by path, so nodes using one `.tres` share one object. That is what we want; leave `resource_local_to_scene` off.
- To fork: `duplicate(true)` (or 4.5's `duplicate_deep(DEEP_DUPLICATE_INTERNAL)`), then `ResourceSaver.save` to a new path. Without a `class_name`, "New Resource…" won't list the type, so a "Save preset as…" button makes new ones.

**EditorUndoRedoManager** ([class](https://docs.godotengine.org/en/4.5/classes/class_editorundoredomanager.html)):
- From `EditorInterface.get_editor_undo_redo()` ([EditorInterface](https://docs.godotengine.org/en/4.5/classes/class_editorinterface.html)). The scene history is taken from the action's first object; `add_do_reference` keeps created nodes alive.
- Local example: `chickenpen/scripts/loft_rig_4d.gd:504-514`.
- When the editor reloads a tab because an instanced scene changed, it clears that tab's undo history (`engine/godot/editor/editor_node.cpp` ~4286).

**Generated nodes that are not saved:**
- Nodes added without an owner are not shown in the Scene dock and not saved; setting `owner = get_tree().edited_scene_root` saves them ([running code in the editor](https://docs.godotengine.org/en/4.5/tutorials/plugins/running_code_in_the_editor.html), [Node](https://docs.godotengine.org/en/4.5/classes/class_node.html)).
- `add_child(n, false, INTERNAL_MODE_BACK)` also hides them from GDScript `get_children()`, so a loop over the authored trees never meets its own echoes.
- **4D trap:** the 4D viewport still picks them: C++ `get_child_count` includes internal children (`scene/main/node.h:488`), and children of a node in the edited scene target themselves (`modules/4d/editor/viewport/editor_main_viewport_4d.cpp:194-228`). A click selects an echo that can't be saved or deleted (`follow_up/engine_gotchas.md`).
- A saved MeshInstance4D stores its generated mesh (24 MB measured): strip it on `NOTIFICATION_EDITOR_PRE_SAVE`, restore on `POST_SAVE` (`look/pen_look_4d.gd:754`).

**Detecting changes in an instanced sub-scene:**
- *What the editor already does:* on tab switch, `EditorData::check_and_update_scene` compares each instance's file time with its scene state (`editor/editor_data.cpp:666-740`). If one changed, it re-instantiates the **whole edited scene**: every `@tool` node gets `_ready` again and unowned output is dropped. So "regenerate in `_ready`" already covers "Ramon edits the range in its own scene, saves, comes back to the pen".
- *Saving* repacks the cached `PackedScene` in place (`editor_node.cpp:2155-2170`), so `load(path)` is current, but `pack` emits no `changed`.
- *Signals:* EditorPlugin `scene_saved` / `resource_saved` ([EditorPlugin](https://docs.godotengine.org/en/4.5/classes/class_editorplugin.html)) need a plugin. EditorFileSystem `filesystem_changed` / `resources_reload` ([class](https://docs.godotengine.org/en/4.5/classes/class_editorfilesystem.html)) are reachable through `EditorInterface.get_resource_filesystem()`.
- *Editable children edited in place:* SceneTree `tree_changed`, `node_added`, `node_removed` ([SceneTree](https://docs.godotengine.org/en/4.5/classes/class_scenetree.html)). Transforms need `set_notify_transform(true)`, as ProtonScatter does.
- *Polling* `FileAccess.get_modified_time(path)` once a second needs no plugin.

**Threads:**
- "Interacting with the active scene tree is **not** thread-safe" ([thread-safe APIs](https://docs.godotengine.org/en/4.5/tutorials/performance/thread_safe_apis.html)). Building nodes outside the tree, loading resources and changing a unique resource from one thread are fine.
- Every WorkerThreadPool task must be waited for ([class](https://docs.godotengine.org/en/4.5/classes/class_workerthreadpool.html)).
- Local pattern: `chickenpen/scripts/pen_scenery_release_4d.gd:89-116` (add_task, poll `is_task_completed`, wait, assign on the main thread). `theatre/theatre_shapes_4d.gd` builds tetra meshes on a worker.
- Whether `PolyMeshBuilder4D` is safe on a worker is unverified.

**Gizmos for exclusion volumes:**
- The 4D module exposes no gizmo-plugin API (`editor/viewport` has only the transform gizmo).
- Instead: a MeshInstance4D with `BoxWireMesh4D` or `Shape4D.to_wire_mesh()` and a `WireMaterial4D`; test points with `Shape4D.has_point()`.
- The zone node should *be* that MeshInstance4D, so a click selects and moves it, with `mesh` kept out of the save by `_validate_property` (`pen_crag_chunk_4d.gd:66`).
- ProtonScatter's colours: inclusive `Color(0.9, 0.7, 0.2, 0.15)`, exclusive `Color(0.9, 0.1, 0.2, 0.15)`.

### ProtonScatter's source, patterns worth keeping ([repo](https://github.com/HungryProton/scatter), `addons/proton_scatter/`)

- **Coalesced, deferred rebuilds** (`src/scatter.gd`):
  - Setters call `rebuild()`, and modifier-stack signals connect with `CONNECT_DEFERRED`.
  - `NOTIFICATION_TRANSFORM_CHANGED` calls `rebuild.call_deferred()`; a flag set on `NOTIFICATION_ENTER_WORLD` skips the one that loading causes.
  - During a running build, `_rebuild_queued = true`, and the result that arrives is thrown away for a fresh build.
- **Threading:**
  - One `Thread` runs `modifier_stack.start_update(self, domain.get_copy())`, so inputs are snapshotted first.
  - Results return through `transforms_ready` (`CONNECT_DEFERRED`), and nodes are made on the main thread.
  - It also calls `set_thread_safety_checks_enabled(false)`, "advanced usage" per the [Thread docs](https://docs.godotengine.org/en/4.5/classes/class_thread.html). Don't copy that.
  - `dbg_disable_thread` runs the same code synchronously.
- **Output:**
  - One `ScatterOutput` child, which `clear_output()` frees whole.
  - It gets an owner only when `show_output_in_tree` is on (`src/common/scatter_util.gd`), hence `force_rebuild_on_load` defaults to true.
  - Copy mode reuses existing children (`_update_duplicates`).
- **Chaining:** `scatter_parent` rebuilds on another scatter's `build_completed`. The Optimiser could feed the Exploder's exclusions this way.
- **Cache** (`src/cache/scatter_cache.gd`): stores every scatter's transforms in a `.res`, updated on `NOTIFICATION_EDITOR_PRE_SAVE`. On load it feeds them to `_on_transforms_ready`, skipping scatters with `force_rebuild_on_load`.
- **Exclusion** (`src/scatter_shape.gd`):
  - `negative` makes a shape an exclusion zone, and its resource's `changed` requests a rebuild.
  - `_set()` makes the shape unique when the node is duplicated. Avoid that trap: give zones plain exported sizes, not shared Shape resources.
- **Undo:** only gizmo handle edits are undoable (`src/shapes/gizmos_plugin/box_gizmo.gd` `commit_handle`); output never enters the history.
- **Presets** (`src/presets/presets.gd`): `duplicate(7)`, then `clear_output()`, `PackedScene.pack`, `ResourceSaver.save`. Loading copies `modifier_stack.get_copy()`.

---

## 3. Local conventions the new tools should follow

From `chickenpen/scripts/pen_rune_range_4d.gd`, `pen_oak_4d.gd` and `pen_trees_4d.gd`:

- **Header first.** A `##` block with Ramon's request quoted and dated, capitalised WHY sections, then "No class_name (engine_gotchas.md)": a `class_name` written with the editor closed is invisible until a rescan, and renames collide. Other scripts come in through `const X := preload("res://…")`; nodes are duck-typed (`has_method`, `get`, `"prop" in node`, `pen_trees_4d.gd:174`).
- **`@tool` with a Rebuild button:** `@export_tool_button("Rebuild") var _rebuild_action: Callable = rebuild` (`pen_rune_range_4d.gd:45`).
- **Deferred, coalesced rebuilds.** One-line setters `func _set_seed(v: int) -> void: range_seed = v; _later()` (114-119). `_later()` returns unless the node is ready and nothing is pending, then calls `rebuild.call_deferred()` (148-152), so ten slider ticks give one rebuild. `pen_oak_4d.gd` rebuilds at once in its setters; `_later()` is the better model.
- **The `_own()` owner rule.** `_own(node)` sets the `OWN` meta (`&"_rune_range_part"`, line 96) and adds the child with no owner, so it is never saved (947-949). `rebuild()` first frees every child with the meta (155-161), so hand-placed children survive. The oak says the same: "nothing built is saved (no owner)" (`pen_oak_4d.gd:33`).
- **Batching.** `_merge()` gathers boxes into one ArrayTetraMesh4D per colour and `_flush()` makes one MeshInstance4D each (858-910). Copies share meshes (`pen_oak_4d.gd` `static var _leaf_sources`).
- **Editor and game split.** The oak builds only its wood in the editor; leaves, wind, trunk and ground snap are runtime-only. `pen_trees_4d.gd` is not `@tool`: it plants at runtime only, with no editor preview today.
- **Runner metrics as plain vars** (`echo_count`, `echo_refused`, `cull_usec`), **one cull loop** (`set_managed(true)`, a single `RenderingServer4D.pre_render` pass), and **Nil-tolerant reads** of new exports (gotchas).

---

## Recommended architecture for the two tools in Godot

**Shared shape:** a `@tool extends Node4D` per tool (no class_name); `@export var preset: Resource` holding a `@tool extends Resource` `.tres` from `WTools/presets/`; `@export_tool_button` buttons and a read-only `report`; all output with an OWN meta, internal, unowned, rebuilt by `_later()`.

### Preset resource

```gdscript
@tool
extends Resource
## W EXPLODER PRESET ... No class_name (engine_gotchas.md).
@export var layer_spacing: float = 4.5: set = _set_layer_spacing
func _set_layer_spacing(v: float) -> void: layer_spacing = v; emit_changed()
```

- The node connects `preset.changed` to `_later()` in the preset setter, disconnecting the old preset first.
- Buttons: "Save preset as…" (`preset.duplicate(true)`, then `ResourceSaver.save`) and "Make local" (`preset = preset.duplicate(true)`, undoable). Shared `.tres` files stay the tested presets.

### W Exploder (`exploder/w_exploder_4d.gd`)

- **Inputs:** its authored children (filtered by `get_script() == OAK`). Exclusion zones are children running a small `w_exclusion_4d.gd` (`extends MeshInstance4D`, exported `size: Vector4`, an exclude flag, a red WireMaterial4D in the editor only, `mesh` hidden by `_validate_property`).
- **Seeds:** one RNG per echo, `rng.seed = hash([String(src.name), layer_index, preset.seed])`. Adding or removing a tree leaves the others' echoes alone.
- **Saved vs generated:** only the authored trees, the zones and the preset path are saved. Echoes go in through `add_child(oak, false, INTERNAL_MODE_BACK)` with an OWN meta and a `&"w_source"` meta naming the source tree.
- **When to regenerate:** at runtime in `_ready`, as today. In the editor only while `preview` is on, through `_later()` (preset changed, a child added or removed, Plant). Zones move silently, so start with the Plant button; a transform-hash poll can come later.
- **Picking:** on `EditorInterface.get_selection().selection_changed`, swap a selected echo for its `w_source` tree. Unverified.
- **Undo:** echoes are never in the history. Preset changes, zones and "Make local" use `add_do_property` / `add_undo_property`, and the setters regenerate. A later "Bake to scene" follows `loft_rig_4d.gd:504-514`.
- **Threads and cache:** neither at first: a few hundred transforms and clearance tests, deterministic. Measure with the script-time monitors first.

### W Optimiser (`optimiser/w_optimiser_4d.gd`)

- **Inputs:** `@export var source: Node4D` (the landmark instance beside it in the pen), or `@export_file("*.tscn") var source_scene` for the lab, plus `profile` (the preset).
- **Buttons:** Analyse (report only), Apply, Clear, Compare (switches `show_original` / `show_w`).
- **Saved vs generated:** the source instance stays untouched and saved. Output goes in one unowned `WOutput` holder child of the optimiser. The original is hidden only through a runtime switch, never by writing `visible` into the instance (that would be saved as an override; gotchas).
- **When to regenerate:**
  - `_ready`, which alone covers "edited in `units/rune_range`, saved, back to the pen" (the editor re-instantiates the pen on tab switch).
  - `profile.changed`.
  - In the editor, a once-a-second poll of `FileAccess.get_modified_time(source.scene_file_path)`.
  - With editable children: `node_added`/`node_removed` filtered by `source.is_ancestor_of(n)`.
- **Threads:**
  1. Snapshot each part on the main thread (mesh, transform, bounds, class).
  2. `WorkerThreadPool.add_task(_build.bind(snapshot, gen))` builds ArrayTetraMesh4D only.
  3. `_process` polls `is_task_completed`, always waits, drops results with a stale `gen`, then makes nodes and colliders.
  4. A `sync_build` export for runners. Test PolyMeshBuilder4D on a worker first.
- **Cache:** Apply writes meshes to `WTools/cache/<unit>_<part>_<key>.res`, keyed by a hash of part names, transforms, tetra counts and profile values (not file times, which git checkout resets). Runtime loads on a match and rebuilds on a miss; commit the cache if runtime relies on it.
- **Undo:** as for the Exploder. A tab reload wipes the history anyway.

### Open checks

1. Does the echo-to-source selection swap work in the 4D viewport?
2. After a tab-switch reload, does the optimiser's exported `source` re-resolve before `_ready`?
3. Is PolyMeshBuilder4D safe on a worker thread?
4. What does the Exploder cost on the main thread at 1,000 echoes?
