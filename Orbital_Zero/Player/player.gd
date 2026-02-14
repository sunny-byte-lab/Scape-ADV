extends CharacterBody3D

# Movement
const SPEED = 2.5
const JUMP_VELOCITY = 4.5
const ROTATION_SPEED = 10.0

# Ground physics
const GRAVITY = 9.8
const GROUND_FRICTION = 15.0
const AIR_FRICTION = 2.0

# Camera
var mouse_sensitivity := 0.1
var camera_rotation_x := 0.0
var camera_rotation_y := 0.0

# State
var is_jumping := false
var was_in_air := false

@export var camera : Camera3D
@onready var anim_player: AnimationPlayer = $UAL1_Standard/AnimationPlayer
@onready var model: Node3D = $UAL1_Standard

# Camera follow
const CAMERA_OFFSET = Vector3(0.0, 2.5, 4.0)
const CAMERA_FOLLOW_SPEED = 8.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Detach camera from player so it can follow smoothly
	if camera:
		camera.set_as_top_level(true)

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		if velocity.y < 0:
			velocity.y = 0

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		is_jumping = true
		anim_player.play("Jump_Start")

	# Movement direction based on camera angle
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var cam_basis := Basis(Vector3.UP, camera_rotation_y * PI / 180.0)
	var direction := (cam_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
		var target_angle := atan2(direction.x, direction.z)
		model.rotation.y = lerp_angle(model.rotation.y, target_angle, ROTATION_SPEED * delta)
	else:
		# Friction (ground vs air)
		var friction = GROUND_FRICTION if is_on_floor() else AIR_FRICTION
		velocity.x = lerp(velocity.x, 0.0, friction * delta)
		velocity.z = lerp(velocity.z, 0.0, friction * delta)

	move_and_slide()

	# Camera follow player
	_update_camera(delta)

	# Animations
	if is_on_floor():
		if was_in_air:
			was_in_air = false
			is_jumping = false
			anim_player.play("Jump_Land")
		elif anim_player.current_animation == "Jump_Land" and anim_player.is_playing():
			pass
		else:
			if direction:
				if anim_player.current_animation != "Walk":
					anim_player.play("Walk")
			else:
				if anim_player.current_animation != "Idle":
					anim_player.play("Idle")
	else:
		was_in_air = true
		if is_jumping and not anim_player.is_playing():
			anim_player.play("Jump")
		elif not is_jumping:
			if anim_player.current_animation != "Jump":
				anim_player.play("Jump")

func _update_camera(delta: float) -> void:
	if not camera:
		return

	# Calculate camera pivot rotation
	var yaw = deg_to_rad(camera_rotation_y)
	var pitch = deg_to_rad(camera_rotation_x)

	# Camera orbits around the player position
	var pivot = global_position + Vector3(0, CAMERA_OFFSET.y, 0)
	var offset_rotated = Vector3(0, 0, CAMERA_OFFSET.z).rotated(Vector3.RIGHT, pitch).rotated(Vector3.UP, yaw)
	var target_pos = pivot + offset_rotated

	# Smooth follow
	camera.global_position = camera.global_position.lerp(target_pos, CAMERA_FOLLOW_SPEED * delta)
	camera.look_at(pivot, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	if event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	if event is InputEventMouseMotion:
		camera_rotation_y -= event.relative.x * mouse_sensitivity
		camera_rotation_x -= event.relative.y * mouse_sensitivity
		camera_rotation_x = clamp(camera_rotation_x, -40, 60)
