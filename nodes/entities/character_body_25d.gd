@tool
@icon("res://addons/daicon/icons/kinematic_daicon.svg")
class_name CharacterBody25D extends PhysicsBody25D
## A character body, like CharacterBody2D. A hidden CharacterBody3D (`core`) does the collision.
## Set `velocity` (px/s on the ground plane: x = east, y = south) and call move_and_slide().
## `velocity` is not the drawn screen velocity: on a ramp that goes north or south, the drawn
## y speed differs from velocity.y. Up and down is `vertical_velocity`, in blocks/s.
##
## Gravity: off by default, as on CharacterBody2D. With use_gravity on, move_and_slide() applies
## gravity_3d to vertical_velocity, and a physics frame with no move_and_slide() call still falls.
##
## Not mirrored: up_direction (up is always 3D Y; see up_direction_3d). get_floor_normal(),
## get_wall_normal(), and the velocity getters return the ground-plane part; the *_3d variants
## return the full Vector3. get_slide_collision() returns a KinematicCollision25D.

## After a teleport above the ground with use_gravity on, gravity waits this many physics frames
## at most for a floor to appear under the feet. A region that is still loading has no floor yet.
const AWAIT_FLOOR_FRAMES: int = 600

## Ground-plane velocity in px/s (x = east, y = south).
var velocity: Vector2 = Vector2.ZERO
## Vertical velocity in blocks/s. Positive is up.
var vertical_velocity: float = 0.0
## The NavigationAgent3D child of this body, or null. At runtime it moves onto a "Feet" node
## under the core, so its position is the feet on the 3D navmesh.
var navigation_agent: NavigationAgent3D

var _moved_frame: int = -1
var _await_floor_frames: int = 0
var _position_delta: Vector2 = Vector2.ZERO
var _requested_velocity: Vector2 = Vector2.ZERO

@export var motion_mode: CharacterBody3D.MotionMode = CharacterBody3D.MOTION_MODE_GROUNDED:
	set(value):
		motion_mode = value
		if core: _body().motion_mode = value
## Up is 3D Y. Change it only for a body that walks on walls or ceilings.
@export var up_direction_3d: Vector3 = Vector3.UP:
	set(value):
		up_direction_3d = value
		if core: _body().up_direction = value
@export var slide_on_ceiling: bool = true:
	set(value):
		slide_on_ceiling = value
		if core: _body().slide_on_ceiling = value
@export_range(1, 64) var max_slides: int = 4:
	set(value):
		max_slides = value
		if core: _body().max_slides = value
@export_range(0, 180, 0.1, "radians_as_degrees") var wall_min_slide_angle: float = deg_to_rad(15.0):
	set(value):
		wall_min_slide_angle = value
		if core: _body().wall_min_slide_angle = value

@export_group("Floor")
@export var floor_stop_on_slope: bool = true:
	set(value):
		floor_stop_on_slope = value
		if core: _body().floor_stop_on_slope = value
@export var floor_constant_speed: bool = false:
	set(value):
		floor_constant_speed = value
		if core: _body().floor_constant_speed = value
@export var floor_block_on_wall: bool = true:
	set(value):
		floor_block_on_wall = value
		if core: _body().floor_block_on_wall = value
@export_range(0, 180, 0.1, "radians_as_degrees") var floor_max_angle: float = deg_to_rad(45.0):
	set(value):
		floor_max_angle = value
		if core: _body().floor_max_angle = value
@export_range(0, 32, 0.1, "or_greater", "suffix:px") var floor_snap_length: float = 1.0:
	set(value):
		floor_snap_length = value
		if core: _body().floor_snap_length = value / tile_size

@export_group("Moving Platform")
@export var platform_on_leave: CharacterBody3D.PlatformOnLeave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_VELOCITY:
	set(value):
		platform_on_leave = value
		if core: _body().platform_on_leave = value
@export_flags_3d_physics var platform_floor_layers: int = 0xFFFFFFFF:
	set(value):
		platform_floor_layers = value
		if core: _body().platform_floor_layers = value
@export_flags_3d_physics var platform_wall_layers: int = 0:
	set(value):
		platform_wall_layers = value
		if core: _body().platform_wall_layers = value

@export_group("Collision")
@export_range(0.001, 256, 0.001, "suffix:px") var safe_margin: float = 0.08:
	set(value):
		safe_margin = value
		if core: _body().safe_margin = value / tile_size

@export_group("Gravity")
## If on, move_and_slide() applies gravity, and a frame with no move_and_slide() still falls.
@export var use_gravity: bool = false
## Downward acceleration, in blocks/s².
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks/s²") var gravity_3d: float = 30.0
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks/s") var max_fall_speed: float = 15.0

@export_group("Shape")
## Radius of the capsule that the body builds when it has no CollisionShape25D child, in px.
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var footprint_radius: float = 6.0
## Height of the body, in blocks. The capsule is BODY_CLEARANCE shorter.
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var body_height: float = 1.0
## How far the draw-order whisker reaches toward the camera, in blocks. Zero means no whisker.
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var whisker_reach: float = 3.0


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	if not has_shape_child(CollisionShape25D.Role.COLLISION): _add_body_shape()
	if not has_shape_child(CollisionShape25D.Role.WHISKER) and whisker_reach > 0.0: _add_whisker()
	_attach_navigation_agent()
	if use_gravity:
		# Run after the scripts that call move_and_slide(), so a frame with no call still falls.
		process_physics_priority = 100
	update_pos()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not core or not use_gravity:
		return
	if _moved_frame == Engine.get_physics_frames():
		return
	var planar: Vector2 = velocity
	velocity = Vector2.ZERO
	_slide(delta)
	velocity = planar


#region CharacterBody2D API
## Moves the body by `velocity` and `vertical_velocity` for one physics frame, and slides along
## collisions. With use_gravity on, it applies gravity first. Returns true on a collision.
func move_and_slide() -> bool:
	if Engine.is_editor_hint() or not core:
		return false
	return _slide(get_physics_process_delta_time())


func apply_floor_snap() -> void:
	_apply_position_write()
	_body().apply_floor_snap()
	_sync_from_core()


## Adds one frame of gravity to vertical_velocity, as move_and_slide() does with use_gravity on.
func apply_gravity(delta: float) -> void:
	if _await_floor_frames > 0:
		_await_floor_frames = 0 if _has_floor_below() else _await_floor_frames - 1
	if _await_floor_frames > 0:
		vertical_velocity = 0.0
	elif _body().is_on_floor() and vertical_velocity <= 0.0:
		vertical_velocity = 0.0
	else:
		vertical_velocity = maxf(vertical_velocity - gravity_3d * delta, -max_fall_speed)


func is_on_floor() -> bool:
	return core != null and _body().is_on_floor()


func is_on_floor_only() -> bool:
	return core != null and _body().is_on_floor_only()


func is_on_wall() -> bool:
	return core != null and _body().is_on_wall()


func is_on_wall_only() -> bool:
	return core != null and _body().is_on_wall_only()


func is_on_ceiling() -> bool:
	return core != null and _body().is_on_ceiling()


func is_on_ceiling_only() -> bool:
	return core != null and _body().is_on_ceiling_only()


func get_floor_angle(up_direction: Vector3 = Vector3.UP) -> float:
	return _body().get_floor_angle(up_direction)


## Ground-plane part of the floor normal, normalized. ZERO for a flat floor.
func get_floor_normal() -> Vector2:
	return _ground(_body().get_floor_normal()).normalized()


func get_floor_normal_3d() -> Vector3:
	return _body().get_floor_normal()


## Ground-plane part of the wall normal, normalized.
func get_wall_normal() -> Vector2:
	return _ground(_body().get_wall_normal()).normalized()


func get_wall_normal_3d() -> Vector3:
	return _body().get_wall_normal()


## The velocity of the last move after the slides, in ground px/s.
func get_real_velocity() -> Vector2:
	return _ground(_body().get_real_velocity()) * tile_size


func get_real_velocity_3d() -> Vector3:
	return _body().get_real_velocity()


func get_platform_velocity() -> Vector2:
	return _ground(_body().get_platform_velocity()) * tile_size


func get_platform_velocity_3d() -> Vector3:
	return _body().get_platform_velocity()


## The motion of the last move, in ground px.
func get_last_motion() -> Vector2:
	return _ground(_body().get_last_motion()) * tile_size


func get_last_motion_3d() -> Vector3:
	return _body().get_last_motion()


## The change of the drawn position in the last move, in px.
func get_position_delta() -> Vector2:
	return _position_delta


func get_slide_collision_count() -> int:
	return _body().get_slide_collision_count()


func get_slide_collision(slide_idx: int) -> KinematicCollision25D:
	var hit := _body().get_slide_collision(slide_idx)
	return KinematicCollision25D.new(hit, tile_size) if hit else null


func get_last_slide_collision() -> KinematicCollision25D:
	var hit := _body().get_last_slide_collision()
	return KinematicCollision25D.new(hit, tile_size) if hit else null
#endregion


## Moves the body by a ground-plane motion in px, as a push from another body. It does not change
## `velocity`. It slides along walls, floors, and ramps as move_and_slide() does. It does nothing in
## the air, and it does not push the body off a ledge: the move is undone when no floor is under
## the new position. Returns the motion done, in px.
func push(motion: Vector2) -> Vector2:
	if Engine.is_editor_hint() or not core or not is_on_floor() or motion == Vector2.ZERO:
		return Vector2.ZERO
	_apply_position_write()
	var body := _body()
	var start := body.global_transform
	var saved_velocity := body.velocity
	# A move_and_collide() along the floor stops at once when safe_margin is small, so slide instead.
	body.velocity = Vector3(motion.x, 0.0, motion.y) / tile_size / get_physics_process_delta_time()
	body.move_and_slide()
	body.velocity = saved_velocity
	if not _has_floor_below():
		body.global_transform = start
	_sync_from_core()
	return _ground(body.global_position - start.origin) * tile_size


## Pushes the CharacterBody25D bodies that the last move_and_slide() ran into, with push().
## A body is pushed only if it is on `layer_mask`, it is at the same level (see same_level()), and
## the requested velocity of this body points into it. The push is along the contact normal, at
## `push_speed` px/s or at the requested speed into the body if that is lower.
func push_slide_colliders(push_speed: float, layer_mask: int) -> void:
	if Engine.is_editor_hint() or not core:
		return
	var step: float = get_physics_process_delta_time()
	var pushed: Array[Object] = []
	for i: int in get_slide_collision_count():
		var hit := get_slide_collision(i)
		var other := hit.get_collider() as CharacterBody25D
		if other == null or other == self or pushed.has(other) or other.collision_layer & layer_mask == 0 or not same_level(self, other):
			continue
		var direction: Vector2 = -hit.get_normal()
		var speed: float = minf(push_speed, _requested_velocity.dot(direction))
		if direction == Vector2.ZERO or speed <= 0.0:
			continue
		pushed.append(other)
		other.push(direction * speed * step)


## Starts an upward move, in blocks/s. Does nothing in the air.
func jump(speed: float) -> void:
	if is_on_floor():
		vertical_velocity = speed


## Puts the feet at a drawn 2D global position and a height in blocks, and stops the body.
## NAN keeps the current height. With use_gravity on, a body above the ground does not fall until
## a floor is under it (see AWAIT_FLOOR_FRAMES).
func teleport(position_2d: Vector2, new_height: float = NAN) -> void:
	velocity = Vector2.ZERO
	vertical_velocity = 0.0
	var h: float = height if is_nan(new_height) else new_height
	_await_floor_frames = AWAIT_FLOOR_FRAMES if use_gravity and h > 0.05 else 0
	if core: _body().velocity = Vector3.ZERO
	super.teleport(position_2d, h)


func _slide(delta: float) -> bool:
	_moved_frame = Engine.get_physics_frames()
	_apply_position_write()
	if use_gravity: apply_gravity(delta)
	var body := _body()
	var before := _get_position_2d()
	_requested_velocity = velocity
	body.velocity = Vector3(velocity.x / tile_size, vertical_velocity, velocity.y / tile_size)
	var collided := body.move_and_slide()
	velocity = _ground(body.velocity) * tile_size
	vertical_velocity = body.velocity.y
	_sync_from_core()
	_position_delta = _get_position_2d() - before
	return collided


func _body() -> CharacterBody3D:
	return core as CharacterBody3D


func _ground(v: Vector3) -> Vector2:
	return Vector2(v.x, v.z)


func _has_floor_below() -> bool:
	var body := _body()
	var feet: Vector3 = body.global_position
	var query := PhysicsRayQueryParameters3D.create(feet + Vector3(0.0, 0.5, 0.0), feet - Vector3(0.0, 0.1, 0.0), body.collision_mask, [body.get_rid()])
	return not body.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## The capsule stands on the feet and is BODY_CLEARANCE shorter than body_height,
## so a 1-block body fits under a deck that is 1 block above its floor.
func _add_body_shape() -> void:
	var capsule := CapsuleShape3D.new()
	capsule.radius = footprint_radius / tile_size
	capsule.height = maxf(body_height - BODY_CLEARANCE, capsule.radius * 2.0)
	add_shape_3d(capsule, Vector3(0.0, capsule.height / 2.0, 0.0), CollisionShape25D.Role.COLLISION, "BodyShape")


## The whisker is the body's box swept toward the camera (up and south).
## Level blocks or occluders inside it are in front of the body, so the body draws under them.
func _add_whisker() -> void:
	var half_width: float = footprint_radius / tile_size * 0.8
	var sweep := Vector3(0.0, whisker_reach, whisker_reach)
	var points := PackedVector3Array()
	for x in [-half_width, half_width]:
		for y in [WHISKER_LIFT, body_height]:
			for z in [-half_width, half_width]:
				var corner := Vector3(x, y, z)
				points.append(corner)
				points.append(corner + sweep)
	var hull := ConvexPolygonShape3D.new()
	hull.points = points
	add_shape_3d(hull, Vector3.ZERO, CollisionShape25D.Role.WHISKER)


## A NavigationAgent3D uses its parent's position, so the agent goes on a node at the feet.
func _attach_navigation_agent() -> void:
	for child: Node in get_children():
		if child is NavigationAgent3D:
			var feet := Node3D.new()
			feet.name = "Feet"
			core.add_child(feet)
			child.reparent(feet, false)
			navigation_agent = child as NavigationAgent3D
			return


func _create_core() -> CollisionObject3D:
	var body := CharacterBody3D.new()
	body.name = "CharacterBody3D"
	body.motion_mode = motion_mode
	body.up_direction = up_direction_3d
	body.slide_on_ceiling = slide_on_ceiling
	body.max_slides = max_slides
	body.wall_min_slide_angle = wall_min_slide_angle
	body.floor_stop_on_slope = floor_stop_on_slope
	body.floor_constant_speed = floor_constant_speed
	body.floor_block_on_wall = floor_block_on_wall
	body.floor_max_angle = floor_max_angle
	body.floor_snap_length = floor_snap_length / tile_size
	body.platform_on_leave = platform_on_leave
	body.platform_floor_layers = platform_floor_layers
	body.platform_wall_layers = platform_wall_layers
	body.safe_margin = safe_margin / tile_size
	return body
