@tool
extends StaticBodyDaicon

func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	# footprint_size is in px on the ground plane; wall_height and occluder_height are in blocks.
