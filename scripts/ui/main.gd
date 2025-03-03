extends Control

var schedule_manager: ScheduleManager
var nav_manager: NavigationManager

# UI References
@onready var content_container = %ContentContainer
@onready var loading_screen = %LoadingScreen
@onready var landing_page = %LandingPage
@onready var calendar_view = %CalendarView
@onready var config_manager = %ConfigManager
@onready var employee_list = %EmployeeList
@onready var employee_detail = %EmployeeDetail
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
	
	# Connect loading signals
	loading_screen.connect("loading_complete", _on_loading_complete)
	
	# Connect ScheduleManager signals
	schedule_manager.connect("organization_loaded", _on_organization_loaded)
	schedule_manager.connect("schedule_loaded", _on_schedule_loaded)
	schedule_manager.connect("configuration_error", _on_configuration_error)
	
	# Connect NavigationManager signals
	nav_manager.connect("screen_changed", _on_screen_changed)
	
	# Start the loading process
	_start_loading_process()

func _start_loading_process():
	# Update loading screen
	loading_screen.update_progress("Loading application settings...")
	
	# The ScheduleManager will automatically start loading in its _ready() function
	# We'll receive signals when different parts are loaded

func _on_organization_loaded():
	loading_screen.update_progress("Organization data loaded...")

func _on_schedule_loaded():
	loading_screen.update_progress("Schedule data loaded...")
	
	# Initialize all views now that data is loaded
	_initialize_views()

func _on_configuration_error(error_message):
	loading_screen.add_error(error_message)

func _initialize_views():
	# Initialize landing page
	landing_page.schedule_manager = schedule_manager
	
	# Initialize calendar view
	calendar_view.schedule_manager = schedule_manager
	
	# Initialize config manager
	config_manager.schedule_manager = schedule_manager
	
	# Initialize employee views
	employee_list.initialize(schedule_manager, nav_manager)
	
	# Connect navigation signals
	landing_page.connect("open_calendar", _on_open_calendar)
	landing_page.connect("open_employees", _on_open_employees)
	landing_page.connect("open_configuration", _on_open_configuration)
	
	# Connect employee signals
	employee_list.connect("employee_selected", _on_employee_selected)
	
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
