@tool
@icon("res://addons/world_25d/icons/static_body_25d.svg")
class_name StaticBody25D extends PhysicsBody25D
## A still body, like StaticBody2D. The core is a StaticBody3D.
##
## With no CollisionShape25D child, the node builds a box from footprint_size and wall_height.
## With occluder_height above zero and no OCCLUDER shape child, it builds an occluder box.
## The node syncs the 2D position only on change (teleport, a position write, or a parent move).
##
## Not mirrored: the Vector2 constant_angular_velocity (it is a float yaw rate here).

## Size of the solid footprint on the ground plane, in px. Zero means no built box.
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var footprint_size: Vector2 = Vector2(12.0, 8.0)
## Height of the built solid box, in blocks.
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var wall_height: float = 1.0
## Height of the built occluder volume, in blocks. Use the height of the art (a 3-tile tree is 3).
## Zero means no occluder. Then normal y-sort is the only draw-order rule.
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var occluder_height: float = 0.0
## Size of the occluder footprint, in px. Zero means footprint_size.
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var occluder_size: Vector2 = Vector2.ZERO
## On for a body that can go away at runtime, for example a barrel. NavigationRegion25D does
## not bake it. It gets a NavigationObstacle3D, so agents with avoidance steer around it.
@export var navigation_obstacle: bool = false

@export var physics_material_override: PhysicsMaterial:
	set(material):
		physics_material_override = material
		if core: (core as StaticBody3D).physics_material_override = material
## Velocity that the body gives to bodies on it, in px/s on the ground plane. The body does not move.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var constant_linear_velocity: Vector2 = Vector2.ZERO:
	set(value):
		constant_linear_velocity = value
		_apply_constant_velocity()
## Vertical velocity that the body gives to bodies on it, in blocks/s.
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks/s") var constant_vertical_velocity: float = 0.0:
	set(value):
		constant_vertical_velocity = value
		_apply_constant_velocity()
## Yaw rate (rotation about the 3D up axis) that the body gives to bodies on it, in rad/s.
@export_custom(PROPERTY_HINT_NONE, "radians_as_degrees,suffix:°/s") var constant_angular_velocity: float = 0.0:
	set(value):
		constant_angular_velocity = value
		_apply_constant_velocity()

var _obstacle: NavigationObstacle3D


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	if _has_footprint() and not has_shape_child(CollisionShape25D.Role.COLLISION):
		add_shape_3d(_box(footprint_size, wall_height), Vector3(0.0, wall_height / 2.0, 0.0))
	if occluder_height > 0.0 and not has_shape_child(CollisionShape25D.Role.OCCLUDER):
		var size: Vector2 = occluder_size if occluder_size != Vector2.ZERO else footprint_size
		add_shape_3d(_box(size, occluder_height), Vector3(0.0, occluder_height / 2.0, 0.0), CollisionShape25D.Role.OCCLUDER)
	if navigation_obstacle and _has_footprint():
		_obstacle = NavigationObstacle3D.new()
		_obstacle.name = "NavigationObstacle3D"
		_obstacle.radius = footprint_size.length() / 2.0 / tile_size
		_obstacle.height = wall_height
		_obstacle.avoidance_enabled = true
		core.add_child(_obstacle)
	update_pos()


## Turns the avoidance obstacle on or off, for example when a barrel breaks.
func set_obstacle_enabled(enabled: bool) -> void:
	if _obstacle:
		_obstacle.avoidance_enabled = enabled


## The solid box that NavigationRegion25D bakes, in 3D global blocks. Empty for a navigation
## obstacle or a body with no footprint. It reads the 2D position, so it also works in the editor.
func get_navigation_footprint() -> AABB:
	return navigation_footprint_of(self)


## get_navigation_footprint() of a body. It reads only exported properties and the native position,
## so it also works on a placeholder in the editor (see is_placeholder()), for example a subclass
## without @tool.
static func navigation_footprint_of(body: StaticBody25D) -> AABB:
	var size_px: Vector2 = body.footprint_size
	if body.navigation_obstacle or size_px.x <= 0.0 or size_px.y <= 0.0:
		return AABB()
	var ts: float = body.tile_size
	var h: float = body.height
	var drawn: Vector2 = body.global_position if body.is_inside_tree() else body.position
	var feet := Vector3(drawn.x / ts, h, drawn.y / ts + h)
	var size := Vector3(size_px.x / ts, body.wall_height, size_px.y / ts)
	return AABB(feet - Vector3(size.x / 2.0, 0.0, size.z / 2.0), size)


func _has_footprint() -> bool:
	return footprint_size.x > 0.0 and footprint_size.y > 0.0


func _box(size_px: Vector2, box_height: float) -> BoxShape3D:
	var box := BoxShape3D.new()
	box.size = Vector3(size_px.x / tile_size, box_height, size_px.y / tile_size)
	return box


func _apply_constant_velocity() -> void:
	var body := core as StaticBody3D
	if not body: return
	body.constant_linear_velocity = Vector3(constant_linear_velocity.x / tile_size, constant_vertical_velocity, constant_linear_velocity.y / tile_size)
	body.constant_angular_velocity = Vector3(0.0, constant_angular_velocity, 0.0)


func _create_core() -> CollisionObject3D:
	var body := StaticBody3D.new()
	body.name = "StaticBody3D"
	return body


func _init_core() -> void:
	super._init_core()
	(core as StaticBody3D).physics_material_override = physics_material_override
	_apply_constant_velocity()
