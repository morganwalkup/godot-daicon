@tool
extends KinematicDaicon

const SPEED = 5
const JUMP_VELOCITY = 5
const gravity = 10
const acceleration = 20
@onready var animation_tree : AnimationTree = $AnimationTree
@onready var animation = animation_tree.get("parameters/playback")

var movement_input := Vector2.ZERO

func _physics_process(delta: float) -> void:
	if not Engine.is_editor_hint():
		var body := core as CharacterBody3D
		movement_input = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		var direction := Vector3(movement_input.x, 0, movement_input.y).normalized()
		if direction != Vector3.ZERO:
			set_animation_direction(movement_input)
		
		var y_vel = body.velocity.y
		body.velocity = body.velocity.move_toward(direction * SPEED, acceleration * delta)
		body.velocity.y = y_vel - gravity * delta
		
		if Input.is_action_just_pressed("ui_accept") and body.is_on_floor():
			body.velocity.y += JUMP_VELOCITY
			
		body.move_and_slide()
		player_animation(direction, body.velocity)
		update_pos()

func player_animation(direction, velocity: Vector3):
	var body := core as CharacterBody3D
	if velocity == Vector3.ZERO:
		animation.travel("Idle")
	elif direction:
		if body.is_on_floor():
			animation.travel("Move")
		else:
			animation.travel("Jump")
	elif not body.is_on_floor():
		animation.travel("Jump Down")

func set_animation_direction(direction):
	animation_tree.set("parameters/Idle/blend_position", direction)
	animation_tree.set("parameters/Move/blend_position", direction)
	animation_tree.set("parameters/Jump/blend_position", direction)
	animation_tree.set("parameters/Jump Down/blend_position", direction)
