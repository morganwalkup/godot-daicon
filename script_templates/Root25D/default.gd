extends Root25D

## Toward the camera: a point at (x, y + 1, z + 1) draws at the same 2D position as (x, y, z).
const VIEW_RAY := Vector3(0, 5, 5)
const RAY_START_HEIGHT: float = 0.5

var position_array: Array[Vector2] = []


func _physics_process(_delta: float) -> void:
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
			var trigger := shader_trigger as CollisionObject25D
			if not is_instance_valid(trigger):
				continue
			if target.z_index >= trigger.z_index and _is_hidden(trigger):
				position_array.append(trigger.get_global_transform_with_canvas().origin)
		mat.set_shader_parameter("CircleCentres", position_array)
		mat.set_shader_parameter("NumCircleCentres", position_array.size())


func _is_hidden(trigger: CollisionObject25D) -> bool:
	if not trigger.core or not trigger.core.is_inside_tree():
		return false
	var from := trigger.get_ground_position_3d() + Vector3(0, RAY_START_HEIGHT, 0)
	var query := PhysicsRayQueryParameters3D.create(from, from + VIEW_RAY, 1, [trigger.get_rid_3d()])
	return not trigger.core.get_world_3d().direct_space_state.intersect_ray(query).is_empty()
