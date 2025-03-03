extends VBoxContainer

signal config_saved(section_name)

var schedule_manager: ScheduleManager

# UI References
@onready var patterns_list = %PatternsList
@onready var add_pattern_button = %AddPatternButton
@onready var remove_pattern_button = %RemovePatternButton
@onready var pattern_name_edit = %NameEdit
@onready var site_option = %SiteOption
@onready var classification_option = %ClassificationOption
@onready var pattern_length_spin = %LengthSpin
@onready var pattern_grid = %PatternGrid
@onready var save_pattern_button = %SaveButton

# Currently selected pattern
var selected_line: ShiftLine
var pattern_editors = []  # Array to track pattern day editors

func init(manager: ScheduleManager):
	schedule_manager = manager
	load_patterns_list()
	setup_site_dropdown()
	setup_classification_dropdown()
	
	# Connect signals
	add_pattern_button.connect("pressed", _on_add_pattern_button_pressed)
	remove_pattern_button.connect("pressed", _on_remove_pattern_button_pressed)
	save_pattern_button.connect("pressed", _on_save_pattern_button_pressed)
	patterns_list.connect("item_selected", _on_pattern_selected)
	pattern_length_spin.connect("value_changed", _on_pattern_length_changed)

func load_patterns_list():
	patterns_list.clear()
	
	# Add each pattern to the list
	for line_id in schedule_manager.current_schedule.shift_lines:
		var line = schedule_manager.current_schedule.shift_lines[line_id]
		patterns_list.add_item(line.name)
		patterns_list.set_item_metadata(patterns_list.get_item_count() - 1, line.id)
	
	# Clear pattern details panel
	clear_pattern_details()
	
	# Disable remove button if no patterns
	remove_pattern_button.disabled = patterns_list.get_item_count() == 0

func setup_site_dropdown():
	site_option.clear()
	
	# Add sites from schedule
	for site_id in schedule_manager.current_schedule.sites:
		var site = schedule_manager.current_schedule.sites[site_id]
		site_option.add_item(site.name)
		site_option.set_item_metadata(site_option.get_item_count() - 1, site.id)
	
	# Disable if no sites
	site_option.disabled = site_option.get_item_count() == 0

func setup_classification_dropdown():
	classification_option.clear()
	
	# Add classifications from organization config
	for classification in schedule_manager.current_organization.classifications:
		classification_option.add_item(classification)
	
	# If no classifications defined, add defaults
	if classification_option.get_item_count() == 0:
		for classification in ["RN", "LPN", "CA"]:
			classification_option.add_item(classification)

func clear_pattern_details():
	pattern_name_edit.text = ""
	
	if site_option.get_item_count() > 0:
		site_option.select(0)
		
	if classification_option.get_item_count() > 0:
		classification_option.select(0)
	
	pattern_length_spin.value = 7  # Default to 1 week
	_on_pattern_length_changed(7)  # Update grid
	
	selected_line = null
	save_pattern_button.disabled = true

func _on_add_pattern_button_pressed():
	# Verify we have sites and classifications
	if site_option.get_item_count() == 0:
		var dialog = AcceptDialog.new()
		dialog.dialog_text = "You need to create at least one site before creating a pattern."
		add_child(dialog)
		dialog.popup_centered()
		return
	
	if classification_option.get_item_count() == 0:
		var dialog = AcceptDialog.new()
		dialog.dialog_text = "You need to define at least one classification before creating a pattern."
		add_child(dialog)
		dialog.popup_centered()
		return
	
	# Create a new pattern with default values
	var site_id = site_option.get_item_metadata(0)
	var classification = classification_option.get_item_text(0)
	var new_line = ShiftLine.new("", "New Pattern")
	new_line.site_id = site_id
	new_line.classification = classification
	new_line.pattern_length = 7  # Default to 1 week
	new_line.start_date = Time.get_datetime_dict_from_system()
	
	# Add to schedule
	schedule_manager.current_schedule.add_shift_line(new_line)
	schedule_manager.save_schedule()
	
	# Reload patterns list
	load_patterns_list()
	
	# Select the new pattern
	for i in range(patterns_list.get_item_count()):
		if patterns_list.get_item_metadata(i) == new_line.id:
			patterns_list.select(i)
			_on_pattern_selected(i)
			break

func _on_remove_pattern_button_pressed():
	var selected_idx = patterns_list.get_selected_items()[0]
	var line_id = patterns_list.get_item_metadata(selected_idx)
	
	# Create confirmation dialog
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Are you sure you want to remove this pattern? This will also remove all associated shifts."
	confirm_dialog.get_ok_button().connect("pressed", _confirm_remove_pattern.bind(line_id))
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func _confirm_remove_pattern(line_id):
	# Remove pattern from schedule
	var lines = schedule_manager.current_schedule.shift_lines
	if lines.has(line_id):
		lines.erase(line_id)
		
		# TODO: Also remove related shifts
		
		schedule_manager.save_schedule()
		
		# Reload patterns list
		load_patterns_list()
		
		emit_signal("config_saved", "Pattern removed")

func _on_pattern_selected(idx):
	var line_id = patterns_list.get_item_metadata(idx)
	selected_line = schedule_manager.current_schedule.shift_lines[line_id]
	
	# Update details panel
	pattern_name_edit.text = selected_line.name
	
	# Set site
	var site_idx = -1
	for i in range(site_option.get_item_count()):
		if site_option.get_item_metadata(i) == selected_line.site_id:
			site_idx = i
			break
	
	if site_idx >= 0:
		site_option.select(site_idx)
	else:
		site_option.select(0)  # Default to first option
	
	# Set classification
	var class_idx = -1
	for i in range(classification_option.get_item_count()):
		if classification_option.get_item_text(i) == selected_line.classification:
			class_idx = i
			break
	
	if class_idx >= 0:
		classification_option.select(class_idx)
	else:
		classification_option.select(0)  # Default to first option
	
	# Set pattern length
	pattern_length_spin.value = selected_line.pattern_length
	_on_pattern_length_changed(selected_line.pattern_length)
	
	# Fill pattern grid with current values
	for day_offset in range(selected_line.pattern_length):
		var shift_found = false
		
		for pattern_shift in selected_line.rotation_pattern:
			if pattern_shift.day_offset == day_offset:
				# Find editor for this day
				if day_offset < pattern_editors.size():
					var editor = pattern_editors[day_offset]
					editor.set_shift_name(pattern_shift.shift_name)
					editor.set_shift_times(pattern_shift.start_time, pattern_shift.end_time)
				
				shift_found = true
				break
		
		if not shift_found and day_offset < pattern_editors.size():
			# No shift for this day, set to Off
			pattern_editors[day_offset].set_shift_name("Off")
			pattern_editors[day_offset].set_shift_times("", "")
	
	save_pattern_button.disabled = false

func _on_pattern_length_changed(value):
	# Clear existing editors
	for editor in pattern_editors:
		editor.queue_free()
	
	pattern_editors.clear()
	
	# Add day editors
	for day in range(value):
		var editor = load("res://scenes/ui/config/pattern_date_editor.tscn").instantiate()
		editor.day_number = day
		editor.day_name = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][day % 7]
		pattern_grid.add_child(editor)
		pattern_editors.append(editor)
		
		# Default to "Off"
		editor.set_shift_name("Off")
		editor.set_shift_times("", "")

func _on_save_pattern_button_pressed():
	if selected_line:
		# Update pattern details
		selected_line.name = pattern_name_edit.text
		selected_line.site_id = site_option.get_item_metadata(site_option.get_selected_id())
		selected_line.classification = classification_option.get_item_text(classification_option.get_selected_id())
		selected_line.pattern_length = pattern_length_spin.value
		
		# Clear existing pattern
		selected_line.rotation_pattern.clear()
		
		# Add updated pattern shifts
		for day in range(pattern_editors.size()):
			var editor = pattern_editors[day]
			var shift_name = editor.get_shift_name()
			
			if shift_name != "Off":
				var start_time = editor.get_start_time()
				var end_time = editor.get_end_time()
				
				selected_line.add_pattern_shift(day, shift_name, start_time, end_time)
		
		# Save changes
		schedule_manager.save_schedule()
		
		# Reload patterns list to reflect name changes
		load_patterns_list()
		
		emit_signal("config_saved", "Pattern")

func get_config_data():
	var patterns_data = []
	
	for line_id in schedule_manager.current_schedule.shift_lines:
		var line = schedule_manager.current_schedule.shift_lines[line_id]
		var pattern_data = {
			"name": line.name,
			"site_id": line.site_id,
			"classification": line.classification,
			"pattern_length": line.pattern_length,
			"rotation_pattern": []
		}
		
		for shift in line.rotation_pattern:
			pattern_data.rotation_pattern.append({
				"day_offset": shift.day_offset,
				"shift_name": shift.shift_name,
				"start_time": shift.start_time,
				"end_time": shift.end_time
			})
		
		patterns_data.append(pattern_data)
	
	return patterns_data

func import_config_data(data):
	if data is Array:
		# Clear existing patterns first
		schedule_manager.current_schedule.shift_lines.clear()
		
		# Add imported patterns
		for pattern_data in data:
			var line = ShiftLine.new(
				"", 
				pattern_data.get("name", "Imported Pattern")
			)
			
			line.site_id = pattern_data.get("site_id", "")
			line.classification = pattern_data.get("classification", "")
			line.pattern_length = pattern_data.get("pattern_length", 7)
			
			# Add rotation pattern
			var rotation_pattern = pattern_data.get("rotation_pattern", [])
			for shift in rotation_pattern:
				line.add_pattern_shift(
					shift.get("day_offset", 0),
					shift.get("shift_name", ""),
					shift.get("start_time", ""),
					shift.get("end_time", "")
				)
			
			schedule_manager.current_schedule.add_shift_line(line)
		
		# Save changes
		schedule_manager.save_schedule()
		
		# Reload patterns list
		load_patterns_list()
