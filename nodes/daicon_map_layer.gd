@tool
@icon("res://addons/daicon/icons/daicon_map_layer.svg")
class_name DaiconMapLayer extends TileMapLayer
## A TileMapLayer that builds its own 3D collision.
## Use it alone (not under a DaiconMap). The height level is z_index / z_step,
## unless level_from_z_index is off. Then it is "level", and z_index only sets the draw order.

var grid_map : GridMap
var extrusion : StaticBody3D
var _dirty := true
var _built_level := 0

#region DaiconMapLayer Exports

@export var mesh_library : MeshLibrary:
	set(library):
		if grid_map: grid_map.mesh_library = library
		mesh_library = library
		_dirty = true
	get():
		return mesh_library
@export var physics_material : PhysicsMaterial:
	set(library):
		if grid_map: grid_map.physics_material = library
		if extrusion: extrusion.physics_material_override = library
		physics_material = library
	get():
		return physics_material
@export var visible_3d: bool = true:
	set(value):
		if grid_map: grid_map.visible = value
		visible_3d = value
	get():
		return visible_3d

@export_group("Height")
## Z-step in sortable system between height levels.
@export var z_step : int = 10:
	set(step):
		z_step = step
		_dirty = true
	get():
		return z_step
## If on, the height level is z_index / z_step (upstream behavior).
@export var level_from_z_index: bool = true:
	set(value):
		level_from_z_index = value
		_dirty = true
		notify_property_list_changed()
	get():
		return level_from_z_index
## Height level of this layer, in blocks. Used when level_from_z_index is off.
@export var level: int = 0:
	set(value):
		level = value
		_dirty = true
	get():
		return level

@export_group("Cell")
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var size: Vector3 = Vector3(1, 1, 1):
	set(v_3):
		if grid_map: grid_map.cell_size = v_3
		size = v_3
	get():
		return size
## Offset of the 3D cells from the 2D tiles. Upstream Daicon uses (0, 0, -0.5).
## Use (0, 0, 0) to put a tile's top face exactly on the tile drawn in 2D.
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var cell_offset: Vector3 = Vector3(0, 0, -0.5):
	set(v_3):
		cell_offset = v_3
		_sync_origin()
	get():
		return cell_offset

@export_group("Extrusion")
## Turns every 2D physics polygon of the tiles into a 3D wall on this layer's level.
@export var extrude_physics: bool = false:
	set(value):
		extrude_physics = value
		_dirty = true
	get():
		return extrude_physics
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var wall_height: float = 1.0:
	set(value):
		wall_height = value
		_dirty = true
	get():
		return wall_height
## 3D collision layer of the walls. 0 means: use the same layer as the blocks.
## Put the walls on their own layer to keep them out of the whisker mask of entities.
@export_flags_3d_physics var extrusion_layer: int = 0:
	set(value):
		extrusion_layer = value
		if extrusion: extrusion.collision_layer = value if value != 0 else layer
	get():
		return extrusion_layer
## If on, the 2D physics of this layer is turned off, so only the 3D walls collide.
@export var disable_2d_collision: bool = true:
	set(value):
		disable_2d_collision = value
		if is_node_ready() and not Engine.is_editor_hint(): collision_enabled = not value
	get():
		return disable_2d_collision

@export_group("Collision")
@export_flags_3d_physics var layer: int = 1:
	set(collision_layer):
		if grid_map: grid_map.collision_layer = collision_layer
		if extrusion and extrusion_layer == 0: extrusion.collision_layer = collision_layer
		layer = collision_layer
	get():
		return layer
@export_flags_3d_physics var mask: int = 1:
	set(collision_mask):
		if grid_map: grid_map.collision_mask = collision_mask
		if extrusion: extrusion.collision_mask = collision_mask
		mask = collision_mask
	get():
		return mask
@export_group("Navigation")
@export var bake_navigation: bool = false:
	set(value):
		if grid_map: grid_map.bake_navigation = value
		bake_navigation = value
	get():
		return bake_navigation
@export_group("Transorm")
@export_custom(PROPERTY_HINT_RANGE, "-360,360,0.1,or_less,or_greater,radians") var rotation_3d: Vector3 = Vector3(0, 0, 0):
	set(v_3):
		if grid_map: grid_map.rotation = v_3
		rotation_3d = v_3
	get():
		return rotation_3d
@export_custom(PROPERTY_HINT_LINK, "") var scale_3d: Vector3 = Vector3(1, 1, 1):
	set(v_3):
		if grid_map: grid_map.scale = v_3
		scale_3d = v_3
	get():
		return scale_3d

#endregion

func _validate_property(property: Dictionary) -> void:
	if property.name == "level" and level_from_z_index: property.usage &= ~PROPERTY_USAGE_EDITOR

func _ready() -> void:
	if not tile_set:
		self.set_y_sort_enabled(true)
		self.tile_set = TileSet.new()
		DaiconMapBuilder.add_item_layer(tile_set)
	if disable_2d_collision and not Engine.is_editor_hint(): collision_enabled = false
	#Expand GridMap
	grid_map = GridMap.new()
	grid_map.set_name("GridMap")
	add_child(grid_map)
	move_child(grid_map, 0)
	
	grid_map.mesh_library = mesh_library
	grid_map.physics_material = physics_material
	grid_map.cell_size = size
	grid_map.collision_layer = layer
	grid_map.collision_mask = mask
	grid_map.bake_navigation = bake_navigation
	grid_map.visible = visible_3d
	
	grid_map.rotation = rotation_3d
	grid_map.scale = scale_3d
	
	extrusion = StaticBody3D.new()
	extrusion.set_name(DaiconMapBuilder.EXTRUSION_NAME)
	extrusion.collision_layer = extrusion_layer if extrusion_layer != 0 else layer
	extrusion.collision_mask = mask
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
	var origin := DaiconMapBuilder.origin_3d(self, tile_set.tile_size, cell_offset)
	if grid_map: grid_map.position = origin
	if extrusion: extrusion.position = origin

func update_grid_map():
	_dirty = false
	if not grid_map: return
	grid_map.clear()
	if extrusion: DaiconMapBuilder.clear_extrusion(extrusion)
	_built_level = get_level()
	DaiconMapBuilder.fill_grid_map(grid_map, self, _built_level, mesh_library)
	if extrude_physics and extrusion: DaiconMapBuilder.fill_extrusion(extrusion, self, _built_level, wall_height)
