extends CharacterBody3D
class_name PlayerController

enum WeaponMode { HITSCAN, PROJECTILE }

@export_group("Movement")
@export var walk_speed := 3.5
@export var sprint_speed := 6.5
@export var acceleration := 60.0
@export var deceleration := 70.0
@export var rotation_speed := 10.0
@export var jump_velocity := 5.0
@export var double_jump_velocity := 5.5
@export var spin_duration := 0.45

@export_group("Camera")
@export var mouse_sensitivity := 0.25
@export var min_pitch := -50.0
@export var max_pitch := 50.0
@export var min_zoom := 1.5
@export var max_zoom := 5.0
@export var zoom_sensitivity := 0.25
@export var aim_zoom := 1.5
@export var aim_offset_x := 0.6
@export var camera_lerp_speed := 10.0

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
@export var aim_blend_speed := 12.0

var emote_manager: EmoteManager
var last_target_rotation: float = 0.0
@export var current_blend_amount: float = 0.0
@export var current_aim_blend: float = 0.0
@export var current_air_blend: float = 0.0

@export var emote_blend_position: float = 0.0
@export var emote_layer_weight: float = 0.0

var target_zoom: float = 3.5
var fire_cooldown_timer: float = 0.0
var sprinting := false

var jump_count := 0
var is_spinning := false
var spin_time := 0.0

var jump_triggered := false
var double_jump_triggered := false

@onready var crosshair: CanvasItem = get_node_or_null("Control/Crosshair") as CanvasItem

func _ready():
	var peer_id = str(name).to_int()
	if peer_id > 0:
		set_multiplayer_authority(peer_id)
	
	if not is_multiplayer_authority():
		if camera:
			camera.current = false
		return

	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	emote_manager = EmoteManager.new(self)
	add_child(emote_manager)
	
	if visual_model:
		last_target_rotation = visual_model.rotation.y
	if spring_arm:
		target_zoom = spring_arm.spring_length
	if animation_tree:
		animation_tree.active = true

func _unhandled_input(event):
	if not is_multiplayer_authority():
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if yaw_pivot:
			yaw_pivot.rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		if pitch_pivot:
			pitch_pivot.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
			pitch_pivot.rotation.x = clamp(pitch_pivot.rotation.x, deg_to_rad(min_pitch), deg_to_rad(max_pitch))

	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			target_zoom = clamp(target_zoom - zoom_sensitivity, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			target_zoom = clamp(target_zoom + zoom_sensitivity, min_zoom, max_zoom)

	if event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED)

func _physics_process(delta):
	if not is_multiplayer_authority():
		return
	handle_gravity(delta)
	handle_cooldowns(delta)

	var aiming := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	if aiming and emote_manager and emote_manager.current_emote != "none":
		emote_manager.force_reset()

	handle_jumping()
	handle_movement(aiming, delta)
	handle_camera_and_rotation(aiming, delta)
	handle_spin_mechanic(delta)

	if crosshair:
		crosshair.visible = aiming

	move_and_slide()
	handle_animations(aiming, delta)

func _process(_delta):
	if not is_multiplayer_authority():
		if animation_tree:
			animation_tree.set("parameters/Movement/blend_position", current_blend_amount)
			animation_tree.set("parameters/AimFilter/blend_amount", current_aim_blend)
			animation_tree.set("parameters/AirBlend/blend_amount", current_air_blend)
			animation_tree.set("parameters/EmoteBlendSpace/blend_position", emote_blend_position)
			animation_tree.set("parameters/UpperBodyLayer/blend_amount", emote_layer_weight)

func handle_gravity(delta: float):
	if not is_on_floor():
		velocity.y += get_gravity().y * delta
	else:
		jump_count = 0
		if is_spinning:
			is_spinning = false

func handle_cooldowns(delta: float):
	fire_cooldown_timer = maxf(fire_cooldown_timer - delta, 0.0)

func handle_jumping():
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_velocity
			jump_count = 1
			jump_triggered = true
		elif jump_count < 2:
			velocity.y = double_jump_velocity
			jump_count = 2
			is_spinning = true
			spin_time = 0.0
			double_jump_triggered = true

func handle_movement(aiming: bool, delta: float):
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	sprinting = Input.is_action_pressed("sprint") and not aiming
	var speed := sprint_speed if sprinting else walk_speed

	var direction := Vector3.ZERO
	if yaw_pivot:
		var forward := yaw_pivot.global_transform.basis.z
		var right := yaw_pivot.global_transform.basis.x
		forward.y = 0.0
		right.y = 0.0
		direction = (right * input_dir.x + forward * input_dir.y).normalized()

	var accel := acceleration if direction != Vector3.ZERO else deceleration
	var current_horizontal_velocity := Vector3(velocity.x, 0.0, velocity.z)
	var target_horizontal_velocity := direction * speed

	current_horizontal_velocity = current_horizontal_velocity.move_toward(target_horizontal_velocity, accel * delta)
	velocity.x = current_horizontal_velocity.x
	velocity.z = current_horizontal_velocity.z

	if direction != Vector3.ZERO and not aiming and not is_spinning:
		last_target_rotation = atan2(direction.x, direction.z) + PI

func handle_camera_and_rotation(aiming: bool, delta: float):
	if aiming:
		if yaw_pivot:
			last_target_rotation = yaw_pivot.rotation.y
		if Input.is_action_pressed("shoot") and fire_cooldown_timer <= 0.0:
			fire_weapon()

	if visual_model and not is_spinning:
		visual_model.rotation.y = lerp_angle(visual_model.rotation.y, last_target_rotation, rotation_speed * delta)

	if spring_arm:
		var actual_target_zoom := aim_zoom if aiming else target_zoom
		var actual_target_offset := aim_offset_x if aiming else 0.0
		spring_arm.spring_length = lerp(spring_arm.spring_length, actual_target_zoom, camera_lerp_speed * delta)
		spring_arm.position.x = lerp(spring_arm.position.x, actual_target_offset, camera_lerp_speed * delta)

func handle_spin_mechanic(delta: float):
	if not is_spinning:
		return

	spin_time += delta
	var progress = clamp(spin_time / spin_duration, 0.0, 1.0)

	if visual_model:
		visual_model.rotation.y = last_target_rotation - (progress * TAU)

	if progress >= 1.0:
		is_spinning = false
		if visual_model:
			visual_model.rotation.y = last_target_rotation

func fire_weapon():
	if not camera or not weapon_barrel:
		return

	fire_cooldown_timer = shoot_cooldown

	var space_state := get_world_3d().direct_space_state
	var screen_center := get_viewport().get_visible_rect().size * 0.5
	var ray_origin := camera.project_ray_origin(screen_center)
	var ray_end := ray_origin + camera.project_ray_normal(screen_center) * 200.0

	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.exclude = [get_rid()]

	var result := space_state.intersect_ray(query)
	var target_3d_point := ray_end

	if not result.is_empty():
		target_3d_point = result["position"]
		if weapon_mode == WeaponMode.HITSCAN:
			var hit_object = result["collider"]
			if hit_object and hit_object.has_method("take_damage"):
				hit_object.take_damage(weapon_damage)
			spawn_impact_visual(result["position"], result["normal"])
	elif weapon_mode == WeaponMode.HITSCAN:
		pass

	if weapon_mode == WeaponMode.PROJECTILE and bullet_scene:
		var bullet_instance := bullet_scene.instantiate()
		var spawn_parent := get_tree().current_scene if get_tree().current_scene else get_tree().root
		spawn_parent.add_child(bullet_instance)

		var bullet_node := bullet_instance as Node3D
		if bullet_node:
			bullet_node.global_position = weapon_barrel.global_position
			bullet_node.look_at(target_3d_point, Vector3.UP)

func spawn_impact_visual(hit_position: Vector3, hit_normal: Vector3):
	if not blood_scene:
		return

	var blood_instance := blood_scene.instantiate()
	var spawn_parent := get_tree().current_scene if get_tree().current_scene else get_tree().root
	spawn_parent.add_child(blood_instance)

	var blood_node := blood_instance as Node3D
	if blood_node:
		blood_node.global_position = hit_position
		if hit_normal.cross(Vector3.UP).length() > 0.001:
			blood_node.look_at(hit_position + hit_normal, Vector3.UP)

func handle_animations(is_aiming: bool, delta: float):
	if not animation_tree:
		return

	var horizontal_speed := Vector3(velocity.x, 0.0, velocity.z).length()
	var target_blend := 0.0
	if horizontal_speed > 0.1:
		target_blend = 1.0 if sprinting else 0.5

	current_blend_amount = move_toward(current_blend_amount, target_blend, anim_blend_speed * delta)
	animation_tree.set("parameters/Movement/blend_position", current_blend_amount)

	var target_aim := 1.0 if is_aiming else 0.0
	current_aim_blend = move_toward(current_aim_blend, target_aim, aim_blend_speed * delta)
	animation_tree.set("parameters/AimFilter/blend_amount", current_aim_blend)

	var target_air := 0.0 if is_on_floor() else 1.0
	current_air_blend = move_toward(current_air_blend, target_air, anim_blend_speed * delta)
	animation_tree.set("parameters/AirBlend/blend_amount", current_air_blend)
