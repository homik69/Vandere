extends Node
class_name EmoteManager

@export var expression_blend_speed := 10.0

var player: PlayerController
var current_emote := "none"

var target_layer_weight := 0.0
var current_layer_weight := 0.0

var is_switching := false
var next_blend_value := 0.0

var emote_registry := {
	"none": 0.0,
	"blush": 1.0,
	"wave": 2.0,
	"jaja": 3.0,
	"murzyd": 4.0
}

func _init(player_ref: PlayerController):
	player = player_ref

func _unhandled_input(event):
	if not player or not player.is_multiplayer_authority():
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if player and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			return
			
		var custom_keybinds = {
			KEY_1: "blush",
			KEY_2: "wave",
			KEY_3: "jaja",
			KEY_4: "murzyd"
		}
		
		if custom_keybinds.has(event.keycode):
			trigger_emote(custom_keybinds[event.keycode])

func trigger_emote(emote_name: String):
	if not player or not player.is_multiplayer_authority():
		return
	if player and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		return

	if not emote_registry.has(emote_name):
		return
		
	var requested_value = emote_registry[emote_name]
	
	if emote_name == "none" or current_emote == emote_name:
		current_emote = "none"
		target_layer_weight = 0.0
		is_switching = false
		return
		
	current_emote = emote_name
	if current_layer_weight > 0.05:
		is_switching = true
		next_blend_value = requested_value
		target_layer_weight = 0.0
	else:
		if player and player.animation_tree:
			player.emote_blend_position = requested_value
			player.animation_tree.set("parameters/EmoteBlendSpace/blend_position", requested_value)
		target_layer_weight = 1.0
		is_switching = false

func select_from_radial_menu(emote_name: String):
	trigger_emote(emote_name)

func _physics_process(delta: float):
	if not player or not player.is_multiplayer_authority():
		return
	if not player.animation_tree:
		return
		
	current_layer_weight = move_toward(current_layer_weight, target_layer_weight, expression_blend_speed * delta)
	player.emote_layer_weight = current_layer_weight
	player.animation_tree.set("parameters/UpperBodyLayer/blend_amount", current_layer_weight)
	
	if is_switching:
		if current_layer_weight <= 0.01:
			if player and player.animation_tree:
				player.emote_blend_position = next_blend_value
				player.animation_tree.set("parameters/EmoteBlendSpace/blend_position", next_blend_value)
			is_switching = false
			
			if current_emote != "none":
				target_layer_weight = 1.0
			else:
				target_layer_weight  = 0.0

func force_reset():
	current_emote = "none"
	target_layer_weight = 0.0
	current_layer_weight = 0.0
	is_switching = false
	if player:
		player.emote_layer_weight = 0.0
		if player.animation_tree:
			player.animation_tree.set("parameters/UpperBodyLayer/blend_amount", 0.0)
