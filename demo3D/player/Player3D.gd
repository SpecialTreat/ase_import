class_name Player3D
extends CharacterBody3D


const WALK_SPEED = 6.0
const ACCELERATION_SPEED = WALK_SPEED * 6.0
const JUMP_VELOCITY = 6.0
const TERMINAL_VELOCITY = -40.0 # Maximum speed at which the player can fall.


@onready var anim_tree: AseAnimationTree = $AseAnimationTree
@onready var body_sprite: Sprite3D = $Sprites/Body
@onready var camera: Camera3D = $Camera3D
@onready var jump_audio: AudioStreamPlayer = $JumpAudio

var gravity: int = ProjectSettings.get("physics/3d/default_gravity")
var _double_jump_charged: bool = false


func _physics_process(delta: float) -> void:
	# =========================================================
	# Jump
	# =========================================================
	if is_on_floor():
		_double_jump_charged = true

	if Input.is_action_just_pressed("jump"):
		if is_on_floor() or _double_jump_charged:
			_double_jump_charged = is_on_floor()
			velocity.y = JUMP_VELOCITY
			anim_tree.start(&"jump")
			jump_audio.play()

	elif Input.is_action_just_released("jump") and velocity.y > 0.0:
		# The player let go of jump early, reduce vertical momentum.
		velocity.y *= 0.6

	# =========================================================
	# Fall
	# =========================================================
	velocity.y = maxf(TERMINAL_VELOCITY, velocity.y - gravity * delta)

	# =========================================================
	# Run
	# =========================================================
	var direction: Vector2 = Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).normalized()
	velocity.x = move_toward(velocity.x, WALK_SPEED * direction.x, ACCELERATION_SPEED * delta)
	velocity.z = move_toward(velocity.z, WALK_SPEED * direction.y, ACCELERATION_SPEED * delta)
	move_and_slide()

	# =========================================================
	# Animation Conditions
	# =========================================================
	if not is_zero_approx(velocity.x):
		body_sprite.flip_h = velocity.x < 0.0

	anim_tree.set_conditions({
		&"on_floor": is_on_floor(),
		&"falling": velocity.y <= 0.0 and not is_on_floor(),
		&"running": maxf(absf(velocity.x), absf(velocity.z)) > 0.1 and is_on_floor(),
	})
