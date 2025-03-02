extends Control

signal open_calendar
signal open_configuration
signal open_employees

var schedule_manager: ScheduleManager

# UI References
@onready var app_title = $VBoxContainer/TitlePanel/VBoxContainer/Title
@onready var app_subtitle = $VBoxContainer/TitlePanel/VBoxContainer/Subtitle
@onready var calendar_button = $VBoxContainer/ButtonsPanel/VBoxContainer/CalendarButton
@onready var employees_button = $VBoxContainer/ButtonsPanel/VBoxContainer/EmployeesButton
@onready var config_button = $VBoxContainer/ButtonsPanel/VBoxContainer/ConfigButton
@onready var reports_button = $VBoxContainer/ButtonsPanel/VBoxContainer/ReportsButton
@onready var status_label = $VBoxContainer/StatusBar/StatusLabel

func _ready():
	# Connect signals
	calendar_button.connect("pressed", _on_calendar_button_pressed)
	employees_button.connect("pressed", _on_employees_button_pressed)
	config_button.connect("pressed", _on_config_button_pressed)
	reports_button.connect("pressed", _on_reports_button_pressed)
	
	# Set app info
	var organization_name = "Default Organization"
	if schedule_manager and schedule_manager.current_organization:
		organization_name = schedule_manager.current_organization.name
	
	app_subtitle.text = "Staff Scheduler for " + organization_name
	
	# Update status
	var today = Time.get_datetime_dict_from_system()
	status_label.text = "Today is " + format_date(today) + ". Ready."

func _on_calendar_button_pressed():
	emit_signal("open_calendar")

func _on_employees_button_pressed():
	emit_signal("open_employees")

func _on_config_button_pressed():
	emit_signal("open_configuration")
	
func _on_reports_button_pressed():
	# Future implementation
	status_label.text = "Reports feature coming soon..."

func format_date(date):
	var month_names = ["January", "February", "March", "April", "May", "June", 
					   "July", "August", "September", "October", "November", "December"]
	var day_names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
	
	return day_names[date.weekday] + ", " + month_names[date.month - 1] + " " + str(date.day) + ", " + str(date.year)
