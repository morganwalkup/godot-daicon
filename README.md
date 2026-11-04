![Daicon](press_kit/1-5%20version.png)

# Daicon

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Godot](https://img.shields.io/badge/Godot-4.5%2B-478cbf.svg)
![Version](https://img.shields.io/badge/version-1.6-orange.svg)

**Daicon** is a Godot plugin for creating 2.5D games.

Its principle is to use 3D space calculations and math to move 2D objects. In this way it simulates the 3D depth of an environment while staying in a 2D dimension. The addon provides a set of new nodes and additional tools that combine 2D and 3D capabilities simultaneously.

https://github.com/user-attachments/assets/388bd1bf-629e-49e4-8d5c-f3ae23a412f4

## Why Daicon?
 
Simulating 3D depth for a 2D game usually means picking between two established, imperfect approaches:
 
1. **Modeling 3D mathematically inside a 2D world** — e.g. computing depth and occlusion by hand for every wall, ramp, and obstacle. This works, and many games use it, but the complexity grows fast with functionality: a flat wall is simple to handle, but a sloped surface can be several times harder to get right than a straight one.
2. **Placing 2D sprites inside a real 3D world** — simpler math, since the engine's own 3D pipeline handles depth and occlusion for you. The trade-off is that you now have to build and think in full 3D, and pixel-perfect 2D rendering is never fully achievable under any 3D projection — some distortion is unavoidable. 
3. **Daicon takes a third path** — it keeps objects as 2D nodes, but drives their position and depth using a lightweight 3D coordinate system under the hood. The goal is to get most of the benefits of approach 2 (simpler depth handling than hand-rolled 2D math) without fully committing to a 3D scene or losing 2D's pixel control.

---

## Features

In this fork, each Daicon node has the API of the Godot built-in 2D node with the same role. Code that you write for `CharacterBody2D` reads the same on `CharacterBody25D`, except for the breaks in [Where the API differs](#where-the-api-differs).

| Daicon node | Built-in model | Hidden 3D node (`core`) |
|---|---|---|
| `CollisionObject25D` | `CollisionObject2D` | (base class) |
| `PhysicsBody25D` | `PhysicsBody2D` | (base class) |
| `StaticBody25D` | `StaticBody2D` | `StaticBody3D` |
| `AnimatableBody25D` | `AnimatableBody2D` | `AnimatableBody3D` |
| `RigidBody25D` | `RigidBody2D` | `RigidBody3D` |
| `CharacterBody25D` | `CharacterBody2D` | `CharacterBody3D` |
| `Area25D` | `Area2D` | `Area3D` |
| `CollisionShape25D` | `CollisionShape2D` | `CollisionShape3D` |
| `TileMapLayer25D` | `TileMapLayer` | `GridMap` and a wall `StaticBody3D` |
| `NavigationRegion25D` | `NavigationRegion3D` | (it is a `NavigationRegion3D`) |

Other nodes:

- `Root25D` — a root node with the shader trigger and target lists of the examples.
- `Shadow25D` — drop shadows for 2.5D objects.
- `KinematicCollision25D` — the collision result of `move_and_collide()` and `get_slide_collision()`.
- Custom shaders (`circle`, `blur_circle`) for see-through effects.
- Editor script templates for the body nodes.
- Example scenes in `examples/` that use the body nodes, `TileMapLayer25D`, and `CollisionShape25D`.

![NODES](https://github.com/user-attachments/assets/fd7c5759-a461-488b-a838-b340924e372b)

---

## Installation

1. Download or clone this repository. The repository root is the addon.
2. Put the repository at `addons/daicon` in your own Godot project (copy it, or add it as a git submodule).
3. In Godot, go to **Project → Project Settings → Plugins**, and enable **Daicon**.

> [!NOTE]
> Daicon ships with ready-made script templates in `addons/daicon/script_templates`. Copy them into your project's own `script_templates` folder to have new Daicon scripts pre-wired when you create them from the editor.

> [!IMPORTANT]
> Requires Godot **4.5+** with the Forward+ renderer. This fork is tested on Godot 4.7.

---

## Quick Start

1. Add a `TileMapLayer25D` with a TileSet that has a String `Item` custom data layer, and set its `mesh_library` (for example `mesh/blocks.tres`).
2. Add a `CharacterBody25D`. Turn on `use_gravity`, and write a script from the template:

```gdscript
extends CharacterBody25D

func _physics_process(_delta: float) -> void:
	velocity = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down") * 80.0
	move_and_slide()
```

3. Open `examples/example.tscn` for a working demo scene.

> [!NOTE]
> Upstream docs, guides, and API reference: [daicon-docs.readthedocs.io](https://daicon-docs.readthedocs.io/en/latest/). They describe the upstream API, not the built-in names of this fork.

---

## Units and coordinates

One rule applies to every Daicon node. 1 block = 1 tile = `tile_size` px (16 by default).

| Value | Unit | Meaning |
|---|---|---|
| `position`, `global_position` | px | Where the node draws: x = X, y = Z − height. |
| Ground position (`get_ground_position()`) | px | The point on the ground plane under the feet: (X, Z). |
| `height` | blocks | The 3D Y of the feet. The `core` origin is at the feet. |
| `velocity`, `linear_velocity`, `constant_linear_velocity` | px/s | On the ground plane: x = east, y = south. Not the drawn screen velocity. |
| `vertical_velocity`, `constant_vertical_velocity` | blocks/s | Up is positive. |
| `safe_margin`, `floor_snap_length`, `footprint_size`, `footprint_radius` | px | Converted to blocks for the core. |
| `collision_layer`, `collision_mask` | 3D layer bits | Forwarded to the core. |

A write to `position` or `global_position` at runtime moves the core there and keeps the height, as a write moves a built-in body. Use `teleport(position, height)` to set a height as well.

---

## Where the API differs

| # | Difference | Reason | What to use |
|---|---|---|---|
| B1 | `velocity` is on the ground plane, not the drawn screen velocity. | The world has height. On a north ramp the drawn y changes more than the ground y. | Read `get_ground_position()` for ground motion. |
| B2 | Height is separate. | 2D has no third axis. | `height`, `vertical_velocity`, `jump()`. |
| B3 | Gravity acts on `vertical_velocity`, not on `velocity.y`. | Same reason as B2. | `use_gravity` (off by default, as on the built-in), `gravity_3d`, `apply_gravity(delta)`. |
| B4 | Normals, collisions, and `get_gravity()` are projected or 3D. | 2D types cannot hold them. | `KinematicCollision25D`, `Vector3` returns, and the `_3d` variants. |
| B5 | Some members are not defined. | No meaning or no 3D counterpart. | See [Not mirrored](#not-mirrored). |
| B6 | `Area2D` and Daicon nodes do not detect each other. | Daicon nodes are 3D. | `Area25D`, or an `Area2D` with `CollisionObject25D.same_level_areas()`. |
| B7 | 2D `rotation` and `scale` do not turn or scale the 3D shapes. | `Node2D` owns these members. | `rotation_3d`, and the shape size. |
| B8 | There is no `get_rid()`. | A 3D RID passed to `PhysicsServer2D` fails silently. | `get_rid_3d()`. |
| B9 | Planar lengths convert px to blocks. | The core works in blocks. | The inspector shows `px` and `blocks` suffixes. |
| B10 | Navigation is 3D. | The navmesh is 3D. | `NavigationAgent3D` on a "Feet" node under the core, and `NavigationRegion25D`. |
| B11 | A position write keeps the current height. | A 2D position alone is ambiguous on a cliff. | `teleport(position, height)`. |

### Not mirrored

| Class | Members that are not defined |
|---|---|
| `CollisionObject25D` | `input_pickable`, `input_event`, `mouse_entered/exited`, `mouse_shape_entered/exited`, `get_rid()`, the shape-owner API (use `CollisionShape25D` children). |
| `CharacterBody25D` | `up_direction` (up is always 3D Y; `up_direction_3d` exists for rare cases). |
| `StaticBody25D` | A `Vector2` `constant_angular_velocity` (it is a float yaw rate). |
| `RigidBody25D` | `_integrate_forces(state)` (define `_integrate_forces_3d(state)` instead), a `Vector2` `center_of_mass` (it is a `Vector3` in blocks). |
| `Area25D` | `audio_bus_override`, `audio_bus_name` (an `Area3D` changes only 3D audio). The shape signal RIDs are 3D. |
| `CollisionShape25D` | `one_way_collision`, `one_way_collision_margin`. The `shape` is a `Shape3D`. |
| `TileMapLayer25D` | `get_coords_for_body_rid()` accepts only 2D RIDs. A native method cannot be overridden. |

---

## Nodes

### Bodies

- `CharacterBody25D` builds a capsule from `footprint_radius` and `body_height` when it has no `CollisionShape25D` child. It builds a whisker (the draw-order area) when `whisker_reach` is above 0.
- `CharacterBody25D` bodies do not push each other: a body with a small `safe_margin` is a solid wall to another body. To push, call `push_slide_colliders(push_speed, layer_mask)` after `move_and_slide()`. It calls `push(motion)` on each `CharacterBody25D` that the move ran into, if that body is on `layer_mask`, at the same level, and the requested velocity points into it. `push()` slides the body along walls and ramps, does nothing in the air, and undoes a move that leaves no floor under the body (a ledge).
- `StaticBody25D` builds a box from `footprint_size` and `wall_height` when it has no `CollisionShape25D` child. With `occluder_height` above 0, it also builds an occluder box. `navigation_obstacle` adds a `NavigationObstacle3D`. `get_navigation_footprint()` gives the box that `NavigationRegion25D` bakes. The static `StaticBody25D.navigation_footprint_of(body)` gives the same box and also works on a placeholder (see [Scripts without @tool](#scripts-without-tool)).
- `AnimatableBody25D` extends `StaticBody25D`. Move it with `position` (a Tween or an AnimationPlayer track), and lift it with `height`. It is never baked into the navmesh.
- `RigidBody25D` re-emits `body_entered`, `body_exited`, and `sleeping_state_changed` with Daicon nodes.
- `Area25D` overlaps in 3D, so an area at another height does not overlap. Inside a Daicon body, its stored `height` is the height above that body.

### Scripts without @tool

Every Daicon class is `@tool`. A subclass script without `@tool` (for example a game prop) gets a placeholder script instance in the editor. A placeholder keeps its exported properties, but it has no `core`, and a call to one of its script methods is an error ("Attempt to call a method on a placeholder instance").

- Editor code that uses another Daicon node must test `CollisionObject25D.is_placeholder(node)` first, and then read only exported properties.
- `NavigationRegion25D` reads the footprint of a placeholder body from its exported properties. A placeholder `TileMapLayer25D` builds no 3D geometry in the editor, so the region shows a warning and does not bake. Add `@tool` to that layer script.

### Shapes

A `CollisionShape25D` child adds its `Shape3D` to the core of its parent. `offset_3d` is the local 3D offset in blocks from the feet. `role` puts the shape on the core (`COLLISION`), the whisker (`WHISKER`), or the occluder (`OCCLUDER`).

### Maps

`TileMapLayer25D` gets its level from `z_index` / `z_step`, or from `level` when `level_from_z_index` is off. A collision with its `GridMap` or its walls maps to the layer through `CollisionObject25D.from_3d()`, so gameplay code can test `collider is TileMapLayer25D`.

### Navigation

`NavigationRegion25D` bakes in the editor from the `TileMapLayer25D` nodes and the still `StaticBody25D` nodes under its parent. It saves `<scene>_nav.tres` next to the scene. The bake settings (`agent_*`, `cell_*`, `border_size`, `geometry_collision_mask`) are exports.

---

## Changes in this fork

This fork is used by Kinsprit. It differs from upstream Daicon:

- The node classes use the names and the API of the Godot built-in 2D nodes (see [Features](#features)). The old names (`DaiconEntity`, `StaticDaicon`, `KinematicDaicon`, `RigidDaicon`, `AnimatedDaicon`, `DaiconMapLayer`) are gone, with no aliases. `DaiconMap` (the legacy `TileMap` class) is deleted.
- The slot system (`*_properties` dictionaries) is deleted. `CollisionShape25D` children and code-built default shapes replace it.
- The repository root is the addon, so it mounts at `addons/daicon`. `blocks.blend` and `blocks.tscn` are in `mesh/source/` behind a `.gdignore`, so a project imports `mesh/blocks.tres` without Blender.
- Daicon nodes and the map GridMaps use global 2D positions. Maps and bodies under an offset parent collide in the correct place.
- The TileSet `Item` custom data layer can be a String (a MeshLibrary item name). An empty value means no block. Int layers still work.
- Maps rebuild when cells change, and when `level` or `z_step` changes.
- `extrude_physics` turns the 2D tile physics polygons into 3D walls on `extrusion_layer`. `disable_2d_collision` (on by default) turns off the 2D physics of the layer at runtime.
- The whisker uses the lowest z of all overlapping occluders and skips the body's own core.
- `TileMapBuilder25D` holds the map build code of `TileMapLayer25D`.

---

## Links & Support

- [Documentation](https://daicon-docs.readthedocs.io/en/latest/)
- [ItchIO](https://alkrei.itch.io/daicon)
- [Bluesky](https://bsky.app/profile/arukurei.bsky.social)
- [Telegram](https://t.me/G_Quasar)
- [YouTube](https://www.youtube.com/@arukurei)
- [Discord](https://discord.gg/663eYk5ZGA)

If you like Daicon and want to support its development, you can donate via [PayPal](https://www.paypal.com/donate/?hosted_button_id=LF5SHGQDXK2PG) or [ItchIO](https://alkrei.itch.io/daicon). Your support is very much appreciated and helps keep the project going!

---

## License

Daicon is released under the [MIT License](LICENSE).
