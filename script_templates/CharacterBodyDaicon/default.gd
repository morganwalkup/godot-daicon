@tool
extends CharacterBodyDaicon

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if Engine.is_editor_hint():
		return
	# velocity is in px/s on the ground plane (x = east, y = south).
	# vertical_velocity is in blocks/s (up is positive).
	move_and_slide()
