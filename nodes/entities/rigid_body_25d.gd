@tool
@icon("res://addons/daicon/icons/rigid_daicon.svg")
class_name RigidBody25D extends PhysicsBody25D
## A body that the physics engine moves, like RigidBody2D. The core is a RigidBody3D.
## Planar values are px on the ground plane (x = east, y = south). Vertical values are blocks.
## Gravity pulls down in 3D (-Y), so gravity_scale acts on vertical_velocity, not on linear_velocity.y.
## The node syncs the 2D position in each physics step.
##
## Not mirrored: _integrate_forces(state) (the state is 3D; define _integrate_forces_3d(state)
## and set custom_integrator), and the Vector2 center_of_mass (it is a Vector3 in blocks).

signal body_entered(body: Node)
signal body_exited(body: Node)
signal body_shape_entered(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int)
signal body_shape_exited(body_rid: RID, body: Node, body_shape_index: int, local_shape_index: int)
signal sleeping_state_changed

@export_custom(PROPERTY_HINT_RANGE, "0.001,1000,or_greater,suffix:kg,exp") var mass: float = 1.0:
	set(value):
		mass = value
		if core: _rigid().mass = value
@export var physics_material_override: PhysicsMaterial:
	set(value):
		physics_material_override = value
		if core: _rigid().physics_material_override = value
@export_range(-8.0, 8.0, 0.001, "or_less", "or_greater") var gravity_scale: float = 1.0:
	set(value):
		gravity_scale = value
		if core: _rigid().gravity_scale = value

@export_group("Mass Distribution")
@export var center_of_mass_mode: RigidBody3D.CenterOfMassMode = RigidBody3D.CENTER_OF_MASS_MODE_AUTO:
	set(value):
		center_of_mass_mode = value
		if core: _rigid().center_of_mass_mode = value
## In blocks, in the core's space. Used with CENTER_OF_MASS_MODE_CUSTOM.
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var center_of_mass: Vector3 = Vector3.ZERO:
	set(value):
		center_of_mass = value
		if core: _rigid().center_of_mass = value
@export var inertia: Vector3 = Vector3.ZERO:
	set(value):
		inertia = value
		if core: _rigid().inertia = value

@export_group("Deactivation")
@export var sleeping: bool = false:
	set(value):
		sleeping = value
		if core: _rigid().sleeping = value
	get():
		return _rigid().sleeping if core else sleeping
@export var can_sleep: bool = true:
	set(value):
		can_sleep = value
		if core: _rigid().can_sleep = value
@export var lock_rotation: bool = false:
	set(value):
		lock_rotation = value
		if core: _rigid().lock_rotation = value
@export var freeze: bool = false:
	set(value):
		freeze = value
		if core: _rigid().freeze = value
@export var freeze_mode: RigidBody3D.FreezeMode = RigidBody3D.FREEZE_MODE_STATIC:
	set(value):
		freeze_mode = value
		if core: _rigid().freeze_mode = value

@export_group("Solver")
@export var custom_integrator: bool = false:
	set(value):
		custom_integrator = value
		if core: _rigid().custom_integrator = value
@export var continuous_cd: bool = false:
	set(value):
		continuous_cd = value
		if core: _rigid().continuous_cd = value
@export var contact_monitor: bool = false:
	set(value):
		contact_monitor = value
		if core: _rigid().contact_monitor = value
@export var max_contacts_reported: int = 0:
	set(value):
		max_contacts_reported = value
		if core: _rigid().max_contacts_reported = value

@export_group("Linear")
## In px/s on the ground plane (x = east, y = south). Height is vertical_velocity.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var linear_velocity: Vector2 = Vector2.ZERO:
	set(value):
		linear_velocity = value
		if core:
			var v := _rigid().linear_velocity
			_rigid().linear_velocity = Vector3(value.x / tile_size, v.y, value.y / tile_size)
	get():
		if not core: return linear_velocity
		var v := _rigid().linear_velocity
		return Vector2(v.x, v.z) * tile_size
## In blocks/s. Up is positive.
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks/s") var vertical_velocity: float = 0.0:
	set(value):
		vertical_velocity = value
		if core:
			var v := _rigid().linear_velocity
			_rigid().linear_velocity = Vector3(v.x, value, v.z)
	get():
		return _rigid().linear_velocity.y if core else vertical_velocity
@export var linear_damp_mode: RigidBody3D.DampMode = RigidBody3D.DAMP_MODE_COMBINE:
	set(value):
		linear_damp_mode = value
		if core: _rigid().linear_damp_mode = value
@export_range(0.0, 100.0, 0.001, "or_greater") var linear_damp: float = 0.0:
	set(value):
		linear_damp = value
		if core: _rigid().linear_damp = value

@export_group("Angular")
## The yaw rate (rotation about the 3D up axis), in rad/s. The full 3D value is angular_velocity_3d.
@export_custom(PROPERTY_HINT_NONE, "radians_as_degrees,suffix:°/s") var angular_velocity: float = 0.0:
	set(value):
		angular_velocity = value
		if core:
			var w := _rigid().angular_velocity
			_rigid().angular_velocity = Vector3(w.x, value, w.z)
	get():
		return _rigid().angular_velocity.y if core else angular_velocity
@export var angular_damp_mode: RigidBody3D.DampMode = RigidBody3D.DAMP_MODE_COMBINE:
	set(value):
		angular_damp_mode = value
		if core: _rigid().angular_damp_mode = value
@export_range(0.0, 100.0, 0.001, "or_greater") var angular_damp: float = 0.0:
	set(value):
		angular_damp = value
		if core: _rigid().angular_damp = value

## The angular velocity of the core, in rad/s.
var angular_velocity_3d: Vector3:
	set(value):
		if core: _rigid().angular_velocity = value
	get():
		return _rigid().angular_velocity if core else Vector3(0.0, angular_velocity, 0.0)


func _ready() -> void:
	super._ready()
	process_physics_priority = 100
	if Engine.is_editor_hint():
		return
	var body := _rigid()
	body.body_entered.connect(func(other: Node) -> void: body_entered.emit(from_3d(other)))
	body.body_exited.connect(func(other: Node) -> void: body_exited.emit(from_3d(other)))
	body.body_shape_entered.connect(func(rid: RID, other: Node, other_shape: int, local_shape: int) -> void: body_shape_entered.emit(rid, from_3d(other), other_shape, local_shape))
	body.body_shape_exited.connect(func(rid: RID, other: Node, other_shape: int, local_shape: int) -> void: body_shape_exited.emit(rid, from_3d(other), other_shape, local_shape))
	body.sleeping_state_changed.connect(sleeping_state_changed.emit)
	if has_method(&"_integrate_forces_3d"):
		PhysicsServer3D.body_set_force_integration_callback(body.get_rid(), Callable(self, &"_integrate_forces_3d"))


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not core:
		return
	_apply_position_write()
	update_pos()


#region RigidBody2D API
## The Daicon nodes (or raw 3D bodies) that touch the body. Needs contact_monitor.
func get_colliding_bodies() -> Array[Node]:
	var result: Array[Node] = []
	if not core: return result
	for other: Node3D in _rigid().get_colliding_bodies():
		var daicon_owner := from_3d(other) as Node
		if daicon_owner and not result.has(daicon_owner): result.append(daicon_owner)
	return result


func get_contact_count() -> int:
	return _rigid().get_contact_count() if core else 0


## impulse and position are in px on the ground plane; vertical is in blocks.
func apply_impulse(impulse: Vector2, position_px: Vector2 = Vector2.ZERO, vertical: float = 0.0) -> void:
	_rigid().apply_impulse(_planar_3d(impulse, vertical), _planar_3d(position_px, 0.0))


func apply_central_impulse(impulse: Vector2, vertical: float = 0.0) -> void:
	_rigid().apply_central_impulse(_planar_3d(impulse, vertical))


func apply_force(force: Vector2, position_px: Vector2 = Vector2.ZERO, vertical: float = 0.0) -> void:
	_rigid().apply_force(_planar_3d(force, vertical), _planar_3d(position_px, 0.0))


func apply_central_force(force: Vector2, vertical: float = 0.0) -> void:
	_rigid().apply_central_force(_planar_3d(force, vertical))


func add_constant_force(force: Vector2, position_px: Vector2 = Vector2.ZERO, vertical: float = 0.0) -> void:
	_rigid().add_constant_force(_planar_3d(force, vertical), _planar_3d(position_px, 0.0))


func add_constant_central_force(force: Vector2, vertical: float = 0.0) -> void:
	_rigid().add_constant_central_force(_planar_3d(force, vertical))


## A yaw torque (about the 3D up axis).
func apply_torque(torque: float) -> void:
	_rigid().apply_torque(Vector3(0.0, torque, 0.0))


func apply_torque_impulse(torque: float) -> void:
	_rigid().apply_torque_impulse(Vector3(0.0, torque, 0.0))


func add_constant_torque(torque: float) -> void:
	_rigid().add_constant_torque(Vector3(0.0, torque, 0.0))


## The 3D variants take blocks.
func apply_impulse_3d(impulse: Vector3, position_3d: Vector3 = Vector3.ZERO) -> void:
	_rigid().apply_impulse(impulse, position_3d)


func apply_force_3d(force: Vector3, position_3d: Vector3 = Vector3.ZERO) -> void:
	_rigid().apply_force(force, position_3d)
#endregion


func _planar_3d(value: Vector2, vertical: float) -> Vector3:
	return Vector3(value.x / tile_size, vertical, value.y / tile_size)


func _rigid() -> RigidBody3D:
	return core as RigidBody3D


func _create_core() -> CollisionObject3D:
	var body := RigidBody3D.new()
	body.name = "RigidBody3D"
	body.mass = mass
	body.physics_material_override = physics_material_override
	body.gravity_scale = gravity_scale
	body.center_of_mass_mode = center_of_mass_mode
	body.center_of_mass = center_of_mass
	body.inertia = inertia
	body.sleeping = sleeping
	body.can_sleep = can_sleep
	body.lock_rotation = lock_rotation
	body.freeze = freeze
	body.freeze_mode = freeze_mode
	body.custom_integrator = custom_integrator
	body.continuous_cd = continuous_cd
	body.contact_monitor = contact_monitor
	body.max_contacts_reported = max_contacts_reported
	body.linear_velocity = Vector3(linear_velocity.x / tile_size, vertical_velocity, linear_velocity.y / tile_size)
	body.linear_damp_mode = linear_damp_mode
	body.linear_damp = linear_damp
	body.angular_velocity = Vector3(0.0, angular_velocity, 0.0)
	body.angular_damp_mode = angular_damp_mode
	body.angular_damp = angular_damp
	return body
