extends Control

signal loading_complete
signal setup_organization
signal setup_sites
signal setup_employees

@onready var progress_bar = %ProgressBar
@onready var status_label = %StatusLabel
@onready var error_container = %ErrorContainer
@onready var error_list = %ErrorList
@onready var continue_button = %ContinueButton
@onready var button_progress = %ProgressArc
@onready var actions_container = %ActionsContainer

var total_steps = 4
var current_step = 0
var errors = []
var auto_continue_time = 5.0  # Seconds to wait before auto-continuing
var tween: Tween
var text_tween: Tween
var setup_required = false

# Setup flags
var has_organization = false
var has_sites = false
var has_employees = false

func _ready():
	# Initialize UI state
	progress_bar.value = 0
	progress_bar.max_value = total_steps
	status_label.text = "Starting up..."
	error_container.visible = false
	continue_button.visible = false
	actions_container.visible = false
	
	# Connect button signals
	continue_button.pressed.connect(_on_continue_pressed)
	
	# Initialize button progress arc
	if button_progress:
		button_progress.value = 100
		button_progress.visible = false

func update_progress(message: String):
	current_step += 1
	progress_bar.value = current_step
	status_label.text = message
	
	# If we're done, show appropriate UI
	if current_step >= total_steps:
		if errors.is_empty() and not setup_required:
			status_label.text = "Loading complete!"
			# Short countdown for no errors
			auto_continue_time = 3.0
			show_continue_button()
		elif setup_required:
			status_label.text = "Setup required!"
			show_setup_actions()
		else:
			status_label.text = "Loading complete with issues."
			error_container.visible = true
			show_error_actions()
			# Longer countdown when there are warnings
			auto_continue_time = 10.0
			show_continue_button()

func show_continue_button():
	continue_button.visible = true
	button_progress.visible = true
	
	# Clean up any existing tweens
	_cleanup_tweens()
	
	# Start the countdown tween
	tween = create_tween()
	tween.tween_property(button_progress, "value", 0, auto_continue_time)
	tween.tween_callback(_on_continue_pressed)
	
	# Set up a parallel tween for text updates
	text_tween = create_tween()
	for i in range(int(auto_continue_time), 0, -1):
		text_tween.tween_callback(func(): continue_button.text = "Continue (" + str(i) + ")") 
		text_tween.tween_interval(1.0)

func _cleanup_tweens():
	if tween:
		if tween.is_valid():
			tween.kill()
		tween = null
		
	if text_tween:
		if text_tween.is_valid():
			text_tween.kill()
		text_tween = null

func show_setup_actions():
	actions_container.visible = true
	
	# Clear existing action buttons
	for child in actions_container.get_children():
		if child != actions_container.get_child(0):  # Keep the header label
			child.queue_free()
	
	# Add action buttons based on what's missing
	if not has_organization:
		_add_setup_action_button(
			"Setup Organization", 
			"Create the basic organization information",
			_on_setup_organization_pressed
		)
	elif not has_sites:
		_add_setup_action_button(
			"Setup Sites", 
			"Add work sites for your organization",
			_on_setup_sites_pressed
		)
	elif not has_employees:
		_add_setup_action_button(
			"Setup Employees", 
			"Add staff members to your organization",
			_on_setup_employees_pressed
		)

func show_error_actions():
	actions_container.visible = true
	
	# Clear existing action buttons
	for child in actions_container.get_children():
		if child != actions_container.get_child(0):  # Keep the header label
			child.queue_free()
	
	# Add specific action buttons based on error types
	var added_fix_button = false
	for error in errors:
		if "classification" in error.to_lower():
			_add_setup_action_button(
				"Fix Classifications", 
				"Setup default classifications",
				_on_fix_classifications_pressed
			)
			added_fix_button = true
			break
	
	# If no specific fixes are available, provide a generic continue option
	if not added_fix_button and errors.size() > 0:
		_add_setup_action_button(
			"Continue Anyway", 
			"Proceed with current configuration",
			_on_continue_pressed
		)

func add_error(error_message: String):
	errors.append(error_message)
	error_list.add_item(error_message)

func set_setup_flags(p_has_organization: bool, p_has_sites: bool, p_has_employees: bool):
	has_organization = p_has_organization
	has_sites = p_has_sites
	has_employees = p_has_employees
	
	# Determine if any setup is required
	setup_required = not (has_organization and has_sites and has_employees)

func _add_setup_action_button(text: String, description: String, callback: Callable):
	var hbox = HBoxContainer.new()
	actions_container.add_child(hbox)
	
	var button = Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(200, 40)
	button.connect("pressed", callback)
	hbox.add_child(button)
	
	var desc_label = Label.new()
	desc_label.text = description
	desc_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hbox.add_child(desc_label)
	
	# Add button animations
	button.mouse_entered.connect(func(): _on_button_mouse_entered(button))
	button.mouse_exited.connect(func(): _on_button_mouse_exited(button))
	button.button_down.connect(func(): _on_button_pressed(button))
	button.button_up.connect(func(): _on_button_released(button))

func _on_continue_pressed():
	_cleanup_tweens()
	emit_signal("loading_complete")

func _on_setup_organization_pressed():
	_cleanup_tweens()
	emit_signal("setup_organization")

func _on_setup_sites_pressed():
	_cleanup_tweens()
	emit_signal("setup_sites")

func _on_setup_employees_pressed():
	_cleanup_tweens()
	emit_signal("setup_employees")

func _on_fix_classifications_pressed():
	# Add default classifications from organization's industry type
	var organization = get_node("/root/Main/ScheduleManager").current_organization
	organization.set_industry_defaults(organization.industry_type)
	get_node("/root/Main/ScheduleManager").save_organization()
	
	# Remove the classification error from the list
	for i in range(errors.size() - 1, -1, -1):
		if "classification" in errors[i].to_lower():
			errors.remove_at(i)
	
	# Update the error list
	error_list.clear()
	for error in errors:
		error_list.add_item(error)
	
	# If no more errors, continue
	if errors.is_empty():
		_on_continue_pressed()
	else:
		# Update UI to show remaining errors
		show_error_actions()

# Button animation methods - using separate tweens to avoid conflicts
func _on_button_mouse_entered(button: Button):
	var hover_tween = create_tween()
	hover_tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.1).set_ease(Tween.EASE_OUT)

func _on_button_mouse_exited(button: Button):
	var exit_tween = create_tween()
	exit_tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_IN)

func _on_button_pressed(button: Button):
	var press_tween = create_tween()
	press_tween.tween_property(button, "scale", Vector2(0.95, 0.95), 0.05).set_ease(Tween.EASE_IN)

func _on_button_released(button: Button):
	var release_tween = create_tween()
	release_tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.05).set_ease(Tween.EASE_OUT)
	release_tween.tween_property(button, "scale", Vector2(1.0, 1.0), 0.1).set_ease(Tween.EASE_IN_OUT)
