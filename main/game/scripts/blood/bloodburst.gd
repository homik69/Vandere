extends GPUParticles3D
# nword zamiast blood uwielbiam
func _ready():
	emitting = true
	finished.connect(queue_free)
