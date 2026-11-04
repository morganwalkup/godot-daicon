@tool
@icon("res://addons/daicon/icons/daicon.svg")
class_name Area25D extends CollisionObject25D
## An area like Area2D. The core is an Area3D, so the overlap respects height: an area at another
## height does not overlap, and no same_level() filter is needed.
## It detects Daicon bodies and other Area25D nodes. It does not detect Area2D or 2D bodies.
##
## With no CollisionShape25D child, the node builds a box from footprint_size and area_height.
## Inside a Daicon body, the stored `height` is the height above that body, and the area keeps it
## when the body moves. get_height() returns the height above the ground, as on every Daicon node.
##
## Not mirrored: audio_bus_override and audio_bus_name (an Area3D changes only 3D audio),
## input_pickable and the mouse signals. The *_rid arguments of the shape signals are 3D RIDs.

signal body_entered(body: Node)
signal body_exited(body: Node)
signal area_entered(area: Node)
signal area_exited(area: Node)
signal body_shape_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int)
signal body_shape_exited(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int)
signal area_shape_entered(area_rid: RID, area: Node, area_shape_index: int, local_shape_index: int)
signal area_shape_exited(area_rid: RID, area: Node, area_shape_index: int, local_shape_index: int)

## Size of the built box on the ground plane, in px. Zero means no built box.
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var footprint_size: Vector2 = Vector2(16.0, 16.0)
## Height of the built box, in blocks.
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var area_height: float = 1.0
@export var monitoring: bool = true:
	set(value):
		monitoring = value
		if core: _area().monitoring = value
@export var monitorable: bool = true:
	set(value):
		monitorable = value
		if core: _area().monitorable = value
@export var priority: int = 0:
	set(value):
		priority = value
		if core: _area().priority = value

@export_group("Gravity")
@export var gravity_space_override: Area3D.SpaceOverride = Area3D.SPACE_OVERRIDE_DISABLED:
	set(value):
		gravity_space_override = value
		if core: _area().gravity_space_override = value
@export var gravity_point: bool = false:
	set(value):
		gravity_point = value
		if core: _area().gravity_point = value
@export var gravity_point_unit_distance: float = 0.0:
	set(value):
		gravity_point_unit_distance = value
		if core: _area().gravity_point_unit_distance = value
## In blocks, in the core's space.
@export var gravity_point_center: Vector3 = Vector3(0, -1, 0):
	set(value):
		gravity_point_center = value
		if core: _area().gravity_point_center = value
## A 3D direction. Down is -Y.
@export var gravity_direction: Vector3 = Vector3(0, -1, 0):
	set(value):
		gravity_direction = value
		if core: _area().gravity_direction = value
## In blocks/s².
@export var gravity: float = 9.8:
	set(value):
		gravity = value
		if core: _area().gravity = value

@export_group("Damp")
@export var linear_damp_space_override: Area3D.SpaceOverride = Area3D.SPACE_OVERRIDE_DISABLED:
	set(value):
		linear_damp_space_override = value
		if core: _area().linear_damp_space_override = value
@export var linear_damp: float = 0.1:
	set(value):
		linear_damp = value
		if core: _area().linear_damp = value
@export var angular_damp_space_override: Area3D.SpaceOverride = Area3D.SPACE_OVERRIDE_DISABLED:
	set(value):
		angular_damp_space_override = value
		if core: _area().angular_damp_space_override = value
@export var angular_damp: float = 0.1:
	set(value):
		angular_damp = value
		if core: _area().angular_damp = value

var _parent_body: CollisionObject25D
var _height_above_parent: float = 0.0
var _body_counts: Dictionary = {}
var _area_counts: Dictionary = {}


func _ready() -> void:
	var stored_height: float = height
	super._ready()
	if Engine.is_editor_hint():
		return
	if footprint_size.x > 0.0 and footprint_size.y > 0.0 and not has_shape_child(CollisionShape25D.Role.COLLISION):
		var box := BoxShape3D.new()
		box.size = Vector3(footprint_size.x / tile_size, area_height, footprint_size.y / tile_size)
		add_shape_3d(box, Vector3(0.0, area_height / 2.0, 0.0))
	_parent_body = find_parent_entity(self)
	if _parent_body:
		_height_above_parent = stored_height
		_last_synced = Vector2(INF, INF)
		_apply_position_write()
	var area := _area()
	area.body_entered.connect(_on_body_entered)
	area.body_exited.connect(_on_body_exited)
	area.area_entered.connect(_on_area_entered)
	area.area_exited.connect(_on_area_exited)
	area.body_shape_entered.connect(func(rid: RID, body: Node, body_shape: int, local_shape: int) -> void: body_shape_entered.emit(rid, from_3d(body), body_shape, local_shape))
	area.body_shape_exited.connect(func(rid: RID, body: Node, body_shape: int, local_shape: int) -> void: body_shape_exited.emit(rid, from_3d(body), body_shape, local_shape))
	area.area_shape_entered.connect(func(rid: RID, other: Area3D, area_shape: int, local_shape: int) -> void: area_shape_entered.emit(rid, from_3d(other), area_shape, local_shape))
	area.area_shape_exited.connect(func(rid: RID, other: Area3D, area_shape: int, local_shape: int) -> void: area_shape_exited.emit(rid, from_3d(other), area_shape, local_shape))


#region Area2D API
## The Daicon nodes (or raw 3D bodies) that overlap the area. One entry for each owner.
func get_overlapping_bodies() -> Array[Node]:
	if not core: return [] as Array[Node]
	return _owners(_area().get_overlapping_bodies())


## The Area25D nodes (or raw 3D areas) that overlap the area. One entry for each owner.
func get_overlapping_areas() -> Array[Node]:
	if not core: return [] as Array[Node]
	return _owners(_area().get_overlapping_areas())


func has_overlapping_bodies() -> bool:
	return core != null and _area().has_overlapping_bodies()


func has_overlapping_areas() -> bool:
	return core != null and _area().has_overlapping_areas()


## Accepts a Daicon body or a raw 3D body.
func overlaps_body(body: Node) -> bool:
	return core != null and get_overlapping_bodies().has(from_3d(body))


## Accepts an Area25D or a raw Area3D.
func overlaps_area(area: Node) -> bool:
	return core != null and get_overlapping_areas().has(from_3d(area))
#endregion


## Inside a Daicon body, this follows a height change of the body that does not move the drawn
## position. A script that overrides it must call super._physics_process(delta).
func _physics_process(_delta: float) -> void:
	if _parent_body and not Engine.is_editor_hint(): _apply_position_write()


func _apply_position_write() -> void:
	if _parent_body and core and is_instance_valid(_parent_body) and not Engine.is_editor_hint() and is_inside_tree():
		var written := global_position
		var h: float = _parent_body.get_height() + _height_above_parent
		if written.is_equal_approx(_last_synced) and is_equal_approx(h, core.position.y): return
		core.position = Vector3(written.x / tile_size, h, written.y / tile_size + h)
		_sync_from_core()
		return
	super._apply_position_write()


func _owners(nodes: Array) -> Array[Node]:
	var result: Array[Node] = []
	for node: Node in nodes:
		var daicon_owner := from_3d(node) as Node
		if daicon_owner and not result.has(daicon_owner): result.append(daicon_owner)
	return result


func _on_body_entered(body: Node) -> void:
	var daicon_owner := from_3d(body) as Node
	_body_counts[daicon_owner] = int(_body_counts.get(daicon_owner, 0)) + 1
	if _body_counts[daicon_owner] == 1: body_entered.emit(daicon_owner)


func _on_body_exited(body: Node) -> void:
	var daicon_owner := from_3d(body) as Node
	var count: int = int(_body_counts.get(daicon_owner, 0)) - 1
	if count > 0:
		_body_counts[daicon_owner] = count
		return
	_body_counts.erase(daicon_owner)
	body_exited.emit(daicon_owner)


func _on_area_entered(area: Area3D) -> void:
	var daicon_owner := from_3d(area) as Node
	_area_counts[daicon_owner] = int(_area_counts.get(daicon_owner, 0)) + 1
	if _area_counts[daicon_owner] == 1: area_entered.emit(daicon_owner)


func _on_area_exited(area: Area3D) -> void:
	var daicon_owner := from_3d(area) as Node
	var count: int = int(_area_counts.get(daicon_owner, 0)) - 1
	if count > 0:
		_area_counts[daicon_owner] = count
		return
	_area_counts.erase(daicon_owner)
	area_exited.emit(daicon_owner)


func _area() -> Area3D:
	return core as Area3D


func _create_core() -> CollisionObject3D:
	var area := Area3D.new()
	area.name = "Area3D"
	area.monitoring = monitoring
	area.monitorable = monitorable
	area.priority = priority
	area.gravity_space_override = gravity_space_override
	area.gravity_point = gravity_point
	area.gravity_point_unit_distance = gravity_point_unit_distance
	area.gravity_point_center = gravity_point_center
	area.gravity_direction = gravity_direction
	area.gravity = gravity
	area.linear_damp_space_override = linear_damp_space_override
	area.linear_damp = linear_damp
	area.angular_damp_space_override = angular_damp_space_override
	area.angular_damp = angular_damp
	return area
