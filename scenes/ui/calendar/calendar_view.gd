# ui/schedule/calendar_view.gd
class_name CalendarView extends Control

signal shift_selected(shift)
signal day_selected(date)

# Properties
var current_date: Dictionary
var view_mode: String = "week"  # "day", "week", "month"
var schedule_manager: ScheduleManager
var selected_site_id: String = ""
var selected_classification: String = ""

# UI References
@onready var calendar_grid = $CalendarGrid
@onready var month_label = $Header/MonthLabel
@onready var prev_button = $Header/PrevButton
@onready var next_button = $Header/NextButton
@onready var view_mode_option = $Header/ViewModeOption
@onready var site_filter = $Filters/SiteFilter
@onready var classification_filter = $Filters/ClassificationFilter

func _ready():
	connect_signals()
	current_date = Time.get_datetime_dict_from_system()
	update_calendar()
	setup_filters()

func connect_signals():
	prev_button.connect("pressed", _on_prev_button_pressed)
	next_button.connect("pressed", _on_next_button_pressed)
	view_mode_option.connect("item_selected", _on_view_mode_changed)
	site_filter.connect("item_selected", _on_site_filter_changed)
	classification_filter.connect("item_selected", _on_classification_filter_changed)

func update_calendar():
	# Clear existing calendar items
	for child in calendar_grid.get_children():
		child.queue_free()
	
	# Get start and end dates for current view
	var start_date = get_view_start_date()
	var end_date = get_view_end_date()
	
	# Update header label
	month_label.text = get_header_text()
	
	# Create calendar days
	create_calendar_days(start_date, end_date)
	
	# Load shifts for current view
	load_shifts(start_date, end_date)

func create_calendar_days(start_date, end_date):
	# Create day cells based on view_mode
	var current = start_date.duplicate()
	
	while TimeUtility.compare_dates(current, end_date) <= 0:
		var day_cell = load("res://scenes/components/day_cell.tscn").instantiate()
		day_cell.date = current.duplicate()
		day_cell.connect("day_clicked", _on_day_clicked)
		calendar_grid.add_child(day_cell)
		
		current = TimeUtility.add_days_to_date(current, 1)

func load_shifts(start_date, end_date):
	# Get shifts from schedule_manager
	var shifts = []
	
	if selected_site_id.is_empty():
		# Get shifts for all sites
		for site_id in schedule_manager.current_schedule.sites:
			var site_shifts = schedule_manager.current_schedule.get_site_shifts(
				site_id, start_date, end_date)
			shifts.append_array(site_shifts)
	else:
		# Get shifts for selected site
		shifts = schedule_manager.current_schedule.get_site_shifts(
			selected_site_id, start_date, end_date)
	
	# Filter by classification if needed
	if not selected_classification.is_empty():
		var filtered_shifts = []
		for shift in shifts:
			if shift.classification == selected_classification:
				filtered_shifts.append(shift)
		shifts = filtered_shifts
	
	# Add shifts to day cells
	for shift in shifts:
		# Find the day cell for this shift
		for day_cell in calendar_grid.get_children():
			if TimeUtility.same_date(day_cell.date, shift.date):
				day_cell.add_shift(shift)
				break

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

# Event handlers
func _on_prev_button_pressed():
	# Move to previous week/month
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
			var days_in_month = TimeUtility.days_in_month(current_date.year, current_date.month)
			if current_date.day > days_in_month:
				current_date.day = days_in_month
	
	update_calendar()

func _on_next_button_pressed():
	# Move to next week/month
	# Similar logic to prev button but adding days instead
	# ...

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
	emit_signal("day_selected", date)

# Helper methods
func get_view_start_date():
	match view_mode:
		"day":
			return current_date.duplicate()
		"week":
			return TimeUtility.get_week_start_date(current_date)
		"month":
			var start = current_date.duplicate()
			start.day = 1
			return start
	
	return current_date.duplicate()

func get_view_end_date():
	match view_mode:
		"day":
			return current_date.duplicate()
		"week":
			var start = TimeUtility.get_week_start_date(current_date)
			return TimeUtility.add_days_to_date(start, 6)
		"month":
			var end = current_date.duplicate()
			end.day = TimeUtility.days_in_month(end.year, end.month)
			return end
	
	return current_date.duplicate()

func get_header_text():
	match view_mode:
		"day":
			return "%s, %d %s %d" % [
				get_weekday_name(current_date.weekday),
				current_date.day,
				get_month_name(current_date.month),
				current_date.year
			]
		"week":
			var start = get_view_start_date()
			var end = get_view_end_date()
			return "%d %s - %d %s %d" % [
				start.day,
				get_month_name(start.month),
				end.day,
				get_month_name(end.month),
				end.year
			]
		"month":
			return "%s %d" % [
				get_month_name(current_date.month),
				current_date.year
			]
	
	return ""

func get_month_name(month):
	var names = ["January", "February", "March", "April", "May", "June", 
				"July", "August", "September", "October", "November", "December"]
	return names[month - 1]

func get_weekday_name(weekday):
	var names = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
	return names[weekday]
