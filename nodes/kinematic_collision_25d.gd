class_name KinematicCollision25D extends RefCounted
## One collision of a 2.5D body, like KinematicCollision2D. It wraps a KinematicCollision3D.
## Vectors are on the ground plane in px (x = east, y = south), unless the name ends in _3d.
## get_position() is the drawn 2D position of the contact point.

var _collision: KinematicCollision3D
var _tile_size: float


func _init(collision: KinematicCollision3D = KinematicCollision3D.new(), tile_size: float = 16.0) -> void:
	_collision = collision
	_tile_size = tile_size


## The 2.5D node that owns the collider, or the collider itself (for example a GridMap is mapped
## to its TileMapLayer25D).
func get_collider(collision_index: int = 0) -> Object:
	return CollisionObject25D.from_3d(_collision.get_collider(collision_index))


func get_collider_3d(collision_index: int = 0) -> Object:
	return _collision.get_collider(collision_index)


func get_collider_id(collision_index: int = 0) -> int:
	var collider := get_collider(collision_index)
	return collider.get_instance_id() if collider else 0


func get_collider_rid(collision_index: int = 0) -> RID:
	return _collision.get_collider_rid(collision_index)


func get_collider_shape(collision_index: int = 0) -> Object:
	return _collision.get_collider_shape(collision_index)


func get_collider_shape_index(collision_index: int = 0) -> int:
	return _collision.get_collider_shape_index(collision_index)


func get_collision_count() -> int:
	return _collision.get_collision_count()


## Ground-plane part of the normal, normalized. ZERO for a flat floor or ceiling.
func get_normal(collision_index: int = 0) -> Vector2:
	var n := _collision.get_normal(collision_index)
	return Vector2(n.x, n.z).normalized()


func get_normal_3d(collision_index: int = 0) -> Vector3:
	return _collision.get_normal(collision_index)


## The drawn 2D position of the contact point, in px.
func get_position(collision_index: int = 0) -> Vector2:
	var p := _collision.get_position(collision_index)
	return Vector2(p.x, p.z - p.y) * _tile_size


func get_position_3d(collision_index: int = 0) -> Vector3:
	return _collision.get_position(collision_index)


func get_travel() -> Vector2:
	var t := _collision.get_travel()
	return Vector2(t.x, t.z) * _tile_size


func get_travel_3d() -> Vector3:
	return _collision.get_travel()


func get_remainder() -> Vector2:
	var r := _collision.get_remainder()
	return Vector2(r.x, r.z) * _tile_size


func get_remainder_3d() -> Vector3:
	return _collision.get_remainder()


func get_angle(collision_index: int = 0, up_direction: Vector3 = Vector3.UP) -> float:
	return _collision.get_angle(collision_index, up_direction)


func get_depth() -> float:
	return _collision.get_depth() * _tile_size


func get_collider_velocity(collision_index: int = 0) -> Vector2:
	var v := _collision.get_collider_velocity(collision_index)
	return Vector2(v.x, v.z) * _tile_size


func get_collider_velocity_3d(collision_index: int = 0) -> Vector3:
	return _collision.get_collider_velocity(collision_index)
