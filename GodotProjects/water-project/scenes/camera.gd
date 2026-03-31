extends Camera3D

@export var camera_offset: Vector3 = Vector3(0, 0, -0.5)
var player_head: Node3D

func _ready():
	var player = get_node("../ProtoController")
	if player:
		player_head = player.get_node("Head") as Node3D    #获取玩家的头部节点
	if not player_head:
		push_error("Camera: Could not find Player Head!")

func _physics_process(delta):
	if player_head:
		global_position = player_head.global_position + player_head.global_basis * camera_offset
		global_rotation = player_head.global_rotation
