# ProtoController v1.0 by Brackeys
# CC0 License
# Intended for rapid prototyping of first-person games.
# Happy prototyping!

extends CharacterBody3D

## Can we move around?
@export var can_move : bool = true
## Are we affected by gravity?
@export var has_gravity : bool = true
## Can we press to jump?
@export var can_jump : bool = true
## Can we hold to run?
@export var can_sprint : bool = false
## Can we press to enter freefly mode (noclip)?
@export var can_freefly : bool = false

@export_group("Speeds")
## Look around rotation speed.
@export var look_speed : float = 0.002
## Normal speed.
@export var base_speed : float = 4.0
## Speed of jump.
@export var jump_velocity : float = 4.5
## How fast do we run?
@export var sprint_speed : float = 6.0
## How fast do we freefly?
@export var freefly_speed : float = 25.0

@export_group("Input Actions")
## Name of Input Action to move Left.
@export var input_left : String = "ui_left"
## Name of Input Action to move Right.
@export var input_right : String = "ui_right"
## Name of Input Action to move Forward.
@export var input_forward : String = "ui_up"
## Name of Input Action to move Backward.
@export var input_back : String = "ui_down"
## Name of Input Action to Jump.
@export var input_jump : String = "ui_accept"
## Name of Input Action to Sprint.
@export var input_sprint : String = "sprint"
## Name of Input Action to toggle freefly mode.
@export var input_freefly : String = "freefly"

var mouse_captured : bool = false
var look_rotation : Vector2
var move_speed : float = 0.0
var freeflying : bool = false
var fire_rate: float = 0.1
var fire_timer: float = 0.0
var pending_mouse_motion: Vector2 = Vector2.ZERO  # Accumulated mouse motion for physics frame processing

## IMPORTANT REFERENCES
@onready var head: Node3D = $Head
@onready var gun: MeshInstance3D = $Head/Gun
@onready var collider: CollisionShape3D = $Collider

func _ready() -> void:
	check_input_mappings()
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x

func _unhandled_input(event: InputEvent) -> void:
	# Mouse capturing
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		capture_mouse()
	if Input.is_key_pressed(KEY_ESCAPE):
		release_mouse()
	
	# Accumulate mouse motion for processing in _physics_process
	if mouse_captured and event is InputEventMouseMotion:
		pending_mouse_motion += event.relative
	
	# Toggle freefly mode
	if can_freefly and Input.is_action_just_pressed(input_freefly):
		if not freeflying:
			enable_freefly()
		else:
			disable_freefly()

func fire_bullet():
	var bullet_scene = load("res://addons/bullet/bullet.tscn")
	if bullet_scene:
		var bullet = bullet_scene.instantiate()
		get_tree().get_root().add_child(bullet)
		var direction = -gun.global_basis.z
		var angle_spread = deg_to_rad(2.0)
		var angle = randf_range(-angle_spread, angle_spread)
		var random_axis = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		direction = direction.rotated(random_axis, angle)
		var gun_length = 1.0
		var gun_tip_position = gun.global_position + direction * (gun_length / 2)
		bullet.global_position = gun_tip_position
		bullet.set_direction(direction)

func _physics_process(delta: float) -> void:
	# Process accumulated mouse motion in physics frame for synchronized rotation and position
	if pending_mouse_motion != Vector2.ZERO:
		rotate_look(pending_mouse_motion)
		pending_mouse_motion = Vector2.ZERO

	# Fire bullet while holding left mouse button
	if mouse_captured and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		fire_timer -= delta
		if fire_timer <= 0:
			fire_bullet()
			fire_timer = fire_rate
	
	# If freeflying, handle freefly and nothing else
	if can_freefly and freeflying:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var motion := (head.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		motion *= freefly_speed * delta
		move_and_collide(motion)
		return
	
	# Apply gravity to velocity
	if has_gravity:
		if not is_on_floor():
			# Apply stronger gravity for faster falling (reduces air time)
			velocity += get_gravity() * delta * 1.5

	# Apply jumping
	if can_jump:
		if Input.is_action_just_pressed(input_jump) and is_on_floor():
			velocity.y = jump_velocity

	# Modify speed based on sprinting
	if can_sprint and Input.is_action_pressed(input_sprint):
			move_speed = sprint_speed
	else:
		move_speed = base_speed

	# Apply desired movement to velocity
	if can_move:
		var input_dir := Input.get_vector(input_left, input_right, input_forward, input_back)
		var move_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
		
		# Calculate acceleration and deceleration rates based on whether we're on ground or in air
		var accel_rate: float
		var decel_rate: float
		
		if is_on_floor():
			# High acceleration and deceleration on ground for responsive movement
			accel_rate = move_speed * 30.0
			decel_rate = move_speed * 25.0
		else:
			# Limited air control - slower acceleration and deceleration in air
			accel_rate = move_speed * 3.0
			decel_rate = move_speed * 1.0
		
		if move_dir:
			# Gradually accelerate toward target speed
			var target_velocity_x = move_dir.x * move_speed
			var target_velocity_z = move_dir.z * move_speed
			velocity.x = move_toward(velocity.x, target_velocity_x, accel_rate * delta)
			velocity.z = move_toward(velocity.z, target_velocity_z, accel_rate * delta)
		else:
			# Gradually decelerate to zero
			velocity.x = move_toward(velocity.x, 0, decel_rate * delta)
			velocity.z = move_toward(velocity.z, 0, decel_rate * delta)
	else:
		velocity.x = 0
		velocity.y = 0
	
	# Use velocity to actually move
	move_and_slide()


## Rotate us to look around.
## Base of controller rotates around y (left/right). Head rotates around x (up/down).
## Modifies look_rotation based on rot_input, then resets basis and rotates by look_rotation.
func rotate_look(rot_input : Vector2):
	# Calculate angle offsets from mouse movement
	# Convert pixel movement to radians based on look_speed
	var pitch_angle = -rot_input.y * look_speed
	var yaw_angle = -rot_input.x * look_speed
	
	# Update rotation values
	look_rotation.x += pitch_angle
	look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
	look_rotation.y += yaw_angle
	
	# Directly apply rotations without smoothing
	# This ensures mouse movements are immediately reflected in the view
	transform.basis = Basis.from_euler(Vector3(0, look_rotation.y, 0))
	head.transform.basis = Basis.from_euler(Vector3(look_rotation.x, 0, 0))


func enable_freefly():
	collider.disabled = true
	freeflying = true
	velocity = Vector3.ZERO

func disable_freefly():
	collider.disabled = false
	freeflying = false


func capture_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true


func release_mouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	mouse_captured = false


## Checks if some Input Actions haven't been created.
## Disables functionality accordingly.
func check_input_mappings():
	if can_move and not InputMap.has_action(input_left):
		push_error("Movement disabled. No InputAction found for input_left: " + input_left)
		can_move = false
	if can_move and not InputMap.has_action(input_right):
		push_error("Movement disabled. No InputAction found for input_right: " + input_right)
		can_move = false
	if can_move and not InputMap.has_action(input_forward):
		push_error("Movement disabled. No InputAction found for input_forward: " + input_forward)
		can_move = false
	if can_move and not InputMap.has_action(input_back):
		push_error("Movement disabled. No InputAction found for input_back: " + input_back)
		can_move = false
	if can_jump and not InputMap.has_action(input_jump):
		push_error("Jumping disabled. No InputAction found for input_jump: " + input_jump)
		can_jump = false
	if can_sprint and not InputMap.has_action(input_sprint):
		push_error("Sprinting disabled. No InputAction found for input_sprint: " + input_sprint)
		can_sprint = false
	if can_freefly and not InputMap.has_action(input_freefly):
		push_error("Freefly disabled. No InputAction found for input_freefly: " + input_freefly)
		can_freefly = false
