extends Control


var schedule_manager: ScheduleManager
var nav_manager: NavigationManager

# UI References using unique names
@onready var content_container = %ContentContainer
@onready var loading_screen = %LoadingScreen
@onready var landing_page = %LandingPage
@onready var calendar_view = %CalendarView
@onready var config_manager = %ConfigManager
@onready var employee_list = %EmployeeList
@onready var employee_detail = %EmployeeDetail
@onready var main_status_bar = %StatusBar
@onready var status_label = %StatusLabel

func _ready():
	# Get references to managers
	schedule_manager = %ScheduleManager
	nav_manager = %NavigationManager
	
	# Hide all screens except loading screen
	loading_screen.visible = true
	landing_page.visible = false
	calendar_view.visible = false
	config_manager.visible = false
	employee_list.visible = false
	employee_detail.visible = false
	main_status_bar.visible = false
	
	# Connect loading signals
	loading_screen.connect("loading_complete", _on_loading_complete)
	loading_screen.connect("setup_organization", _on_setup_organization)
	loading_screen.connect("setup_sites", _on_setup_sites)
	loading_screen.connect("setup_employees", _on_setup_employees)
	
	# Connect ScheduleManager signals
	schedule_manager.organization_loaded.connect(_on_organization_loaded)
	schedule_manager.schedule_loaded.connect(_on_schedule_loaded)
	schedule_manager.configuration_error.connect(_on_configuration_error)
	
	# Connect NavigationManager signals
	nav_manager.screen_changed.connect(_on_screen_changed)
	
	# Start the loading process
	_start_loading_process()
	
	# Generate test shifts
	generate_test_shifts()

func _start_loading_process():
	# Update loading screen
	loading_screen.update_progress("Loading application settings...")
	
	# Start the loading process AFTER all signal connections are established
	schedule_manager.start_loading()
	
	# Check setup flags for the loading screen
	var has_organization = schedule_manager.current_organization != null and not schedule_manager.current_organization.name.is_empty()
	var has_sites = schedule_manager.current_schedule != null and not schedule_manager.current_schedule.sites.is_empty()
	var has_employees = schedule_manager.current_schedule != null and not schedule_manager.current_schedule.employees.is_empty()
	
	loading_screen.set_setup_flags(has_organization, has_sites, has_employees)
	
	# The ScheduleManager will automatically start loading in its _ready() function
	# We'll receive signals when different parts are loaded

func _on_organization_loaded():
	loading_screen.update_progress("Organization data loaded...")

func _on_schedule_loaded():
	loading_screen.update_progress("Schedule data loaded...")
	
	# Initialize all views now that data is loaded
	_initialize_views()

func _on_setup_organization():
	# Navigate directly to organization setup
	nav_manager.navigate_to("config")
	# Ensure organization tab is selected
	config_manager.tab_container.current_tab = 0  # Assuming organization tab is first

func _on_setup_sites():
	# Navigate directly to sites setup
	nav_manager.navigate_to("config")
	# Ensure sites tab is selected
	config_manager.tab_container.current_tab = 1  # Assuming sites tab is second

func _on_setup_employees():
	# Navigate directly to employee manager
	nav_manager.navigate_to("employee_list")

func _on_configuration_error(error_message):
	loading_screen.add_error(error_message)

func _initialize_views():
	# Initialize landing page
	landing_page.schedule_manager = schedule_manager
	
	# Initialize calendar view
	calendar_view.initialize(schedule_manager, nav_manager)
	
	# Initialize config manager
	config_manager.initialize(schedule_manager, nav_manager)
	
	# Initialize employee views
	employee_list.initialize(schedule_manager, nav_manager)
	
	# Connect navigation signals
	landing_page.open_calendar.connect(_on_open_calendar)
	landing_page.open_employees.connect(_on_open_employees)
	landing_page.open_configuration.connect(_on_open_configuration)
	
	# Connect employee signals
	employee_list.employee_selected.connect(_on_employee_selected)
	
	# Connect calendar signals
	calendar_view.shift_selected.connect(_on_shift_selected)
	calendar_view.day_selected.connect(_on_day_selected)
	
	# Final loading step
	loading_screen.update_progress("User interface initialized...")

func _on_loading_complete():
	# Start navigation system with landing page
	nav_manager.navigate_to("landing")

func _on_screen_changed(screen_name: String, _previous_screen: String):
	# Hide all screens
	landing_page.visible = false
	calendar_view.visible = false
	config_manager.visible = false
	employee_list.visible = false
	employee_detail.visible = false
	loading_screen.visible = false

	main_status_bar.visible = true
	
	# Show the requested screen
	match screen_name:
		"landing":
			landing_page.visible = true
			landing_page._ready()  # Refresh
		"calendar":
			calendar_view.visible = true
			calendar_view.update_calendar()
		"config":
			config_manager.visible = true
		"employee_list":
			employee_list.visible = true
			employee_list.load_employees()  # Refresh
		"employee_detail":
			employee_detail.visible = true

func _on_open_calendar():
	nav_manager.navigate_to("calendar")
	
func _on_open_employees():
	nav_manager.navigate_to("employee_list")
	
func _on_open_configuration():
	nav_manager.navigate_to("config")

func _on_employee_selected(employee_id: String):
	# Initialize employee detail view
	employee_detail.initialize(schedule_manager, nav_manager, employee_id)
	
	# Navigate to employee detail
	nav_manager.navigate_to("employee_detail")

func _on_shift_selected(shift):
	# Display shift details in the status bar
	set_temp_message("Selected shift: %s at %s (%s to %s)" % [
		shift.classification,
		shift.site_id,
		shift.start_time,
		shift.end_time
	])

func _on_day_selected(date):
	# Show selected date in status bar
	set_temp_message("Selected date: %04d-%02d-%02d" % [
		date.year, date.month, date.day
	])
	
func set_temp_message(msg: String, delay: float = 3.0):
	if not status_label:
		return
	status_label.text = msg
	await get_tree().create_timer(delay).timeout
	status_label.text = ""


func _on_home_pressed() -> void:
	nav_manager.navigate_to("landing")


func _on_back_pressed() -> void:
	nav_manager.go_back()



func generate_test_shifts():
	print("Generating test shifts...")
	
	# Generate shifts from patterns
	generate_shifts_from_patterns()
	
	# Generate random coverage shifts
	generate_coverage_shifts()
	
	# Create some open shifts
	generate_open_shifts()
	
	print("Test shifts generation complete!")

func generate_shifts_from_patterns():
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
	
	print("Generated %d shifts from patterns" % [generated.size()])

func generate_coverage_shifts():
	# Get current date and end of next month
	var current_date = Time.get_datetime_dict_from_system()
	var end_date = current_date.duplicate()
	end_date.month += 1
	if end_date.month > 12:
		end_date.month = 1
		end_date.year += 1
	end_date.day = TimeUtility.days_in_month(end_date.year, end_date.month)
	
	# Coverage reasons
	var reasons = ["sick", "vacation", "personal", "family", "education"]
	
	# Get all employees by classification
	var employees_by_class = {"RN": [], "LPN": [], "CA": []}
	for employee_id in schedule_manager.current_schedule.employees:
		var employee = schedule_manager.current_schedule.employees[employee_id]
		if employees_by_class.has(employee.classification):
			employees_by_class[employee.classification].append(employee)
	
	# Add some coverage shifts
	var coverage_shift_count = 0
	
	# For each site
	for site_id in ["RHH", "HH"]:
		# Add a few random coverage shifts for each classification
		for classification in ["RN", "LPN", "CA"]:
			# Number of coverage shifts to create
			var count = 5 if site_id == "RHH" else 3
			if classification == "CA":
				count *= 2  # More CA coverage needs typically
			
			for _i in range(count):
				# Random date in the next month
				var days_to_add = randi() % 30 + 1
				var shift_date = TimeUtility.add_days_to_date(current_date, days_to_add)
				
				# Random times (day/evening/night)
				var shift_type = randi() % 3
				var start_time
				var end_time
				
				if shift_type == 0:  # Day
					start_time = "07:00"
					end_time = "15:00"
				elif shift_type == 1:  # Evening
					start_time = "15:00"
					end_time = "23:00"
				else:  # Night
					start_time = "23:00"
					end_time = "07:00"
				
				# Create the shift
				var shift = schedule_manager.create_shift(
					site_id, classification, shift_date, start_time, end_time)
					
				# Mark it as coverage
				shift.is_pattern_shift = false
				shift.coverage_reason = reasons[randi() % reasons.size()]
				
				# Assign to a random employee of the right classification (60% chance)
				if randi() % 100 < 60 and not employees_by_class[classification].is_empty():
					var employee = employees_by_class[classification][randi() % employees_by_class[classification].size()]
					if employee.can_work_at_site(site_id):
						shift.assign_employee(employee.id)
						
						# Sometimes mark as overtime (30% chance)
						if randi() % 100 < 30:
							shift.is_overtime = true
							shift.ot_multiplier = 1.5
				
				coverage_shift_count += 1
	
	print("Generated %d coverage shifts" % [coverage_shift_count])

func generate_open_shifts():
	# Get current date and end of next month
	var current_date = Time.get_datetime_dict_from_system()
	var end_date = current_date.duplicate()
	end_date.month += 1
	if end_date.month > 12:
		end_date.month = 1
		end_date.year += 1
	end_date.day = TimeUtility.days_in_month(end_date.year, end_date.month)
	
	# Add some open shifts
	var open_shift_count = 0
	
	# For each site
	for site_id in ["RHH", "HH"]:
		# Add a few random open shifts for each classification
		for classification in ["RN", "LPN", "CA"]:
			# Number of open shifts to create
			var count = 4 if site_id == "RHH" else 2
			if classification == "CA":
				count *= 2  # More CA needs typically
			
			for _i in range(count):
				# Random date in the next 14 days (more urgent needs)
				var days_to_add = randi() % 14 + 1
				var shift_date = TimeUtility.add_days_to_date(current_date, days_to_add)
				
				# Random times (day/evening/night)
				var shift_type = randi() % 3
				var start_time
				var end_time
				
				if shift_type == 0:  # Day
					start_time = "07:00"
					end_time = "15:00"
				elif shift_type == 1:  # Evening
					start_time = "15:00"
					end_time = "23:00"
				else:  # Night
					start_time = "23:00"
					end_time = "07:00"
				
				# Create the shift
				var shift = schedule_manager.create_shift(
					site_id, classification, shift_date, start_time, end_time)
					
				# Ensure it's open
				shift.status = "open"
				
				# Create shift offers for some of the open shifts (40% chance)
				if randi() % 100 < 40:
					# Find appropriate tier
					var tier_id = ""
					for tier in schedule_manager.current_organization.shift_offering_rules:
						tier_id = tier.id
						break
					
					if not tier_id.is_empty():
						schedule_manager.create_shift_offer(shift.id, tier_id)
				
				open_shift_count += 1
	
	print("Generated %d open shifts" % [open_shift_count])
