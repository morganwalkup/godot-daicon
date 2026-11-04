@tool
extends AnimatableBody25D

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# Write position (px) to move the body on the ground plane, and height (blocks) to lift it.
