extends Area3D

@export var speed: float = 30.0
@export var lifetime: float = 5.0
@export var rotation_speed: float = 10.0
@export var min_speed_threshold: float = 0.1

var timer: Timer
var velocity: Vector3
var angular_velocity: Vector3
var is_falling: bool = false
var fall_gravity: float = 9.8
var has_collided: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	timer = Timer.new()
	add_child(timer)
	timer.wait_time = lifetime
	timer.one_shot = true
	timer.timeout.connect(func():
		queue_free()
	)
	timer.start()
	# Initialize angular velocity with small random values
	angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * rotation_speed * 0.1

func set_direction(dir: Vector3) -> void:
	velocity = dir * speed
	# Set bullet rotation to face the direction of movement
	look_at(global_position + dir, Vector3.UP)

func _process(delta: float) -> void:
	# Check if velocity is below threshold
	if velocity.length() < min_speed_threshold:
		# Stop rotation and movement
		angular_velocity = Vector3.ZERO
		velocity = Vector3.ZERO
		return
	
	if is_falling:
		velocity.y -= fall_gravity * delta
	
	# Apply rotation
	rotation += angular_velocity * delta
	
	var motion = velocity * delta
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(global_position, global_position + motion)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	
	if result:
		global_position = result.position
		if not has_collided:
			has_collided = true
			is_falling = true
			velocity *= randf_range(0.15, 0.35)
			# Add random angular velocity on first collision
			angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * rotation_speed
		else:
			# Add smaller random angular velocity on subsequent collisions
			var random_rotation = Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)).normalized() * rotation_speed * 0.5
			angular_velocity += random_rotation
			angular_velocity = angular_velocity.normalized() * rotation_speed
		var normal = result.normal
		velocity = velocity.bounce(normal) * randf_range(0.15, 0.35)
	else:
		position += motion

func _on_body_entered(body: Node) -> void:
	if not has_collided:
		has_collided = true
		is_falling = true
		velocity *= randf_range(0.15, 0.35)
		# Add random angular velocity on first collision
		angular_velocity = Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized() * rotation_speed
	else:
		# Add smaller random angular velocity on subsequent collisions
		var random_rotation = Vector3(randf_range(-0.5, 0.5), randf_range(-0.5, 0.5), randf_range(-0.5, 0.5)).normalized() * rotation_speed * 0.5
		angular_velocity += random_rotation
		angular_velocity = angular_velocity.normalized() * rotation_speed
