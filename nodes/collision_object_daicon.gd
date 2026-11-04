@tool
@icon("res://addons/daicon/icons/daicon.svg")
class_name CollisionObjectDaicon extends Node2D
## Base of every Daicon body and area. The API is like CollisionObject2D, but a hidden 3D node
## (`core`) does the physics. 1 block = 1 tile = `tile_size` px.
##
## Units (the same for every Daicon class):
## - `position` / `global_position`: px, where the node draws. x = X, y = Z - height (in tiles).
## - Ground position: px on the ground plane under the node (X, Z). See get_ground_position().
## - `height`: blocks above the ground (3D Y). The core origin is at the feet.
## - `collision_layer` / `collision_mask`: 3D layer bits.
##
## Not mirrored: input_pickable, input_event, mouse_entered/exited, mouse_shape_*, get_rid()
## (use get_rid_3d()), the shape-owner API (use CollisionShapeDaicon children).
## 2D rotation and scale do not rotate or scale the 3D shapes.

## Bodies whose heights differ by this much or more are not on the same level (see same_level()).
const SAME_LEVEL_TOLERANCE: float = 0.75
## Height of the whisker bottom above the feet, in blocks. It must be more than the rise of a 45° ramp
## across the whisker half-width, or a body on a ramp sees the ramp as an occluder and draws under it.
const WHISKER_LIFT: float = 0.35
const OWNER_META := &"daicon_owner"

## The hidden 3D node. Read-only.
var core: CollisionObject3D
## The draw-order area, or null. 3D bodies inside it are in front of this node, so it draws under them.
var whisker: Area3D
var _occluder: StaticBody3D
var _last_synced: Vector2 = Vector2(INF, INF)

## How many pixels are 1 block.
@export var tile_size: int = 16:
	set(size):
		if size > 0: tile_size = size

## Height of the feet above the ground, in blocks. Setting it keeps the ground position.
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var height: float = 0.0:
	set(value):
		height = value
		if core:
			core.position.y = value
			_sync_from_core()
	get():
		return core.position.y if core else height

## Z-step between height levels in the draw order.
@export var z_step: int = 10
## Height of the node in blocks, for the draw order.
@export var z_sort_coef: float = 1.0
## Rounds the drawn position to whole pixels after each sync, against pixel-art jitter.
## The core does not move.
@export var pixel_snap: bool = false
## Rotation of the core, in radians. 2D rotation does not affect the core.
@export_custom(PROPERTY_HINT_RANGE, "-360,360,0.1,or_less,or_greater,radians") var rotation_3d: Vector3 = Vector3.ZERO:
	set(value):
		rotation_3d = value
		if core: core.rotation = value

@export_group("Collision")
## 3D layers of the core.
@export_flags_3d_physics var collision_layer: int = 1:
	set(value):
		collision_layer = value
		if core: core.collision_layer = value
## 3D layers that the core collides with.
@export_flags_3d_physics var collision_mask: int = 1:
	set(value):
		collision_mask = value
		if core: core.collision_mask = value
@export var collision_priority: float = 1.0:
	set(value):
		collision_priority = value
		if core: core.collision_priority = value
## 3D layer of the occluder body that CollisionShapeDaicon nodes with role OCCLUDER build.
@export_flags_3d_physics var occluder_layer: int = 1 << 1
@export var disable_mode: CollisionObject3D.DisableMode = CollisionObject3D.DISABLE_MODE_REMOVE:
	set(value):
		disable_mode = value
		if core: core.disable_mode = value


func _ready() -> void:
	if tile_size <= 0: tile_size = 16
	set_y_sort_enabled(true)
	z_index = 1
	_init_core()
	for child: Node in get_children():
		if child is CollisionShapeDaicon: (child as CollisionShapeDaicon).attach()
	core.set_meta("z_index", z_index)
	if not Engine.is_editor_hint():
		_last_synced = _get_position_2d()
		set_notify_transform(true)


## A write to `position` or `global_position` at runtime moves the core there and keeps the height,
## as a write moves a built-in body. A parent move does the same.
func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_apply_position_write()


## Moves the core to a 2D position written since the last sync. The transform notification of a
## CanvasItem is deferred, so a physics move must call this first or the sync loses the write.
func _apply_position_write() -> void:
	if Engine.is_editor_hint() or not core or not is_inside_tree():
		return
	var written := global_position
	if written.is_equal_approx(_last_synced):
		return
	var h: float = core.position.y
	core.position = Vector3(written.x / tile_size, h, written.y / tile_size + h)
	_sync_from_core()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		if not core: _init_core()
		var position_2d := _get_position_2d()
		var core_2d := _project(core.position)
		if not position_2d.is_equal_approx(core_2d):
			core.position.x = position_2d.x / tile_size
			core.position.z = position_2d.y / tile_size + core.position.y


func _validate_property(_property: Dictionary) -> void:
	pass


#region Collision API
func set_collision_layer_value(layer_number: int, value: bool) -> void:
	collision_layer = _set_bit(collision_layer, layer_number, value)


func get_collision_layer_value(layer_number: int) -> bool:
	return collision_layer & (1 << (layer_number - 1)) != 0


func set_collision_mask_value(layer_number: int, value: bool) -> void:
	collision_mask = _set_bit(collision_mask, layer_number, value)


func get_collision_mask_value(layer_number: int) -> bool:
	return collision_mask & (1 << (layer_number - 1)) != 0


## The 3D RID of the core. There is no get_rid(): a 3D RID must not go to PhysicsServer2D.
func get_rid_3d() -> RID:
	return core.get_rid() if core else RID()


## The Daicon node that owns a 3D body or area, or the node itself if no Daicon node owns it.
static func from_3d(node: Object) -> Object:
	if node and node.has_meta(OWNER_META):
		var daicon_owner: Object = node.get_meta(OWNER_META)
		if is_instance_valid(daicon_owner): return daicon_owner
	return node


func _set_bit(bits: int, layer_number: int, value: bool) -> int:
	var bit := 1 << (layer_number - 1)
	return (bits | bit) if value else (bits & ~bit)
#endregion


#region Position and height
func get_height() -> float:
	return height


func set_height(value: float) -> void:
	height = value


## Position of the feet on the ground plane, in px. It ignores the height.
func get_ground_position() -> Vector2:
	if not core: return _get_position_2d() + Vector2(0.0, height * tile_size)
	return Vector2(core.position.x, core.position.z) * tile_size


## Position of the feet in 3D, in blocks.
func get_ground_position_3d() -> Vector3:
	if not core:
		var ground := get_ground_position() / tile_size
		return Vector3(ground.x, height, ground.y)
	return core.global_position


## Puts the feet at a drawn 2D global position and a height in blocks, without physics.
## NAN keeps the current height.
func teleport(position_2d: Vector2, new_height: float = NAN) -> void:
	var h: float = height if is_nan(new_height) else new_height
	if not core:
		_set_position_2d(position_2d)
		height = h
		return
	core.position = Vector3(position_2d.x / tile_size, h, position_2d.y / tile_size + h)
	_sync_from_core()


## True if this node and another node are near the same height. See height_of().
func is_same_level(other: Node) -> bool:
	return same_level(self, other)


## True if two nodes (for example a hitbox and a hurtbox) are near the same height. See height_of().
static func same_level(a: Node, b: Node) -> bool:
	return absf(height_of(a) - height_of(b)) < SAME_LEVEL_TOLERANCE


## The areas that overlap `area` and are near its height. It accepts an Area2D or an AreaDaicon.
static func same_level_areas(area: Node) -> Array:
	var result: Array = []
	for other: Node in area.call("get_overlapping_areas"):
		if same_level(area, other): result.append(other)
	return result


## Height of a node in blocks: the height of its nearest Daicon ancestor (or itself), or 0.
static func height_of(node: Node) -> float:
	var curr: Node = node
	while curr:
		if curr is CollisionObjectDaicon: return (curr as CollisionObjectDaicon).get_height()
		curr = curr.get_parent()
	return 0.0


## Walks up the parent chain and returns the first Daicon ancestor, or null.
static func find_parent_entity(node: Node) -> CollisionObjectDaicon:
	var curr: Node = node.get_parent()
	while curr:
		if curr is CollisionObjectDaicon: return curr as CollisionObjectDaicon
		curr = curr.get_parent()
	return null
#endregion


#region Draw order
## Writes the 2D position from the core and sets z_index with the whisker.
func update_pos(coef: float = 0.0) -> void:
	if coef == 0.0: coef = z_sort_coef
	_set_position_2d(_project(core.position))
	var h: float = core.position.y
	var bodies: Array[Node3D] = whisker.get_overlapping_bodies() if whisker else ([] as Array[Node3D])
	if not bodies.is_empty():
		# The lowest z of all occluders wins, so the node draws under every one of them.
		var lowest := z_index_for_height(h, coef)
		for body in bodies:
			if body == core: continue
			var occluder_z: int
			if body.has_meta("z_index"):
				occluder_z = int(body.get_meta("z_index")) - 1
			else:
				occluder_z = int(snappedf(h + 0.5, 0.01) + 0.55) * z_step - 1
			lowest = mini(lowest, occluder_z)
		z_index = lowest
	else:
		z_index = z_index_for_height(h, coef)
	core.set_meta("z_index", z_index)
	if _occluder: _occluder.set_meta("z_index", z_index)


## The z_index of a node that stands at a height (in blocks), with no occluder.
func z_index_for_height(at_height: float, coef: float = 0.0) -> int:
	if coef == 0.0: coef = z_sort_coef
	return int((snappedf(at_height, 0.01) + coef) * z_step + 2)
#endregion


#region Shapes
## The 3D node that holds the shapes of a CollisionShapeDaicon role. It builds the whisker or the
## occluder when the first shape needs it.
func shape_parent(role: int) -> CollisionObject3D:
	if not core: return null
	match role:
		CollisionShapeDaicon.Role.WHISKER:
			if not whisker:
				whisker = Area3D.new()
				whisker.name = "Whisker"
				whisker.collision_layer = 0
				whisker.collision_mask = 1 | occluder_layer
				# Keep it monitorable: physics treats a non-monitorable area as static, and then it misses static bodies.
				whisker.monitorable = true
				core.add_child(whisker)
			return whisker
		CollisionShapeDaicon.Role.OCCLUDER:
			if not _occluder:
				_occluder = StaticBody3D.new()
				_occluder.name = "Occluder"
				_occluder.collision_layer = occluder_layer
				_occluder.collision_mask = 0
				_occluder.set_meta(OWNER_META, self)
				_occluder.set_meta("z_index", z_index)
				core.add_child(_occluder)
			return _occluder
	return core


## Adds a CollisionShape3D to the node of a role, with a local position in blocks from the feet.
func add_shape_3d(shape: Shape3D, local_position: Vector3, role: int = CollisionShapeDaicon.Role.COLLISION, shape_name: String = "") -> CollisionShape3D:
	var parent := shape_parent(role)
	if not parent: return null
	var node := CollisionShape3D.new()
	if not shape_name.is_empty(): node.name = shape_name
	node.shape = shape
	node.position = local_position
	parent.add_child(node)
	return node


## True if the node has a CollisionShapeDaicon child of a role.
func has_shape_child(role: int = CollisionShapeDaicon.Role.COLLISION) -> bool:
	for child: Node in get_children():
		if child is CollisionShapeDaicon and (child as CollisionShapeDaicon).role == role: return true
	return false
#endregion


#region Core
func _create_core() -> CollisionObject3D:
	return StaticBody3D.new()


func _init_core() -> void:
	if core and is_instance_valid(core): return
	var start_height: float = height
	var position_2d := _get_position_2d()
	core = _create_core()
	core.set_meta(OWNER_META, self)
	add_child(core)
	move_child(core, 0)
	core.disable_mode = disable_mode
	core.collision_layer = collision_layer
	core.collision_mask = collision_mask
	core.collision_priority = collision_priority
	core.rotation = rotation_3d
	core.position = Vector3(position_2d.x / tile_size, start_height, position_2d.y / tile_size + start_height)


func _sync_from_core() -> void:
	update_pos()


## The drawn 2D position of a 3D point, in px.
func _project(point: Vector3) -> Vector2:
	return Vector2(point.x, point.z - point.y) * tile_size


func _get_position_2d() -> Vector2:
	return global_position if is_inside_tree() else position


func _set_position_2d(value: Vector2) -> void:
	if pixel_snap and not Engine.is_editor_hint(): value = value.round()
	if is_inside_tree():
		_last_synced = value
		global_position = value
	else:
		position = value
#endregion
