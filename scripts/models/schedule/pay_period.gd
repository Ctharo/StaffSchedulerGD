class_name PayPeriod extends Resource

@export var id: String
@export var start_date: Dictionary
@export var end_date: Dictionary
@export var status: String = "open"  # open, closed, paid
@export var pay_date: Dictionary

func _init(p_id: String = "", p_start_date: Dictionary = {}, p_end_date: Dictionary = {}) -> void:
	id = p_id if p_id else str(randi())
	start_date = p_start_date
	end_date = p_end_date

func is_date_in_period(date: Dictionary) -> bool:
	return TimeUtility.is_date_in_range(date, start_date, end_date)

func calculate_hours_for_employee(schedule: Schedule, employee_id: String) -> Dictionary:
	var result = {
		"regular_hours": 0.0,
		"overtime_hours": 0.0,
		"total_hours": 0.0,
		"shifts": [],
		"days_worked": {}  # To track consecutive days
	}
	
	if not schedule.employees.has(employee_id):
		return result
	
	# Get all shifts for this employee in the pay period
	var shifts = []
	for shift_id in schedule.shifts:
		var shift = schedule.shifts[shift_id]
		if shift.assigned_employee_id == employee_id and is_date_in_period(shift.date):
			shifts.append(shift)
			
			# Track days worked for consecutive days calculation
			var date_key = "%04d-%02d-%02d" % [shift.date.year, shift.date.month, shift.date.day]
			result.days_worked[date_key] = true
			
			# Sum up hours
			var hours = shift.duration_hours
			if shift.is_overtime:
				result.overtime_hours += hours
			else:
				result.regular_hours += hours
			
			result.total_hours += hours
			result.shifts.append(shift)
	
	return result
