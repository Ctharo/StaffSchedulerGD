class_name ScheduleManager extends Node

signal organization_loaded
signal schedule_loaded
signal configuration_error

var current_schedule: Schedule
var file_path: String = "user://schedule_data.tres"
var current_organization: Organization
var organization_file_path: String = "user://organization_config.tres"


func start_loading() -> void:
	load_organization()
	load_schedule()
	if current_schedule.sites.is_empty():
		initialize_basic_data()

func load_organization() -> void:
	if ResourceLoader.exists(organization_file_path):
		current_organization = ResourceLoader.load(organization_file_path)
	else:
		current_organization = Organization.new("default", "Default Organization")
		current_organization.set_industry_defaults("healthcare")
		ResourceSaver.save(current_organization, organization_file_path)
	organization_loaded.emit()

func load_schedule() -> void:
	if ResourceLoader.exists(file_path):
		current_schedule = ResourceLoader.load(file_path)
	else:
		current_schedule = Schedule.new()
		initialize_basic_data()
	schedule_loaded.emit()



func save_schedule() -> void:
	ResourceSaver.save(current_schedule, file_path)

func save_organization() -> void:
	ResourceSaver.save(current_organization, organization_file_path)

func initialize_basic_data() -> void:
	# Create sites
	var rhh: Site = Site.new("RHH", "Rotary Hospice House")
	var hh: Site = Site.new("HH", "Home Hospice")
	current_schedule.add_site(rhh)
	current_schedule.add_site(hh)
	
	# Create basic shift requirements
	create_default_shift_requirements()
	
	# Create initial pay periods
	initialize_pay_periods()
	
	save_schedule()

func create_default_shift_requirements() -> void:
	# Day shift requirements for RHH
	var day_rhh = ShiftRequirement.new("", "Day", "RHH")
	day_rhh.start_time = "07:00"
	day_rhh.end_time = "19:00"
	day_rhh.set_required_count("RN", 1)
	day_rhh.set_required_count("LPN", 0)
	day_rhh.set_required_count("CA", 2)
	current_schedule.add_shift_requirement(day_rhh)
	
	# Night shift requirements for RHH
	var night_rhh = ShiftRequirement.new("", "Night", "RHH")
	night_rhh.start_time = "19:00"
	night_rhh.end_time = "07:00"
	night_rhh.set_required_count("RN", 1)
	night_rhh.set_required_count("LPN", 0)
	night_rhh.set_required_count("CA", 1)
	current_schedule.add_shift_requirement(night_rhh)
	
	# Day shift requirements for HH
	var day_hh = ShiftRequirement.new("", "Day", "HH")
	day_hh.start_time = "07:00"
	day_hh.end_time = "19:00"
	day_hh.set_required_count("RN", 1)
	day_hh.set_required_count("LPN", 0)
	day_hh.set_required_count("CA", 1)
	current_schedule.add_shift_requirement(day_hh)
	
	# Night shift requirements for HH
	var night_hh = ShiftRequirement.new("", "Night", "HH")
	night_hh.start_time = "19:00"
	night_hh.end_time = "07:00"
	night_hh.set_required_count("RN", 1)
	night_hh.set_required_count("LPN", 0)
	night_hh.set_required_count("CA", 1)
	current_schedule.add_shift_requirement(night_hh)

func initialize_pay_periods() -> void:
	# Create initial pay periods based on organization settings
	var now = Time.get_datetime_dict_from_system()
	var current_period_start = current_organization.pay_period_start_date
	
	# If no start date defined, use current date aligned to pay period
	if current_period_start.is_empty():
		current_period_start = TimeUtility.get_aligned_pay_period_start(
			now, 
			current_organization.pay_period_type,
			current_organization.pay_period_start_day
		)
	
	# Create a few pay periods
	for i in range(6):  # Create 6 pay periods
		var period_start = current_period_start.duplicate()
		if i > 0:
			period_start = TimeUtility.get_next_pay_period_start(
				current_period_start, 
				current_organization.pay_period_type,
				i
			)
		
		var period_end = TimeUtility.get_pay_period_end(
			period_start,
			current_organization.pay_period_type
		)
		
		var pay_period = PayPeriod.new("", period_start, period_end)
		
		# Set pay date (typically a few days after period end)
		pay_period.pay_date = TimeUtility.add_days_to_date(period_end, 5)
		
		current_schedule.pay_periods[pay_period.id] = pay_period

func create_employee(first_name: String, last_name: String, classification: String, 
					employment_status: String = "full_time") -> Employee:
	var employee = Employee.new("", first_name, last_name, classification)
	employee.employment_status = employment_status
	
	# Set defaults based on employment status
	match employment_status:
		"full_time":
			employee.fte = 1.0
			employee.max_hours_per_week = 40
		"part_time":
			employee.fte = 0.5  # Default to half-time, can be adjusted
			employee.max_hours_per_week = 20
		"casual":
			employee.fte = 0.0
			employee.max_hours_per_week = 40  # Can work up to full time
			
	current_schedule.add_employee(employee)
	save_schedule()
	return employee

func create_shift(site_id: String, classification: String, date: Dictionary, 
				 start_time: String, end_time: String, pay_period_id: String = "") -> Shift:
	var shift = Shift.new()
	shift.site_id = site_id
	shift.classification = classification
	shift.date = date
	shift.start_time = start_time
	shift.end_time = end_time
	
	# Assign to pay period if not specified
	if pay_period_id.is_empty():
		pay_period_id = get_pay_period_for_date(date).id
	
	shift.pay_period_id = pay_period_id
	
	current_schedule.add_shift(shift)
	save_schedule()
	return shift

func create_shift_line(name: String, site_id: String, classification: String) -> ShiftLine:
	var line = ShiftLine.new("", name)
	line.site_id = site_id
	line.classification = classification
	line.start_date = Time.get_datetime_dict_from_system()
	
	current_schedule.add_shift_line(line)
	save_schedule()
	return line

func add_pattern_to_line(line_id: String, pattern: Array) -> bool:
	if not current_schedule.shift_lines.has(line_id):
		return false
		
	var line = current_schedule.shift_lines[line_id]
	
	# Clear existing pattern
	line.rotation_pattern.clear()
	line.pattern_length = 0
	
	# Add new pattern
	for shift in pattern:
		line.add_pattern_shift(
			shift.day_offset,
			shift.shift_name,
			shift.start_time,
			shift.end_time
		)
	
	save_schedule()
	return true

func get_pay_period_for_date(date: Dictionary) -> PayPeriod:
	for period_id in current_schedule.pay_periods:
		var period = current_schedule.pay_periods[period_id]
		if period.is_date_in_period(date):
			return period
	
	# If no matching period, create one
	var period_start = TimeUtility.get_aligned_pay_period_start(
		date, 
		current_organization.pay_period_type,
		current_organization.pay_period_start_day
	)
	
	var period_end = TimeUtility.get_pay_period_end(
		period_start,
		current_organization.pay_period_type
	)
	
	var pay_period = PayPeriod.new("", period_start, period_end)
	pay_period.pay_date = TimeUtility.add_days_to_date(period_end, 5)
	
	current_schedule.pay_periods[pay_period.id] = pay_period
	save_schedule()
	
	return pay_period

func check_for_overtime(employee_id: String, shift: Shift) -> bool:
	if not current_schedule.employees.has(employee_id):
		return false
		
	var employee = current_schedule.employees[employee_id]
	var is_overtime = false
	
	# Get the applicable overtime rules
	for rule in current_organization.overtime_rules:
		match rule.type:
			"daily":
				# Check if shift exceeds daily threshold
				if shift.duration_hours > rule.threshold:
					is_overtime = true
					break
			
			"weekly":
				# Get week containing this shift
				var week_start = TimeUtility.get_week_start_date(shift.date)
				var week_end = TimeUtility.add_days_to_date(week_start, 6)
				
				# Get all shifts for this employee in this week
				var weekly_shifts = current_schedule.get_employee_shifts(employee_id, week_start, week_end)
				
				# Calculate total hours
				var total_hours = 0.0
				for existing_shift in weekly_shifts:
					total_hours += existing_shift.duration_hours
				
				# Add new shift hours
				total_hours += shift.duration_hours
				
				if total_hours > rule.threshold:
					is_overtime = true
					break
			
			"pay_period":
				# Get pay period for this shift
				var pay_period = null
				if not shift.pay_period_id.is_empty() and current_schedule.pay_periods.has(shift.pay_period_id):
					pay_period = current_schedule.pay_periods[shift.pay_period_id]
				else:
					pay_period = get_pay_period_for_date(shift.date)
				
				# Calculate total hours in this pay period
				var hours_data = pay_period.calculate_hours_for_employee(current_schedule, employee_id)
				var total_hours = hours_data.total_hours + shift.duration_hours
				
				if total_hours > rule.threshold:
					is_overtime = true
					break
			
			"consecutive_days":
				# Get a range of days before this shift
				var prev_days_start = TimeUtility.add_days_to_date(shift.date, -rule.threshold)
				var prev_days_end = TimeUtility.add_days_to_date(shift.date, -1)
				
				# Get all shifts in this range
				var prev_shifts = current_schedule.get_employee_shifts(employee_id, prev_days_start, prev_days_end)
				
				# Build a map of consecutive days worked
				var days_worked = {}
				for prev_shift in prev_shifts:
					var date_key = "%04d-%02d-%02d" % [prev_shift.date.year, prev_shift.date.month, prev_shift.date.day]
					days_worked[date_key] = true
				
				# Check if we have consecutive days up to threshold
				var consecutive_count = 0
				var check_date = prev_days_start
				
				while TimeUtility.compare_dates(check_date, prev_days_end) <= 0:
					var date_key = "%04d-%02d-%02d" % [check_date.year, check_date.month, check_date.day]
					
					if days_worked.has(date_key):
						consecutive_count += 1
						if consecutive_count >= rule.threshold:
							is_overtime = true
							break
					else:
						consecutive_count = 0
					
					check_date = TimeUtility.add_days_to_date(check_date, 1)
				
				if consecutive_count >= rule.threshold:
					is_overtime = true
	
	return is_overtime

func assign_employee_to_shift(shift_id: String, employee_id: String, is_coverage: bool = false, 
							 reason: String = "", force_overtime: bool = false) -> bool:
	# First check if this would be an OT situation
	var shift = current_schedule.shifts[shift_id]
	var is_overtime = force_overtime or check_for_overtime(employee_id, shift)
	
	if is_overtime:
		shift.is_overtime = true
		
		# Get the appropriate OT multiplier based on rules
		for rule in current_organization.overtime_rules:
			if check_rule_applies(rule, employee_id, shift):
				shift.ot_multiplier = rule.multiplier
				break
	
	var result = current_schedule.assign_shift(shift_id, employee_id, is_coverage, reason)
	if result:
		save_schedule()
	return result

@warning_ignore("unused_parameter")
func check_rule_applies(rule: Dictionary, employee_id: String, shift: Shift) -> bool:
	# Helper to check if a specific OT rule applies
	# Implementation would check the various conditions based on rule type
	return false

func assign_employee_to_line(line_id: String, employee_id: String) -> bool:
	var result = current_schedule.assign_employee_to_line(line_id, employee_id)
	if result:
		save_schedule()
	return result

func create_shift_exchange(original_shift_id: String, new_employee_id: String, reason: String = "exchange") -> bool:
	var result = current_schedule.create_shift_exchange(original_shift_id, new_employee_id, reason)
	if result:
		save_schedule()
	return result

func create_shift_offer(shift_id: String, tier_id: String, employee_ids: Array = []) -> ShiftOffer:
	if not current_schedule.shifts.has(shift_id):
		return null
		
	var shift = current_schedule.shifts[shift_id]
	var offer = ShiftOffer.new("", shift_id)
	offer.offering_tier = tier_id
	
	# Get auto-resolution timeframe from organization's configuration
	var tier = current_organization.get_shift_offering_tier(tier_id)
	if not tier.is_empty():
		var hours_until_resolve = tier.get("hours_until_auto_resolve", 24)
		offer.expires_date = TimeUtility.add_hours_to_datetime(
			offer.created_date, 
			hours_until_resolve
		)
	else:
		# Default expiration: 24 hours
		offer.expires_date = TimeUtility.add_hours_to_datetime(
			offer.created_date, 
			24
		)
	
	# Offer to all specified employees
	if not employee_ids.is_empty():
		for employee_id in employee_ids:
			offer.offer_to_employee(employee_id)
	else:
		# If no employees specified, find eligible ones based on tier conditions
		if not tier.is_empty() and tier.has("conditions"):
			var eligible_employees = find_eligible_employees_for_tier(shift, tier)
			for employee in eligible_employees:
				offer.offer_to_employee(employee.id)
	
	current_schedule.shift_offers[offer.id] = offer
	save_schedule()
	
	return offer

func find_eligible_employees_for_tier(shift: Shift, tier: Dictionary) -> Array:
	var eligible_employees = []
	var conditions = tier.get("conditions", [])
	
	for employee_id in current_schedule.employees:
		var employee = current_schedule.employees[employee_id]
		var is_eligible = true
		
		# Check classification match
		if employee.classification != shift.classification:
			continue
			
		# Check site preference
		if not employee.can_work_at_site(shift.site_id):
			continue
			
		# Check availability
		if not employee.is_available(shift.date, shift.start_time, shift.end_time):
			continue
		
		# Check tier-specific conditions
		for condition in conditions:
			if condition.has("status") and employee.employment_status != condition.status:
				is_eligible = false
				break
				
			if condition.has("pay_type"):
				var would_be_overtime = check_for_overtime(employee_id, shift)
				
				if condition.pay_type == "straight" and would_be_overtime:
					is_eligible = false
					break
					
				if condition.pay_type == "overtime" and not would_be_overtime:
					is_eligible = false
					break
		
		if is_eligible:
			eligible_employees.append(employee)
	
	return eligible_employees

func process_shift_offer_response(offer_id: String, employee_id: String, response: String) -> bool:
	if not current_schedule.shift_offers.has(offer_id):
		return false
		
	var offer = current_schedule.shift_offers[offer_id]
	if not employee_id in offer.offered_to_employee_ids:
		return false
		
	offer.record_response(employee_id, response)
	
	# If accepted, assign the shift
	if response == "accepted" and offer.status == "open":
		var shift_id = offer.shift_id
		var is_ot = false
		
		# Check if this was an OT tier
		var tier = current_organization.get_shift_offering_tier(offer.offering_tier)
		if not tier.is_empty():
			for condition in tier.get("conditions", []):
				if condition.has("pay_type") and condition.pay_type == "overtime":
					is_ot = true
					break
		
		# Assign the shift
		if assign_employee_to_shift(shift_id, employee_id, true, "offered", is_ot):
			offer.status = "filled"
			save_schedule()
			return true
	
	save_schedule()
	return true

func check_auto_resolve_shift_offers() -> void:
	# This would be called periodically to auto-resolve expiring offers
	var _now = Time.get_datetime_dict_from_system()
	
	for offer_id in current_schedule.shift_offers:
		var offer = current_schedule.shift_offers[offer_id]
		
		if offer.status == "open" and offer.has_expired():
			auto_resolve_shift_offer(offer)
	
	save_schedule()

func auto_resolve_shift_offer(offer: ShiftOffer) -> void:
	# Check if anyone accepted
	var accepted_employee = offer.get_accepted_employee_id()
	
	if not accepted_employee.is_empty():
		# Assign to first employee who accepted
		assign_employee_to_shift(offer.shift_id, accepted_employee, true, "offered")
		offer.status = "filled"
	else:
		# Nobody accepted - move to next tier or split shift
		var current_tier_id = offer.offering_tier
		var next_tier = find_next_offering_tier(current_tier_id)
		
		if not next_tier.is_empty():
			if next_tier.has("conditions") and has_split_shift_condition(next_tier):
				# Create split shift offer
				split_shift_and_offer(offer.shift_id)
				offer.status = "cancelled"
			else:
				# Create new offer at next tier
				create_shift_offer(offer.shift_id, next_tier.id)
				offer.status = "cancelled"
		else:
			# No more tiers - mark as unfilled
			offer.status = "expired"

func has_split_shift_condition(tier: Dictionary) -> bool:
	for condition in tier.get("conditions", []):
		if condition.has("split_shift") and condition.split_shift:
			return true
	return false

func find_next_offering_tier(current_tier_id: String) -> Dictionary:
	var current_priority = -1
	var next_tier = {}
	var lowest_higher_priority = 999
	
	# Find the priority of the current tier
	for tier in current_organization.shift_offering_rules:
		if tier.id == current_tier_id:
			current_priority = tier.priority
			break
	
	if current_priority < 0:
		return {}
	
	# Find the next tier with higher priority (lower is better)
	for tier in current_organization.shift_offering_rules:
		if tier.priority > current_priority and tier.priority < lowest_higher_priority:
			lowest_higher_priority = tier.priority
			next_tier = tier
	
	return next_tier

func split_shift_and_offer(shift_id: String) -> Array:
	if not current_schedule.shifts.has(shift_id):
		return []
		
	var original_shift = current_schedule.shifts[shift_id]
	
	# Calculate middle point of the shift
	var start_minutes = TimeUtility.parse_time_to_minutes(original_shift.start_time)
	var end_minutes = TimeUtility.parse_time_to_minutes(original_shift.end_time)
	
	if end_minutes < start_minutes:  # Overnight shift
		end_minutes += 24 * 60
	
	@warning_ignore("integer_division")
	var middle_minutes = start_minutes + (end_minutes - start_minutes) / 2
	if middle_minutes >= 24 * 60:
		middle_minutes -= 24 * 60
	
	@warning_ignore("integer_division")
	var middle_time = "%02d:%02d" % [middle_minutes / 60, middle_minutes % 60]
	
	# Create first half shift
	var first_half = create_shift(
		original_shift.site_id,
		original_shift.classification,
		original_shift.date,
		original_shift.start_time,
		middle_time,
		original_shift.pay_period_id
	)
	first_half.is_split_shift = true
	first_half.parent_shift_id = original_shift.id
	
	# Create second half shift
	var second_half = create_shift(
		original_shift.site_id,
		original_shift.classification,
		original_shift.date,
		middle_time,
		original_shift.end_time,
		original_shift.pay_period_id
	)
	second_half.is_split_shift = true
	second_half.parent_shift_id = original_shift.id
	
	# Update original shift
	original_shift.split_segments = [first_half.id, second_half.id]
	original_shift.status = "cancelled"
	
	# Create offers for both halves
	var split_tier_id = find_split_shift_tier_id()
	if not split_tier_id.is_empty():
		create_shift_offer(first_half.id, split_tier_id)
		create_shift_offer(second_half.id, split_tier_id)
	
	save_schedule()
	return [first_half, second_half]

func find_split_shift_tier_id() -> String:
	for tier in current_organization.shift_offering_rules:
		if has_split_shift_condition(tier):
			return tier.id
	return ""

func get_daily_schedule(date: Dictionary) -> Dictionary:
	# Returns a comprehensive daily schedule for all sites
	var daily_schedule = {}
	
	for site_id in current_schedule.sites:
		var site = current_schedule.sites[site_id]
		daily_schedule[site_id] = {
			"name": site.name,
			"shifts": current_schedule.get_shifts_by_date(date, site_id),
			"staffing": current_schedule.check_staffing_requirements(date, site_id)
		}
	
	return daily_schedule

func generate_shifts_for_date_range(start_date: Dictionary, end_date: Dictionary) -> Array:
	# Generate shifts from all lines for the given date range
	var generated_shifts = []
	
	for line_id in current_schedule.shift_lines:
		var line = current_schedule.shift_lines[line_id]
		if not line.assigned_employee_id.is_empty():
			var line_shifts = line.get_shifts_for_date_range(start_date, end_date)
			for shift in line_shifts:
				# Check if this shift already exists in the schedule
				var existing = false
				for existing_shift_id in current_schedule.shifts:
					var existing_shift = current_schedule.shifts[existing_shift_id]
					if TimeUtility.same_date(existing_shift.date, shift.date) and \
					   existing_shift.start_time == shift.start_time and \
					   existing_shift.end_time == shift.end_time and \
					   existing_shift.site_id == shift.site_id and \
					   existing_shift.classification == shift.classification and \
					   existing_shift.assigned_employee_id == shift.assigned_employee_id:
						existing = true
						break
				
				if not existing:
					current_schedule.add_shift(shift)
					generated_shifts.append(shift)
	
	if not generated_shifts.is_empty():
		save_schedule()
	
	return generated_shifts

func export_schedule_to_csv(start_date: Dictionary, end_date: Dictionary) -> String:
	var csv_content = "Date,Day,Site,Shift,Classification,Start,End,Employee,Pattern,Reason\n"
	
	var current_date = start_date.duplicate()
	while TimeUtility.compare_dates(current_date, end_date) <= 0:
		var date_str = "%04d-%02d-%02d" % [current_date.year, current_date.month, current_date.day]
		var day_name = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][current_date.weekday]
		
		var daily_schedule = get_daily_schedule(current_date)
		
		for site_id in daily_schedule:
			var site_data = daily_schedule[site_id]
			for classification in site_data.shifts:
				for shift in site_data.shifts[classification]:
					var employee_name = "Unassigned"
					if not shift.assigned_employee_id.is_empty() and current_schedule.employees.has(shift.assigned_employee_id):
						employee_name = current_schedule.employees[shift.assigned_employee_id].get_full_name()
					
					var pattern_info =  "Pattern" if shift.is_pattern_shift else "Coverage"
					var reason = shift.coverage_reason
					
					var row = "%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" % [
						date_str,
						day_name,
						shift.site_id,
						TimeUtility.get_shift_name_from_time(shift.start_time),
						shift.classification,
						shift.start_time,
						shift.end_time,
						employee_name,
						pattern_info,
						reason
					]
					
					csv_content += row
		
		current_date = TimeUtility.add_days_to_date(current_date, 1)
	
	return csv_content
