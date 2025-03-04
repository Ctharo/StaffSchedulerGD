extends Control

signal send_message(msg: String, duration: float)
signal shift_selected(shift)
signal day_selected(date)

# Properties
var current_date: Dictionary
var view_mode: String = "week"  # "day", "week", "month"
var schedule_manager: ScheduleManager
var nav_manager: NavigationManager
var selected_site_id: String = ""
var selected_classification: String = ""

# UI References using unique names
@onready var navigation_bar = %NavigationBar
@onready var calendar_grid = %CalendarGrid
@onready var month_label = %MonthLabel
@onready var prev_button = %PrevButton
@onready var next_button = %NextButton
@onready var today_button = %TodayButton
@onready var view_mode_option = %ViewModeOption
@onready var site_filter = %SiteFilter
@onready var classification_filter = %ClassificationFilter
@onready var status_label = %StatusLabel

func _ready():
	# Initialize date
	current_date = Time.get_datetime_dict_from_system()
		
	# Set up keyboard shortcuts
	set_process_input(true)

func _input(event):
	# Keyboard shortcuts for calendar navigation
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_LEFT:
				# Previous day/week/month
				_on_prev_button_pressed()
				accept_event()
			KEY_RIGHT:
				# Next day/week/month
				_on_next_button_pressed()
				accept_event()
			KEY_UP:
				# Change view mode (zoom out)
				var idx = view_mode_option.selected
				if idx > 0:
					view_mode_option.select(idx - 1)
					_on_view_mode_changed(idx - 1)
				accept_event()
			KEY_DOWN:
				# Change view mode (zoom in)
				var idx = view_mode_option.selected
				if idx < view_mode_option.item_count - 1:
					view_mode_option.select(idx + 1)
					_on_view_mode_changed(idx + 1)
				accept_event()
			KEY_HOME:
				# Today
				_on_today_button_pressed()
				accept_event()

func post_initialize():
	# Initialize navigation bar
	if nav_manager:
		navigation_bar.initialize(nav_manager)
		navigation_bar.set_screen_title("Schedule Calendar")
	
	# Setup filters
	setup_filters()
	
	# Update calendar view
	update_calendar()

func initialize(p_schedule_manager: ScheduleManager, p_nav_manager: NavigationManager):
	schedule_manager = p_schedule_manager
	nav_manager = p_nav_manager
	
	# Complete initialization
	post_initialize()



func setup_filters():
	# Set up site filter
	site_filter.clear()
	site_filter.add_item("All Sites")
	site_filter.set_item_metadata(0, "")
	
	var idx = 1
	for site_id in schedule_manager.current_schedule.sites:
		var site = schedule_manager.current_schedule.sites[site_id]
		site_filter.add_item(site.name)
		site_filter.set_item_metadata(idx, site.id)
		idx += 1
	
	# Set up classification filter
	classification_filter.clear()
	classification_filter.add_item("All Classifications")
	classification_filter.set_item_metadata(0, "")
	
	idx = 1
	for classification in schedule_manager.current_organization.classifications:
		classification_filter.add_item(classification)
		classification_filter.set_item_metadata(idx, classification)
		idx += 1

func update_calendar():
	# Clear existing calendar cells
	for child in calendar_grid.get_children():
		child.queue_free()
	
	# Get start and end dates for current view
	var start_date = get_view_start_date()
	var end_date = get_view_end_date()
	
	# Update header text
	update_header_text()
	
	# Create calendar grid
	create_calendar_grid(start_date, end_date)
	
	# Load shifts for the current view
	load_shifts(start_date, end_date)
	
	# Update status
	update_status_message()

	if view_mode == "day":
		# In day view, the current_date is the selected date
		_update_selected_day_visual(current_date)
	else:
		# In week or month view, highlight today by default
		var today = Time.get_datetime_dict_from_system()
		_update_selected_day_visual(today)

func create_calendar_grid(start_date: Dictionary, end_date: Dictionary):
	var day_cell_scene = load("res://scenes/ui/calendar/day_cell.tscn")
	
	match view_mode:
		"day":
			# Single day view
			var day_cell = day_cell_scene.instantiate()
			day_cell.date = current_date.duplicate()
			day_cell.connect("day_clicked", _on_day_clicked)
			day_cell.connect("shift_clicked", _on_shift_clicked)
			calendar_grid.add_child(day_cell)
			
		"week":
			# Week view (7 days)
			var current = start_date.duplicate()
			for _i in range(7):
				var day_cell = day_cell_scene.instantiate()
				day_cell.date = current.duplicate()
				day_cell.connect("day_clicked", _on_day_clicked)
				day_cell.connect("shift_clicked", _on_shift_clicked)
				calendar_grid.add_child(day_cell)
				
				current = TimeUtility.add_days_to_date(current, 1)
				
		"month":
			# Month view (up to 6 weeks)
			var current = start_date.duplicate()
			
			# First, determine how many weeks we need to display (4-6 depending on month)
			var weeks_needed = 0
			var temp_date = current.duplicate()
			
			while TimeUtility.compare_dates(temp_date, end_date) <= 0:
				weeks_needed += 1
				temp_date = TimeUtility.add_days_to_date(temp_date, 7)
			
			# Now create the calendar grid
			for _week in range(weeks_needed):
				for _day in range(7):
					var day_cell = day_cell_scene.instantiate()
					day_cell.date = current.duplicate()
					
					# Gray out days from other months
					if current.month != current_date.month:
						day_cell.set_meta("other_month", true)
					
					day_cell.connect("day_clicked", _on_day_clicked)
					day_cell.connect("shift_clicked", _on_shift_clicked)
					calendar_grid.add_child(day_cell)
					
					current = TimeUtility.add_days_to_date(current, 1)

func load_shifts(start_date: Dictionary, end_date: Dictionary):
	if not schedule_manager:
		return
	
	# Get shifts from schedule manager based on filters
	var all_shifts = []
	
	# Filter by site if specified
	if selected_site_id.is_empty():
		# Get shifts for all sites
		for site_id in schedule_manager.current_schedule.sites:
			var site_shifts = schedule_manager.current_schedule.get_site_shifts(
				site_id, start_date, end_date)
			all_shifts.append_array(site_shifts)
	else:
		# Get shifts for selected site
		all_shifts = schedule_manager.current_schedule.get_site_shifts(
			selected_site_id, start_date, end_date)
	
	# Filter by classification if needed
	if not selected_classification.is_empty():
		var filtered_shifts = []
		for shift in all_shifts:
			if shift.classification == selected_classification:
				filtered_shifts.append(shift)
		all_shifts = filtered_shifts
	
	# Add shifts to appropriate day cells
	for shift in all_shifts:
		# Find the day cell for this shift
		for day_cell in calendar_grid.get_children():
			if TimeUtility.same_date(day_cell.date, shift.date):
				day_cell.add_shift(shift)
				break

func get_view_start_date() -> Dictionary:
	match view_mode:
		"day":
			return current_date.duplicate()
			
		"week":
			# Get the Sunday at or before the current date
			return TimeUtility.get_week_start_date(current_date)
			
		"month":
			# Get the first day of the month
			var start = current_date.duplicate()
			start.day = 1
			
			# If the first day isn't a Sunday, go back to the previous Sunday
			return TimeUtility.get_week_start_date(start)
	
	return current_date.duplicate()

func get_view_end_date() -> Dictionary:
	match view_mode:
		"day":
			return current_date.duplicate()
			
		"week":
			# Get Saturday at the end of the week
			var start = get_view_start_date()
			return TimeUtility.add_days_to_date(start, 6)
			
		"month":
			# Get the last day of the month
			var end = current_date.duplicate()
			end.day = TimeUtility.days_in_month(end.year, end.month)
			
			# If the last day isn't a Saturday, go forward to the next Saturday
			var weekday = end.weekday
			var days_to_add = 6 - weekday  # Days to get to Saturday
			
			return TimeUtility.add_days_to_date(end, days_to_add)
	
	return current_date.duplicate()

func update_header_text():
	var month_names = ["January", "February", "March", "April", "May", "June", 
					"July", "August", "September", "October", "November", "December"]
	
	match view_mode:
		"day":
			var weekday_names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
			month_label.text = "%s, %s %d, %d" % [
				weekday_names[current_date.weekday],
				month_names[current_date.month - 1],
				current_date.day,
				current_date.year
			]
			
		"week":
			var start_date = get_view_start_date()
			var end_date = get_view_end_date()
			
			if start_date.month == end_date.month:
				# Same month
				month_label.text = "%s %d - %d, %d" % [
					month_names[start_date.month - 1],
					start_date.day,
					end_date.day,
					start_date.year
				]
			else:
				# Different months
				month_label.text = "%s %d - %s %d, %d" % [
					month_names[start_date.month - 1],
					start_date.day,
					month_names[end_date.month - 1],
					end_date.day,
					end_date.year
				]
			
		"month":
			month_label.text = "%s %d" % [month_names[current_date.month - 1], current_date.year]

func update_status_message():
	# Get counts for loaded shifts
	var shift_count = 0
	var assigned_count = 0
	
	for day_cell in calendar_grid.get_children():
		if day_cell.has_method("get_shift_count"):
			shift_count += day_cell.get_shift_count()
			assigned_count += day_cell.get_assigned_shift_count()
	
	set_msg("Loaded %d shifts (%d assigned, %d open)" % [
		shift_count, 
		assigned_count, 
		shift_count - assigned_count
	])

# Event handlers
func _on_prev_button_pressed():
	match view_mode:
		"day":
			current_date = TimeUtility.add_days_to_date(current_date, -1)
		"week":
			current_date = TimeUtility.add_days_to_date(current_date, -7)
		"month":
			if current_date.month > 1:
				current_date.month -= 1
			else:
				current_date.month = 12
				current_date.year -= 1
			# Keep day within valid range for new month
			var max_days = TimeUtility.days_in_month(current_date.year, current_date.month)
			if current_date.day > max_days:
				current_date.day = max_days
	
	update_calendar()

func _on_next_button_pressed():
	match view_mode:
		"day":
			current_date = TimeUtility.add_days_to_date(current_date, 1)
		"week":
			current_date = TimeUtility.add_days_to_date(current_date, 7)
		"month":
			if current_date.month < 12:
				current_date.month += 1
			else:
				current_date.month = 1
				current_date.year += 1
			# Keep day within valid range for new month
			var max_days = TimeUtility.days_in_month(current_date.year, current_date.month)
			if current_date.day > max_days:
				current_date.day = max_days
	
	update_calendar()

func _on_today_button_pressed():
	current_date = Time.get_datetime_dict_from_system()
	update_calendar()

func _on_view_mode_changed(index):
	view_mode = view_mode_option.get_item_metadata(index)
	update_calendar()

func _on_site_filter_changed(index):
	selected_site_id = site_filter.get_item_metadata(index)
	update_calendar()

func _on_classification_filter_changed(index):
	selected_classification = classification_filter.get_item_metadata(index)
	update_calendar()

func _on_day_clicked(date):
	# First emit the signal so other components can react
	emit_signal("day_selected", date)
	
	# Store the selection
	var previously_selected_date = current_date.duplicate()
	current_date = date.duplicate()
	
	# If we're in month or week view, optionally switch to day view
	if view_mode != "day":
		view_mode = "day"
		view_mode_option.select(0)  # Assuming 0 is the index for "day" in the option button
		update_calendar()
	else:
		# If already in day view, just highlight the selected day
		_update_selected_day_visual(date)
	
	# Update status message
	set_msg("Selected date: %04d-%02d-%02d" % [date.year, date.month, date.day])
	
	# On right-click, show context menu for adding shifts
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		show_add_shift_menu(date)

func _update_selected_day_visual(selected_date):
	# Clear previous selection visual on all cells
	for day_cell in calendar_grid.get_children():
		day_cell.update_display()  # Reset to default style
	
	# Find the day cell that matches the selected date and highlight it
	for day_cell in calendar_grid.get_children():
		if TimeUtility.same_date(day_cell.date, selected_date):
			var style = StyleBoxFlat.new()
			style.bg_color = Color(0.8, 0.9, 0.8, 0.3)
			style.set_border_width_all(2)
			style.border_color = Color(0.3, 0.7, 0.3)
			day_cell.add_theme_stylebox_override("panel", style)
			break


func _on_shift_clicked(shift):
	emit_signal("shift_selected", shift)
	# Show shift assignment dialog
	show_shift_assignment_dialog(shift)

func show_shift_assignment_dialog(shift):
	var dialog_scene = load("res://scenes/ui/schedule/shift_assignment_dialog.tscn")
	var dialog = dialog_scene.instantiate()
	
	# Initialize dialog with the shift and schedule manager
	dialog.schedule_manager = schedule_manager
	dialog.initialize(shift)
	
	# Connect to dialog signals
	dialog.connect("assignment_completed", _on_shift_assignment_completed)
	
	# Add to the scene and show
	add_child(dialog)
	dialog.popup_centered()

func _on_shift_assignment_completed(shift_id, employee_id):
	# Refresh the calendar to show the updated assignment
	update_calendar()
	
	# Show a status message
	if not employee_id.is_empty():
		var employee_name = "Unknown"
		if schedule_manager.current_schedule.employees.has(employee_id):
			employee_name = schedule_manager.current_schedule.employees[employee_id].get_full_name()
		
		set_msg("Shift assigned to %s" % employee_name)
	else:
		set_msg("Shift offering created")

func show_add_shift_menu(date):
	# Create popup menu for adding a new shift
	var popup = PopupMenu.new()
	
	# Add options for each classification
	var idx = 0
	for classification in schedule_manager.current_organization.classifications:
		popup.add_item("Add " + classification + " Shift", idx)
		idx += 1
	
	# Add separator and additional options
	popup.add_separator()
	popup.add_item("Add Multiple Shifts...", 100)
	
	# Connect to signal
	popup.id_pressed.connect(func(id): _on_add_shift_menu_selected(id, date))
	
	# Show popup at mouse position
	add_child(popup)
	popup.position = get_global_mouse_position()
	popup.popup()

func _on_add_shift_menu_selected(id, date):
	if id < 100:
		# Add a single shift for the selected classification
		var classification = schedule_manager.current_organization.classifications[id]
		
		# Default shift times (could be made configurable)
		var start_time = "07:00"
		var end_time = "19:00"
		
		# Get site ID (use first site if none selected)
		var site_id = selected_site_id
		if site_id.is_empty() and not schedule_manager.current_schedule.sites.is_empty():
			site_id = schedule_manager.current_schedule.sites.keys()[0]
		
		# Create the shift
		var new_shift = schedule_manager.create_shift(
			site_id, classification, date, start_time, end_time)
		
		# Update the calendar
		update_calendar()
		
		# Show status message
		set_msg("Created new %s shift on %04d-%02d-%02d" % [
			classification, date.year, date.month, date.day
		])
	else:
		# This would open a more complex shift creation dialog
		set_msg("Multi-shift creation not implemented yet")


func _on_navigation_bar_home_pressed() -> void:
	nav_manager.go_home()

func _on_navigation_bar_back_pressed() -> void:
	nav_manager.go_back()

func set_msg(msg: String, delay: float = 3.0):
	send_message.emit(msg, delay)
