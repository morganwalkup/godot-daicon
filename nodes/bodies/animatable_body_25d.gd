@tool
@icon("res://addons/world_25d/icons/animatable_body_25d.svg")
class_name AnimatableBody25D extends StaticBody25D
## A body that code or an AnimationPlayer moves, like AnimatableBody2D. The core is an AnimatableBody3D.
## Move it with `position` (a Tween or a track) and lift it with `height`. A position write moves
## the core; with sync_to_physics, the core moves in the physics step and carries the bodies on it.
## It is never baked into the navmesh.

## Moves the core in the physics step, so the bodies on it move with it.
@export var sync_to_physics: bool = true:
	set(value):
		sync_to_physics = value
		if core: (core as AnimatableBody3D).sync_to_physics = value


func _ready() -> void:
	super._ready()
	process_physics_priority = 100


## With sync_to_physics, a write reaches the core only in the physics step, so the drawn position
## follows the core one physics frame later, as on AnimatableBody2D.
func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint() or not core:
		return
	_apply_position_write()
	update_pos()


## Always empty: a moving body is not baked.
func get_navigation_footprint() -> AABB:
	return AABB()


func _create_core() -> CollisionObject3D:
	var body := AnimatableBody3D.new()
	body.name = "AnimatableBody3D"
	body.sync_to_physics = sync_to_physics
	return body
