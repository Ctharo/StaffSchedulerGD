extends Window

signal assignment_completed(shift_id, employee_id)

var schedule_manager: ScheduleManager
var shift: Shift

# UI References
@onready var shift_details_label = $VBoxContainer/ShiftDetailsLabel
@onready var available_employees_list = $VBoxContainer/HSplitContainer/AvailableEmployeesPanel/EmployeesList
@onready var employee_details_container = $VBoxContainer/HSplitContainer/EmployeeDetailsPanel/VBoxContainer/DetailsContainer
@onready var name_label = $VBoxContainer/HSplitContainer/EmployeeDetailsPanel/VBoxContainer/DetailsContainer/NameLabel
@onready var classification_label = $VBoxContainer/HSplitContainer/EmployeeDetailsPanel/VBoxContainer/DetailsContainer/ClassificationLabel
@onready var status_label = $VBoxContainer/HSplitContainer/EmployeeDetailsPanel/VBoxContainer/DetailsContainer/StatusLabel
@onready var hours_label = $VBoxContainer/HSplitContainer/EmployeeDetailsPanel/VBoxContainer/DetailsContainer/HoursLabel
@onready var overtime_label = $VBoxContainer/HSplitContainer/EmployeeDetailsPanel/VBoxContainer/DetailsContainer/OvertimeLabel
@onready var conflict_label = $VBoxContainer/HSplitContainer/EmployeeDetailsPanel/VBoxContainer/DetailsContainer/ConflictLabel
@onready var notes_edit = $VBoxContainer/HSplitContainer/EmployeeDetailsPanel/VBoxContainer/DetailsContainer/NotesEdit
@onready var assign_button = $VBoxContainer/ButtonsPanel/AssignButton
@onready var cancel_button = $VBoxContainer/ButtonsPanel/CancelButton
@onready var offer_button = $VBoxContainer/ButtonsPanel/OfferButton
@onready var ot_checkbox = $VBoxContainer/ButtonsPanel/OTCheckbox
@onready var search_edit = $VBoxContainer/HSplitContainer/AvailableEmployeesPanel/VBoxContainer/FilterContainer/SearchEdit
@onready var show_all_check = $VBoxContainer/HSplitContainer/AvailableEmployeesPanel/VBoxContainer/FilterContainer/ShowAllCheck

# Currently selected employee
var selected_employee_id: String = ""
var force_overtime: bool = false

func _ready():
	connect_signals()
	
	# Reset UI state
	clear_employee_details()
	
	# Disable buttons initially
	assign_button.disabled = true
	
func connect_signals():
	search_edit.connect("text_changed", _on_search_text_changed)
	show_all_check.connect("toggled", _on_show_all_toggled)
	cancel_button.connect("pressed", _on_cancel_button_pressed)
	assign_button.connect("pressed", _on_assign_button_pressed)
	offer_button.connect("pressed", _on_offer_button_pressed)
	ot_checkbox.connect("toggled", _on_ot_checkbox_toggled)
	available_employees_list.connect("item_selected", _on_employee_selected)
	
	# Also close on window close request
	close_requested.connect(_on_cancel_button_pressed)

func initialize(p_shift: Shift):
	shift = p_shift
	
	# Update shift details
	var month_names = ["January", "February", "March", "April", "May", "June", 
					"July", "August", "September", "October", "November", "December"]
	var weekday_names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
	
	var date_str = "%s, %s %d, %d" % [
		weekday_names[shift.date.weekday],
		month_names[shift.date.month - 1],
		shift.date.day,
		shift.date.year
	]
	
	shift_details_label.text = "Assign: %s at %s\n%s from %s to %s" % [
		shift.classification,
		shift.site_id,
		date_str,
		shift.start_time,
		shift.end_time
	]
	
	# Load available employees
	load_available_employees(false)
	
	# Check if shift is already assigned
	if not shift.assigned_employee_id.is_empty():
		var employee = schedule_manager.current_schedule.employees.get(shift.assigned_employee_id)
		if employee:
			# Select the currently assigned employee
			for i in range(available_employees_list.get_item_count()):
				if available_employees_list.get_item_metadata(i) == employee.id:
					available_employees_list.select(i)
					_on_employee_selected(i)
					break
			
			# Update assign button text
			assign_button.text = "Reassign"

func load_available_employees(show_all: bool):
	available_employees_list.clear()
	
	var search_query = search_edit.text.to_lower()
	
	if show_all:
		# Show all employees with matching classification
		for employee_id in schedule_manager.current_schedule.employees:
			var employee = schedule_manager.current_schedule.employees[employee_id]
			
			# Skip if classification doesn't match
			if employee.classification != shift.classification:
				continue
				
			# Skip if search filter doesn't match
			if not search_query.is_empty() and not employee.get_full_name().to_lower().contains(search_query):
				continue
				
			# Add to list
			var item_text = employee.get_full_name()
			
			# Check availability
			var available = employee.is_available(shift.date, shift.start_time, shift.end_time)
			if not available:
				item_text += " (Unavailable)"
			
			# Check if this would be overtime
			var would_be_ot = schedule_manager.check_for_overtime(employee_id, shift)
			if would_be_ot:
				item_text += " (OT)"
			
			# Add to list
			available_employees_list.add_item(item_text)
			available_employees_list.set_item_metadata(available_employees_list.get_item_count() - 1, employee_id)
	else:
		# Only show available employees
		var available_employees = schedule_manager.current_schedule.find_available_employees(shift)
		
		for employee in available_employees:
			# Skip if search filter doesn't match
			if not search_query.is_empty() and not employee.get_full_name().to_lower().contains(search_query):
				continue
				
			var item_text = employee.get_full_name()
			
			# Check if this would be overtime
			var would_be_ot = schedule_manager.check_for_overtime(employee.id, shift)
			if would_be_ot:
				item_text += " (OT)"
			
			available_employees_list.add_item(item_text)
			available_employees_list.set_item_metadata(available_employees_list.get_item_count() - 1, employee.id)
		
		# If the list is empty, show a message
		if available_employees.is_empty():
			available_employees_list.add_item("No available employees found")
			assign_button.disabled = true

func _on_search_text_changed(_new_text):
	# Reload the employee list with the new search filter
	load_available_employees(show_all_check.button_pressed)

func _on_show_all_toggled(button_pressed):
	# Reload the employee list based on the show all toggle
	load_available_employees(button_pressed)

func _on_employee_selected(idx):
	# Get the selected employee ID
	selected_employee_id = available_employees_list.get_item_metadata(idx)
	
	# Load employee details
	if schedule_manager.current_schedule.employees.has(selected_employee_id):
		var employee = schedule_manager.current_schedule.employees[selected_employee_id]
		
		# Update UI with employee details
		name_label.text = employee.get_full_name()
		classification_label.text = "Classification: " + employee.classification
		status_label.text = "Status: " + employee.employment_status.capitalize()
		
		# Calculate hours this week
		var week_start = TimeUtility.get_week_start_date(shift.date)
		var week_end = TimeUtility.add_days_to_date(week_start, 6)
		var shifts = schedule_manager.current_schedule.get_employee_shifts(selected_employee_id, week_start, week_end)
		
		var total_hours = 0.0
		for existing_shift in shifts:
			total_hours += existing_shift.duration_hours
		
		hours_label.text = "Hours this week: %.1f/%d" % [total_hours, employee.max_hours_per_week]
		
		# Check for overtime
		var would_be_ot = schedule_manager.check_for_overtime(selected_employee_id, shift)
		overtime_label.visible = would_be_ot
		ot_checkbox.button_pressed = would_be_ot
		force_overtime = would_be_ot
		
		# Check for availability conflicts
		var is_available = employee.is_available(shift.date, shift.start_time, shift.end_time)
		conflict_label.visible = !is_available
		
		# Enable assign button
		assign_button.disabled = false
	else:
		clear_employee_details()
		assign_button.disabled = true

func clear_employee_details():
	name_label.text = ""
	classification_label.text = ""
	status_label.text = ""
	hours_label.text = ""
	overtime_label.visible = false
	conflict_label.visible = false
	notes_edit.text = ""

func _on_ot_checkbox_toggled(button_pressed):
	force_overtime = button_pressed

func _on_assign_button_pressed():
	if selected_employee_id.is_empty():
		return
	
	# Get notes text
	var notes = notes_edit.text
	
	# Assign employee to shift
	var success = schedule_manager.assign_employee_to_shift(
		shift.id, selected_employee_id, true, 
		"manual_assignment: " + notes, force_overtime)
	
	if success:
		emit_signal("assignment_completed", shift.id, selected_employee_id)
		queue_free()
	else:
		# Show error
		var dialog = AcceptDialog.new()
		dialog.dialog_text = "Failed to assign employee to shift."
		add_child(dialog)
		dialog.popup_centered()

func _on_offer_button_pressed():
	# Implement shift offering functionality
	# This would create a ShiftOffer and send to eligible employees
	
	# For now, just a placeholder
	var dialog = AcceptDialog.new()
	dialog.dialog_text = "Shift offering functionality would be implemented here."
	add_child(dialog)
	dialog.popup_centered()
	
	# Notify that we've "completed" (with empty employee_id to indicate an offering)
	emit_signal("assignment_completed", shift.id, "")
	queue_free()

func _on_cancel_button_pressed():
	queue_free()
