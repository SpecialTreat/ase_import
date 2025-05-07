class_name Player2D
extends CharacterBody2D


const WALK_SPEED: float = 200.0
const ACCELERATION_SPEED: float = WALK_SPEED * 6.0
const JUMP_VELOCITY: float = -400.0
const TERMINAL_VELOCITY: float = 400.0 # Maximum speed at which the player can fall.


@onready var anim_tree: AseAnimationTree = $AseAnimationTree
@onready var body_sprite: Sprite2D = $Sprites/Body
@onready var camera: Camera2D = $Camera2D
@onready var jump_audio: AudioStreamPlayer = $JumpAudio

var gravity: int = ProjectSettings.get("physics/2d/default_gravity")
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

	elif Input.is_action_just_released("jump") and velocity.y < 0.0:
		# The player let go of jump early, reduce vertical momentum.
		velocity.y *= 0.6

	# =========================================================
	# Fall
	# =========================================================
	velocity.y = minf(TERMINAL_VELOCITY, velocity.y + gravity * delta)

	# =========================================================
	# Run
	# =========================================================
	var direction: float = Input.get_axis("move_left", "move_right")
	velocity.x = move_toward(velocity.x, WALK_SPEED * direction, ACCELERATION_SPEED * delta)
	move_and_slide()

	# =========================================================
	# Animation Conditions
	# =========================================================
	if not is_zero_approx(velocity.x):
		body_sprite.flip_h = velocity.x < 0.0

	anim_tree.set_conditions({
		&"on_floor": is_on_floor(),
		&"falling": velocity.y >= 0.0 and not is_on_floor(),
		&"running": absf(velocity.x) > 0.1 and is_on_floor(),
	})
