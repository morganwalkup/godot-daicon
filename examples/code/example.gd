@tool
extends Daicon
## Cuts a circle in the map layers over each trigger that stands behind a block, so the trigger
## stays visible. A trigger is hidden when a ray from it toward the camera hits a block.

## Toward the camera: a point at (x, y + 1, z + 1) draws at the same 2D position as (x, y, z).
const VIEW_RAY := Vector3(0, 5, 5)
const RAY_START_HEIGHT: float = 0.5

var position_array: Array[Vector2] = []


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	shader_target_nodes.sort_custom(func(a: Node, b: Node) -> bool: return (a as CanvasItem).z_index < (b as CanvasItem).z_index)
	shader_trigger_nodes.sort_custom(func(a: Node, b: Node) -> bool: return (a as CanvasItem).z_index < (b as CanvasItem).z_index)
	for shader_target: Node in shader_target_nodes:
		if not is_instance_valid(shader_target):
			continue
		var target := shader_target as CanvasItem
		var mat := target.material as ShaderMaterial
		if not mat:
			continue
		position_array.clear()
		for shader_trigger: Node in shader_trigger_nodes:
			var trigger := shader_trigger as CollisionObjectDaicon
			if not is_instance_valid(trigger):
				continue
			# The target is on or above the trigger's level, and a block hides the trigger.
			if target.z_index >= trigger.z_index and _is_hidden(trigger):
				# Screen position of the trigger, for FRAGCOORD in the shader.
				position_array.append(trigger.get_global_transform_with_canvas().origin)
		mat.set_shader_parameter("CircleCentres", position_array)
		mat.set_shader_parameter("NumCircleCentres", position_array.size())


func _is_hidden(trigger: CollisionObjectDaicon) -> bool:
	if not trigger.core or not trigger.core.is_inside_tree():
		return false
	var from := trigger.get_ground_position_3d() + Vector3(0, RAY_START_HEIGHT, 0)
	var query := PhysicsRayQueryParameters3D.create(from, from + VIEW_RAY, 1, [trigger.get_rid_3d()])
	return not trigger.core.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
