@tool
class_name DaiconMapBuilder extends RefCounted
## Shared 3D build logic for DaiconMap and DaiconMapLayer.
##
## Height levels: a layer on level L puts its blocks at Y [L-1, L) and its
## extruded walls at Y [L, L + wall_height). A tile drawn at row R on level L
## puts its 3D cell at Z = R + L, so its top face projects back onto row R.

const ITEM_LAYER := "Item"
const EXTRUSION_NAME := "Extrusion"

static var _warned_int_layers: Dictionary = {}


## Returns the MeshLibrary item for a tile, or -1 (GridMap.INVALID_CELL_ITEM) for none.
## A String "Item" layer holds the MeshLibrary item name. An empty string means no item.
## An int "Item" layer holds the item index (upstream format). Its unset value 0 is "Block".
static func item_for(tile_set: TileSet, tile_data: TileData, mesh_library: MeshLibrary) -> int:
	if not tile_set or not tile_data: return GridMap.INVALID_CELL_ITEM
	var layer_id := tile_set.get_custom_data_layer_by_name(ITEM_LAYER)
	if layer_id < 0: return GridMap.INVALID_CELL_ITEM
	var value: Variant = tile_data.get_custom_data_by_layer_id(layer_id)
	match typeof(value):
		TYPE_STRING, TYPE_STRING_NAME:
			var item_name := String(value)
			if item_name.is_empty() or not mesh_library: return GridMap.INVALID_CELL_ITEM
			var item := mesh_library.find_item_by_name(item_name)
			if item < 0: push_warning("Daicon: MeshLibrary has no item named '%s'." % item_name)
			return item
		TYPE_INT:
			if Engine.is_editor_hint() and not _warned_int_layers.has(tile_set):
				_warned_int_layers[tile_set] = true
				push_warning("Daicon: TileSet '%s' has an int \"Item\" layer. Unset tiles become item 0 (Block). Use a String layer with item names instead." % tile_set.resource_path)
			return int(value)
	return GridMap.INVALID_CELL_ITEM


## Adds a String "Item" custom data layer to a new TileSet.
static func add_item_layer(tile_set: TileSet) -> void:
	if tile_set.get_custom_data_layer_by_name(ITEM_LAYER) >= 0: return
	var index := tile_set.get_custom_data_layers_count()
	tile_set.add_custom_data_layer(index)
	tile_set.set_custom_data_layer_name(index, ITEM_LAYER)
	tile_set.set_custom_data_layer_type(index, TYPE_STRING)


## Writes the GridMap cells for one TileMapLayer on one height level.
static func fill_grid_map(grid_map: GridMap, layer: TileMapLayer, level: int, mesh_library: MeshLibrary) -> void:
	if not layer.tile_set: return
	for cell in layer.get_used_cells():
		var item := item_for(layer.tile_set, layer.get_cell_tile_data(cell), mesh_library)
		if item < 0: continue
		grid_map.set_cell_item(Vector3i(cell.x, level - 1, cell.y + level), item)


## Returns the 2D origin of a layer in tile units, for the 3D nodes that mirror it.
static func origin_3d(node: Node2D, tile_size: Vector2i, cell_offset: Vector3) -> Vector3:
	var origin := node.global_position if node.is_inside_tree() else node.position
	return Vector3(origin.x / tile_size.x, 0.0, origin.y / tile_size.y) + cell_offset


## Rebuilds the extruded walls of one TileMapLayer in a StaticBody3D.
## Every polygon of every 2D physics layer becomes a prism from the level floor up by wall_height.
## The body origin must match origin_3d() of the parent map.
static func fill_extrusion(body: StaticBody3D, layer: TileMapLayer, level: int, wall_height: float) -> void:
	var tile_set := layer.tile_set
	if not tile_set or wall_height <= 0.0: return
	var tile_size := Vector2(tile_set.tile_size)
	var cache: Dictionary = {}
	for cell in layer.get_used_cells():
		var tile_data := layer.get_cell_tile_data(cell)
		if not tile_data: continue
		var alternative := layer.get_cell_alternative_tile(cell)
		var key := [layer.get_cell_source_id(cell), layer.get_cell_atlas_coords(cell), alternative]
		var shapes: Array = cache.get(key, [])
		if not cache.has(key):
			shapes = _tile_shapes(tile_set, tile_data, alternative, tile_size, wall_height)
			cache[key] = shapes
		if shapes.is_empty(): continue
		var center := layer.map_to_local(cell) / tile_size
		var transform := Transform3D(Basis.IDENTITY, Vector3(center.x, float(level), center.y + float(level)))
		for shape in shapes:
			var shape_owner := body.create_shape_owner(layer)
			body.shape_owner_add_shape(shape_owner, shape)
			body.shape_owner_set_transform(shape_owner, transform)


## Removes all the walls that fill_extrusion() added to a body.
static func clear_extrusion(body: StaticBody3D) -> void:
	for owner_id in body.get_shape_owners():
		body.remove_shape_owner(owner_id)


static func _tile_shapes(tile_set: TileSet, tile_data: TileData, alternative: int, tile_size: Vector2, wall_height: float) -> Array:
	var shapes: Array = []
	var transpose := alternative & TileSetAtlasSource.TRANSFORM_TRANSPOSE
	var flip_h := alternative & TileSetAtlasSource.TRANSFORM_FLIP_H
	var flip_v := alternative & TileSetAtlasSource.TRANSFORM_FLIP_V
	for physics_layer in tile_set.get_physics_layers_count():
		for polygon_index in tile_data.get_collision_polygons_count(physics_layer):
			var points := tile_data.get_collision_polygon_points(physics_layer, polygon_index)
			if points.size() < 3: continue
			var transformed := PackedVector2Array()
			for point in points:
				var p := point
				if transpose: p = Vector2(p.y, p.x)
				if flip_h: p.x = -p.x
				if flip_v: p.y = -p.y
				transformed.append(p / tile_size)
			if Geometry2D.is_polygon_clockwise(transformed): transformed.reverse()
			for part in Geometry2D.decompose_polygon_in_convex(transformed):
				var prism := PackedVector3Array()
				for p in part:
					prism.append(Vector3(p.x, 0.0, p.y))
					prism.append(Vector3(p.x, wall_height, p.y))
				var shape := ConvexPolygonShape3D.new()
				shape.points = prism
				shapes.append(shape)
	return shapes
