extends Node
var schedule_manager: ScheduleManager

# UI References
@onready var calendar_view = $VBoxContainer/CalendarView
@onready var status_label = $VBoxContainer/StatusBar/StatusLabel
@onready var generate_shifts_button = $VBoxContainer/Toolbar/GenerateShiftsButton
@onready var export_button = $VBoxContainer/Toolbar/ExportButton

func _ready():
	connect_signals()
	
	# Set schedule manager reference for child components
	calendar_view.schedule_manager = schedule_manager

func connect_signals():
	pass
