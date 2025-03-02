class_name NavigationManager extends Node

signal screen_changed(screen_name, previous_screen)
signal navigation_stack_updated(stack)

# Navigation stack to track screen history
var nav_stack = []
var current_screen = ""
var dirty_screens = {} # Tracks screens with unsaved changes

func navigate_to(screen_name: String, force: bool = false) -> bool:
	# Check if current screen has unsaved changes
	if not force and current_screen in dirty_screens:
		return false
	
	var previous_screen = current_screen
	
	# Push current screen to stack if we're not returning to the landing page
	if current_screen != "" and screen_name != "landing":
		nav_stack.push_back(current_screen)
	
	# If we're going to landing page, clear the stack
	if screen_name == "landing":
		nav_stack.clear()
	
	# Update current screen
	current_screen = screen_name
	
	# Emit signals
	emit_signal("screen_changed", screen_name, previous_screen)
	emit_signal("navigation_stack_updated", nav_stack)
	
	return true

func go_back() -> bool:
	# Can't go back if stack is empty
	if nav_stack.is_empty():
		return navigate_to("landing")
	
	# Check if current screen has unsaved changes
	if current_screen in dirty_screens:
		return false
	
	# Pop previous screen from stack
	var previous_screen = current_screen
	current_screen = nav_stack.pop_back()
	
	# Emit signals
	emit_signal("screen_changed", current_screen, previous_screen)
	emit_signal("navigation_stack_updated", nav_stack)
	
	return true

func mark_screen_dirty(screen_name: String, is_dirty: bool = true) -> void:
	if is_dirty:
		dirty_screens[screen_name] = true
	elif screen_name in dirty_screens:
		dirty_screens.erase(screen_name)
	
	# Re-emit navigation stack to update UI (like back button state)
	emit_signal("navigation_stack_updated", nav_stack)

func can_navigate_away_from_current() -> bool:
	return not (current_screen in dirty_screens)

func show_unsaved_changes_dialog(callback: Callable) -> void:
	# Create confirmation dialog
	var dialog = ConfirmationDialog.new()
	dialog.dialog_text = "You have unsaved changes. Do you want to save before leaving?"
	dialog.add_button("Discard", true, "discard")
	
	# Connect to dialog signals
	dialog.connect("confirmed", func():
		# Save changes
		callback.call(true)
	)
	
	dialog.connect("custom_action", func(action):
		if action == "discard":
			# Discard changes and continue
			mark_screen_dirty(current_screen, false)
			callback.call(false)
	)
	
	dialog.connect("canceled", func():
		# Stay on current screen
		pass
	)
	
	# Add dialog to scene and show it
	get_tree().root.add_child(dialog)
	dialog.popup_centered()
