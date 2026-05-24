extends Node
class_name HealthComponent

signal health_changed(current_health: int, max_health: int)
signal died

@export var max_health := 100
@export var current_health := 100

func _ready():
	current_health = max_health

func damage(amount: int):
	if current_health <= 0:
		return
		
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	
	if current_health <= 0:
		died.emit()
