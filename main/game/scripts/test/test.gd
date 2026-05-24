extends Node3D

@export var player_scene: PackedScene

func _ready():
	multiplayer.peer_disconnected.connect(remove_player)
	
	if multiplayer.is_server():
		add_player(multiplayer.get_unique_id())
	else:
		notify_server_ready.rpc_id(1)

@rpc("any_peer", "reliable")
func notify_server_ready():
	var sender_id = multiplayer.get_remote_sender_id()
	add_player(sender_id)

func add_player(id: int):
	var player = player_scene.instantiate()
	player.name = str(id)
	player.set_multiplayer_authority(id)
	add_child(player)

func remove_player(id: int):
	var player = get_node_or_null(str(id))
	if player:
		player.queue_free()
