extends Control

# Reference to the schedule manager
var schedule_manager: ScheduleManager

# UI References
@onready var tab_container = $TabContainer
@onready var organization_tab = $TabContainer/OrganizationTab
@onready var sites_tab = $TabContainer/SitesTab
@onready var employees_tab = $TabContainer/EmployeesTab
@onready var shift_patterns_tab = $TabContainer/ShiftPatternsTab
@onready var overtime_tab = $TabContainer/OvertimeTab
@onready var shift_offerings_tab = $TabContainer/ShiftOfferingsTab
@onready var classifications_tab = $TabContainer/ClassificationsTab
@onready var pay_periods_tab = $TabContainer/PayPeriodsTab
@onready var status_label = $StatusLabel

# Initialize
func _ready():
	# Get reference to the schedule manager from the main scene
	schedule_manager = get_node("/root/Main/ScheduleManager")
	
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
	status_label.text = "Configuration manager loaded successfully."

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
	status_label.text = section_name + " configuration saved successfully."
	# Auto-hide the message after 3 seconds
	await get_tree().create_timer(3.0).timeout
	status_label.text = ""

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
	
	status_label.text = "Configuration exported to: " + export_path

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
			
			status_label.text = "Configuration imported successfully."
		else:
			status_label.text = "Error parsing configuration file."
	else:
		status_label.text = "Configuration file not found: " + import_path
