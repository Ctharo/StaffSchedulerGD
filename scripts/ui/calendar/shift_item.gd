extends PanelContainer

signal shift_clicked(shift)

var shift: Shift

# UI References
@onready var classification_label = $HBoxContainer/ClassificationLabel
@onready var time_label = $HBoxContainer/VBoxContainer/TimeLabel
@onready var name_label = $HBoxContainer/VBoxContainer/NameLabel
@onready var status_label = $HBoxContainer/StatusLabel

func _ready():
	connect("gui_input", _on_gui_input)
	update_display()

func update_display():
	if shift == null:
		return
	
	# Set classification
	classification_label.text = shift.classification
	
	# Set time range
	var start_time_display = shift.start_time.substr(0, 5)  # Just HH:MM
	var end_time_display = shift.end_time.substr(0, 5)      # Just HH:MM
	time_label.text = start_time_display + "-" + end_time_display
	
	# Set employee name if assigned
	if not shift.assigned_employee_id.is_empty():
		var employee_name = get_employee_display_name(shift.assigned_employee_id)
		name_label.text = employee_name
	else:
		name_label.text = "Unassigned"
		name_label.add_theme_color_override("font_color", Color(0.7, 0.3, 0.3))
	
	# Set status and color coding
	update_status_display()

func update_status_display():
	# Set status indicators
	status_label.text = ""
	
	# Create a stylebox duplicate for this shift
	var style = get_theme_stylebox("panel").duplicate()
	add_theme_stylebox_override("panel", style)
	
	# Set colors and status indicators based on shift properties
	if shift.is_overtime:
		status_label.text = "OT"
		status_label.add_theme_color_override("font_color", Color(0.8, 0.3, 0.3))
	elif shift.is_split_shift:
		status_label.text = "SP"
		status_label.add_theme_color_override("font_color", Color(0.3, 0.5, 0.8))
	
	# Change background color based on shift status and type
	if shift.status == "open":
		# Open shifts are light red/pink
		style.bg_color = Color(1.0, 0.9, 0.9)
		style.border_color = Color(0.9, 0.7, 0.7)
	elif shift.is_pattern_shift:
		if shift.assigned_employee_id.is_empty():
			# Unassigned pattern shifts are light yellow
			style.bg_color = Color(1.0, 1.0, 0.9)
			style.border_color = Color(0.9, 0.9, 0.7)
		else:
			# Assigned pattern shifts are light blue
			style.bg_color = Color(0.9, 0.95, 1.0)
			style.border_color = Color(0.7, 0.8, 0.9)
	elif not shift.is_pattern_shift:
		# Coverage shifts are light green
		style.bg_color = Color(0.9, 1.0, 0.9)
		style.border_color = Color(0.7, 0.9, 0.7)
	
	# Hover effect
	mouse_entered.connect(func(): _on_mouse_entered(style))
	mouse_exited.connect(func(): _on_mouse_exited(style))

func _on_mouse_entered(style):
	# Darken the background slightly on hover
	style.bg_color = style.bg_color.darkened(0.1)
	
func _on_mouse_exited(style):
	# Restore the original background color
	style.bg_color = style.bg_color.lightened(0.1)

func get_employee_display_name(employee_id: String) -> String:
	# Access the schedule manager to get the employee name
	var schedule = get_schedule()
	if schedule and schedule.employees.has(employee_id):
		var employee = schedule.employees[employee_id]
		return employee.last_name + ", " + employee.first_name.substr(0, 1) + "."
	
	return "Unknown"

func get_schedule() -> Schedule:
	# Try to find the schedule in the scene tree
	var parent = get_parent()
	while parent:
		if parent.has_method("get_schedule"):
			return parent.get_schedule()
		
		# Try to access via schedule_manager
		if parent.has_method("get_node") and parent.get_node_or_null("/root/Main/ScheduleManager"):
			var schedule_manager = parent.get_node("/root/Main/ScheduleManager")
			return schedule_manager.current_schedule
			
		parent = parent.get_parent()
	
	# As a fallback, try to get the schedule from the global ScheduleManager
	if Engine.has_singleton("ScheduleManager"):
		var schedule_manager = Engine.get_singleton("ScheduleManager")
		return schedule_manager.current_schedule
	
	return null

func _on_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		emit_signal("shift_clicked", shift)
