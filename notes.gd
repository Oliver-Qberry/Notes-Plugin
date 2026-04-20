@tool
extends EditorPlugin

var dock

func _enter_tree() -> void:
	dock = preload("res://addons/Notes/notes_plugin_control.tscn").instantiate()
	if dock.has_signal("request_filesystem_scan"):
		dock.connect("request_filesystem_scan", Callable(self, "_refresh_filesystem_dock"))
	add_control_to_dock(DOCK_SLOT_LEFT_BR, dock) # TODO: add it to the right hand panel
	#dock.request_open_note.connect(_open_note_in_editor)


func _exit_tree() -> void:
	if dock:
		remove_control_from_docks(dock)
		dock.free()
		dock = null


func _open_note_in_editor(note_path: String) -> void:
	var ei := get_editor_interface()
	ei.open_scene_from_path(note_path)
	# optional: highlight in FileSystem dock
	var fsd := ei.get_file_system_dock()
	if fsd:
		fsd.navigate_to_path(note_path)

func _refresh_filesystem_dock() -> void:
	var ei := get_editor_interface()
	if ei:
		var fs := ei.get_resource_filesystem()
		if fs:
			fs.scan()
