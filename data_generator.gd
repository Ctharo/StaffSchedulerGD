extends Node

# This script generates developer test data for the Staff Scheduler application
# It creates an organization, sites, shift lines, and staff members

# Reference to the schedule manager
var schedule_manager: ScheduleManager

func _ready():
	# Get reference to schedule manager
	schedule_manager = get_node("/root/Main/ScheduleManager")
	
	# Create base organization and data
	create_test_data()

func create_test_data():
	print("Creating developer test data...")
	
	# 1. Create organization
	create_organization()
	
	# 2. Create sites
	create_sites()
	
	# 3. Create shift patterns
	create_shift_lines()
	
	# 4. Create staff members
	create_staff_members()
	
	print("Developer test data created successfully!")

func create_organization():
	print("Creating organization...")
	
	# Create or update the organization
	var organization = schedule_manager.current_organization
	organization.name = "Prince George Hospice and Palliative Care Society"
	organization.industry_type = "healthcare"
	
	# Set up classifications if they don't exist
	if organization.classifications.is_empty():
		organization.classifications = ["RN", "LPN", "CA"]
	
	# Save organization
	schedule_manager.save_organization()
	print("Organization created.")

func create_sites():
	print("Creating sites...")
	
	# Check if sites exist first
	var has_rhh = false
	var has_hh = false
	
	for site_id in schedule_manager.current_schedule.sites:
		var site = schedule_manager.current_schedule.sites[site_id]
		if site.id == "RHH":
			has_rhh = true
		elif site.id == "HH":
			has_hh = true
	
	# Create RHH if it doesn't exist
	if not has_rhh:
		var rhh = Site.new("RHH", "Rotary Hospice House")
		rhh.address = "1506 Ferry Avenue, Prince George, BC V2L 5H2"
		rhh.phone = "(250) 563-2551"
		schedule_manager.current_schedule.add_site(rhh)
	
	# Create HH if it doesn't exist
	if not has_hh:
		var hh = Site.new("HH", "Home Hospice")
		hh.address = "1506 Ferry Avenue, Prince George, BC V2L 5H2"
		hh.phone = "(250) 563-2551"
		schedule_manager.current_schedule.add_site(hh)
	
	# Save changes
	schedule_manager.save_schedule()
	print("Sites created.")

func create_shift_lines():
	print("Creating shift lines...")
	
	# RHH Nursing Lines (6)
	create_nursing_lines("RHH", 6)
	
	# HH Nursing Lines (3)
	create_nursing_lines("HH", 3)
	
	# RHH Care Aide Lines (10)
	create_ca_lines("RHH", 10)
	
	# HH Care Aide Lines (3)
	create_ca_lines("HH", 3)
	
	# Save changes
	schedule_manager.save_schedule()
	print("Shift lines created.")

func create_nursing_lines(site_id: String, count: int):
	# Get existing line count to continue numbering
	var existing_count = 0
	for line_id in schedule_manager.current_schedule.shift_lines:
		var line = schedule_manager.current_schedule.shift_lines[line_id]
		if line.site_id == site_id and (line.classification == "RN" or line.classification == "LPN"):
			existing_count += 1
	
	# Create lines
	for i in range(count):
		var line_number = existing_count + i + 1
		var classification = "RN" if i % 3 != 2 else "LPN"  # 2 RNs to 1 LPN ratio
		var line = ShiftLine.new("", "%s %s Line %d" % [site_id, classification, line_number])
		line.site_id = site_id
		line.classification = classification
		line.pattern_length = 14  # Two week rotation
		line.start_date = Time.get_datetime_dict_from_system()
		
		# Create rotation pattern (day/night shifts with days off)
		# This is a simplified pattern - in reality, these would be more complex
		for j in range(14):
			var day_offset = j
			var is_day_off = false
			
			# Days off pattern (varies by line to ensure coverage)
			if line_number % 3 == 0:
				is_day_off = (j == 0 or j == 1 or j == 8 or j == 9)
			elif line_number % 3 == 1:
				is_day_off = (j == 2 or j == 3 or j == 10 or j == 11)
			else:
				is_day_off = (j == 4 or j == 5 or j == 12 or j == 13)
			
			if is_day_off:
				# Off day - no shift to add
				pass
			else:
				# Alternate between day and night shifts
				var is_day_shift = (j % 4 < 2)
				var shift_name = "Day" if is_day_shift else "Night"
				var start_time = "07:00" if is_day_shift else "19:00"
				var end_time = "19:00" if is_day_shift else "07:00"
				
				line.add_pattern_shift(day_offset, shift_name, start_time, end_time)
		
		# Add to schedule
		schedule_manager.current_schedule.add_shift_line(line)

func create_ca_lines(site_id: String, count: int):
	# Get existing line count to continue numbering
	var existing_count = 0
	for line_id in schedule_manager.current_schedule.shift_lines:
		var line = schedule_manager.current_schedule.shift_lines[line_id]
		if line.site_id == site_id and line.classification == "CA":
			existing_count += 1
	
	# Create lines
	for i in range(count):
		var line_number = existing_count + i + 1
		var line = ShiftLine.new("", "%s CA Line %d" % [site_id, line_number])
		line.site_id = site_id
		line.classification = "CA"
		line.pattern_length = 14  # Two week rotation
		line.start_date = Time.get_datetime_dict_from_system()
		
		# Create rotation pattern (day/evening/night shifts with days off)
		for j in range(14):
			var day_offset = j
			var is_day_off = false
			
			# Days off pattern (varies by line to ensure coverage)
			var line_offset = line_number % 5
			if line_offset == 0:
				is_day_off = (j == 0 or j == 1 or j == 8 or j == 9)
			elif line_offset == 1:
				is_day_off = (j == 2 or j == 3 or j == 10 or j == 11)
			elif line_offset == 2:
				is_day_off = (j == 4 or j == 5 or j == 12 or j == 13)
			elif line_offset == 3:
				is_day_off = (j == 6 or j == 7 or j == 0 or j == 8)
			else:
				is_day_off = (j == 1 or j == 7 or j == 8 or j == 13)
			
			if is_day_off:
				# Off day - no shift to add
				pass
			else:
				# Rotate through day, evening, and night shifts
				var shift_type = (j + line_offset) % 3
				var shift_name = "Day"
				var start_time = "07:00"
				var end_time = "15:00"
				
				if shift_type == 1:
					shift_name = "Evening"
					start_time = "15:00"
					end_time = "23:00"
				elif shift_type == 2:
					shift_name = "Night"
					start_time = "23:00"
					end_time = "07:00"
				
				line.add_pattern_shift(day_offset, shift_name, start_time, end_time)
		
		# Add to schedule
		schedule_manager.current_schedule.add_shift_line(line)

func create_staff_members():
	print("Creating staff members...")
	
	# First names data
	var first_names = [
		# Female names
		"Emma", "Olivia", "Sophia", "Ava", "Isabella", "Mia", "Charlotte", "Amelia", 
		"Harper", "Evelyn", "Abigail", "Emily", "Elizabeth", "Sofia", "Avery",
		"Ella", "Scarlett", "Grace", "Lily", "Aria", "Zoey", "Penelope", 
		# Male names
		"Liam", "Noah", "William", "James", "Oliver", "Benjamin", "Elijah", "Lucas",
		"Mason", "Logan", "Alexander", "Ethan", "Jacob", "Michael", "Daniel",
		"Henry", "Jackson", "Sebastian", "Aiden", "Matthew", "Samuel", "David"
	]
	
	# Last names data
	var last_names = [
		"Smith", "Johnson", "Williams", "Brown", "Jones", "Miller", "Davis", 
		"Garcia", "Rodriguez", "Wilson", "Martinez", "Anderson", "Taylor", 
		"Thomas", "Hernandez", "Moore", "Martin", "Jackson", "Thompson", "White",
		"Lopez", "Lee", "Gonzalez", "Harris", "Clark", "Lewis", "Robinson", 
		"Walker", "Perez", "Hall", "Young", "Allen", "Sanchez", "Wright", "King",
		"Scott", "Green", "Baker", "Adams", "Nelson", "Hill", "Ramirez", "Campbell",
		"Mitchell", "Roberts", "Carter", "Phillips", "Evans", "Turner", "Torres"
	]
	
	# Get existing count
	var existing_count = schedule_manager.current_schedule.employees.size()
	
	# Create 12 nursing staff (8 RNs, 4 LPNs)
	for i in range(12):
		var first_name = first_names[randi() % first_names.size()]
		var last_name = last_names[randi() % last_names.size()]
		var classification = "RN" if i < 8 else "LPN"
		var employment_status = "full_time" if i % 3 == 0 else ("part_time" if i % 3 == 1 else "casual")
		
		var employee = Employee.new("", first_name, last_name, classification)
		employee.email = "%s.%s@example.com" % [first_name.to_lower(), last_name.to_lower()]
		employee.phone = "250-555-%04d" % [1000 + randi() % 9000]
		employee.employment_status = employment_status
		
		# Set FTE based on employment status
		if employment_status == "full_time":
			employee.fte = 1.0
			employee.max_hours_per_week = 40
		elif employment_status == "part_time":
			employee.fte = 0.5
			employee.max_hours_per_week = 20
		else:  # casual
			employee.fte = 0.0
			employee.max_hours_per_week = 40
		
		# Set site preferences (some work at both sites)
		if i % 4 == 0:
			employee.site_preferences = ["RHH", "HH"]
		elif i % 4 == 1 or i % 4 == 2:
			employee.site_preferences = ["RHH"]
		else:
			employee.site_preferences = ["HH"]
		
		# Add employee
		schedule_manager.current_schedule.add_employee(employee)
	
	# Create 18 care aides
	for i in range(18):
		var first_name = first_names[randi() % first_names.size()]
		var last_name = last_names[randi() % last_names.size()]
		var employment_status = "full_time" if i % 3 == 0 else ("part_time" if i % 3 == 1 else "casual")
		
		var employee = Employee.new("", first_name, last_name, "CA")
		employee.email = "%s.%s@example.com" % [first_name.to_lower(), last_name.to_lower()]
		employee.phone = "250-555-%04d" % [1000 + randi() % 9000]
		employee.employment_status = employment_status
		
		# Set FTE based on employment status
		if employment_status == "full_time":
			employee.fte = 1.0
			employee.max_hours_per_week = 40
		elif employment_status == "part_time":
			employee.fte = 0.5
			employee.max_hours_per_week = 20
		else:  # casual
			employee.fte = 0.0
			employee.max_hours_per_week = 40
		
		# Set site preferences (some work at both sites)
		if i % 6 == 0:
			employee.site_preferences = ["RHH", "HH"]
		elif i < 12:  # 2/3 of CAs at RHH
			employee.site_preferences = ["RHH"]
		else:
			employee.site_preferences = ["HH"]
		
		# Add employee
		schedule_manager.current_schedule.add_employee(employee)
	
	# Set up basic availability for all employees
	for employee_id in schedule_manager.current_schedule.employees:
		var employee = schedule_manager.current_schedule.employees[employee_id]
		
		# Set availability for all days
		for day in range(7):
			# Most employees are available during standard shifts
			var availability = []
			
			# Randomize availability a bit
			var is_available = randi() % 10 < 8  # 80% chance of being available on any day
			
			if is_available:
				# Default availability is 7am to 11pm
				availability.append({"start": "07:00", "end": "23:00"})
			
			employee.availability[day] = availability
	
	# Assign some employees to shift lines
	assign_employees_to_lines()
	
	# Save changes
	schedule_manager.save_schedule()
	print("Staff members created.")

func assign_employees_to_lines():
	print("Assigning employees to shift lines...")
	
	# Get all full-time and part-time employees by classification
	var rn_employees = []
	var lpn_employees = []
	var ca_employees = []
	
	for employee_id in schedule_manager.current_schedule.employees:
		var employee = schedule_manager.current_schedule.employees[employee_id]
		
		# Skip casual employees for line assignments
		if employee.employment_status == "casual":
			continue
		
		match employee.classification:
			"RN":
				rn_employees.append(employee)
			"LPN":
				lpn_employees.append(employee)
			"CA":
				ca_employees.append(employee)
	
	# Get shift lines by classification
	var rn_lines = []
	var lpn_lines = []
	var ca_lines = []
	
	for line_id in schedule_manager.current_schedule.shift_lines:
		var line = schedule_manager.current_schedule.shift_lines[line_id]
		
		# Skip already assigned lines
		if not line.assigned_employee_id.is_empty():
			continue
		
		match line.classification:
			"RN":
				rn_lines.append(line)
			"LPN":
				lpn_lines.append(line)
			"CA":
				ca_lines.append(line)
	
	# Assign employees to lines
	_assign_to_lines(rn_employees, rn_lines)
	_assign_to_lines(lpn_employees, lpn_lines)
	_assign_to_lines(ca_employees, ca_lines)

func _assign_to_lines(employees, lines):
	# Shuffle both arrays to randomize assignments
	employees.shuffle()
	lines.shuffle()
	
	# Assign employees to lines
	var assigned_count = 0
	for i in range(min(employees.size(), lines.size())):
		var employee = employees[i]
		var line = lines[i]
		
		# Check if employee can work at this site
		if not employee.can_work_at_site(line.site_id):
			continue
		
		# Assign the line
		if schedule_manager.assign_employee_to_line(line.id, employee.id):
			assigned_count += 1
	
	print("Assigned %d employees to %d lines" % [assigned_count, lines.size()])

# Generate shifts for the next month
func generate_shifts_for_month():
	print("Generating shifts for the next month...")
	
	# Get current date and end of next month
	var current_date = Time.get_datetime_dict_from_system()
	var end_date = current_date.duplicate()
	end_date.month += 1
	if end_date.month > 12:
		end_date.month = 1
		end_date.year += 1
	end_date.day = TimeUtility.days_in_month(end_date.year, end_date.month)
	
	# Generate shifts
	var generated = schedule_manager.generate_shifts_for_date_range(current_date, end_date)
	
	print("Generated %d shifts for the next month" % [generated.size()])
