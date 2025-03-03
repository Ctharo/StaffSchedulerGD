extends VBoxContainer

signal config_saved(section_name)

var schedule_manager: ScheduleManager

# UI References
@onready var employees_list = %EmployeesList
@onready var add_employee_button = %AddEmployeeButton
@onready var remove_employee_button = %RemoveEmployeeButton
@onready var employee_details_container = %EmployeeDetailsContainer
@onready var first_name_edit = %FirstNameEdit
@onready var last_name_edit = %LastNameEdit
@onready var email_edit = %EmailEdit
@onready var phone_edit = %PhoneEdit
@onready var classification_option = %ClassificationOption
@onready var employment_status_option = %StatusOption
@onready var fte_spin = %FTESpin
@onready var max_hours_spin = %MaxHoursSpin
@onready var site_preferences = %SitePreferencesContainer
@onready var save_employee_button = %SaveButton
@onready var availability_button = %EditAvailabilityButton

# Currently selected employee
var selected_employee: Employee

func init(manager: ScheduleManager):
	schedule_manager = manager
	load_employees_list()
	setup_classification_dropdown()
	setup_site_preferences()
	
	# Connect signals
	add_employee_button.connect("pressed", _on_add_employee_button_pressed)
	remove_employee_button.connect("pressed", _on_remove_employee_button_pressed)
	save_employee_button.connect("pressed", _on_save_employee_button_pressed)
	employees_list.connect("item_selected", _on_employee_selected)
	availability_button.connect("pressed", _on_edit_availability_pressed)
	employment_status_option.connect("item_selected", _on_employment_status_changed)

func load_employees_list():
	employees_list.clear()
	
	# Add each employee to the list
	for employee_id in schedule_manager.current_schedule.employees:
		var employee = schedule_manager.current_schedule.employees[employee_id]
		employees_list.add_item(employee.get_full_name() + " (" + employee.classification + ")")
		employees_list.set_item_metadata(employees_list.get_item_count() - 1, employee.id)
	
	# Clear employee details panel
	clear_employee_details()
	
	# Disable remove button if no employees
	remove_employee_button.disabled = employees_list.get_item_count() == 0

func setup_classification_dropdown():
	classification_option.clear()
	
	# Add classifications from organization config
	for classification in schedule_manager.current_organization.classifications:
		classification_option.add_item(classification)
	
	# If no classifications defined, add defaults
	if classification_option.get_item_count() == 0:
		for classification in ["RN", "LPN", "CA"]:
			classification_option.add_item(classification)

func setup_site_preferences():
	# Clear existing checkboxes
	for child in site_preferences.get_children():
		child.queue_free()
	
	# Add a checkbox for each site
	for site_id in schedule_manager.current_schedule.sites:
		var site = schedule_manager.current_schedule.sites[site_id]
		
		var hbox = HBoxContainer.new()
		site_preferences.add_child(hbox)
		
		var checkbox = CheckBox.new()
		checkbox.text = site.name
		checkbox.name = "SiteCheck_" + site.id
		hbox.add_child(checkbox)

func clear_employee_details():
	first_name_edit.text = ""
	last_name_edit.text = ""
	email_edit.text = ""
	phone_edit.text = ""
	classification_option.select(0)
	employment_status_option.select(0)  # Assuming index 0 is full_time
	fte_spin.value = 1.0
	max_hours_spin.value = 40
	
	# Uncheck all site preferences
	for child in site_preferences.get_children():
		var checkbox = child.get_node_or_null("SiteCheck_.*")
		if checkbox:
			checkbox.button_pressed = false
	
	selected_employee = null
	save_employee_button.disabled = true

func _on_add_employee_button_pressed():
	# Create a new employee with default values
	var new_employee = Employee.new("", "New", "Employee", "")
	
	# Add to schedule
	schedule_manager.current_schedule.add_employee(new_employee)
	schedule_manager.save_schedule()
	
	# Reload employees list
	load_employees_list()
	
	# Select the new employee
	for i in range(employees_list.get_item_count()):
		if employees_list.get_item_metadata(i) == new_employee.id:
			employees_list.select(i)
			_on_employee_selected(i)
			break

func _on_remove_employee_button_pressed():
	var selected_idx = employees_list.get_selected_items()[0]
	var employee_id = employees_list.get_item_metadata(selected_idx)
	
	# Create confirmation dialog
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Are you sure you want to remove this employee? This will also remove all their shifts and assignments."
	confirm_dialog.get_ok_button().connect("pressed", _confirm_remove_employee.bind(employee_id))
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func _confirm_remove_employee(employee_id):
	# Remove employee from schedule
	schedule_manager.current_schedule.remove_employee(employee_id)
	schedule_manager.save_schedule()
	
	# Reload employees list
	load_employees_list()
	
	emit_signal("config_saved", "Employee removed")

func _on_employee_selected(idx):
	var employee_id = employees_list.get_item_metadata(idx)
	selected_employee = schedule_manager.current_schedule.employees[employee_id]
	
	# Update details panel
	first_name_edit.text = selected_employee.first_name
	last_name_edit.text = selected_employee.last_name
	email_edit.text = selected_employee.email
	phone_edit.text = selected_employee.phone
	
	# Set classification
	var class_idx = -1
	for i in range(classification_option.get_item_count()):
		if classification_option.get_item_text(i) == selected_employee.classification:
			class_idx = i
			break
	
	if class_idx >= 0:
		classification_option.select(class_idx)
	else:
		classification_option.select(0)  # Default to first option
	
	# Set employment status
	var status_idx = 0  # Default to full-time (index 0)
	for i in range(employment_status_option.get_item_count()):
		if employment_status_option.get_item_text(i).to_lower() == selected_employee.employment_status:
			status_idx = i
			break
	
	employment_status_option.select(status_idx)
	
	# Set FTE and max hours
	fte_spin.value = selected_employee.fte
	max_hours_spin.value = selected_employee.max_hours_per_week
	
	# Set site preferences
	for child in site_preferences.get_children():
		for checkbox in child.get_children():
			if checkbox is CheckBox:
				var site_id = checkbox.name.replace("SiteCheck_", "")
				checkbox.button_pressed = site_id in selected_employee.site_preferences
	
	save_employee_button.disabled = false

func _on_employment_status_changed(index):
	var status = employment_status_option.get_item_text(index).to_lower()
	
	# Update FTE and max hours based on status
	match status:
		"full_time":
			fte_spin.value = 1.0
			max_hours_spin.value = 40
		"part_time":
			fte_spin.value = 0.5
			max_hours_spin.value = 20
		"casual":
			fte_spin.value = 0.0
			max_hours_spin.value = 40
	
	# Enable/disable FTE field based on status
	fte_spin.editable = status != "casual"

func _on_save_employee_button_pressed():
	if selected_employee:
		# Update employee details
		selected_employee.first_name = first_name_edit.text
		selected_employee.last_name = last_name_edit.text
		selected_employee.email = email_edit.text
		selected_employee.phone = phone_edit.text
		selected_employee.classification = classification_option.get_item_text(classification_option.get_selected_id())
		selected_employee.employment_status = employment_status_option.get_item_text(employment_status_option.get_selected_id()).to_lower()
		selected_employee.fte = fte_spin.value
		selected_employee.max_hours_per_week = max_hours_spin.value
		
		# Update site preferences
		selected_employee.site_preferences.clear()
		for child in site_preferences.get_children():
			for checkbox in child.get_children():
				if checkbox is CheckBox and checkbox.button_pressed:
					var site_id = checkbox.name.replace("SiteCheck_", "")
					selected_employee.site_preferences.append(site_id)
		
		# Save changes
		schedule_manager.save_schedule()
		
		# Reload employees list to reflect name changes
		load_employees_list()
		
		emit_signal("config_saved", "Employee")

func _on_edit_availability_pressed():
	if selected_employee:
		# TODO: Show availability editor dialog
		# This would be a calendar-like interface to set weekly availability
		pass

func get_config_data():
	# This would export employee data for backup/import
	# Simplified version - in a real implementation, you'd want to exclude sensitive data
	var employees_data = []
	
	for employee_id in schedule_manager.current_schedule.employees:
		var employee = schedule_manager.current_schedule.employees[employee_id]
		employees_data.append({
			"first_name": employee.first_name,
			"last_name": employee.last_name,
			"email": employee.email,
			"classification": employee.classification,
			"employment_status": employee.employment_status,
			"fte": employee.fte,
			"max_hours": employee.max_hours_per_week,
			"site_preferences": employee.site_preferences
		})
	
	return employees_data

func import_config_data(_data):
	# Import employee data
	# In a real implementation, you'd want to handle duplicate detection
	pass
