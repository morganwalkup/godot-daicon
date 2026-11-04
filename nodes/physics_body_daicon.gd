@tool
class_name PhysicsBodyDaicon extends CollisionObjectDaicon
## Base of the Daicon bodies, like PhysicsBody2D. `motion` vectors are on the ground plane in px.
## The extra last argument `motion_height` is a vertical motion in blocks.

## The capsule of a 1-block character is this much shorter than 1 block, so it fits under a deck
## that is 1 block above its floor.
const BODY_CLEARANCE: float = 0.15

@export_group("Axis Lock")
@export var axis_lock_linear_x: bool = false:
	set(value):
		axis_lock_linear_x = value
		if core: (core as PhysicsBody3D).axis_lock_linear_x = value
@export var axis_lock_linear_y: bool = false:
	set(value):
		axis_lock_linear_y = value
		if core: (core as PhysicsBody3D).axis_lock_linear_y = value
@export var axis_lock_linear_z: bool = false:
	set(value):
		axis_lock_linear_z = value
		if core: (core as PhysicsBody3D).axis_lock_linear_z = value
@export var axis_lock_angular_x: bool = false:
	set(value):
		axis_lock_angular_x = value
		if core: (core as PhysicsBody3D).axis_lock_angular_x = value
@export var axis_lock_angular_y: bool = false:
	set(value):
		axis_lock_angular_y = value
		if core: (core as PhysicsBody3D).axis_lock_angular_y = value
@export var axis_lock_angular_z: bool = false:
	set(value):
		axis_lock_angular_z = value
		if core: (core as PhysicsBody3D).axis_lock_angular_z = value


## Moves the body along `motion` (ground px) and `motion_height` (blocks), and stops at the first
## collision. Returns the collision, or null.
func move_and_collide(motion: Vector2, test_only: bool = false, safe_margin: float = 0.08, recovery_as_collision: bool = false, motion_height: float = 0.0) -> KinematicCollisionDaicon:
	var body := core as PhysicsBody3D
	if not body: return null
	var hit := body.move_and_collide(_motion_3d(motion, motion_height), test_only, safe_margin / tile_size, recovery_as_collision)
	if not test_only: _sync_from_core()
	return KinematicCollisionDaicon.new(hit, tile_size) if hit else null


## True if the body would collide when it moves along `motion` from `from`. `from` is a drawn 2D
## transform; the body keeps its current height. `collision` gets the result, if not null.
func test_move(from: Transform2D, motion: Vector2, collision: KinematicCollisionDaicon = null, safe_margin: float = 0.08, recovery_as_collision: bool = false, max_collisions: int = 1, motion_height: float = 0.0) -> bool:
	var body := core as PhysicsBody3D
	if not body: return false
	var h: float = height
	var xform := Transform3D(body.global_basis, Vector3(from.origin.x / tile_size, h, from.origin.y / tile_size + h))
	var hit := KinematicCollision3D.new()
	var result := body.test_move(xform, _motion_3d(motion, motion_height), hit, safe_margin / tile_size, recovery_as_collision, max_collisions)
	if collision:
		collision._collision = hit
		collision._tile_size = tile_size
	return result


func add_collision_exception_with(body: Node) -> void:
	(core as PhysicsBody3D).add_collision_exception_with(_core_of(body))


func remove_collision_exception_with(body: Node) -> void:
	(core as PhysicsBody3D).remove_collision_exception_with(_core_of(body))


## The bodies that this body ignores. Daicon cores are mapped to their Daicon nodes.
func get_collision_exceptions() -> Array:
	return (core as PhysicsBody3D).get_collision_exceptions().map(func(b: Node) -> Object: return CollisionObjectDaicon.from_3d(b))


## The gravity at the body, in blocks per second squared (Vector3: 3D Y is up).
func get_gravity() -> Vector3:
	return (core as PhysicsBody3D).get_gravity()


func _motion_3d(motion: Vector2, motion_height: float) -> Vector3:
	return Vector3(motion.x / tile_size, motion_height, motion.y / tile_size)


func _core_of(node: Node) -> Node:
	return (node as CollisionObjectDaicon).core if node is CollisionObjectDaicon else node


func _init_core() -> void:
	super._init_core()
	var body := core as PhysicsBody3D
	if not body: return
	body.axis_lock_linear_x = axis_lock_linear_x
	body.axis_lock_linear_y = axis_lock_linear_y
	body.axis_lock_linear_z = axis_lock_linear_z
	body.axis_lock_angular_x = axis_lock_angular_x
	body.axis_lock_angular_y = axis_lock_angular_y
	body.axis_lock_angular_z = axis_lock_angular_z
