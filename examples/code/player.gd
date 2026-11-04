@tool
extends CharacterBody25D
## The example player. The arrow keys move it on the ground plane; ui_accept jumps.

const SPEED: float = 80.0 # px/s on the ground plane
const ACCELERATION: float = 320.0 # px/s²
const JUMP_VELOCITY: float = 5.0 # blocks/s

@onready var animation_tree: AnimationTree = $AnimationTree
@onready var animation: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")


func _init() -> void:
	use_gravity = true
	gravity_3d = 10.0


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var input := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input != Vector2.ZERO:
		set_animation_direction(input)
	velocity = velocity.move_toward(input.normalized() * SPEED, ACCELERATION * delta)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		jump(JUMP_VELOCITY)
	move_and_slide()
	player_animation(input)


func player_animation(input: Vector2) -> void:
	if velocity == Vector2.ZERO and is_on_floor():
		animation.travel("Idle")
	elif input != Vector2.ZERO:
		animation.travel("Move" if is_on_floor() else "Jump")
	elif not is_on_floor():
		animation.travel("Jump Down")


func set_animation_direction(direction: Vector2) -> void:
	animation_tree.set("parameters/Idle/blend_position", direction)
	animation_tree.set("parameters/Move/blend_position", direction)
	animation_tree.set("parameters/Jump/blend_position", direction)
	animation_tree.set("parameters/Jump Down/blend_position", direction)
