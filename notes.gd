@tool
extends Control
signal request_filesystem_scan

const NOTES_DIR := "res://addons/Notes/files"
const DEFAULT_NOTE_NAME := "note"
const NOTES_ORDER_PATH := "res://addons/Notes/files/.notes_order"
const SIDE_PANEL_MAX_WIDTH_RATIO := 1.0
const SIDE_PANEL_MIN_WIDTH_RATIO := 0.2
const SIDE_PANEL_WIDTH_RATIO := 0.75

@onready var text_edit: TextEdit = $"MainMargin/VBoxContainer/TextEdit"
@onready var title: Label = $"MainMargin/VBoxContainer/HBoxContainer/VBoxContainer/ProjName"
@onready var file_title = $MainMargin/VBoxContainer/HBoxContainer/VBoxContainer/Title
@onready var side_bar: Control = $"FilePanel"
@onready var side_panel_surface: Control = $"FilePanel/ColorRect"
@onready var file_list: VBoxContainer = $"FilePanel/ColorRect/VBoxContainer/FileListScroll/FileList"
@onready var new_file_name: LineEdit = $"FilePanel/ColorRect/VBoxContainer/MarginContainer2/VBoxContainer/NewFileName"
@onready var delete_current_button: Button = $"MainMargin/VBoxContainer/HBoxContainer/DeleteCurrentButton"
@onready var confirm_delete: ConfirmationDialog = $"ConfirmDelete"

var current_note_path := ""
var pending_delete_path := ""
var panel_tween: Tween

func _ready() -> void:
	ensure_notes_dir()
	if get_files_in_folder(NOTES_DIR).is_empty():
		var default_path := NOTES_DIR.path_join(DEFAULT_NOTE_NAME + ".txt")
		write_note_file(default_path, "This is your first note. Edit me!")

	refresh_file_list()
	call_deferred("_initialize_side_panel_position")

	text_edit.size_flags_vertical = SIZE_EXPAND_FILL
	text_edit.size_flags_horizontal = SIZE_EXPAND_FILL
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.text_changed.connect(save_note)
	delete_current_button.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1.0))
	delete_current_button.add_theme_color_override("font_hover_color", Color(1.0, 0.45, 0.45, 1.0))
	delete_current_button.add_theme_color_override("font_pressed_color", Color(0.75, 0.2, 0.2, 1.0))

func save_note() -> void:
	if current_note_path.is_empty():
		return

	write_note_file(current_note_path, text_edit.text)

func open_note(path: String) -> String:
	if not FileAccess.file_exists(path):
		print("Note file does not exist: %s" % path)
		return ""

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		print("Failed to open file: %s" % path)
		return ""

	var content := file.get_as_text()
	file.close()
	return content

func open_note_file(path: String) -> void:
	current_note_path = path
	text_edit.text = open_note(path)
	update_title(path)
	update_delete_button_state()

func _on_save_button_pressed() -> void:
	save_note()

func get_files_in_folder(path: String) -> Array[String]:
	var files_list: Array[String] = []
	var dir_access := DirAccess.open(path)

	if dir_access:
		dir_access.list_dir_begin()
		var file_name := dir_access.get_next()

		while file_name != "":
			if not dir_access.current_is_dir() and file_name.ends_with(".txt"):
				files_list.append(path.path_join(file_name))
			file_name = dir_access.get_next()

		dir_access.list_dir_end()
	else:
		printerr("Could not open directory: ", path)

	return get_files_in_creation_order(files_list)

func create_file(file_name: String) -> String:
	var cleaned_name := file_name.strip_edges()
	if cleaned_name.is_empty():
		return ""

	cleaned_name = cleaned_name.trim_suffix(".txt")
	cleaned_name = cleaned_name.replace("/", "_").replace("\\", "_")
	ensure_notes_dir()
	var file_path := NOTES_DIR.path_join(cleaned_name + ".txt")
	if FileAccess.file_exists(file_path):
		return file_path

	if not write_note_file(file_path, "New note file."):
		push_error("Failed to create note at path: %s" % file_path)
		return ""

	append_to_note_order(file_path)
	request_filesystem_scan.emit()
	return file_path

func refresh_file_list(selected_path := "") -> void:
	for child in file_list.get_children():
		child.queue_free()

	var files := get_files_in_folder(NOTES_DIR)

	for path in files:
		create_file_row(path)

	if files.is_empty():
		current_note_path = ""
		text_edit.text = ""
		title.text = "Notes"
		update_delete_button_state()
		return

	var note_to_open := get_welcome_note_path(files)
	if note_to_open.is_empty():
		note_to_open = files[0]
	if not selected_path.is_empty() and files.has(selected_path):
		note_to_open = selected_path

	open_note_file(note_to_open)

func write_note_file(path: String, content: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string(content)
		file.close()
		return true
	else:
		print("Failed to open file. Error code:", FileAccess.get_open_error())
		return false

func ensure_notes_dir() -> void:
	var err := DirAccess.make_dir_recursive_absolute(NOTES_DIR)
	if err != OK and err != ERR_ALREADY_EXISTS:
		push_error("Failed to ensure notes directory exists (%s), error: %d" % [NOTES_DIR, err])

func get_files_in_creation_order(files: Array[String]) -> Array[String]:
	var ordered: Array[String] = []
	var known_order := load_note_order()
	var missing: Array[String] = []

	for path in known_order:
		if files.has(path):
			ordered.append(path)

	for path in files:
		if not ordered.has(path):
			missing.append(path)

	missing.sort_custom(func(a: String, b: String) -> bool:
		return FileAccess.get_modified_time(a) < FileAccess.get_modified_time(b)
	)
	ordered.append_array(missing)

	if not arrays_equal(known_order, ordered):
		save_note_order(ordered)

	return ordered

func load_note_order() -> Array[String]:
	var order: Array[String] = []
	if not FileAccess.file_exists(NOTES_ORDER_PATH):
		return order

	var file := FileAccess.open(NOTES_ORDER_PATH, FileAccess.READ)
	if file == null:
		return order

	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if not line.is_empty() and not order.has(line):
			order.append(line)
	file.close()
	return order

func save_note_order(order: Array[String]) -> void:
	var file := FileAccess.open(NOTES_ORDER_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Failed to save note order file: %s" % NOTES_ORDER_PATH)
		return

	for path in order:
		file.store_line(path)
	file.close()

func append_to_note_order(path: String) -> void:
	var order := load_note_order()
	if not order.has(path):
		order.append(path)
		save_note_order(order)

func remove_from_note_order(path: String) -> void:
	var order := load_note_order()
	if order.has(path):
		order.erase(path)
		save_note_order(order)

func arrays_equal(a: Array[String], b: Array[String]) -> bool:
	if a.size() != b.size():
		return false
	for i in range(a.size()):
		if a[i] != b[i]:
			return false
	return true

func get_file_name(path: String) -> String:
	var folders := path.split("/")
	var name := folders[folders.size() - 1]
	return name.trim_suffix(".txt")

func get_welcome_note_path(files: Array[String]) -> String:
	for path in files:
		if path.get_file().to_lower() == "welcome.txt":
			return path
	return ""

func update_delete_button_state() -> void:
	delete_current_button.disabled = current_note_path.is_empty()

func create_file_row(path: String) -> void:
	var row := HBoxContainer.new()
	row.size_flags_horizontal = SIZE_EXPAND_FILL

	var open_button := Button.new()
	open_button.size_flags_horizontal = SIZE_EXPAND_FILL
	open_button.text = get_file_name(path)
	open_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	open_button.pressed.connect(_on_file_open_button_pressed.bind(path))

	var delete_button := Button.new()
	delete_button.custom_minimum_size = Vector2(24, 24)
	delete_button.flat = true
	#delete_button.text = "x" # TODO: Change this to an icon
	delete_button.icon = load("res://addons/Notes/icons/delete_icon.svg")
	delete_button.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3, 1.0))
	delete_button.add_theme_color_override("font_hover_color", Color(1.0, 0.45, 0.45, 1.0))
	delete_button.add_theme_color_override("font_pressed_color", Color(0.75, 0.2, 0.2, 1.0))
	delete_button.tooltip_text = "Delete %s" % get_file_name(path)
	delete_button.pressed.connect(_request_delete_file.bind(path))

	row.add_child(open_button)
	row.add_child(delete_button)
	file_list.add_child(row)

func _on_file_open_button_pressed(path: String) -> void:
	open_note_file(path)
	close_side_panel()

func _request_delete_file(path: String) -> void:
	pending_delete_path = path
	confirm_delete.dialog_text = "Delete note \"%s\"?" % get_file_name(path)
	confirm_delete.popup_centered()

func _on_delete_current_button_pressed() -> void:
	if current_note_path.is_empty():
		return
	_request_delete_file(current_note_path)

func _on_confirm_delete_confirmed() -> void:
	if pending_delete_path.is_empty():
		return

	if FileAccess.file_exists(pending_delete_path):
		var err := DirAccess.remove_absolute(pending_delete_path)
		if err != OK:
			push_error("Failed to delete %s (error %d)" % [pending_delete_path, err])
			pending_delete_path = ""
			return
		remove_from_note_order(pending_delete_path)
		request_filesystem_scan.emit()

	var deleted_path := pending_delete_path
	pending_delete_path = ""

	var files := get_files_in_folder(NOTES_DIR)
	if files.is_empty():
		current_note_path = ""
		text_edit.text = ""
		title.text = "Notes"
		update_delete_button_state()
		refresh_file_list()
		return

	var next_path := files[0]
	if deleted_path != current_note_path and files.has(current_note_path):
		next_path = current_note_path

	refresh_file_list(next_path)

func update_title(path: String) -> void:
	var project_name := str(ProjectSettings.get_setting("application/config/name", "Unnamed Project"))
	#title.text = "%s - %s" % [project_name, get_file_name(path)] # TODO: Update this, to use new set up
	title.text = project_name
	file_title.text = get_file_name(path)

func _on_open_button_pressed() -> void:
	if side_bar.visible:
		close_side_panel()
	else:
		open_side_panel()

func _on_close_button_pressed() -> void:
	close_side_panel()

func _on_create_button_pressed() -> void:
	var created_path := create_file(new_file_name.text)
	if created_path.is_empty():
		return

	new_file_name.text = ""
	refresh_file_list(created_path)
	close_side_panel()
	new_file_name.grab_focus()

func _on_new_file_name_text_submitted(_new_text: String) -> void:
	_on_create_button_pressed()

func _input(event: InputEvent) -> void:
	if not side_bar.visible:
		return

	if event.is_action_pressed("ui_cancel"):
		close_side_panel()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if not side_panel_surface.get_global_rect().has_point(mouse_event.global_position):
				close_side_panel()
				get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if side_bar == null:
			return
		_update_side_panel_layout(side_bar.visible)

func _initialize_side_panel_position() -> void:
	_update_side_panel_layout(false)
	side_bar.visible = false

func get_side_panel_width() -> float:
	var available_width := size.x
	if available_width <= 0.0:
		available_width = get_viewport_rect().size.x

	var responsive_width := available_width * SIDE_PANEL_WIDTH_RATIO
	return clampf(responsive_width, SIDE_PANEL_MIN_WIDTH_RATIO * size.x, SIDE_PANEL_MAX_WIDTH_RATIO * size.x)

func _update_side_panel_layout(is_open: bool) -> void:
	if side_bar == null:
		return
	var width := get_side_panel_width()
	if is_open:
		side_bar.offset_left = 0.0
		side_bar.offset_right = width
	else:
		side_bar.offset_left = - width
		side_bar.offset_right = 0.0

func stop_panel_tween() -> void:
	if panel_tween and panel_tween.is_running():
		panel_tween.kill()
	panel_tween = null

func open_side_panel() -> void:
	stop_panel_tween()
	side_bar.visible = true
	var width := get_side_panel_width()
	side_bar.offset_left = - width
	side_bar.offset_right = 0.0
	panel_tween = create_tween()
	panel_tween.set_trans(Tween.TRANS_CUBIC)
	panel_tween.set_ease(Tween.EASE_OUT)
	panel_tween.tween_property(side_bar, "offset_left", 0.0, 0.2)
	panel_tween.parallel().tween_property(side_bar, "offset_right", width, 0.2)
	panel_tween.finished.connect(func() -> void: panel_tween = null)

func close_side_panel() -> void:
	if not side_bar.visible:
		return
	stop_panel_tween()
	var width := get_side_panel_width()
	panel_tween = create_tween()
	panel_tween.set_trans(Tween.TRANS_CUBIC)
	panel_tween.set_ease(Tween.EASE_IN)
	panel_tween.tween_property(side_bar, "offset_left", -width, 0.18)
	panel_tween.parallel().tween_property(side_bar, "offset_right", 0.0, 0.18)
	panel_tween.finished.connect(func() -> void:
		side_bar.visible = false
		panel_tween = null
	)
