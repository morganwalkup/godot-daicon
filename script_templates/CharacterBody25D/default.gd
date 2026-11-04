@tool
extends CharacterBody25D

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	# velocity is in px/s on the ground plane (x = east, y = south).
	# vertical_velocity is in blocks/s (up is positive). With use_gravity on, move_and_slide()
	# applies gravity.
	move_and_slide()
