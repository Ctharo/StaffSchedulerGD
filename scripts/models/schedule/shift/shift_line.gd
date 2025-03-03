class_name ShiftLine extends Resource

@export var id: String
@export var name: String  # "RN Day Line 1", "CA Evening Line 3", etc.
@export var site_id: String  # "RHH" or "HH"
@export var classification: String  # "RN", "LPN", "CA"
@export var assigned_employee_id: String = ""
@export var rotation_pattern: Array = []  # Array of dictionaries with shift details

# Rotation pattern format:
# [
#   {
#     "day_offset": 0,      # Day 0 of pattern
#     "shift_name": "Day",  # Name of shift
#     "start_time": "07:00",
#     "end_time": "19:00"
#   },
#   {
#     "day_offset": 1,      # Day 1 of pattern
#     "shift_name": "Day", 
#     "start_time": "07:00",
#     "end_time": "19:00"
#   },
#   {
#     "day_offset": 2,      # Day 2 of pattern
#     "shift_name": "Off",  # Off day
#     "start_time": "",
#     "end_time": ""
#   }
# ]

@export var pattern_length: int = 0  # Total days in pattern
@export var start_date: Dictionary  # When this pattern starts

func _init(p_id: String = "", p_name: String = "") -> void:
	id = p_id if p_id else str(randi())
	name = p_name

func add_pattern_shift(day_offset: int, shift_name: String, start_time: String, end_time: String) -> void:
	rotation_pattern.append({
		"day_offset": day_offset,
		"shift_name": shift_name,
		"start_time": start_time,
		"end_time": end_time
	})
	pattern_length = max(pattern_length, day_offset + 1)

func assign_to_employee(employee_id: String) -> void:
	assigned_employee_id = employee_id

func get_shifts_for_date_range(p_start_date: Dictionary, end_date: Dictionary) -> Array:
	var shifts = []
	
	if pattern_length <= 0 or assigned_employee_id.is_empty():
		return shifts
	
	var current_date = p_start_date.duplicate()
	
	while TimeUtility.compare_dates(current_date, end_date) <= 0:
		# FIXME: Are we accessing the correct start_date?
		var days_since_start = TimeUtility.days_between(self.start_date, current_date)
		var pattern_day = days_since_start % pattern_length
		
		# Find pattern for this day
		for pattern in rotation_pattern:
			if pattern.day_offset == pattern_day and pattern.shift_name != "Off":
				var shift = Shift.new()
				shift.site_id = site_id
				shift.classification = classification
				shift.date = current_date.duplicate()
				shift.start_time = pattern.start_time
				shift.end_time = pattern.end_time
				shift.assigned_employee_id = assigned_employee_id
				shift.line_id = id
				shift.is_pattern_shift = true
				shift.status = "assigned"
				shifts.append(shift)
				break
		
		current_date = TimeUtility.add_days_to_date(current_date, 1)
	
	return shifts
