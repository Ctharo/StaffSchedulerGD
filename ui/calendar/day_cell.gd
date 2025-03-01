# ui/schedule/day_cell.gd
class_name DayCell extends PanelContainer

signal day_clicked(date)
signal shift_clicked(shift)

var date: Dictionary
var shifts = []

# UI References
@onready var day_label = $VBoxContainer/DayLabel
@onready var shifts_container = $VBoxContainer/ScrollContainer/ShiftsContainer
@onready var staffing_indicator = $VBoxContainer/StaffingIndicator

func _ready():
	connect("gui_input", _on_gui_input)
	update_display()

func update_display():
	day_label.text = str(date.day)
	
	# Highlight current day
	var today = Time.get_datetime_dict_from_system()
	if TimeUtility.same_date(date, today):
		add_theme_color_override("bg_color", Color(0.8, 0.9, 0.8))
	
	# Color weekends differently
	if date.weekday == 0 or date.weekday == 6:  # Sunday or Saturday
		if not TimeUtility.same_date(date, today):
			add_theme_color_override("bg_color", Color(0.95, 0.95, 0.95))

func add_shift(shift):
	shifts.append(shift)
	
	var shift_item = load("res://scenes/components/shift_item.tscn").instantiate()
	shift_item.shift = shift
	shift_item.connect("shift_clicked", _on_shift_clicked)
	shifts_container.add_child(shift_item)
	
	update_staffing_indicator()

func update_staffing_indicator():
	# Check staffing levels against requirements
	# Change indicator color based on under/over staffing
	# This could query the schedule manager for staffing requirements
	# ...
	pass

func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("day_clicked", date)

func _on_shift_clicked(shift):
	emit_signal("shift_clicked", shift)
