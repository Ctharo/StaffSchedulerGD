extends Control

signal send_message(msg: String, timeout: float)


# Reference to the schedule manager
var schedule_manager: ScheduleManager
var nav_manager: NavigationManager

# UI References
@onready var navigation_bar = %NavigationBar
@onready var tab_container = %TabContainer
@onready var organization_tab = %OrganizationTab
@onready var sites_tab = %SitesTab
@onready var employees_tab = %EmployeesTab
@onready var shift_patterns_tab = %ShiftPatternsTab
@onready var overtime_tab = %OvertimeTab
@onready var shift_offerings_tab = %ShiftOfferingsTab
@onready var classifications_tab = %ClassificationsTab
@onready var pay_periods_tab = %PayPeriodsTab
var set_msg_method: Callable

# Initialize
func _ready():
	# Get reference to the schedule manager from the main scene
	schedule_manager = get_node("/root/Main/ScheduleManager")



func initialize(p_schedule_manager: ScheduleManager, p_nav_manager: NavigationManager):
	
	schedule_manager = p_schedule_manager
	nav_manager = p_nav_manager
	
	navigation_bar.initialize(nav_manager)
	
	# Initialize all tabs
	organization_tab.init(schedule_manager)
	sites_tab.init(schedule_manager)
	employees_tab.init(schedule_manager)
	shift_patterns_tab.init(schedule_manager)
	overtime_tab.init(schedule_manager)
	shift_offerings_tab.init(schedule_manager)
	classifications_tab.init(schedule_manager)
	pay_periods_tab.init(schedule_manager)
	
	# Connect save button signals
	connect_save_signals()
	
	# Display welcome message
	set_msg("Configuration manager loaded successfully.")
	
func connect_save_signals():
	# Connect save signals from each tab
	organization_tab.connect("config_saved", _on_config_saved)
	sites_tab.connect("config_saved", _on_config_saved)
	employees_tab.connect("config_saved", _on_config_saved)
	shift_patterns_tab.connect("config_saved", _on_config_saved)
	overtime_tab.connect("config_saved", _on_config_saved)
	shift_offerings_tab.connect("config_saved", _on_config_saved)
	classifications_tab.connect("config_saved", _on_config_saved)
	pay_periods_tab.connect("config_saved", _on_config_saved)

func _on_config_saved(section_name):
	set_msg(section_name + " configuration saved successfully.")

func _on_export_button_pressed():
	# Export all configuration to a file
	var export_path = "user://config_export.json"
	var config_data = {
		"organization": organization_tab.get_config_data(),
		"sites": sites_tab.get_config_data(),
		"classifications": classifications_tab.get_config_data(),
		"overtime_rules": overtime_tab.get_config_data(),
		"shift_offerings": shift_offerings_tab.get_config_data(),
		"pay_periods": pay_periods_tab.get_config_data()
	}
	
	var json_string = JSON.stringify(config_data, "\t")
	var file = FileAccess.open(export_path, FileAccess.WRITE)
	file.store_string(json_string)
	file.close()
	
	set_msg("Configuration exported to: " + export_path)
	
func _on_import_button_pressed():
	# Import configuration from a file
	var import_path = "user://config_export.json"
	
	if FileAccess.file_exists(import_path):
		var file = FileAccess.open(import_path, FileAccess.READ)
		var json_string = file.get_as_text()
		file.close()
		
		var json = JSON.new()
		var error = json.parse(json_string)
		
		if error == OK:
			var config_data = json.get_data()
			
			# Import each section
			organization_tab.import_config_data(config_data.get("organization", {}))
			sites_tab.import_config_data(config_data.get("sites", {}))
			classifications_tab.import_config_data(config_data.get("classifications", {}))
			overtime_tab.import_config_data(config_data.get("overtime_rules", {}))
			shift_offerings_tab.import_config_data(config_data.get("shift_offerings", {}))
			pay_periods_tab.import_config_data(config_data.get("pay_periods", {}))
			
			set_msg("Configuration imported successfully.")
		else:
			set_msg("Error parsing configuration file.")
	else:
		set_msg("Configuration file not found: " + import_path)

func set_msg(msg: String, delay: float = 3.0):
	send_message.emit(msg, delay)


func _on_navigation_bar_home_pressed() -> void:
	nav_manager.go_home()

func _on_navigation_bar_back_pressed() -> void:
	nav_manager.go_back()
