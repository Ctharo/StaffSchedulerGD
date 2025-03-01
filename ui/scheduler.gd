# ui/schedule/scheduler.gd
class_name Scheduler extends Control

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
	calendar_view.connect("day_selected", _on_day_selected)
	calendar_view.connect("shift_selected", _on_shift_selected)
	generate_shifts_button.connect("
