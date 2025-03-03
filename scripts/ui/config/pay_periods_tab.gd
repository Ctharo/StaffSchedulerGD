extends VBoxContainer

signal config_saved(section_name)

var schedule_manager: ScheduleManager

# UI References
@onready var pay_period_type_option = %TypeOption
@onready var start_day_option = %StartDayOption
@onready var start_date_picker = %StartDatePicker
@onready var periods_list = %PeriodsList
@onready var regenerate_button = %RegenerateButton
@onready var save_button = %SaveButton

func init(manager: ScheduleManager):
	schedule_manager = manager
	setup_type_dropdown()
	setup_day_dropdown()
	load_current_config()
	load_periods_list()
	
	# Connect signals
	pay_period_type_option.connect("item_selected", _on_period_type_changed)
	start_day_option.connect("item_selected", _on_start_day_changed)
	regenerate_button.connect("pressed", _on_regenerate_button_pressed)
	save_button.connect("pressed", _on_save_button_pressed)

func setup_type_dropdown():
	pay_period_type_option.clear()
	
	pay_period_type_option.add_item("Weekly")
	pay_period_type_option.set_item_metadata(0, "weekly")
	
	pay_period_type_option.add_item("Biweekly")
	pay_period_type_option.set_item_metadata(1, "biweekly")
	
	pay_period_type_option.add_item("Semimonthly")
	pay_period_type_option.set_item_metadata(2, "semimonthly")
	
	pay_period_type_option.add_item("Monthly")
	pay_period_type_option.set_item_metadata(3, "monthly")

func setup_day_dropdown():
	start_day_option.clear()
	
	start_day_option.add_item("Sunday")
	start_day_option.set_item_metadata(0, 0)
	
	start_day_option.add_item("Monday")
	start_day_option.set_item_metadata(1, 1)
	
	start_day_option.add_item("Tuesday")
	start_day_option.set_item_metadata(2, 2)
	
	start_day_option.add_item("Wednesday")
	start_day_option.set_item_metadata(3, 3)
	
	start_day_option.add_item("Thursday")
	start_day_option.set_item_metadata(4, 4)
	
	start_day_option.add_item("Friday")
	start_day_option.set_item_metadata(5, 5)
	
	start_day_option.add_item("Saturday")
	start_day_option.set_item_metadata(6, 6)

func load_current_config():
	var organization = schedule_manager.current_organization
	
	# Set current pay period type
	var type_idx = -1
	for i in range(pay_period_type_option.get_item_count()):
		if pay_period_type_option.get_item_metadata(i) == organization.pay_period_type:
			type_idx = i
			break
	
	if type_idx >= 0:
		pay_period_type_option.select(type_idx)
	else:
		pay_period_type_option.select(1)  # Default to biweekly
	
	# Set current start day
	var day_idx = -1
	for i in range(start_day_option.get_item_count()):
		if start_day_option.get_item_metadata(i) == organization.pay_period_start_day:
			day_idx = i
			break
	
	if day_idx >= 0:
		start_day_option.select(day_idx)
	else:
		start_day_option.select(0)  # Default to Sunday
	
	# Set current start date if available
	if not organization.pay_period_start_date.is_empty():
		# Convert organization date to DatePicker format
		var date = organization.pay_period_start_date
		start_date_picker.selected_date = "%04d-%02d-%02d" % [date.year, date.month, date.day]
	else:
		# Use current date
		var now = Time.get_datetime_dict_from_system()
		start_date_picker.selected_date = "%04d-%02d-%02d" % [now.year, now.month, now.day]
	
	# Disable start day for semimonthly and monthly
	var current_type = pay_period_type_option.get_item_metadata(pay_period_type_option.get_selected_id())
	start_day_option.disabled = current_type == "semimonthly" or current_type == "monthly"

func load_periods_list():
	periods_list.clear()
	
	# Add each pay period to the list
	for period_id in schedule_manager.current_schedule.pay_periods:
		var period = schedule_manager.current_schedule.pay_periods[period_id]
		
		var start_date_str = "%04d-%02d-%02d" % [period.start_date.year, period.start_date.month, period.start_date.day]
		var end_date_str = "%04d-%02d-%02d" % [period.end_date.year, period.end_date.month, period.end_date.day]
		
		periods_list.add_item(start_date_str + " to " + end_date_str + " (" + period.status + ")")
	
	# Disable regenerate button if no periods
	regenerate_button.disabled = periods_list.get_item_count() == 0

func _on_period_type_changed(idx):
	var period_type = pay_period_type_option.get_item_metadata(idx)
	
	# Disable start day for semimonthly and monthly
	start_day_option.disabled = period_type == "semimonthly" or period_type == "monthly"

func _on_start_day_changed(_idx):
	# Nothing to do here, just record in save
	pass

func _on_regenerate_button_pressed():
	# Create confirmation dialog
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "This will regenerate all pay periods based on your new settings. This may affect existing shifts and overtime calculations. Continue?"
	confirm_dialog.get_ok_button().connect("pressed", _confirm_regenerate_periods)
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func _confirm_regenerate_periods():
	# Save settings first
	_on_save_button_pressed()
	
	# Clear existing pay periods
	schedule_manager.current_schedule.pay_periods.clear()
	
	# Create new pay periods
	schedule_manager.initialize_pay_periods()
	
	# Reload periods list
	load_periods_list()
	
	emit_signal("config_saved", "Pay periods regenerated")

func _on_save_button_pressed():
	var organization = schedule_manager.current_organization
	
	# Update pay period settings
	organization.pay_period_type = pay_period_type_option.get_item_metadata(pay_period_type_option.get_selected_id())
	organization.pay_period_start_day = start_day_option.get_item_metadata(start_day_option.get_selected_id())
	
	# Parse selected date
	var date_parts = start_date_picker.selected_date.split("-")
	if date_parts.size() == 3:
		organization.pay_period_start_date = {
			"year": int(date_parts[0]),
			"month": int(date_parts[1]),
			"day": int(date_parts[2]),
			"hour": 0,
			"minute": 0,
			"second": 0
		}
	
	# Save organization settings
	schedule_manager.save_organization()
	
	emit_signal("config_saved", "Pay period settings")

func get_config_data():
	var organization = schedule_manager.current_organization
	
	return {
		"pay_period_type": organization.pay_period_type,
		"pay_period_start_day": organization.pay_period_start_day,
		"pay_period_start_date": organization.pay_period_start_date
	}

func import_config_data(data):
	if data is Dictionary:
		var organization = schedule_manager.current_organization
		
		if data.has("pay_period_type"):
			organization.pay_period_type = data.pay_period_type
		
		if data.has("pay_period_start_day"):
			organization.pay_period_start_day = data.pay_period_start_day
		
		if data.has("pay_period_start_date"):
			organization.pay_period_start_date = data.pay_period_start_date
		
		schedule_manager.save_organization()
		
		# Reload config
		load_current_config()
		
		# Ask if user wants to regenerate pay periods
		var confirm_dialog = ConfirmationDialog.new()
		confirm_dialog.dialog_text = "Do you want to regenerate pay periods based on these imported settings?"
		confirm_dialog.get_ok_button().connect("pressed", _confirm_regenerate_periods)
		add_child(confirm_dialog)
		confirm_dialog.popup_centered()
