extends Node
## Smoke-test hook (autoload). It does nothing unless the game runs with `-- --smoke-out=<png path>`.
## Then it waits `--smoke-frames=<n>` frames (default 90), saves a screenshot, and quits.

var _out_path: String = ""
var _frames_left: int = 90


func _ready() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--smoke-out="):
			_out_path = arg.trim_prefix("--smoke-out=")
		elif arg.begins_with("--smoke-frames="):
			_frames_left = arg.trim_prefix("--smoke-frames=").to_int()
	set_process(not _out_path.is_empty())


func _process(_delta: float) -> void:
	_frames_left -= 1
	if _frames_left > 0:
		return
	set_process(false)
	await RenderingServer.frame_post_draw
	var err := get_viewport().get_texture().get_image().save_png(_out_path)
	if err != OK:
		push_error("Smoke: cannot save %s: %s" % [_out_path, error_string(err)])
	get_tree().quit(0 if err == OK else 1)
