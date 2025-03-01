class_name Shift extends Resource

signal assigned_employee_changed

@export var id: String
@export var site_id: String  # "RHH" or "HH"
@export var classification: String  # "RN", "LPN", "CA"
@export var date: Dictionary  # {year, month, day}
@export var start_time: String  # Format: "HH:MM" (24-hour)
@export var end_time: String  # Format: "HH:MM" (24-hour)
@export var assigned_employee_id: String = ""
@export var notes: String = ""
@export var status: String = "open"  # open, assigned, completed, cancelled

# Shift origin tracking
@export var line_id: String = ""  # If part of a pattern/line
@export var is_pattern_shift: bool = true  # True if regular pattern, false if coverage/exchange
@export var coverage_reason: String = ""  # "sick", "vacation", "exchange", etc.
@export var replaced_shift_id: String = ""  # If this shift replaces another

# Pay information
@export var is_overtime: bool = false
@export var ot_multiplier: float = 1.5
@export var pay_category: String = "regular"  # regular, premium, on_call, etc.
@export var pay_period_id: String = ""

# Split shift information
@export var is_split_shift: bool = false
@export var parent_shift_id: String = ""  # If this is part of a split shift
@export var split_segments: Array = []  # For parent shifts that were split

# Calculated properties
var duration_hours: float:
	get:
		return TimeUtility.calculate_hours_between(start_time, end_time)

var shift_display_name: String:
	get:
		var time_range = start_time.substr(0, 5) + " - " + end_time.substr(0, 5)
		return site_id + " " + classification + " " + time_range

func _init() -> void:
	id = str(randi())

func assign_employee(employee_id: String) -> bool:
	assigned_employee_id = employee_id
	status = "assigned"
	assigned_employee_changed.emit()
	return true

func unassign_employee() -> void:
	assigned_employee_id = ""
	status = "open"
	assigned_employee_changed.emit()

func set_completed() -> void:
	status = "completed"

func mark_as_coverage(reason: String, original_shift_id: String = "") -> void:
	is_pattern_shift = false
	coverage_reason = reason
	replaced_shift_id = original_shift_id

func copy() -> Shift:
	var new_shift = Shift.new()
	new_shift.site_id = site_id
	new_shift.classification = classification
	new_shift.date = date.duplicate()
	new_shift.start_time = start_time
	new_shift.end_time = end_time
	new_shift.line_id = line_id
	new_shift.is_pattern_shift = is_pattern_shift
	return new_shift
