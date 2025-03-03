extends Control

var schedule_manager: ScheduleManager
var nav_manager: NavigationManager
var employee: Employee
var employee_id: String
var is_dirty: bool = false
var editing_cell: Control = null

# UI References
@onready var navigation_bar = $VBoxContainer/NavigationBar
@onready var info_grid = $VBoxContainer/ScrollContainer/VBoxContainer/InfoSection/InfoGrid
@onready var availability_grid = $VBoxContainer/ScrollContainer/VBoxContainer/AvailabilitySection/AvailabilityGrid
@onready var save_button = $VBoxContainer/ButtonPanel/SaveButton
@onready var cancel_button = $VBoxContainer/ButtonPanel/CancelButton

# Editable fields
var editable_fields = {}

func _ready():
	# Set up navigation bar
	navigation_bar.connect("back_pressed", _on_back_button_pressed)
	navigation_bar.connect("home_pressed", _on_home_button_pressed)
	
	# Connect buttons
	save_button.connect("pressed", _on_save_button_pressed)
	cancel_button.connect("pressed", _on_cancel_button_pressed)
	
	# Disable save/cancel buttons initially
	save_button.disabled = true
	cancel_button.disabled = true

func initialize(p_schedule_manager: ScheduleManager, p_nav_manager: NavigationManager, p_employee_id: String):
	schedule_manager = p_schedule_manager
	nav_manager = p_nav_manager
	employee_id = p_employee_id
	
	# Initialize navigation bar
	navigation_bar.initialize(nav_manager)
	
	# Load employee data
	load_employee_data()

func load_employee_data():
	if not schedule_manager.current_schedule.employees.has(employee_id):
		push_error("Employee not found: " + employee_id)
		return
	
	employee = schedule_manager.current_schedule.employees[employee_id]
	
	# Update screen title
	navigation_bar.set_screen_title("Employee: " + employee.get_full_name())
	
	# Clear any existing UI
	_clear_ui()
	
	# Set up basic info section
	_setup_info_section()
	
	# Set up availability section
	_setup_availability_section()
	
	# Reset dirty state
	is_dirty = false
	save_button.disabled = true
	cancel_button.disabled = true
	nav_manager.mark_screen_dirty("employee_detail", false)

func _clear_ui():
	# Clear info grid
	for child in info_grid.get_children():
		child.queue_free()
	
	# Clear availability grid
	for child in availability_grid.get_children():
		child.queue_free()
	
	# Clear editable fields mapping
	editable_fields.clear()

func _setup_info_section():
	# Add basic info fields
	_add_info_field("First Name", employee.first_name, "first_name")
	_add_info_field("Last Name", employee.last_name, "last_name")
	_add_info_field("Email", employee.email, "email")
	_add_info_field("Phone", employee.phone, "phone")
	
	# Add dropdown fields
	_add_dropdown_field("Classification", employee.classification, "classification", 
		schedule_manager.current_organization.classifications)
	
	var status_options = ["full_time", "part_time", "casual"]
	_add_dropdown_field("Employment Status", employee.employment_status, "employment_status", 
		status_options)
	
	# Add numeric fields
	_add_numeric_field("FTE", employee.fte, "fte", 0.0, 1.0, 0.1)
	_add_numeric_field("Max Hours/Week", employee.max_hours_per_week, "max_hours_per_week", 0, 168, 1)
	
	# Add site preferences (checkboxes)
	_add_site_preferences()

func _setup_availability_section():
	# Simple placeholder - this would be more complex in a real app
	var weekday_names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
	
	for day in range(7):
		var hbox = HBoxContainer.new()
		availability_grid.add_child(hbox)
		
		var day_label = Label.new()
		day_label.text = weekday_names[day] + ":"
		day_label.custom_minimum_size.x = 100
		hbox.add_child(day_label)
		
		# Add available checkbox
		var checkbox = CheckBox.new()
		checkbox.text = "Available"
		
		# Check if employee has any availability slots for this day
		if employee.availability.has(day) and not employee.availability[day].is_empty():
			checkbox.button_pressed = true
		
		# Connect signal
		checkbox.connect("toggled", _on_availability_toggled.bind(day))
		
		hbox.add_child(checkbox)
		
		# Placeholder for more detailed availability editor
		var edit_button = Button.new()
		edit_button.text = "Edit Hours"
		edit_button.custom_minimum_size.x = 100
		edit_button.connect("pressed", _on_edit_hours_pressed.bind(day))
		hbox.add_child(edit_button)

func _add_info_field(label_text: String, value: String, property_name: String):
	# Add label
	var label = Label.new()
	label.text = label_text + ":"
	info_grid.add_child(label)
	
	# Add value line edit
	var line_edit = LineEdit.new()
	line_edit.text = value
	line_edit.editable = false
	line_edit.custom_minimum_size.x = 200
	
	# Connect to make editable on click
	line_edit.connect("gui_input", _on_field_gui_input.bind(line_edit, property_name))
	
	info_grid.add_child(line_edit)
	
	# Store reference
	editable_fields[property_name] = line_edit

func _add_dropdown_field(label_text: String, value: String, property_name: String, options: Array):
	# Add label
	var label = Label.new()
	label.text = label_text + ":"
	info_grid.add_child(label)
	
	# Create container for dropdown and edit button
	var hbox = HBoxContainer.new()
	info_grid.add_child(hbox)
	
	# Add value label
	var value_label = Label.new()
	value_label.text = value.capitalize()
	value_label.custom_minimum_size.x = 150
	hbox.add_child(value_label)
	
	# Add edit button
	var edit_button = Button.new()
	edit_button.text = "Edit"
	edit_button.connect("pressed", _on_edit_dropdown_pressed.bind(value_label, property_name, options))
	hbox.add_child(edit_button)
	
	# Store reference
	editable_fields[property_name] = value_label

func _add_numeric_field(label_text: String, value: float, property_name: String, min_value: float, max_value: float, step: float):
	# Add label
	var label = Label.new()
	label.text = label_text + ":"
	info_grid.add_child(label)
	
	# Create container for spinbox and edit button
	var hbox = HBoxContainer.new()
	info_grid.add_child(hbox)
	
	# Add value label
	var value_label = Label.new()
	value_label.text = str(value)
	value_label.custom_minimum_size.x = 150
	hbox.add_child(value_label)
	
	# Add edit button
	var edit_button = Button.new()
	edit_button.text = "Edit"
	edit_button.connect("pressed", _on_edit_numeric_pressed.bind(
		value_label, property_name, min_value, max_value, step))
	hbox.add_child(edit_button)
	
	# Store reference
	editable_fields[property_name] = value_label

func _add_site_preferences():
	# Add label
	var label = Label.new()
	label.text = "Site Preferences:"
	info_grid.add_child(label)
	
	# Create container for site checkboxes
	var vbox = VBoxContainer.new()
	info_grid.add_child(vbox)
	
	# Add a checkbox for each site
	for site_id in schedule_manager.current_schedule.sites:
		var site = schedule_manager.current_schedule.sites[site_id]
		
		var checkbox = CheckBox.new()
		checkbox.text = site.name
		checkbox.button_pressed = site_id in employee.site_preferences
		
		# Connect toggled signal
		checkbox.connect("toggled", _on_site_preference_toggled.bind(site_id))
		
		vbox.add_child(checkbox)

# Event handlers for editable fields
func _on_field_gui_input(event: InputEvent, field: LineEdit, property_name: String):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_start_editing_field(field, property_name)

func _start_editing_field(field: LineEdit, property_name: String):
	# If already editing another field, apply that edit first
	if editing_cell != null and editing_cell != field:
		_apply_edit()
	
	# Make field editable
	field.editable = true
	field.grab_focus()
	
	# Connect to signals for handling edit completion
	if not field.is_connected("text_submitted", _on_edit_completed):
		field.connect("text_submitted", _on_edit_completed.bind(field, property_name))
	
	if not field.is_connected("focus_exited", _on_field_focus_exited):
		field.connect("focus_exited", _on_field_focus_exited.bind(field, property_name))
	
	editing_cell = field

func _on_edit_completed(_new_text: String, field: LineEdit, property_name: String):
	var new_value = field.text
	
	# Apply the edit if value changed
	if _get_employee_property(property_name) != new_value:
		_set_employee_property(property_name, new_value)
		_mark_as_dirty()
	
	# Reset field state
	field.editable = false
	editing_cell = null

func _on_field_focus_exited(field: LineEdit, property_name: String):
	_on_edit_completed("", field, property_name)

func _on_edit_dropdown_pressed(label: Label, property_name: String, options: Array):
	# Create dropdown dialog
	var dialog = ConfirmationDialog.new()
	dialog.title = "Select " + property_name.capitalize()
	
	var option_list = OptionButton.new()
	option_list.custom_minimum_size = Vector2(200, 30)
	
	# Add options
	var current_value = _get_employee_property(property_name)
	var selected_idx = 0
	
	for i in range(options.size()):
		var option = options[i]
		option_list.add_item(option.capitalize())
		
		if option == current_value:
			selected_idx = i
	
	option_list.select(selected_idx)
	
	dialog.add_child(option_list)
	
	# Connect confirm signal
	dialog.connect("confirmed", func():
		var selected_option = options[option_list.selected]
		
		# Update if value changed
		if current_value != selected_option:
			_set_employee_property(property_name, selected_option)
			label.text = selected_option.capitalize()
			_mark_as_dirty()
	)
	
	# Show dialog
	get_tree().root.add_child(dialog)
	dialog.popup_centered()

func _on_edit_numeric_pressed(label: Label, property_name: String, min_value: float, max_value: float, step: float):
	# Create spinbox dialog
	var dialog = ConfirmationDialog.new()
	dialog.title = "Edit " + property_name.capitalize()
	
	var spinbox = SpinBox.new()
	spinbox.min_value = min_value
	spinbox.max_value = max_value
	spinbox.step = step
	spinbox.value = float(_get_employee_property(property_name))
	spinbox.custom_minimum_size = Vector2(200, 30)
	
	dialog.add_child(spinbox)
	
	# Connect confirm signal
	dialog.connect("confirmed", func():
		var new_value = spinbox.value
		
		# Update if value changed
		if float(_get_employee_property(property_name)) != new_value:
			_set_employee_property(property_name, new_value)
			label.text = str(new_value)
			_mark_as_dirty()
	)
	
	# Show dialog
	get_tree().root.add_child(dialog)
	dialog.popup_centered()

func _on_site_preference_toggled(is_checked: bool, site_id: String):
	var preferences = employee.site_preferences.duplicate()
	
	if is_checked and not site_id in preferences:
		preferences.append(site_id)
		_mark_as_dirty()
	elif not is_checked and site_id in preferences:
		preferences.erase(site_id)
		_mark_as_dirty()
	
	employee.site_preferences = preferences

func _on_availability_toggled(is_checked: bool, day: int):
	if is_checked:
		# Add default availability for this day if none exists
		if not employee.availability.has(day) or employee.availability[day].is_empty():
			# Default 9-5 availability
			employee.availability[day] = [{"start": "09:00", "end": "17:00"}]
			_mark_as_dirty()
	else:
		# Remove availability for this day
		if employee.availability.has(day) and not employee.availability[day].is_empty():
			employee.availability[day] = []
			_mark_as_dirty()

func _on_edit_hours_pressed(_day: int):
	# In a real app, this would open a more detailed availability editor
	# For now, just show a simple dialog
	var dialog = AcceptDialog.new()
	dialog.title = "Availability Editor"
	dialog.dialog_text = "This would open a detailed availability editor for specific time slots."
	
	get_tree().root.add_child(dialog)
	dialog.popup_centered()

func _apply_edit():
	if editing_cell is LineEdit:
		var property_name = ""
		
		# Find property name for this field
		for prop in editable_fields:
			if editable_fields[prop] == editing_cell:
				property_name = prop
				break
		
		if not property_name.is_empty():
			_on_edit_completed("", editing_cell, property_name)

func _get_employee_property(property_name: String):
	match property_name:
		"first_name": return employee.first_name
		"last_name": return employee.last_name
		"email": return employee.email
		"phone": return employee.phone
		"classification": return employee.classification
		"employment_status": return employee.employment_status
		"fte": return employee.fte
		"max_hours_per_week": return employee.max_hours_per_week
	
	return null

func _set_employee_property(property_name: String, value):
	match property_name:
		"first_name": employee.first_name = value
		"last_name": employee.last_name = value
		"email": employee.email = value
		"phone": employee.phone = value
		"classification": employee.classification = value
		"employment_status": employee.employment_status = value
		"fte": employee.fte = value
		"max_hours_per_week": employee.max_hours_per_week = value

func _mark_as_dirty():
	if not is_dirty:
		is_dirty = true
		save_button.disabled = false
		cancel_button.disabled = false
		nav_manager.mark_screen_dirty("employee_detail", true)

func _on_save_button_pressed():
	# Make sure any in-progress edit is applied
	if editing_cell != null:
		_apply_edit()
	
	# Update navigation bar title in case name changed
	navigation_bar.set_screen_title("Employee: " + employee.get_full_name())
	
	# Save the employee
	schedule_manager.save_schedule()
	
	# Reset dirty state
	is_dirty = false
	save_button.disabled = true
	cancel_button.disabled = true
	nav_manager.mark_screen_dirty("employee_detail", false)

func _on_cancel_button_pressed():
	# Reload employee data, discarding changes
	load_employee_data()

func _on_back_button_pressed():
	# Check for unsaved changes
	if is_dirty:
		nav_manager.show_unsaved_changes_dialog(func(should_save: bool):
			if should_save:
				_on_save_button_pressed()
			nav_manager.go_back()
		)
	else:
		nav_manager.go_back()

func _on_home_button_pressed():
	# Check for unsaved changes
	if is_dirty:
		nav_manager.show_unsaved_changes_dialog(func(should_save: bool):
			if should_save:
				_on_save_button_pressed()
			nav_manager.navigate_to("landing")
		)
	else:
		nav_manager.navigate_to("landing")
