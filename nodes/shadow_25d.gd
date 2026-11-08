@tool
@icon("res://addons/world_25d/icons/shadow_25d.svg")
class_name Shadow25D extends Sprite2D
## A drop shadow for its nearest 2.5D ancestor (see CollisionObject25D.find_parent_25d()).
## A ShapeCast3D under the ancestor's core finds the highest floor below the feet. The sprite
## draws on that floor, and it fades out between fade_start_distance and max_distance.

const SHAPE_NAME := "ShadowShapeCast"

## Radius of the cylinder that finds the floor, in px on the ground plane.
@export_range(0.5, 32.0, 0.1, "suffix:px") var cast_radius: float = 5.6:
	set(value):
		cast_radius = value
		if shape_cast and shape_cast.shape is CylinderShape3D: (shape_cast.shape as CylinderShape3D).radius = _cast_radius_blocks()
## Opacity of the shadow at or below fade_start_distance.
@export_range(0.0, 1.0, 0.05) var shadow_opacity: float = 0.6:
	set(value):
		shadow_opacity = value
		if _debug_layer: _debug_layer.queue_redraw()
## Farthest floor, in blocks below the feet. There is no shadow above a deeper drop.
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var max_distance: float = 10.0:
	set(value):
		max_distance = maxf(value, 0.1)
		if shape_cast: shape_cast.target_position = Vector3.DOWN * max_distance
## The shadow fades out from this distance to the floor, in blocks.
@export_custom(PROPERTY_HINT_NONE, "suffix:blocks") var fade_start_distance: float = 1.0
## 3D layers of the floors that take the shadow.
@export_flags_3d_physics var floor_mask: int = 1:
	set(value):
		floor_mask = value
		if shape_cast: shape_cast.collision_mask = value
## Offset of the shadow from the feet, in px.
@export var pivot_offset: Vector2 = Vector2.ZERO:
	set(value):
		pivot_offset = value
		if is_node_ready(): _update_shadow_projection()

@export_group("Debug")
## Draws the line from the feet to the shadow and the cast radius.
@export var debug_ray: bool = false:
	set(value):
		debug_ray = value
		_update_debug_overlay()
@export var debug_color: Color = Color("00ffcc"):
	set(value):
		debug_color = value
		if debug_ray and _debug_layer: _debug_layer.queue_redraw()

## The 2.5D ancestor that casts the shadow, or null. Read-only.
var parent_25d: CollisionObject25D
## The ShapeCast3D under the core of parent_25d. Read-only.
var shape_cast: ShapeCast3D
var _debug_layer: Node2D


func _ready() -> void:
	z_as_relative = false
	show_behind_parent = true
	_find_parent()
	if parent_25d and parent_25d.core: _add_shape_cast()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PARENTED or what == NOTIFICATION_UNPARENTED:
		update_configuration_warnings()


func _get_configuration_warnings() -> PackedStringArray:
	if not CollisionObject25D.find_parent_25d(self):
		return PackedStringArray(["Shadow25D must be a child node of a 2.5D body or area."])
	return PackedStringArray()


func _process(_delta: float) -> void:
	if not parent_25d:
		_find_parent()
		if not parent_25d: return
	if not parent_25d.core: return
	if not shape_cast or not is_instance_valid(shape_cast) or shape_cast.get_parent() != parent_25d.core:
		_add_shape_cast()
	if Engine.is_editor_hint() and shape_cast:
		shape_cast.force_shapecast_update()
	_update_shadow_projection()
	_update_debug_overlay()


func _find_parent() -> void:
	var found := CollisionObject25D.find_parent_25d(self)
	# A placeholder has no core in the editor (see CollisionObject25D.is_placeholder()).
	parent_25d = null if CollisionObject25D.is_placeholder(found) else found


## Uses the ShapeCast3D that is already under the core, or adds one.
func _add_shape_cast() -> void:
	if not parent_25d or not parent_25d.core: return
	var existing := parent_25d.core.get_node_or_null(SHAPE_NAME)
	if existing is ShapeCast3D:
		shape_cast = existing as ShapeCast3D
	else:
		shape_cast = ShapeCast3D.new()
		shape_cast.name = SHAPE_NAME
		var cylinder := CylinderShape3D.new()
		cylinder.radius = _cast_radius_blocks()
		cylinder.height = 0.1
		shape_cast.shape = cylinder
		parent_25d.core.add_child(shape_cast, true)
	shape_cast.target_position = Vector3.DOWN * max_distance
	shape_cast.collision_mask = floor_mask
	shape_cast.collide_with_bodies = true
	shape_cast.collide_with_areas = false
	shape_cast.exclude_parent = true
	shape_cast.max_results = 4
	shape_cast.enabled = true


func _update_shadow_projection() -> void:
	if not parent_25d or not parent_25d.core: return
	var core := parent_25d.core
	var core_y: float = core.position.y
	var floor_y: float = core_y
	var distance: float = 0.0
	var hit_floor := true
	var on_floor := core is CharacterBody3D and (core as CharacterBody3D).is_on_floor()
	if not on_floor and shape_cast and shape_cast.is_colliding():
		var best_point := Vector3(0.0, -INF, 0.0)
		for i: int in shape_cast.get_collision_count():
			var point := shape_cast.get_collision_point(i)
			if point.y > best_point.y: best_point = point
		floor_y = best_point.y
		distance = core.global_position.distance_to(best_point)
	elif not on_floor and not Engine.is_editor_hint():
		floor_y = core_y - max_distance
		distance = max_distance
		hit_floor = false

	# The position and z_index setters always call the RenderingServer, so the editor would redraw every frame.
	var new_position := Vector2(pivot_offset.x, (core_y - floor_y) * parent_25d.tile_size + pivot_offset.y)
	if not position.is_equal_approx(new_position): position = new_position
	visible = hit_floor and distance <= max_distance
	if not visible:
		modulate.a = 0.0
	elif distance <= fade_start_distance:
		modulate.a = shadow_opacity
	else:
		var t := (distance - fade_start_distance) / maxf(max_distance - fade_start_distance, 0.001)
		modulate.a = lerpf(shadow_opacity, 0.0, clampf(t, 0.0, 1.0))
	var floor_z := int(snappedf(floor_y, 0.01) + 1.0) * parent_25d.z_step
	var new_z := mini(floor_z, parent_25d.z_index - 1)
	if z_index != new_z: z_index = new_z


func _update_debug_overlay() -> void:
	if not debug_ray:
		if _debug_layer and is_instance_valid(_debug_layer): _debug_layer.queue_free()
		_debug_layer = null
		return
	if not _debug_layer or not is_instance_valid(_debug_layer):
		_debug_layer = Node2D.new()
		_debug_layer.name = "ShadowDebugOverlay"
		_debug_layer.z_index = 4096
		_debug_layer.z_as_relative = false
		_debug_layer.draw.connect(_on_debug_draw)
		add_child(_debug_layer)
	_debug_layer.queue_redraw()


func _on_debug_draw() -> void:
	if not parent_25d: return
	_debug_layer.draw_line(to_local(parent_25d.global_position), Vector2.ZERO, Color(1, 0, 0.4, 0.9), 2.0)
	_debug_layer.draw_arc(Vector2.ZERO, cast_radius, 0.0, TAU, 24, Color(debug_color, 0.8), 1.5)
	_debug_layer.draw_circle(Vector2.ZERO, 3.0, debug_color)


func _cast_radius_blocks() -> float:
	var tile: float = float(parent_25d.tile_size) if parent_25d else 16.0
	return cast_radius / tile
