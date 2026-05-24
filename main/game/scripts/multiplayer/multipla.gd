extends Node2D

const PORT = 7070

@onready var vbox_container = $Panel/VBoxContainer
@onready var ip_line = $Panel/VBoxContainer/IPLine
@onready var create_b = $Panel/VBoxContainer/CreateB
@onready var connect_b = $Panel/VBoxContainer/ConnectB
@onready var panel = $Panel

func _ready():
	create_b.pressed.connect(host_game)
	connect_b.pressed.connect(join_game)
	multiplayer.connected_to_server.connect(_on_connected_to_server)

func host_game():
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_server(PORT)
	if error != OK:
		return
	multiplayer.multiplayer_peer = peer
	get_tree().change_scene_to_file("res://main/game/scenes/test/test.tscn")

func join_game():
	var ip = ip_line.text
	if ip.is_empty():
		ip = "127.0.0.1"
	var peer = ENetMultiplayerPeer.new()
	var error = peer.create_client(ip, PORT)
	if error != OK:
		return
	multiplayer.multiplayer_peer = peer

func _on_connected_to_server():
	get_tree().change_scene_to_file("res://main/game/scenes/test/test.tscn")
