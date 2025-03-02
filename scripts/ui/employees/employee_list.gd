extends Control

signal employee_selected(employee_id)

var schedule_manager: ScheduleManager
var nav_manager: NavigationManager

# UI References
@onready var navigation_bar = $VBoxContainer/NavigationBar
@onready var search_bar = $VBoxContainer/SearchPanel/HBoxContainer/SearchBar
@onready var classification_filter = $VBoxContainer/SearchPanel/HBoxContainer/ClassificationFilter
@onready var sort_option = $VBoxContainer/SearchPanel/HBoxContainer/SortOption
@onready var employee_list = $VBoxContainer/EmployeeList
@onready var add_button = $VBoxContainer/ButtonsPanel/AddButton

var employees_data = []
var filtered_employees = []

func _ready():
	# Set up navigation bar
	navigation_bar.set_screen_title("Employee Manager")
	navigation_bar.connect("back_pressed", _on_back_button_pressed)
	navigation_bar.connect("home_pressed", _on_home_button_pressed)
	
	# Connect signals
	search_bar.connect("text_changed", _on_search_text_changed)
	classification_filter.connect("item_selected", _on_filter_changed)
	sort_option.connect("item_selected", _on_sort_option_changed)
	employee_list.connect("item_activated", _on_employee_list_item_activated)
	add_button.connect("pressed", _on_add_button_pressed)

func initialize(p_schedule_manager: ScheduleManager, p_nav_manager: NavigationManager):
	schedule_manager = p_schedule_manager
	nav_manager = p_nav_manager
	navigation_bar.initialize(nav_manager)
	
	# Set up classification filter
	_setup_classification_filter()
	
	# Initialize employee list
	load_employees()

func _setup_classification_filter():
	classification_filter.clear()
	classification_filter.add_item("All Classifications")
	classification_filter.set_item_metadata(0, "")
	
	var idx = 1
	for classification in schedule_manager.current_organization.classifications:
		classification_filter.add_item(classification)
		classification_filter.set_item_metadata(idx, classification)
		idx += 1

func load_employees():
	employees_data.clear()
	
	# Get all employees from schedule manager
	for employee_id in schedule_manager.current_schedule.employees:
		var employee = schedule_manager.current_schedule.employees[employee_id]
		employees_data.append({
			"id": employee.id,
			"first_name": employee.first_name,
			"last_name": employee.last_name,
			"classification": employee.classification,
			"status": employee.employment_status,
			"display_name": employee.get_full_name()
		})
	
	# Apply current filters and sort
	apply_filters()

func apply_filters():
	var search_text = search_bar.text.to_lower()
	var selected_classification = ""
	
	if classification_filter.selected > 0:
		selected_classification = classification_filter.get_item_metadata(classification_filter.selected)
	
	# Apply filters
	filtered_employees.clear()
	for employee in employees_data:
		# Apply search filter
		if not search_text.is_empty():
			var name_lower = employee.display_name.to_lower()
			if not search_text in name_lower:
				continue
		
		# Apply classification filter
		if not selected_classification.is_empty() and employee.classification != selected_classification:
			continue
			
		filtered_employees.append(employee)
	
	# Apply sort
	_sort_employees()
	
	# Update list
	_update_employee_list()

func _sort_employees():
	var sort_mode = sort_option.selected
	
	match sort_mode:
		0: # Sort by Last Name
			filtered_employees.sort_custom(func(a, b): return a.last_name < b.last_name)
		1: # Sort by First Name
			filtered_employees.sort_custom(func(a, b): return a.first_name < b.first_name)
		2: # Sort by Classification
			filtered_employees.sort_custom(func(a, b): return a.classification < b.classification)
		3: # Sort by Status
			filtered_employees.sort_custom(func(a, b): return a.status < b.status)

func _update_employee_list():
	employee_list.clear()
	
	for employee in filtered_employees:
		var display_text = employee.display_name + " (" + employee.classification + ")"
		employee_list.add_item(display_text)
		employee_list.set_item_metadata(employee_list.get_item_count() - 1, employee.id)

func _on_search_text_changed(new_text):
	apply_filters()

func _on_filter_changed(_idx):
	apply_filters()

func _on_sort_option_changed(_idx):
	apply_filters()

func _on_employee_list_item_activated(idx):
	var employee_id = employee_list.get_item_metadata(idx)
	emit_signal("employee_selected", employee_id)

func _on_add_button_pressed():
	# Create new empty employee and get its ID
	var new_employee = schedule_manager.create_employee("New", "Employee", "")
	emit_signal("employee_selected", new_employee.id)

func _on_back_button_pressed():
	nav_manager.go_back()

func _on_home_button_pressed():
	nav_manager.navigate_to("landing")
