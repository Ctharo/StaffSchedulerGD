# ui/schedule/shift_assignment_dialog.gd
class_name ShiftAssignmentDialog extends Window

signal assignment_completed(shift_id, employee_id)

var schedule_manager: ScheduleManager
var shift: Shift

# UI References
@onready var shift_details_label = $VBoxContainer/ShiftDetailsLabel
@onready var available_employees_list = $VBoxContainer/HSplitContainer/AvailableEmployeesPanel/EmployeesList
@onready var employee_details_container = $VBoxContainer/HSplitContainer/EmployeeDetailsPanel/VBoxContainer
@onready var assign_button = $VBoxContainer/ButtonsPanel/AssignButton
@onready var cancel_button = $VBoxContainer/ButtonsPanel/CancelButton
@onready var offer_button = $VBoxContainer/ButtonsPanel/OfferButton
@onready var ot_checkbox = $VBoxContainer/ButtonsPanel/OTCheckbox

# Currently selected employee
var selected_employee_id: String = ""

func _ready():
	connect_signals()
	
func connect_signals():
	cancel_button.connect("pressed", _on_cancel_button_pressed)
	assign_button.connect("pressed", _on_assign_button_pressed)
	offer_button.connect("pressed", _on_offer_button_pressed)
	available_employees_list.connect("item_selected", _on_employee_selected)

func initialize(p_shift: Shift):
	shift = p_shift
	
	# Update shift details
	shift_details_label.text = "Assign: %s at %s\n%s from %s to %s" % [
		shift.classification,
		shift.site_id,
		TimeUtility.format_date(shift.date),
		shift.start_time,
		shift.end_time
	]
	
	# Find available employees
	load_available_employees()
	
	# Disable assign button until an employee is selected
	assign_button.disabled = true

func load_available_employees():
	available_employees_list.clear()
	
	# Get available employees from schedule manager
	var available_employees = schedule_manager.current_schedule.find_available_employees(shift)
	
	# Add to list
	for employee in available_employees:
		var item_text = employee.get_full_name()
		
		# Check if this would be overtime
		var would_be_ot = schedule_manager.check_for_overtime(employee.id, shift)
		if would_be_ot:
			item_text += " (OT)"
		
		available_employees_list.add_item(item_text)
		available_employees_list.set_item_metadata(available_employees_list.get_item_count() - 1, employee.id)

func _on_employee_selected(idx):
	var employee_id = available_employees_list.get_item_metadata(idx)
	selected_employee_id = employee_id
	
	# Get employee details
	var employee = schedule_manager.current_schedule.employees[employee_id]
	
	# Update details display
	# ...
	
	# Check if this would be overtime
	var would_be_ot = schedule_manager.check_for_overtime(employee_id, shift)
	ot_checkbox.button_pressed = would_be_ot
	
	# Enable assign button
	assign_button.disabled = false

func _on_assign_button_pressed():
	if selected_employee_id.is_empty():
		return
	
	# Assign employee to shift
	var force_ot = ot_checkbox.button_pressed
	var success = schedule_manager.assign_employee_to_shift(
		shift.id, selected_employee_id, true, "manual_assignment", force_ot)
	
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
	# Show shift offering dialog
	var offering_dialog = load("res://scenes/components/shift_offering_dialog.tscn").instantiate()
	offering_dialog.schedule_manager = schedule_manager
	offering_dialog.shift = shift
	add_child(offering_dialog)
	offering_dialog.popup_centered()
	
	# Connect to completed signal
	offering_dialog.connect("offering_created", func():
		emit_signal("assignment_completed", shift.id, "")
		queue_free()
	)

func _on_cancel_button_pressed():
	queue_free()
