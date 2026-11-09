@tool
@icon("res://addons/world_25d/icons/tile_map_layer_25d.svg")
class_name TileMapLayer25D extends TileMapLayer
## A TileMapLayer that also builds 3D collision: GridMap blocks from the "Item" custom data, and
## (with extrude_physics) 3D walls from the 2D physics polygons. The whole native TileMapLayer API
## stays the same. The height level is z_index / z_step, unless level_from_z_index is off.
## Then it is "level", and z_index only sets the draw order.
##
## A collision with the GridMap or the extrusion maps to this node through
## CollisionObject25D.from_3d(), so gameplay code can test `collider is TileMapLayer25D`.
## collision_layer and collision_mask are 3D layers (the GridMap names). The 2D tile physics is
## off at runtime while disable_2d_collision is on.
##
## Not mirrored: get_coords_for_body_rid() takes only 2D RIDs (a native method cannot be overridden).

## The GridMap of the blocks. Read-only. See get_grid_map().
var grid_map : GridMap
## The StaticBody3D of the extruded walls. Read-only. See get_extrusion().
var extrusion : StaticBody3D
var _dirty := true
var _built_level := 0

#region TileMapLayer25D Exports

## MeshLibrary of the GridMap blocks. A tile's String custom data layer "Item" names the item.
## An empty name places no block. A name the library does not contain prints a warning.
## An int "Item" layer is the old index format: its unset value 0 is the item Block.
@export var mesh_library : MeshLibrary:
	set(library):
		if grid_map: grid_map.mesh_library = library
		mesh_library = library
		_dirty = true
## Friction and bounce of the blocks and the extruded walls. Empty uses the project default.
## The material is GridMap.physics_material and the wall body's physics_material_override.
@export var physics_material : PhysicsMaterial:
	set(material):
		if grid_map: grid_map.physics_material = material
		if extrusion: extrusion.physics_material_override = material
		physics_material = material
## Shows the GridMap meshes. The 2D tiles stay drawn, and the collision stays on.
## The extruded walls have no mesh.
@export var visible_3d: bool = true:
	set(value):
		if grid_map: grid_map.visible = value
		visible_3d = value

@export_group("Height")
## Draw-order gap between height levels. With level_from_z_index on, the level is
## z_index / z_step (integer division). A step of 0 forces level 0.
## With the default 10, z_index 0, 10, and 20 are levels 0, 1, and 2.
@export var z_step : int = 10:
	set(step):
		z_step = step
		_dirty = true
## If on, the level is z_index / z_step, and z_index also sets the 2D draw order.
## If off, level sets the height, z_index only sets the draw order, and level shows in the inspector.
@export var level_from_z_index: bool = true:
	set(value):
		level_from_z_index = value
		_dirty = true
		notify_property_list_changed()
## Height of this layer, in blocks. Used when level_from_z_index is off, and hidden while that flag is on.
## A tile at column X and row R on level L becomes the GridMap cell (X, L - 1, R + L).
## The block fills Y from L - 1 up to L, so its top is a floor at height L and draws on row R.
## Extruded walls start at height L.
@export var level: int = 0:
	set(value):
		level = value
		_dirty = true

@export_group("Cell")
## Size of one GridMap cell, in blocks (GridMap.cell_size). X is east, Y is up, and Z is south.
## This scales the blocks. The 2D tile size stays the same, and the wall polygons stay one tile wide.
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var cell_size_3d: Vector3 = Vector3(1, 1, 1):
	set(v_3):
		if grid_map: grid_map.cell_size = v_3
		cell_size_3d = v_3
## Shift of the GridMap and the extruded walls from the 2D layer, in blocks.
## The default (0, 0, -0.5) is the upstream plugin value.
## (0, 0, 0) puts each block's top face on the tile drawn in 2D.
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var cell_offset: Vector3 = Vector3(0, 0, -0.5):
	set(v_3):
		cell_offset = v_3
		_sync_origin()

@export_group("Extrusion")
## Builds a 3D wall from every 2D physics polygon of every used tile, on this layer's level.
## Tile flip and transpose apply. A polygon with fewer than 3 points is skipped.
## A wall_height of 0 or less builds no walls.
@export var extrude_physics: bool = false:
	set(value):
		extrude_physics = value
		_dirty = true
## Height of each extruded wall above the floor at level, in blocks.
## A body can stand on the top of the wall.
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var wall_height: float = 1.0:
	set(value):
		wall_height = value
		_dirty = true
## 3D collision layer of the walls. 0 uses collision_layer, the same layer as the blocks.
## Put the walls on their own layer to keep them out of the whisker mask of 2.5D bodies.
## A wall outside that mask does not change draw order.
@export_flags_3d_physics var extrusion_layer: int = 0:
	set(value):
		extrusion_layer = value
		if extrusion: extrusion.collision_layer = value if value != 0 else collision_layer
## If on, the 2D physics of this layer is off at runtime, so only the 3D blocks and walls collide.
## The editor keeps the 2D polygons, so they can still be edited.
@export var disable_2d_collision: bool = true:
	set(value):
		disable_2d_collision = value
		if is_node_ready() and not Engine.is_editor_hint(): collision_enabled = not value

@export_group("Collision")
## 3D layers of the GridMap blocks. The walls use these layers while extrusion_layer is 0.
@export_flags_3d_physics var collision_layer: int = 1:
	set(value):
		if grid_map: grid_map.collision_layer = value
		if extrusion and extrusion_layer == 0: extrusion.collision_layer = value
		collision_layer = value
## 3D layers that the GridMap blocks and the extruded walls scan for collisions.
@export_flags_3d_physics var collision_mask: int = 1:
	set(value):
		if grid_map: grid_map.collision_mask = value
		if extrusion: extrusion.collision_mask = value
		collision_mask = value
@export_group("Navigation")
## Forwards GridMap.bake_navigation. Leave this off when a NavigationRegion25D bakes the map.
## That bake reads the block colliders and the wall colliders, and the game loads the saved navmesh.
@export var bake_navigation: bool = false:
	set(value):
		if grid_map: grid_map.bake_navigation = value
		bake_navigation = value
@export_group("Transform")
## Euler rotation of the GridMap, in radians. The inspector shows degrees.
## This rotates the blocks. The 2D tiles keep Node2D rotation, and the walls keep their own orientation.
@export_custom(PROPERTY_HINT_RANGE, "-360,360,0.1,or_less,or_greater,radians") var rotation_3d: Vector3 = Vector3(0, 0, 0):
	set(v_3):
		if grid_map: grid_map.rotation = v_3
		rotation_3d = v_3
## Scale of the GridMap. This scales the blocks.
## The 2D tiles keep Node2D scale, and the walls keep their own size.
@export_custom(PROPERTY_HINT_LINK, "") var scale_3d: Vector3 = Vector3(1, 1, 1):
	set(v_3):
		if grid_map: grid_map.scale = v_3
		scale_3d = v_3

#endregion

func _validate_property(property: Dictionary) -> void:
	if property.name == "level" and level_from_z_index: property.usage &= ~PROPERTY_USAGE_EDITOR

func _ready() -> void:
	if not tile_set:
		set_y_sort_enabled(true)
		tile_set = TileSet.new()
		TileMapBuilder25D.add_item_layer(tile_set)
	if disable_2d_collision and not Engine.is_editor_hint(): collision_enabled = false
	grid_map = GridMap.new()
	grid_map.set_name("GridMap")
	add_child(grid_map)
	move_child(grid_map, 0)
	
	grid_map.mesh_library = mesh_library
	grid_map.physics_material = physics_material
	grid_map.cell_size = cell_size_3d
	grid_map.collision_layer = collision_layer
	grid_map.collision_mask = collision_mask
	grid_map.set_meta(CollisionObject25D.OWNER_META, self)
	grid_map.bake_navigation = bake_navigation
	grid_map.visible = visible_3d
	
	grid_map.rotation = rotation_3d
	grid_map.scale = scale_3d
	
	extrusion = StaticBody3D.new()
	extrusion.set_name(TileMapBuilder25D.EXTRUSION_NAME)
	extrusion.collision_layer = extrusion_layer if extrusion_layer != 0 else collision_layer
	extrusion.collision_mask = collision_mask
	extrusion.set_meta(CollisionObject25D.OWNER_META, self)
	extrusion.physics_material_override = physics_material
	add_child(extrusion)
	move_child(extrusion, 1)
	
	changed.connect(_mark_dirty)
	_sync_origin()
	update_grid_map()

func _process(_delta: float) -> void:
	_sync_origin()
	if _built_level != get_level(): _dirty = true
	if _dirty: update_grid_map()

## The GridMap of the blocks, for NavigationRegion25D and checks.
func get_grid_map() -> GridMap:
	return grid_map


## The StaticBody3D of the extruded walls, for NavigationRegion25D and checks.
func get_extrusion() -> StaticBody3D:
	return extrusion


## Returns the height level of this layer.
func get_level() -> int:
	if level_from_z_index: return z_index / z_step if z_step != 0 else 0
	return level

func _mark_dirty() -> void:
	_dirty = true

## Called by the engine when cells change, in the editor and at runtime.
## The "changed" signal does not fire for set_cell() at runtime.
func _update_cells(_coords: Array[Vector2i], _forced_cleanup: bool) -> void:
	_dirty = true

func _sync_origin() -> void:
	if not tile_set: return
	var origin := TileMapBuilder25D.origin_3d(self, tile_set.tile_size, cell_offset)
	# A write to Node3D.position always notifies, so the editor would redraw every frame.
	if grid_map and not grid_map.position.is_equal_approx(origin): grid_map.position = origin
	if extrusion and not extrusion.position.is_equal_approx(origin): extrusion.position = origin

func update_grid_map() -> void:
	_dirty = false
	if not grid_map: return
	grid_map.clear()
	if extrusion: TileMapBuilder25D.clear_extrusion(extrusion)
	_built_level = get_level()
	TileMapBuilder25D.fill_grid_map(grid_map, self, _built_level, mesh_library)
	if extrude_physics and extrusion: TileMapBuilder25D.fill_extrusion(extrusion, self, _built_level, wall_height)
