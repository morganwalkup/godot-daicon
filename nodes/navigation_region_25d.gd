@tool
@icon("res://addons/daicon/icons/daicon_map_layer.svg")
class_name NavigationRegion25D
extends NavigationRegion3D
## The 3D navmesh of one map (one streamed region), for NavigationAgent3D on Daicon body cores.
## Put it as a direct child of the map's 2D root. Press "Bake navmesh" in the inspector.
## The bake reads the 3D blocks, ramps, and walls of every TileMapLayer25D under the parent,
## get_navigation_footprint() of every StaticBody25D, and a ground floor at height 0. It saves
## the NavigationMesh next to the scene. The game never bakes: it only loads the saved file.
## The whole native NavigationRegion3D API stays the same.

## The string values stay the same as in the old Kinsprit NavRegion25D, so saved fingerprints stay valid.
const SOURCE_GROUP := &"nav_region_25d_source"
const FINGERPRINT_META := &"source_fingerprint"
const DEFAULT_NAME := "NavigationRegion25D"
const POLL_SECONDS: float = 2.0

@export_tool_button("Bake navmesh", "Bake") var bake_button: Callable = bake
## Bake area in tiles, in the parent's space (x = X, y = Z on the ground). Zero size means the
## union of the TileMapLayer25D cells. Set it when two regions must meet at an exact edge.
@export var bounds: Rect2 = Rect2()
## Adds a walkable floor at height 0 over the bake area (a WorldBoundaryShape3D ground cannot be
## read by the baker).
@export var bake_ground: bool = true
## How many pixels are 1 block.
@export var tile_size: int = 16

@export_group("Bake")
## 3D layers of the static colliders that the bake reads.
@export_flags_3d_physics var geometry_collision_mask: int = 0xFFFFFFFF
## These must match navigation/3d/default_cell_size and default_cell_height in project.godot.
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var cell_size: float = 0.125
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var cell_height: float = 0.05
## Less than the 1-block clearance under a deck, so agents fit under it.
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var agent_height: float = 0.9
## At most one cell_size. The voxelization can make a thin wall up to one cell thicker on each side,
## so a gap that a 6 px body just fits through (0.75 blocks) can shrink to 0.5 blocks. A larger
## radius erodes that gap shut, and the navmesh splits where the body can walk (a 0.8-block gate
## in the forest). The body is wider than the agent and slides along the walls.
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var agent_radius: float = 0.125
## At least cell_size: a 45° ramp rises cell_size per cell. Much less than any ledge.
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var agent_max_climb: float = 0.15
@export_range(0.0, 90.0, 0.1, "degrees") var agent_max_slope: float = 50.0
## Geometry outside the bounds that the bake reads but trims off, so edges at the bounds are
## straight and the navmeshes of two regions that touch connect.
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var border_size: float = 0.5

var _poll: float = 0.0
var _stale: bool = false
var _placeholder_count: int = 0


func _ready() -> void:
	_sync_origin()
	set_process(Engine.is_editor_hint())
	if Engine.is_editor_hint():
		_poll = POLL_SECONDS


func _process(delta: float) -> void:
	_sync_origin()
	_poll += delta
	if _poll < POLL_SECONDS:
		return
	_poll = 0.0
	var placeholders := _placeholder_layers().size()
	var stale := placeholders == 0 and is_stale()
	if stale != _stale or placeholders != _placeholder_count:
		_stale = stale
		_placeholder_count = placeholders
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	if not get_parent() is Node2D:
		return PackedStringArray(["NavigationRegion25D must be a child of the map's 2D root."])
	var placeholders := _placeholder_layers()
	if not placeholders.is_empty():
		return PackedStringArray(["%s has a script without @tool, so it builds no 3D geometry in the editor. Add @tool to the script, or the bake and the stale check cannot read the layer." % placeholders[0].name])
	if not navigation_mesh:
		return PackedStringArray(["No navmesh. Press \"Bake navmesh\" in the inspector."])
	if _stale:
		return PackedStringArray(["The navmesh is stale: the map changed after the last bake. Press \"Bake navmesh\" and save the scene."])
	return PackedStringArray()


## Bakes the navmesh from the map and saves it to navmesh_path(). Editor and check scripts only.
func bake() -> void:
	var placeholders := _placeholder_layers()
	if not placeholders.is_empty():
		push_error("NavigationRegion25D: not baked. %s has a script without @tool, so the editor cannot read its 3D geometry." % placeholders[0].get_path())
		return
	var start := Time.get_ticks_usec()
	var path := navmesh_path()
	var nm: NavigationMesh = navigation_mesh if navigation_mesh and navigation_mesh.resource_path == path else NavigationMesh.new()
	bake_into(nm)
	nm.take_over_path(path)
	var err := ResourceSaver.save(nm, path)
	navigation_mesh = null
	navigation_mesh = nm
	_stale = false
	update_configuration_warnings()
	print("NavigationRegion25D: baked %s in %.0f ms (%d polygons), save error %d" % [path, (Time.get_ticks_usec() - start) / 1000.0, nm.get_polygon_count(), err])
	if Engine.is_editor_hint() and Engine.has_singleton("EditorInterface"):
		var editor: Object = Engine.get_singleton("EditorInterface")
		editor.call("mark_scene_as_unsaved")
		editor.call("get_resource_filesystem").call("update_file", path)


## Bakes into a NavigationMesh without saving it.
func bake_into(nm: NavigationMesh) -> void:
	_set_parameters(nm)
	var data := collect_source_geometry(nm)
	NavigationServer3D.bake_from_source_geometry_data(nm, data)
	nm.set_meta(FINGERPRINT_META, _fingerprint(data))


## True if there is no navmesh, or the map's geometry differs from the geometry of the last bake.
func is_stale() -> bool:
	if not navigation_mesh or not navigation_mesh.has_meta(FINGERPRINT_META):
		return true
	var probe := NavigationMesh.new()
	_set_parameters(probe)
	return String(navigation_mesh.get_meta(FINGERPRINT_META)) != _fingerprint(collect_source_geometry(probe))


## res://<scene path without extension>_nav.tres, or _<name>_nav.tres for a region not named
## NavigationRegion25D.
func navmesh_path() -> String:
	var scene_root: Node = owner if owner else self
	var base := scene_root.scene_file_path.get_basename()
	if name != DEFAULT_NAME:
		base += "_" + String(name).to_snake_case()
	return base + "_nav.tres"


## The source geometry in this node's space: map layers, still bodies, and the ground floor.
func collect_source_geometry(nm: NavigationMesh) -> NavigationMeshSourceGeometryData3D:
	_sync_origin()
	var parent := get_parent()
	var data := NavigationMeshSourceGeometryData3D.new()
	if not parent:
		return data
	var sources: Array[Node] = []
	for layer: TileMapLayer25D in _map_layers():
		for node: Node in [layer.get_grid_map(), layer.get_extrusion()]:
			if node:
				node.add_to_group(SOURCE_GROUP)
				sources.append(node)
	NavigationServer3D.parse_source_geometry_data(nm, data, self)
	for node: Node in sources:
		node.remove_from_group(SOURCE_GROUP)
	for node: Node in parent.find_children("*", "Node2D", true, false):
		if node is StaticBody25D:
			_add_footprint(data, node as StaticBody25D)
	if bake_ground:
		var box := nm.filter_baking_aabb.grow(border_size + agent_radius + cell_size)
		var a := Vector3(box.position.x, 0.0, box.position.z)
		var b := Vector3(box.end.x, 0.0, box.position.z)
		var c := Vector3(box.end.x, 0.0, box.end.z)
		var d := Vector3(box.position.x, 0.0, box.end.z)
		data.add_faces(PackedVector3Array([a, b, c, a, c, d]), global_transform)
	return data


## The bake area in this node's space, from `bounds` or from the TileMapLayer25D cells.
func bake_aabb() -> AABB:
	if bounds.has_area():
		return AABB(Vector3(bounds.position.x, -1.0, bounds.position.y), Vector3(bounds.size.x, 10.0, bounds.size.y))
	var box := AABB()
	var first := true
	for layer: TileMapLayer25D in _map_layers():
		var rect := layer.get_used_rect()
		if not rect.has_area() or not layer.tile_set:
			continue
		var level: int = layer.get_level()
		var origin: Vector3 = to_local(TileMapBuilder25D.origin_3d(layer, layer.tile_set.tile_size, layer.cell_offset))
		var cells := AABB(origin + Vector3(rect.position.x, -1.0, rect.position.y + level), Vector3(rect.size.x, 10.0, rect.size.y))
		box = cells if first else box.merge(cells)
		first = false
	return box


## The map layers that the bake reads. A placeholder layer (see _placeholder_layers()) is not one.
func _map_layers() -> Array[TileMapLayer25D]:
	return _find_layers(false)


## The map layers with a script without @tool. In the editor they have a placeholder script
## instance and build no GridMap or extrusion (see CollisionObject25D.is_placeholder()).
func _placeholder_layers() -> Array[TileMapLayer25D]:
	return _find_layers(true)


func _find_layers(placeholders: bool) -> Array[TileMapLayer25D]:
	var layers: Array[TileMapLayer25D] = []
	var parent := get_parent()
	if not parent:
		return layers
	for node: Node in parent.find_children("*", "TileMapLayer", true, false):
		if node is TileMapLayer25D and CollisionObject25D.is_placeholder(node) == placeholders:
			layers.append(node as TileMapLayer25D)
	return layers


## Keeps this node under the parent's 2D origin, as TileMapLayer25D does with its GridMap.
func _sync_origin() -> void:
	var parent := get_parent() as Node2D
	if not parent or not is_inside_tree():
		return
	position = Vector3(parent.global_position.x / tile_size, 0.0, parent.global_position.y / tile_size)


func _set_parameters(nm: NavigationMesh) -> void:
	nm.cell_size = cell_size
	nm.cell_height = cell_height
	nm.agent_height = agent_height
	nm.agent_radius = agent_radius
	nm.agent_max_climb = agent_max_climb
	nm.agent_max_slope = agent_max_slope
	nm.border_size = border_size
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = geometry_collision_mask
	nm.geometry_source_geometry_mode = NavigationMesh.SOURCE_GEOMETRY_GROUPS_EXPLICIT
	nm.geometry_source_group_name = SOURCE_GROUP
	# The bake trims border_size off the inside of the filter AABB.
	nm.filter_baking_aabb = bake_aabb().grow(border_size)


## A still body builds its footprint only at runtime, so the bake adds the same box here.
## add_faces() takes global space: the data already holds the inverse of this node's transform.
## The static helper, not body.get_navigation_footprint(): in the editor the body can be a
## placeholder (a subclass without @tool, for example a barrel), and a placeholder has no methods.
func _add_footprint(data: NavigationMeshSourceGeometryData3D, body: StaticBody25D) -> void:
	var footprint := StaticBody25D.navigation_footprint_of(body)
	if not footprint.has_volume():
		return
	var box := BoxMesh.new()
	box.size = footprint.size
	data.add_faces(box.get_faces(), Transform3D(Basis.IDENTITY, footprint.get_center()))


## A hash of the bake parameters and the source triangles, rounded to 1/1024 block and sorted,
## so neither float noise nor the order in which the parser visits cells changes it.
func _fingerprint(data: NavigationMeshSourceGeometryData3D) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(("%s|%s|%s|%s|%s|%s|%s|%s" % [cell_size, cell_height, agent_height, agent_radius, agent_max_climb, agent_max_slope, border_size, bake_aabb()]).to_utf8_buffer())
	var vertices := data.get_vertices()
	var indices := data.get_indices()
	var triangles: Array[String] = []
	var tri := PackedInt32Array()
	tri.resize(9)
	for t in range(0, indices.size() - 2, 3):
		for k in 3:
			var v: int = indices[t + k] * 3
			for axis in 3:
				tri[k * 3 + axis] = roundi(vertices[v + axis] * 1024.0)
		triangles.append(tri.to_byte_array().hex_encode())
	triangles.sort()
	ctx.update("\n".join(triangles).to_utf8_buffer())
	return ctx.finish().hex_encode()
