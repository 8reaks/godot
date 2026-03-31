extends Area3D

@export var speed: float = 30.0
@export var lifetime: float = 5.0

var timer: Timer
var velocity: Vector3
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

func set_direction(dir: Vector3) -> void:
	velocity = dir * speed

func _process(delta: float) -> void:
	if is_falling:
		velocity.y -= fall_gravity * delta
	
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
		var normal = result.normal
		velocity = velocity.bounce(normal) * randf_range(0.15, 0.35)
	else:
		position += motion

func _on_body_entered(body: Node) -> void:
	if not has_collided:
		has_collided = true
		is_falling = true
		velocity *= randf_range(0.15, 0.35)
