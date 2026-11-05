extends Node

func _ready() -> void:
	print("In Main")
	printerr("In printerr")
	push_warning("In Warning Main")
	push_error("In Error Main")
	_change_scene.call_deferred()
	
func _change_scene() -> void:
	if OS.has_feature("dedicated_server") or "--server" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file("res://server/ServerMain.tscn")
	else:
		get_tree().change_scene_to_file("res://client/scenes/UserAuth.tscn")
