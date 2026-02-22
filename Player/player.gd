extends CharacterBody3D

# Movement
const SPEED = 2.5
const SPRINT_SPEED = 5.0
const CROUCH_SPEED = 1.5
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
var is_punching := false
var is_fpp := false
var punch_toggle := false  # false = Punch_Cross, true = Punch_Jab

@export var camera : Camera3D
@onready var anim_player: AnimationPlayer = $UAL1_Standard/AnimationPlayer
@onready var model: Node3D = $UAL1_Standard
@onready var fpp_camera: Camera3D = $FPPCamera

# Camera follow
const CAMERA_OFFSET = Vector3(0.0, 2.5, 4.0)
const CAMERA_FOLLOW_SPEED = 8.0

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Detach TPP camera so it can follow smoothly
	if camera:
		camera.set_as_top_level(true)
	# FPP camera stays parented to player (moves with it automatically)
	fpp_camera.current = false
	camera.current = true

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
	
	# Sprint Logic
	var is_sprinting = Input.is_key_pressed(KEY_SHIFT) and input_dir.y < 0
	# Crouch Logic
	var is_crouching = Input.is_key_pressed(KEY_C)
	
	var current_speed = SPEED
	if is_crouching:
		current_speed = CROUCH_SPEED
	elif is_sprinting:
		current_speed = SPRINT_SPEED

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
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

	# Clear punching flag when animation finishes and reset speed
	if is_punching and not anim_player.is_playing():
		is_punching = false
		anim_player.speed_scale = 1.0

	# Animations
	if is_on_floor():
		if was_in_air:
			was_in_air = false
			is_jumping = false
			anim_player.play("Jump_Land")
		elif anim_player.current_animation == "Jump_Land" and anim_player.is_playing():
			# Allow directional input to break out of landing animation early
			if direction:
				if is_sprinting:
					anim_player.play("Sprint")
				elif is_crouching:
					anim_player.play("Crouch_Fwd")
				else:
					anim_player.play("Walk")
		elif is_punching:
			pass  # Let punch_cross finish
		else:
			# Landing animation just finished — or normal ground movement
			if direction:
				if is_crouching:
					if anim_player.current_animation != "Crouch_Fwd":
						anim_player.play("Crouch_Fwd")
				elif is_sprinting:
					if anim_player.current_animation != "Sprint":
						anim_player.play("Sprint")
				else:
					if anim_player.current_animation != "Walk":
						anim_player.play("Walk")
			else:
				if is_crouching:
					if anim_player.current_animation != "Crouch_Idle":
						anim_player.play("Crouch_Idle")
				elif anim_player.current_animation != "Idle":
					anim_player.play("Idle")
	else:
		was_in_air = true
		is_punching = false  # Cancel punch if player leaves ground
		# Wait for Jump_Start to finish before looping Jump
		if anim_player.current_animation == "Jump_Start" and anim_player.is_playing():
			pass  # Let Jump_Start play fully
		elif anim_player.current_animation != "Jump":
			anim_player.play("Jump")

func _update_camera(delta: float) -> void:
	if is_fpp:
		# FPP: rotate the camera node directly using mouse look
		fpp_camera.rotation.x = deg_to_rad(camera_rotation_x)
		# Rotate the whole player body on Y so movement matches look direction
		rotation.y = deg_to_rad(-camera_rotation_y)
		return

	if not camera:
		return

	# TPP: Calculate camera pivot rotation
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
		# Left click — punch (alternates each press)
		if event.button_index == MOUSE_BUTTON_LEFT:
			if is_on_floor():
				is_punching = true
				punch_toggle = !punch_toggle
				anim_player.speed_scale = 1.5
				anim_player.play("Punch_Jab" if punch_toggle else "Punch_Cross")

	if event is InputEventMouseMotion:
		camera_rotation_y -= event.relative.x * mouse_sensitivity
		camera_rotation_x -= event.relative.y * mouse_sensitivity
		# Tighter vertical clamp in FPP for realistic feel
		var pitch_limit = 80.0 if is_fpp else 60.0
		camera_rotation_x = clamp(camera_rotation_x, -pitch_limit, pitch_limit)

	# Toggle FPP / TPP with V key
	if event is InputEventKey and event.keycode == KEY_V and event.pressed and not event.echo:
		is_fpp = !is_fpp
		if is_fpp:
			# Switch to first-person
			camera.current = false
			fpp_camera.current = true
			model.visible = false   # Hide body — simulates looking through your own eyes
		else:
			# Switch back to third-person
			fpp_camera.current = false
			camera.current = true
			model.visible = true

	# Punch on Ctrl press OR left mouse click (alternates Punch_Cross / Punch_Jab)
	if event is InputEventKey and event.keycode == KEY_CTRL and event.pressed and not event.echo:
		if is_on_floor():
			is_punching = true
			punch_toggle = !punch_toggle
			anim_player.speed_scale = 1.5
			anim_player.play("Punch_Jab" if punch_toggle else "Punch_Cross")
