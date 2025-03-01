extends VBoxContainer

signal config_saved(section_name)

var schedule_manager: ScheduleManager

# UI References
@onready var org_name_edit = $ScrollContainer/VBoxContainer/NameSection/NameEdit
@onready var industry_type_option = $ScrollContainer/VBoxContainer/IndustrySection/IndustryOption
@onready var save_button = $ScrollContainer/VBoxContainer/SaveSection/SaveButton

func init(manager: ScheduleManager):
	schedule_manager = manager
	load_current_config()
	
	# Connect signals
	save_button.connect("pressed", _on_save_button_pressed)
	industry_type_option.connect("item_selected", _on_industry_type_selected)

func load_current_config():
	var organization = schedule_manager.current_organization
	
	# Load organization details
	org_name_edit.text = organization.name
	
	# Setup industry type dropdown
	industry_type_option.clear()
	for industry in ["healthcare", "retail", "manufacturing", "hospitality", "other"]:
		industry_type_option.add_item(industry.capitalize())
	
	# Set current selection
	var industry_index = industry_type_option.get_item_index(organization.industry_type.capitalize())
	if industry_index >= 0:
		industry_type_option.select(industry_index)
	else:
		industry_type_option.select(0)  # Default to first option

func _on_save_button_pressed():
	# Save organization details
	var organization = schedule_manager.current_organization
	organization.name = org_name_edit.text
	
	# Industry is already saved from dropdown selection
	
	# Save the organization to disk
	schedule_manager.save_organization()
	
	# Emit signal to notify parent
	emit_signal("config_saved", "Organization")

func _on_industry_type_selected(index):
	var industry = industry_type_option.get_item_text(index).to_lower()
	schedule_manager.current_organization.industry_type = industry
	
	# Ask if user wants to load industry defaults
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Do you want to load default settings for the " + industry + " industry?"
	confirm_dialog.get_ok_button().connect("pressed", _load_industry_defaults)
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func _load_industry_defaults():
	var industry = schedule_manager.current_organization.industry_type
	schedule_manager.current_organization.set_industry_defaults(industry)
	
	# Reload config in all tabs
	# This would need to be implemented by sending a signal to parent to refresh all tabs

func get_config_data():
	return {
		"name": org_name_edit.text,
		"industry_type": industry_type_option.get_item_text(industry_type_option.get_selected_id()).to_lower()
	}

func import_config_data(data):
	if data.has("name"):
		org_name_edit.text = data.name
	
	if data.has("industry_type"):
		var industry_index = industry_type_option.get_item_index(data.industry_type.capitalize())
		if industry_index >= 0:
			industry_type_option.select(industry_index)
