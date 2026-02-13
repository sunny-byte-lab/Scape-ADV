extends CharacterBody3D

const WALK_SPEED = 1.4
const JUMP_VELOCITY = 4.5
const MOUSE_SENSITIVITY := 0.1

# Camera behind character settings
const CAMERA_DISTANCE := 3.5
const CAMERA_HEIGHT := 2.0
const CAMERA_LOOK_HEIGHT := 1.2

# Touch input
const TOUCH_SENSITIVITY := 0.005

var rotation_x := 0.0
var rotation_y := 0.0

var touch_joystick_input: Vector2 = Vector2.ZERO
var touch_look_delta: Vector2 = Vector2.ZERO
var is_mobile: bool = false

@export var camera: Camera3D
@export var character_model: Node3D

var animation_player: AnimationPlayer
var current_anim: String = ""

# Animation name slots
var anim_idle: String = ""
var anim_walk_fwd: String = ""
var anim_walk_bwd: String = ""
var anim_strafe_left: String = ""
var anim_strafe_right: String = ""
var anim_jump_start: String = ""
var anim_jump_air: String = ""
var anim_jump_land: String = ""
var was_on_floor: bool = true

func _ready() -> void:
	is_mobile = OS.get_name() in ["Android", "iOS"]

	if not is_mobile:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		_setup_mobile_controls()

	if character_model:
		_find_animation_player(character_model)

	if animation_player:
		var anims = animation_player.get_animation_list()
		print("Available animations: ", anims)
		_discover_animations(anims)
		_play_anim(anim_idle)


# ──────────────── Animation helpers ────────────────

func _find_animation_player(node: Node) -> void:
	if node is AnimationPlayer:
		animation_player = node
		return
	for child in node.get_children():
		if animation_player:
			return
		_find_animation_player(child)

func _discover_animations(anims: PackedStringArray) -> void:
	print("=== ALL ANIMATIONS ===")
	for i in range(anims.size()):
		print("  [%d] %s" % [i, anims[i]])

	# Pass 1 — exact (case-insensitive)
	for a in anims:
		var l = a.to_lower()
		if l == "idle":          anim_idle = a
		elif l == "walk_fwd":    anim_walk_fwd = a
		elif l == "walk_bwd":    anim_walk_bwd = a
		elif l == "walk_left":   anim_strafe_left = a
		elif l == "walk_right":  anim_strafe_right = a
		elif l == "jump_start": anim_jump_start = a
		elif l == "jump":       anim_jump_air = a
		elif l == "jump_land":  anim_jump_land = a

	# Pass 2 — partial with exclusions
	if anim_idle == "":
		for a in anims:
			var l = a.to_lower()
			if l.contains("idle") and not l.contains("crouch") and not l.contains("jump") and not l.contains("crawl"):
				anim_idle = a; break

	if anim_walk_fwd == "":
		for a in anims:
			var l = a.to_lower()
			if (l.contains("walk") and l.contains("fwd")) or l.contains("walking"):
				if not l.contains("crouch"):
					anim_walk_fwd = a; break

	if anim_walk_bwd == "":
		for a in anims:
			var l = a.to_lower()
			if l.contains("walk") and (l.contains("bwd") or l.contains("back")):
				if not l.contains("crouch"):
					anim_walk_bwd = a; break

	if anim_strafe_left == "":
		for a in anims:
			var l = a.to_lower()
			if l.contains("walk") and l.contains("left") and not l.contains("crouch"):
				anim_strafe_left = a; break

	if anim_strafe_right == "":
		for a in anims:
			var l = a.to_lower()
			if l.contains("walk") and l.contains("right") and not l.contains("crouch"):
				anim_strafe_right = a; break

	if anim_jump_start == "":
		for a in anims:
			var l = a.to_lower()
			if l.contains("jump") and l.contains("start"):
				anim_jump_start = a; break

	if anim_jump_air == "":
		for a in anims:
			var l = a.to_lower()
			if l == "jump" or (l.contains("jump") and l.contains("idle")):
				anim_jump_air = a; break

	if anim_jump_land == "":
		for a in anims:
			var l = a.to_lower()
			if l.contains("jump") and l.contains("land"):
				anim_jump_land = a; break

	# Pass 3 — last resort
	if anim_idle == "":
		anim_idle = _first_match(anims, ["idle", "t-pose", "a_pose"])
	if anim_walk_fwd == "":
		anim_walk_fwd = _first_match(anims, ["walk", "jog", "run"])

	print("Mapped -> Idle:%s  Walk_F:%s  Walk_B:%s  StrafeL:%s  StrafeR:%s  JumpStart:%s  JumpAir:%s  JumpLand:%s" % [
		anim_idle, anim_walk_fwd, anim_walk_bwd, anim_strafe_left, anim_strafe_right, anim_jump_start, anim_jump_air, anim_jump_land])

func _first_match(anims: PackedStringArray, keys: Array) -> String:
	for k in keys:
		for a in anims:
			if a.to_lower().contains(k):
				return a
	return ""

func _play_anim(anim_name: String) -> void:
	if not animation_player or anim_name == "" or current_anim == anim_name:
		return
	animation_player.play(anim_name)
	current_anim = anim_name

func _pick_directional_anim(input_dir: Vector2) -> void:
	var ax = abs(input_dir.x)
	var ay = abs(input_dir.y)
	if ay >= ax:
		if input_dir.y < 0:
			_play_anim(anim_walk_fwd if anim_walk_fwd != "" else anim_idle)
		else:
			_play_anim(anim_walk_bwd if anim_walk_bwd != "" else anim_walk_fwd)
	else:
		if input_dir.x > 0:
			_play_anim(anim_strafe_right if anim_strafe_right != "" else anim_walk_fwd)
		else:
			_play_anim(anim_strafe_left if anim_strafe_left != "" else anim_walk_fwd)


# ──────────────── Mobile controls ────────────────

func _setup_mobile_controls() -> void:
	if not ResourceLoader.exists("res://UI/mobile_hud.tscn"):
		print("mobile_hud.tscn not found, skipping mobile controls")
		return
	
	var mobile_hud_scene = load("res://UI/mobile_hud.tscn")
	var mobile_hud = mobile_hud_scene.instantiate()
	add_child(mobile_hud)
	
	var joystick = mobile_hud.get_node("TouchControls/VirtualJoystick")
	if joystick:
		joystick.joystick_input.connect(_on_joystick_input)
	
	var touch_look = mobile_hud.get_node("TouchControls/TouchLook")
	if touch_look:
		touch_look.look_input.connect(_on_look_input)

func _on_joystick_input(dir: Vector2) -> void:
	touch_joystick_input = dir

func _on_look_input(delta: Vector2) -> void:
	touch_look_delta = delta


# ──────────────── Physics / movement ────────────────

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_play_anim(anim_jump_start)

	# Input
	var input_dir: Vector2
	if is_mobile:
		input_dir = touch_joystick_input
		if touch_look_delta != Vector2.ZERO:
			rotation_y -= touch_look_delta.x * TOUCH_SENSITIVITY * 50.0
			rotation_x -= touch_look_delta.y * TOUCH_SENSITIVITY * 50.0
			rotation_x = clamp(rotation_x, -40.0, 60.0)
			touch_look_delta = Vector2.ZERO
	else:
		input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")

	# Body rotation (controlled by mouse)
	rotation_degrees.y = rotation_y

	# Movement direction
	var direction := (transform.basis * Vector3(-input_dir.x, 0, -input_dir.y)).normalized()

	if direction:
		velocity.x = direction.x * WALK_SPEED
		velocity.z = direction.z * WALK_SPEED

		# Rotate character model to face movement direction
		if character_model:
			var target_angle = atan2(direction.x, direction.z) + PI
			character_model.rotation.y = lerp_angle(character_model.rotation.y, target_angle, 10.0 * delta)

		if is_on_floor():
			_pick_directional_anim(input_dir)
	else:
		velocity.x = move_toward(velocity.x, 0, WALK_SPEED)
		velocity.z = move_toward(velocity.z, 0, WALK_SPEED)
		if is_on_floor():
			_play_anim(anim_idle)

	move_and_slide()

	# --- Jump animation states (after move_and_slide so is_on_floor is updated) ---
	if not is_on_floor():
		# In the air: play Jump (air) after Jump_Start finishes
		if anim_jump_air != "":
			if current_anim == anim_jump_start and animation_player and not animation_player.is_playing():
				_play_anim(anim_jump_air)
			elif current_anim != anim_jump_start and current_anim != anim_jump_air:
				_play_anim(anim_jump_air)

	# Just landed
	if is_on_floor() and not was_on_floor:
		if anim_jump_land != "":
			_play_anim(anim_jump_land)
		else:
			_play_anim(anim_idle)

	was_on_floor = is_on_floor()

	# Camera — always behind (uses body rotation, not model rotation)
	_update_camera()


# ──────────────── Camera ────────────────

func _update_camera() -> void:
	if not camera:
		return
	var yaw_rad = deg_to_rad(rotation_y)
	var offset = Vector3(
		sin(yaw_rad) * CAMERA_DISTANCE,
		CAMERA_HEIGHT,
		cos(yaw_rad) * CAMERA_DISTANCE
	)
	camera.global_position = global_position + offset
	camera.look_at(global_position + Vector3(0, CAMERA_LOOK_HEIGHT, 0), Vector3.UP)


# ──────────────── Input ────────────────

func _unhandled_input(event: InputEvent) -> void:
	if is_mobile:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotation_y -= event.relative.x * MOUSE_SENSITIVITY
		rotation_x -= event.relative.y * MOUSE_SENSITIVITY
		rotation_x = clamp(rotation_x, -40.0, 60.0)
