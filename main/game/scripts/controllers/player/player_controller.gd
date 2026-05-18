####################
### Jaja Control ###
###   by homik   ###
####################

extends CharacterBody3D
class_name PlayerController

enum WeaponMode { HITSCAN, PROJECTILE }

@export_group("Movement")
@export var walk_speed := 3.5
@export var sprint_speed := 6.5
@export var acceleration := 60.0
@export var deceleration := 70.0
@export var rotation_speed := 10.0

@export_group("Camera")
@export var mouse_sensitivity := 0.25
@export var min_pitch := -50.0
@export var max_pitch := 50.0
@export var min_zoom := 1.5
@export var max_zoom := 5.0
@export var zoom_sensitivity := 0.25
@export var aim_zoom := 1.5
@export var aim_offset_x := 0.6

@export_group("Combat")
@export var weapon_mode: WeaponMode = WeaponMode.HITSCAN
@export var shoot_cooldown := 0.2
@export var weapon_damage := 25
@export var bullet_scene: PackedScene
@export var blood_scene: PackedScene

@export_group("Nodes")
@export var yaw_pivot: Node3D
@export var pitch_pivot: Node3D
@export var visual_model: Node3D
@export var spring_arm: SpringArm3D
@export var camera: Camera3D
@export var weapon_barrel: Node3D
@export var animation_tree: AnimationTree

@export_group("Animations")
@export var anim_blend_speed := 8.0
@export var expression_blend_speed := 10.0
@export var aim_blend_speed := 12.0

# "input_map": "animacja" jak cos
var emote_bindings := {
	"blush": "blush"
}

var last_target_rotation: float = 0.0
var current_blend_amount: float = 0.0
var current_expression_amount: float = 0.0
var current_aim_blend: float = 0.0

var target_zoom: float = 3.5
var fire_cooldown_timer: float = 0.0
var sprinting := false
var is_emoting := false
var current_emote_name := "none"

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if visual_model:
		last_target_rotation = visual_model.rotation.y
	if spring_arm:
		target_zoom = spring_arm.spring_length
	if animation_tree:
		animation_tree.active = true

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			yaw_pivot.rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
			pitch_pivot.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
			pitch_pivot.rotation.x = clamp(pitch_pivot.rotation.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_zoom = clamp(target_zoom - zoom_sensitivity, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_zoom = clamp(target_zoom + zoom_sensitivity, min_zoom, max_zoom)

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)
		
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		for action in emote_bindings.keys():
			if typeof(action) == TYPE_STRING and event.is_action_pressed(action):
				if is_emoting and current_emote_name == emote_bindings[action]:
					stop_emote()
				else:
					play_emote(emote_bindings[action])
				break

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += get_gravity().y * delta

	if fire_cooldown_timer > 0.0:
		fire_cooldown_timer -= delta

	var aiming = Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	
	if aiming and is_emoting:
		stop_emote()

	var input_dir = Input.get_vector("move_left", "move_right", "move_forward", "move_back")

	var speed = sprint_speed if Input.is_action_pressed("sprint") and not aiming else walk_speed
	sprinting = true if Input.is_action_pressed("sprint") and not aiming else false

	var direction = Vector3.ZERO
	if yaw_pivot:
		var forward = yaw_pivot.global_transform.basis.z
		var right = yaw_pivot.global_transform.basis.x
		forward.y = 0
		right.y = 0
		forward = forward.normalized()
		right = right.normalized()
		direction = (right * input_dir.x + forward * input_dir.y).normalized()

	var accel = acceleration if direction != Vector3.ZERO else deceleration
	var current_horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	var target_horizontal_velocity = direction * speed
	
	current_horizontal_velocity = current_horizontal_velocity.move_toward(target_horizontal_velocity, accel * delta)

	velocity.x = current_horizontal_velocity.x
	velocity.z = current_horizontal_velocity.z
	
	$Control/Crosshair.visible = aiming
	
	if aiming:
		last_target_rotation = yaw_pivot.rotation.y
		if Input.is_action_pressed("shoot") and fire_cooldown_timer <= 0.0:
			fire_weapon()
	elif direction != Vector3.ZERO:
		last_target_rotation = atan2(direction.x, direction.z) + PI

	if visual_model:
		visual_model.rotation.y = lerp_angle(visual_model.rotation.y, last_target_rotation, rotation_speed * delta)

	if spring_arm:
		var actual_target_zoom = aim_zoom if aiming else target_zoom
		var actual_target_offset = aim_offset_x if aiming else 0.0
		
		spring_arm.spring_length = lerp(spring_arm.spring_length, actual_target_zoom, 10.0 * delta)
		spring_arm.position.x = lerp(spring_arm.position.x, actual_target_offset, 10.0 * delta)

	move_and_slide()
	handle_animations(aiming, delta)

func fire_weapon():
	if not camera or not weapon_barrel:
		return

	fire_cooldown_timer = shoot_cooldown
	
	var space_state = get_world_3d().direct_space_state
	var screen_center = get_viewport().get_visible_rect().size / 2
	
	var ray_origin = camera.project_ray_origin(screen_center)
	var ray_end = ray_origin + camera.project_ray_normal(screen_center) * 200.0
	
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [get_rid()]
	
	var result = space_state.intersect_ray(query)
	var target_3d_point: Vector3 = ray_end
	
	if result:
		target_3d_point = result.position

	if weapon_mode == WeaponMode.HITSCAN:
		if result:
			var hit_object = result.collider
			if hit_object.has_method("take_damage"):
				hit_object.take_damage(weapon_damage)
				spawn_impact_visual(result.position, result.normal)
	
	elif weapon_mode == WeaponMode.PROJECTILE and bullet_scene:
		var bullet_instance = bullet_scene.instantiate()
		get_tree().root.add_child(bullet_instance)
		bullet_instance.global_transform.origin = weapon_barrel.global_transform.origin
		bullet_instance.look_at(target_3d_point, Vector3.UP)

func spawn_impact_visual(hit_position: Vector3, hit_normal: Vector3):
	if not blood_scene:
		return
	var blood_instance = blood_scene.instantiate()
	get_tree().root.add_child(blood_instance)
	blood_instance.global_transform.origin = hit_position
	if hit_normal.cross(Vector3.UP).length() > 0.001:
		blood_instance.look_at(hit_position + hit_normal, Vector3.UP)

func play_emote(emote_id: String):
	is_emoting = true
	current_emote_name = emote_id

func stop_emote():
	is_emoting = false
	current_emote_name = "none"

func handle_animations(is_aiming: bool, delta: float):
	if not animation_tree:
		return

	var horizontal_speed = Vector3(velocity.x, 0, velocity.z).length()
	var target_blend = 0.0
	if is_on_floor() and horizontal_speed > 0.1:
		target_blend = 1.0 if sprinting else 0.5

	current_blend_amount = move_toward(current_blend_amount, target_blend, anim_blend_speed * delta)
	animation_tree.set("parameters/Movement/blend_position", current_blend_amount)

	var target_aim = 1.0 if is_aiming else 0.0
	current_aim_blend = move_toward(current_aim_blend, target_aim, aim_blend_speed * delta)
	animation_tree.set("parameters/AimFilter/blend_amount", current_aim_blend)

	var target_expression = 1.0 if is_emoting and current_emote_name == "blush" else 0.0
	current_expression_amount = move_toward(current_expression_amount, target_expression, expression_blend_speed * delta)
	animation_tree.set("parameters/UpperBodyLayer/blend_amount", current_expression_amount)
