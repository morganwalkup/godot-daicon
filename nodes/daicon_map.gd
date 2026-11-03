@tool
@icon("res://addons/daicon/icons/daicon_map.svg")
class_name DaiconMap extends TileMap
## Builds 3D collision from its TileMapLayer children.
## The height level of a child layer is its z_index / z_step, or its "daicon_level" metadata if set.

var grid_map : GridMap
var extrusion : StaticBody3D
var _dirty := true
var _layer_levels: Dictionary = {}

#region DaiconMap Exports

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
## Z-step in sortable system between height levels.
@export var z_step : int = 10:
	set(step):
		z_step = step
		_dirty = true
	get():
		return z_step
@export var visible_3d: bool = true:
	set(value):
		if grid_map: grid_map.visible = value
		visible_3d = value
	get():
		return visible_3d

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
## Turns every 2D physics polygon of the tiles into a 3D wall on the layer's level.
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

@export_group("Collision")
@export_flags_3d_physics var layer: int = 1:
	set(collision_layer):
		if grid_map: grid_map.collision_layer = collision_layer
		if extrusion: extrusion.collision_layer = collision_layer
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

func _ready() -> void:
	if not tile_set:
		self.set_y_sort_enabled(true)
		self.set_layer_y_sort_enabled(0, true)
		self.set_tileset(TileSet.new())
		DaiconMapBuilder.add_item_layer(tile_set)
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
	extrusion.collision_layer = layer
	extrusion.collision_mask = mask
	extrusion.physics_material_override = physics_material
	add_child(extrusion)
	move_child(extrusion, 1)
	
	child_entered_tree.connect(_on_child_changed)
	child_exiting_tree.connect(_on_child_changed)
	for child in get_children(): _watch_layer(child)
	_sync_origin()
	update_grid_map()

func _process(_delta: float) -> void:
	_sync_origin()
	for child in get_children():
		if child is TileMapLayer and _layer_levels.get(child, null) != _level_of(child): _dirty = true
	if _dirty: update_grid_map()

## Returns the height level of a child layer.
func _level_of(child: TileMapLayer) -> int:
	if child.has_meta(&"daicon_level"): return int(child.get_meta(&"daicon_level"))
	return child.z_index / z_step if z_step != 0 else 0

func _watch_layer(child: Node) -> void:
	if child is TileMapLayer and not child.changed.is_connected(_mark_dirty):
		child.changed.connect(_mark_dirty)

func _on_child_changed(child: Node) -> void:
	_watch_layer(child)
	_dirty = true

func _mark_dirty() -> void:
	_dirty = true

func _sync_origin() -> void:
	if not tile_set: return
	var origin := DaiconMapBuilder.origin_3d(self, tile_set.tile_size, cell_offset)
	if grid_map: grid_map.position = origin
	if extrusion: extrusion.position = origin

func get_cells() -> int:
	var count := 0
	for layer_index in range(0, get_layers_count()):
		count += len(get_used_cells(layer_index))
	for child in get_children():
		if child is TileMapLayer: count += len(child.get_used_cells())
	return count

func update_grid_map():
	_dirty = false
	if not grid_map: return
	grid_map.clear()
	if extrusion: DaiconMapBuilder.clear_extrusion(extrusion)
	_layer_levels.clear()
	for layer_index in range(0, get_layers_count()):
		var z = get_layer_z_index(layer_index) / z_step
		for tile in get_used_cells(layer_index):
			var item := DaiconMapBuilder.item_for(tile_set, get_cell_tile_data(layer_index, tile), mesh_library)
			if item < 0: continue
			grid_map.set_cell_item(Vector3i(tile.x, z - 1, tile.y + z), item)
	for child in get_children():
		if child is TileMapLayer:
			var level := _level_of(child)
			_layer_levels[child] = level
			DaiconMapBuilder.fill_grid_map(grid_map, child, level, mesh_library)
			if extrude_physics and extrusion: DaiconMapBuilder.fill_extrusion(extrusion, child, level, wall_height)
