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
	config_manager.schedule_manager = schedule_manager
	
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
	
	# Show or hide main status bar based on the screen
	if screen_name == "landing":
		# Don't show main status bar on landing page
		main_status_bar.visible = false
	else:
		# Show main status bar on other screens
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
	status_label.text = "Selected shift: %s at %s (%s to %s)" % [
		shift.classification,
		shift.site_id,
		shift.start_time,
		shift.end_time
	]

func _on_day_selected(date):
	# Show selected date in status bar
	status_label.text = "Selected date: %04d-%02d-%02d" % [
		date.year, date.month, date.day
	]
