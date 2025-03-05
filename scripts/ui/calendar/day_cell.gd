extends PanelContainer

signal day_clicked(date)
signal shift_clicked(shift)

var date: Dictionary
var shifts = []
var is_other_month: bool = false

# UI References
@onready var day_label = $VBoxContainer/DayLabel
@onready var shifts_container = $VBoxContainer/ScrollContainer/ShiftsContainer
@onready var staffing_indicator = $VBoxContainer/StaffingIndicator
@onready var full_indicator = $VBoxContainer/StaffingIndicator/FullLabel
@onready var short_indicator = $VBoxContainer/StaffingIndicator/ShortLabel

func _ready():
	connect("gui_input", _on_gui_input)
	update_display()

func update_display():
	# Update day number
	if date.has("day"):
		day_label.text = str(date.day)
	
	# Highlight current day
	var today = Time.get_datetime_dict_from_system()
	if TimeUtility.same_date(date, today):
		add_theme_color_override("bg_color", Color(0.8, 0.9, 0.8, 0.3))
	
	# Style for weekends
	if date.has("weekday") and (date.weekday == 0 or date.weekday == 6):  # Sunday or Saturday
		if not TimeUtility.same_date(date, today):
			add_theme_color_override("bg_color", Color(0.95, 0.95, 0.97, 0.5))
	
	# Handle days from other months (for month view)
	if has_meta("other_month") and get_meta("other_month", false):
		is_other_month = true
		day_label.modulate = Color(0.7, 0.7, 0.7)
		add_theme_color_override("bg_color", Color(0.95, 0.95, 0.95, 0.3))
	
	# Default for staffing indicators (will be updated in update_staffing_indicators)
	full_indicator.visible = false
	short_indicator.visible = false

func add_shift(shift):
	shifts.append(shift)
	
	var shift_item_scene = load("res://scenes/ui/calendar/shift_item.tscn")
	var shift_item = shift_item_scene.instantiate()
	shift_item.shift = shift
	shift_item.connect("shift_clicked", _on_shift_item_clicked)
	shifts_container.add_child(shift_item)
	
	update_staffing_indicators()

func update_staffing_indicators():
	# This would be much more complex in a real app, checking against requirements
	# For now, just a simple placeholder implementation
	var filled_count = 0
	var total_count = shifts.size()
	
	for shift in shifts:
		if not shift.assigned_employee_id.is_empty():
			filled_count += 1
	
	# Update indicators
	if total_count > 0:
		if filled_count == total_count:
			full_indicator.visible = true
			short_indicator.visible = false
		else:
			full_indicator.visible = false
			short_indicator.visible = true
	else:
		full_indicator.visible = false
		short_indicator.visible = false

func get_shift_count() -> int:
	return shifts.size()

func get_assigned_shift_count() -> int:
	var count = 0
	for shift in shifts:
		if not shift.assigned_employee_id.is_empty():
			count += 1
	return count

func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Immediately emit the signal with the date
		emit_signal("day_clicked", date)
		
		# Apply visual feedback for selection
		var style: StyleBoxFlat = get_theme_stylebox("panel").duplicate()
		style.bg_color = Color(0.8, 0.9, 0.8, 0.3)
		style.set_border_width_all(2)
		style.border_color = Color(0.3, 0.7, 0.3)
		add_theme_stylebox_override("panel", style)

func _on_shift_item_clicked(shift):
	emit_signal("shift_clicked", shift)
