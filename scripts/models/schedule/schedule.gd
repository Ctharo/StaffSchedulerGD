class_name Schedule extends Resource

signal schedule_updated

@export var employees: Dictionary = {}  # key: employee_id, value: Employee
@export var shifts: Dictionary = {}  # key: shift_id, value: Shift
@export var sites: Dictionary = {}  # key: site_id, value: Site
@export var shift_requirements: Dictionary = {}  # key: requirement_id, value: ShiftRequirement
@export var shift_lines: Dictionary = {}  # key: line_id, value: ShiftLine
@export var pay_periods: Dictionary = {}  # key: period_id, value: PayPeriod
@export var shift_offers: Dictionary = {}  # key: offer_id, value: ShiftOffer
@export var configurations: Dictionary = {}  # key: config_key, value: Configuration

func add_employee(employee: Employee) -> void:
	employees[employee.id] = employee
	schedule_updated.emit()

func remove_employee(employee_id: String) -> bool:
	if employees.has(employee_id):
		employees.erase(employee_id)
		schedule_updated.emit()
		return true
	return false

func add_shift(shift: Shift) -> void:
	shifts[shift.id] = shift
	schedule_updated.emit()

func remove_shift(shift_id: String) -> bool:
	if shifts.has(shift_id):
		shifts.erase(shift_id)
		schedule_updated.emit()
		return true
	return false

func add_site(site: Site) -> void:
	sites[site.id] = site

func add_shift_requirement(requirement: ShiftRequirement) -> void:
	shift_requirements[requirement.id] = requirement

func add_shift_line(line: ShiftLine) -> void:
	shift_lines[line.id] = line

func assign_employee_to_line(line_id: String, employee_id: String) -> bool:
	if not shift_lines.has(line_id) or not employees.has(employee_id):
		return false
		
	var line = shift_lines[line_id]
	var employee = employees[employee_id]
	
	# Check if employee has correct classification
	if employee.classification != line.classification:
		return false
		
	# Check if employee can work at this site
	if not employee.can_work_at_site(line.site_id):
		return false
	
	# Assign the line to the employee
	line.assign_to_employee(employee_id)
	employee.assigned_line_id = line_id
	
	schedule_updated.emit()
	return true

func assign_shift(shift_id: String, employee_id: String, is_coverage: bool = false, reason: String = "") -> bool:
	if not shifts.has(shift_id) or not employees.has(employee_id):
		return false
		
	var shift = shifts[shift_id]
	var employee = employees[employee_id]
	
	# Check if employee has the required classification
	if employee.classification != shift.classification:
		return false
		
	# Check if employee can work at this site
	if not employee.can_work_at_site(shift.site_id):
		return false
		
	# Check if employee is available
	if not employee.is_available(shift.date, shift.start_time, shift.end_time):
		return false
		
	# Check if assignment would exceed max hours
	if would_exceed_max_hours(employee_id, shift):
		return false
	
	if is_coverage:
		shift.mark_as_coverage(reason)
	
	shift.assign_employee(employee_id)
	schedule_updated.emit()
	return true

func unassign_shift(shift_id: String) -> bool:
	if not shifts.has(shift_id):
		return false
		
	shifts[shift_id].unassign_employee()
	schedule_updated.emit()
	return true

func would_exceed_max_hours(employee_id: String, new_shift: Shift) -> bool:
	if not employees.has(employee_id):
		return true
		
	var employee = employees[employee_id]
	
	# Get week start and end dates (Sunday to Saturday)
	var week_start = TimeUtility.get_week_start_date(new_shift.date)
	var week_end = TimeUtility.add_days_to_date(week_start, 6)
	
	# Get all shifts for this employee in the current week
	var employee_shifts = get_employee_shifts(employee_id, week_start, week_end)
	
	# Calculate total hours
	var total_hours = 0.0
	for shift in employee_shifts:
		total_hours += shift.duration_hours
	
	# Add hours from the new shift
	total_hours += new_shift.duration_hours
	
	return total_hours > employee.max_hours_per_week

func get_employee_shifts(employee_id: String, start_date: Dictionary, end_date: Dictionary) -> Array:
	var employee_shifts = []
	
	# Get shifts directly assigned in the schedule
	for shift_id in shifts:
		var shift = shifts[shift_id]
		if shift.assigned_employee_id == employee_id and TimeUtility.is_date_in_range(shift.date, start_date, end_date):
			employee_shifts.append(shift)
	
	# Get shifts from the employee's assigned line
	var employee = employees.get(employee_id)
	if employee and not employee.assigned_line_id.is_empty() and shift_lines.has(employee.assigned_line_id):
		var line = shift_lines[employee.assigned_line_id]
		var line_shifts = line.get_shifts_for_date_range(start_date, end_date)
		
		# Add line shifts, but don't duplicate any that are already in the schedule
		# (they might have been modified)
		for line_shift in line_shifts:
			var is_duplicate = false
			for existing_shift in employee_shifts:
				if TimeUtility.same_date(existing_shift.date, line_shift.date) and \
				   existing_shift.start_time == line_shift.start_time and \
				   existing_shift.site_id == line_shift.site_id:
					is_duplicate = true
					break
			
			if not is_duplicate:
				employee_shifts.append(line_shift)
	
	return employee_shifts

func get_site_shifts(site_id: String, start_date: Dictionary, end_date: Dictionary) -> Array:
	var site_shifts = []
	
	# Get shifts directly in the schedule
	for shift_id in shifts:
		var shift = shifts[shift_id]
		if shift.site_id == site_id and TimeUtility.is_date_in_range(shift.date, start_date, end_date):
			site_shifts.append(shift)
	
	# Get shifts from all lines for this site
	for line_id in shift_lines:
		var line = shift_lines[line_id]
		if line.site_id == site_id and not line.assigned_employee_id.is_empty():
			var line_shifts = line.get_shifts_for_date_range(start_date, end_date)
			
			# Add line shifts, but don't duplicate any that are already in the schedule
			for line_shift in line_shifts:
				var is_duplicate = false
				for existing_shift in site_shifts:
					if TimeUtility.same_date(existing_shift.date, line_shift.date) and \
					   existing_shift.start_time == line_shift.start_time and \
					   existing_shift.assigned_employee_id == line_shift.assigned_employee_id:
						is_duplicate = true
						break
				
				if not is_duplicate:
					site_shifts.append(line_shift)
	
	return site_shifts

func get_shifts_by_date(date: Dictionary, site_id: String = "") -> Dictionary:
	# Returns shifts grouped by classification
	var result = {}
	
	# Get all shifts from the schedule
	for shift_id in shifts:
		var shift = shifts[shift_id]
		if TimeUtility.same_date(shift.date, date) and (site_id.is_empty() or shift.site_id == site_id):
			if not result.has(shift.classification):
				result[shift.classification] = []
			result[shift.classification].append(shift)
	
	# Get shifts from all lines
	for line_id in shift_lines:
		var line = shift_lines[line_id]
		if (site_id.is_empty() or line.site_id == site_id) and not line.assigned_employee_id.is_empty():
			var start_of_day = date.duplicate()
			var end_of_day = date.duplicate()
			var line_shifts = line.get_shifts_for_date_range(start_of_day, end_of_day)
			
			for line_shift in line_shifts:
				# Check if this shift already exists in the schedule
				var is_duplicate = false
				if result.has(line_shift.classification):
					for existing_shift in result[line_shift.classification]:
						if existing_shift.assigned_employee_id == line_shift.assigned_employee_id and \
						   existing_shift.start_time == line_shift.start_time:
							is_duplicate = true
							break
				else:
					result[line_shift.classification] = []
				
				if not is_duplicate:
					result[line_shift.classification].append(line_shift)
	
	return result

func find_available_employees(shift: Shift) -> Array:
	var available_employees = []
	for employee_id in employees:
		var employee = employees[employee_id]
		if employee.classification == shift.classification and \
		   employee.can_work_at_site(shift.site_id) and \
		   employee.is_available(shift.date, shift.start_time, shift.end_time) and \
		   not would_exceed_max_hours(employee_id, shift):
			available_employees.append(employee)
	return available_employees

func check_staffing_requirements(date: Dictionary, site_id: String) -> Dictionary:
	# Returns a dictionary showing required vs actual staffing levels
	var result = {}
	
	# Get all shift requirements for this site
	for req_id in shift_requirements:
		var req = shift_requirements[req_id]
		if req.site_id == site_id:
			var shift_name = req.shift_name
			result[shift_name] = {
				"requirements": req.requirements.duplicate(),
				"actual": {},
				"missing": {}
			}
			
			# Initialize actual counts to 0
			for classification in req.requirements:
				result[shift_name]["actual"][classification] = 0
			
			# Count actual staff scheduled for this shift
			var shift_time_range = {
				"start": req.start_time,
				"end": req.end_time
			}
			
			var date_shifts = get_shifts_by_date(date, site_id)
			for classification in date_shifts:
				if not result[shift_name]["actual"].has(classification):
					result[shift_name]["actual"][classification] = 0
				
				for shift in date_shifts[classification]:
					# Check if this shift overlaps with the requirement time range
					if TimeUtility.is_time_overlapping(shift.start_time, shift.end_time, 
													  shift_time_range.start, shift_time_range.end):
						result[shift_name]["actual"][classification] += 1
			
			# Calculate missing staff
			for classification in req.requirements:
				var required = req.requirements[classification]
				var actual = result[shift_name]["actual"].get(classification, 0)
				var missing = required - actual
				if missing > 0:
					result[shift_name]["missing"][classification] = missing
	
	return result

func create_shift_exchange(original_shift_id: String, new_employee_id: String, reason: String = "exchange") -> bool:
	if not shifts.has(original_shift_id) or not employees.has(new_employee_id):
		return false
	
	var original_shift = shifts[original_shift_id]
	var original_employee_id = original_shift.assigned_employee_id
	
	if original_employee_id.is_empty():
		return false
	
	# Create a copy of the original shift as a coverage shift
	var new_shift = original_shift.copy()
	new_shift.mark_as_coverage(reason, original_shift_id)
	
	# Try to assign the new employee
	if not assign_shift(new_shift.id, new_employee_id, true, reason):
		return false
	
	# Unassign the original employee
	original_shift.unassign_employee()
	
	# Add the new shift to the schedule
	add_shift(new_shift)
	
	return true
