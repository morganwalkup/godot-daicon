@tool
class_name CollisionShapeDaicon extends Node2D
## A 3D shape for its parent Daicon body or area, like CollisionShape2D for a 2D body.
## The 2D position is an offset on the ground plane, in px. `offset_3d` adds a 3D offset in blocks
## from the feet. At runtime the node puts a CollisionShape3D under the parent's core.
##
## Not mirrored: one_way_collision, one_way_collision_margin. `shape` is a Shape3D.

enum Role {
	## A collision shape of the core.
	COLLISION,
	## A shape of the draw-order whisker (see CollisionObjectDaicon.whisker).
	WHISKER,
	## A shape of the occluder body: other nodes behind it draw under the parent.
	OCCLUDER,
}

@export var shape: Shape3D:
	set(value):
		shape = value
		if _shape_3d: _shape_3d.shape = value
		queue_redraw()
		update_configuration_warnings()
@export var disabled: bool = false:
	set(value):
		disabled = value
		if _shape_3d: _shape_3d.disabled = value
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var offset_3d: Vector3 = Vector3.ZERO:
	set(value):
		offset_3d = value
		_sync_shape()
		queue_redraw()
@export var role: Role = Role.COLLISION
@export var debug_color: Color = Color(0.0, 0.6, 0.7, 0.42):
	set(value):
		debug_color = value
		queue_redraw()

var _shape_3d: CollisionShape3D


func _ready() -> void:
	set_process(Engine.is_editor_hint())
	attach()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED or what == NOTIFICATION_UNPARENTED:
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if not get_parent() is CollisionObjectDaicon:
		warnings.append("CollisionShapeDaicon must be a direct child of a Daicon body or area.")
	if not shape:
		warnings.append("A shape must be set.")
	return warnings


## Puts the 3D shape under the parent's core. The parent calls it after it builds its core.
func attach() -> void:
	var parent := get_parent() as CollisionObjectDaicon
	if not parent or CollisionObjectDaicon.is_placeholder(parent) or not parent.core or not shape: return
	if _shape_3d and is_instance_valid(_shape_3d): return
	_shape_3d = parent.add_shape_3d(shape, _local_position(parent), role, name)
	_shape_3d.disabled = disabled
	if Engine.is_editor_hint(): _shape_3d.owner = null


func _exit_tree() -> void:
	if _shape_3d and is_instance_valid(_shape_3d): _shape_3d.queue_free()
	_shape_3d = null


func _sync_shape() -> void:
	var parent := get_parent() as CollisionObjectDaicon
	if _shape_3d and parent: _shape_3d.position = _local_position(parent)


func _local_position(parent: CollisionObjectDaicon) -> Vector3:
	return Vector3(position.x / parent.tile_size, 0.0, position.y / parent.tile_size) + offset_3d


func _process(_delta: float) -> void:
	if Engine.is_editor_hint(): _sync_shape()


func _draw() -> void:
	if not shape: return
	if not Engine.is_editor_hint() and not (is_inside_tree() and get_tree().debug_collisions_hint): return
	var parent := get_parent() as CollisionObjectDaicon
	var ts: float = float(parent.tile_size) if parent else 16.0
	var box := _footprint()
	var base := Rect2(Vector2(box.position.x, box.position.z + offset_3d.z - offset_3d.y - box.position.y) * ts, Vector2(box.size.x, box.size.z) * ts)
	base.position.x += offset_3d.x * ts
	draw_rect(base, debug_color, true)
	var top := base
	top.position.y -= box.size.y * ts
	draw_rect(top, Color(debug_color, 1.0), false, 1.0)
	draw_line(base.position, top.position, Color(debug_color, 1.0))
	draw_line(base.position + Vector2(base.size.x, 0.0), top.position + Vector2(top.size.x, 0.0), Color(debug_color, 1.0))


## The shape's bounds in blocks, from the feet: x and z are the footprint, y is the height.
func _footprint() -> AABB:
	if shape is BoxShape3D:
		var s: Vector3 = (shape as BoxShape3D).size
		return AABB(-s / 2.0, s)
	if shape is CapsuleShape3D:
		var c := shape as CapsuleShape3D
		return AABB(Vector3(-c.radius, -c.height / 2.0, -c.radius), Vector3(c.radius * 2.0, c.height, c.radius * 2.0))
	if shape is CylinderShape3D:
		var y := shape as CylinderShape3D
		return AABB(Vector3(-y.radius, -y.height / 2.0, -y.radius), Vector3(y.radius * 2.0, y.height, y.radius * 2.0))
	if shape is SphereShape3D:
		var r: float = (shape as SphereShape3D).radius
		return AABB(Vector3(-r, -r, -r), Vector3(r, r, r) * 2.0)
	return shape.get_debug_mesh().get_aabb()
