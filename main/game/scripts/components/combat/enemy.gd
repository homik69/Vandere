extends RigidBody3D

@export var health_component: HealthComponent

func _ready():
	if health_component and not health_component.died.is_connected(_on_health_component_died):
		health_component.died.connect(_on_health_component_died)

func take_damage(amount: int):
	if health_component:
		health_component.damage(amount)
		print(amount)

func _on_health_component_died():
	await get_tree().create_timer(0.5).timeout
	queue_free()
