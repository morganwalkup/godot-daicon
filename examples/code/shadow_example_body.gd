@tool
extends CharacterBodyDaicon
## A body for the shadow example. The arrow keys move it on the ground plane; ui_accept jumps.

const SPEED: float = 80.0 # px/s on the ground plane
const ACCELERATION: float = 320.0 # px/s²
const JUMP_VELOCITY: float = 5.0 # blocks/s


func _init() -> void:
	use_gravity = true
	gravity_3d = 10.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = velocity.move_toward(input.normalized() * SPEED, ACCELERATION * delta)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		jump(JUMP_VELOCITY)
	move_and_slide()
