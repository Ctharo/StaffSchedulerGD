extends VBoxContainer

signal config_saved(section_name)

var schedule_manager: ScheduleManager

# UI References
@onready var classifications_list = %ClassificationsList
@onready var add_classification_button = %AddClassificationButton
@onready var remove_classification_button = %RemoveClassificationButton
@onready var classification_edit = %ClassificationEdit
@onready var save_classification_button = %SaveButton

# Currently selected classification
var selected_classification_idx = -1

func init(manager: ScheduleManager):
	schedule_manager = manager
	load_classifications_list()
	
	# Connect signals
	add_classification_button.connect("pressed", _on_add_classification_button_pressed)
	remove_classification_button.connect("pressed", _on_remove_classification_button_pressed)
	save_classification_button.connect("pressed", _on_save_classification_button_pressed)
	classifications_list.connect("item_selected", _on_classification_selected)

func load_classifications_list():
	classifications_list.clear()
	
	# Add each classification to the list
	for classification in schedule_manager.current_organization.classifications:
		classifications_list.add_item(classification)
	
	# Clear details
	classification_edit.text = ""
	
	# Disable remove button if no classifications
	remove_classification_button.disabled = classifications_list.get_item_count() == 0
	save_classification_button.disabled = true
	
	selected_classification_idx = -1

func _on_add_classification_button_pressed():
	# Create a new classification with default value
	var new_classification = "New Classification"
	
	# Add to organization
	schedule_manager.current_organization.classifications.append(new_classification)
	schedule_manager.save_organization()
	
	# Reload classifications list
	load_classifications_list()
	
	# Select the new classification
	for i in range(classifications_list.get_item_count()):
		if classifications_list.get_item_text(i) == new_classification:
			classifications_list.select(i)
			_on_classification_selected(i)
			break

func _on_remove_classification_button_pressed():
	var selected_idx = classifications_list.get_selected_items()[0]
	
	# Create confirmation dialog
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Are you sure you want to remove this classification? This may affect employees and shifts using this classification."
	confirm_dialog.get_ok_button().connect("pressed", _confirm_remove_classification.bind(selected_idx))
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func _confirm_remove_classification(idx):
	# Remove classification from organization
	schedule_manager.current_organization.classifications.remove_at(idx)
	schedule_manager.save_organization()
	
	# Reload classifications list
	load_classifications_list()
	
	emit_signal("config_saved", "Classification removed")

func _on_classification_selected(idx):
	selected_classification_idx = idx
	var classification = schedule_manager.current_organization.classifications[idx]
	
	# Update details
	classification_edit.text = classification
	save_classification_button.disabled = false

func _on_save_classification_button_pressed():
	if selected_classification_idx >= 0:
		# Update classification
		schedule_manager.current_organization.classifications[selected_classification_idx] = classification_edit.text
		schedule_manager.save_organization()
		
		# Reload classifications list
		load_classifications_list()
		
		emit_signal("config_saved", "Classification")

func get_config_data():
	return schedule_manager.current_organization.classifications.duplicate()

func import_config_data(data):
	if data is Array:
		# Replace existing classifications with imported ones
		schedule_manager.current_organization.classifications = data.duplicate()
		schedule_manager.save_organization()
		
		# Reload classifications list
		load_classifications_list()
