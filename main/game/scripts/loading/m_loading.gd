extends Control

var progress := []
@export var scene_path := ""
var scene_load_status = 0

func _ready() -> void:
	ResourceLoader.load_threaded_request(scene_path)

func _process(_delta: float) -> void:
	scene_load_status = ResourceLoader.load_threaded_get_status(scene_path, progress)
	$Progress.text = str(floor(progress[0] * 100)) + "%"
	if scene_load_status == ResourceLoader.THREAD_LOAD_LOADED:
		var new_scene = ResourceLoader.load_threaded_get(scene_path)
		get_tree().change_scene_to_packed(new_scene)
