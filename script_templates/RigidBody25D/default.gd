@tool
extends RigidBody25D

func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	# linear_velocity is in px/s on the ground plane; vertical_velocity is in blocks/s (up is positive).
	body_entered.connect(_on_body_entered)


func _on_body_entered(_body: Node) -> void:
	pass
