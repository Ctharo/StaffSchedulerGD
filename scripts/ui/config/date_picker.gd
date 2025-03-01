extends HBoxContainer

signal date_selected(date)

@export var selected_date: String = ""  # Format: YYYY-MM-DD

# UI References
@onready var year_spin = $YearSpin
@onready var month_option = $MonthOption
@onready var day_spin = $DaySpin

func _ready():
	setup_month_dropdown()
	
	# Connect signals
	year_spin.connect("value_changed", _on_date_part_changed)
	month_option.connect("item_selected", _on_date_part_changed)
	day_spin.connect("value_changed", _on_date_part_changed)
	
	# Set initial date
	if selected_date.is_empty():
		var now = Time.get_datetime_dict_from_system()
		year_spin.value = now.year
		month_option.select(now.month - 1)  # 0-based index
		day_spin.value = now.day
	else:
		var parts = selected_date.split("-")
		if parts.size() == 3:
			year_spin.value = int(parts[0])
			month_option.select(int(parts[1]) - 1)  # 0-based index
			day_spin.value = int(parts[2])
	
	_update_day_limits()

func setup_month_dropdown():
	month_option.clear()
	
	var month_names = ["January", "February", "March", "April", "May", "June", 
					   "July", "August", "September", "October", "November", "December"]
	
	for i in range(12):
		month_option.add_item(month_names[i])
		month_option.set_item_metadata(i, i + 1)  # Store 1-based month number

func _on_date_part_changed(_value):
	_update_day_limits()
	
	var year = year_spin.value
	var month = month_option.get_item_metadata(month_option.get_selected_id())
	var day = day_spin.value
	
	selected_date = "%04d-%02d-%02d" % [year, month, day]
	emit_signal("date_selected", selected_date)

func _update_day_limits():
	var year = year_spin.value
	var month = month_option.get_item_metadata(month_option.get_selected_id())
	
	# Calculate days in month
	var days_in_month = TimeUtility.days_in_month(year, month)
	
	# Update day spinner
	day_spin.max_value = days_in_month
	
	# Clamp current day if needed
	if day_spin.value > days_in_month:
		day_spin.value = days_in_month
