@tool
@icon("res://addons/world_25d/icons/node_25d.svg")
class_name Root25D extends Node2D

@export var shader_trigger_nodes : Array[Node]
@export var shader_target_nodes : Array[Node]

func _ready() -> void:
	self.set_y_sort_enabled(true)
