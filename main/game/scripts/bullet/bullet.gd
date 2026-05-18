extends Area3D

@export var speed := 40.0
@export var damage := 10
@export var lifetime := 4.0
@export var blood_scene: PackedScene

func _ready():
	get_tree().create_timer(lifetime).timeout.connect(queue_free)
	body_entered.connect(_on_body_entered)

func _physics_process(delta):
	global_transform.origin += -global_transform.basis.z * speed * delta

func _on_body_entered(body):
	if body.has_method("take_damage"):
		body.take_damage(damage)
		spawn_impact_visual(global_transform.origin, global_transform.basis.z)
	queue_free()

func spawn_impact_visual(hit_position: Vector3, hit_normal: Vector3):
	if not blood_scene:
		return
	var blood_instance = blood_scene.instantiate()
	get_tree().root.add_child(blood_instance)
	blood_instance.global_transform.origin = hit_position
	if hit_normal.cross(Vector3.UP).length() > 0.001:
		blood_instance.look_at(hit_position + hit_normal, Vector3.UP)
