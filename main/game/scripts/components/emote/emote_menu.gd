extends Control
class_name RadialMenu

@export var player: PlayerController
@export var radius := 130.0

var options: Array = []
var label_nodes: Array[Label] = []
var current_selection := -1
var is_open := false
var menu_material: ShaderMaterial = null

var menu_tween: Tween
var selection_tween: Tween
var shader_tween: Tween
var current_shader_angle := 0.0

func _ready():
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	grow_horizontal = GROW_DIRECTION_BOTH
	grow_vertical = GROW_DIRECTION_BOTH
	
	if has_node("EmoteMenu"):
		menu_material = $EmoteMenu.material as ShaderMaterial
		
	_center_background_panel()

func _process(_delta):
	if not is_open:
		return
	_update_selection()

func _unhandled_input(event):
	if event.is_action_pressed("emote_menu"):
		_build_menu()
		_open()
	elif event.is_action_released("emote_menu") and is_open:
		_close()

func _center_background_panel():
	if has_node("EmoteMenu"):
		var panel = $EmoteMenu
		panel.custom_minimum_size = Vector2(350, 350)
		panel.size = Vector2(350, 350)
		panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		panel.grow_horizontal = GROW_DIRECTION_BOTH
		panel.grow_vertical = GROW_DIRECTION_BOTH
		panel.position = -panel.size / 2

func _build_menu():
	if selection_tween and selection_tween.is_valid():
		selection_tween.kill()
		
	for label in label_nodes:
		if is_instance_valid(label):
			label.queue_free()
	label_nodes.clear()
	
	if not player or not player.emote_manager:
		return
		
	options = player.emote_manager.emote_registry.keys()
	options.erase("none")
	
	var count = options.size()
	for i in range(count):
		var angle = i * (2 * PI / count) - (PI / 2)
		var label = Label.new()
		label.text = options[i].capitalize()
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		add_child(label)
		label_nodes.append(label)
		
		var text_size = label.get_theme_font("font").get_string_size(label.text, label.horizontal_alignment, -1, label.get_theme_font_size("font_size"))
		label.custom_minimum_size = text_size
		label.size = text_size
		label.pivot_offset = text_size / 2
		
		label.position = Vector2(cos(angle), sin(angle)) * radius - (text_size / 2)

func _open():
	if menu_tween and menu_tween.is_valid():
		menu_tween.kill()
		
	is_open = true
	visible = true
	_center_background_panel()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if menu_material:
		menu_material.set_shader_parameter("selection_strength", 0.0)
		
	pivot_offset = Vector2.ZERO 
	modulate.a = 0.0
	scale = Vector2(0.7, 0.7)
	
	menu_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	menu_tween.tween_property(self, "modulate:a", 1.0, 0.2)
	menu_tween.tween_property(self, "scale", Vector2.ONE, 0.2)

func _close():
	if menu_tween and menu_tween.is_valid():
		menu_tween.kill()
		
	is_open = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	menu_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	menu_tween.tween_property(self, "modulate:a", 0.0, 0.15)
	menu_tween.tween_property(self, "scale", Vector2(0.7, 0.7), 0.15)
	
	menu_tween.chain().tween_callback(func():
		visible = false
		if current_selection != -1 and current_selection < options.size():
			player.emote_manager.select_from_radial_menu(options[current_selection])
	)

func _update_selection():
	var mouse_pos = get_local_mouse_position()
	
	if mouse_pos.length() < 40.0:
		if current_selection != -1:
			current_selection = -1
			_clear_highlights()
			_animate_shader_angle(false, 0.0)
		return
	
	var angle = mouse_pos.angle() + (PI / 2)
	if angle < 0:
		angle += 2 * PI
		
	var count = options.size()
	var step = 2 * PI / count
	var new_selection = int(round(angle / step)) % count
	
	if new_selection != current_selection:
		current_selection = new_selection
		
		var target_angle = new_selection * step - (PI / 2)
		_animate_shader_angle(true, target_angle)
		
		if selection_tween and selection_tween.is_valid():
			selection_tween.kill()
			
		selection_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		
		for i in range(label_nodes.size()):
			if i == current_selection:
				selection_tween.tween_property(label_nodes[i], "modulate", Color.DARK_MAGENTA, 0.15)
				selection_tween.tween_property(label_nodes[i], "scale", Vector2(1.15, 1.15), 0.15)
			else:
				selection_tween.tween_property(label_nodes[i], "modulate", Color.WHITE, 0.15)
				selection_tween.tween_property(label_nodes[i], "scale", Vector2.ONE, 0.15)

func _animate_shader_angle(active: bool, target_angle: float):
	if not menu_material:
		return
		
	if shader_tween and shader_tween.is_valid():
		shader_tween.kill()
		
	shader_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	if active:
		var diff = target_angle - current_shader_angle
		diff = fmod(diff + PI, 2 * PI)
		if diff < 0:
			diff += 2 * PI
		diff -= PI
		target_angle = current_shader_angle + diff
		
		shader_tween.tween_property(self, "current_shader_angle", target_angle, 0.2)
		shader_tween.tween_property(menu_material, "shader_parameter/selection_strength", 1.0, 0.15)
	else:
		shader_tween.tween_property(menu_material, "shader_parameter/selection_strength", 0.0, 0.15)
		
	shader_tween.chain().tween_callback(func():
		if menu_material:
			menu_material.set_shader_parameter("float_angle", current_shader_angle)
	)

func _process_shader_tween():
	if menu_material and shader_tween && shader_tween.is_valid():
		menu_material.set_shader_parameter("float_angle", current_shader_angle)

func _notification(what):
	if what == NOTIFICATION_INTERNAL_PROCESS or what == NOTIFICATION_PROCESS:
		if is_open and menu_material:
			menu_material.set_shader_parameter("float_angle", current_shader_angle)

func _clear_highlights():
	if selection_tween and selection_tween.is_valid():
		selection_tween.kill()
		
	selection_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	for label in label_nodes:
		selection_tween.tween_property(label, "modulate", Color.WHITE, 0.15)
		selection_tween.tween_property(label, "scale", Vector2.ONE, 0.15)
