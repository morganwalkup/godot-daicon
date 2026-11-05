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

@export var mesh_library : MeshLibrary:
	set(library):
		if grid_map: grid_map.mesh_library = library
		mesh_library = library
		_dirty = true
@export var physics_material : PhysicsMaterial:
	set(material):
		if grid_map: grid_map.physics_material = material
		if extrusion: extrusion.physics_material_override = material
		physics_material = material
@export var visible_3d: bool = true:
	set(value):
		if grid_map: grid_map.visible = value
		visible_3d = value

@export_group("Height")
## Z-step between height levels in the draw order.
@export var z_step : int = 10:
	set(step):
		z_step = step
		_dirty = true
## If on, the height level is z_index / z_step (upstream behavior).
@export var level_from_z_index: bool = true:
	set(value):
		level_from_z_index = value
		_dirty = true
		notify_property_list_changed()
## Height level of this layer, in blocks. Used when level_from_z_index is off.
@export var level: int = 0:
	set(value):
		level = value
		_dirty = true

@export_group("Cell")
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var size: Vector3 = Vector3(1, 1, 1):
	set(v_3):
		if grid_map: grid_map.cell_size = v_3
		size = v_3
## Offset of the 3D cells from the 2D tiles. The upstream plugin uses (0, 0, -0.5).
## Use (0, 0, 0) to put a tile's top face exactly on the tile drawn in 2D.
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var cell_offset: Vector3 = Vector3(0, 0, -0.5):
	set(v_3):
		cell_offset = v_3
		_sync_origin()

@export_group("Extrusion")
## Turns every 2D physics polygon of the tiles into a 3D wall on this layer's level.
@export var extrude_physics: bool = false:
	set(value):
		extrude_physics = value
		_dirty = true
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var wall_height: float = 1.0:
	set(value):
		wall_height = value
		_dirty = true
## 3D collision layer of the walls. 0 means: use the same layer as the blocks.
## Put the walls on their own layer to keep them out of the whisker mask of 2.5D bodies.
@export_flags_3d_physics var extrusion_layer: int = 0:
	set(value):
		extrusion_layer = value
		if extrusion: extrusion.collision_layer = value if value != 0 else collision_layer
## If on, the 2D physics of this layer is turned off, so only the 3D walls collide.
@export var disable_2d_collision: bool = true:
	set(value):
		disable_2d_collision = value
		if is_node_ready() and not Engine.is_editor_hint(): collision_enabled = not value

@export_group("Collision")
## 3D layers of the GridMap blocks (and of the walls while extrusion_layer is 0).
@export_flags_3d_physics var collision_layer: int = 1:
	set(value):
		if grid_map: grid_map.collision_layer = value
		if extrusion and extrusion_layer == 0: extrusion.collision_layer = value
		collision_layer = value
## 3D layers that the GridMap blocks and the walls collide with.
@export_flags_3d_physics var collision_mask: int = 1:
	set(value):
		if grid_map: grid_map.collision_mask = value
		if extrusion: extrusion.collision_mask = value
		collision_mask = value
@export_group("Navigation")
@export var bake_navigation: bool = false:
	set(value):
		if grid_map: grid_map.bake_navigation = value
		bake_navigation = value
@export_group("Transform")
@export_custom(PROPERTY_HINT_RANGE, "-360,360,0.1,or_less,or_greater,radians") var rotation_3d: Vector3 = Vector3(0, 0, 0):
	set(v_3):
		if grid_map: grid_map.rotation = v_3
		rotation_3d = v_3
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
	grid_map.cell_size = size
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
	if grid_map: grid_map.position = origin
	if extrusion: extrusion.position = origin

func update_grid_map() -> void:
	_dirty = false
	if not grid_map: return
	grid_map.clear()
	if extrusion: TileMapBuilder25D.clear_extrusion(extrusion)
	_built_level = get_level()
	TileMapBuilder25D.fill_grid_map(grid_map, self, _built_level, mesh_library)
	if extrude_physics and extrusion: TileMapBuilder25D.fill_extrusion(extrusion, self, _built_level, wall_height)
