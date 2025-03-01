extends VBoxContainer

signal config_saved(section_name)

var schedule_manager: ScheduleManager

# UI References
@onready var rules_list = $HSplitContainer/RulesPanel/RulesList
@onready var add_rule_button = $HSplitContainer/RulesPanel/AddRuleButton
@onready var remove_rule_button = $HSplitContainer/RulesPanel/RemoveRuleButton
@onready var rule_name_edit = $HSplitContainer/RuleDetailsPanel/ScrollContainer/VBoxContainer/NameSection/NameEdit
@onready var rule_type_option = $HSplitContainer/RuleDetailsPanel/ScrollContainer/VBoxContainer/TypeSection/TypeOption
@onready var threshold_spin = $HSplitContainer/RuleDetailsPanel/ScrollContainer/VBoxContainer/ThresholdSection/ThresholdSpin
@onready var multiplier_spin = $HSplitContainer/RuleDetailsPanel/ScrollContainer/VBoxContainer/MultiplierSection/MultiplierSpin
@onready var save_rule_button = $HSplitContainer/RuleDetailsPanel/ScrollContainer/VBoxContainer/SaveSection/SaveButton

# Currently selected rule
var selected_rule_idx = -1

func init(manager: ScheduleManager):
	schedule_manager = manager
	load_rules_list()
	setup_rule_type_dropdown()
	
	# Connect signals
	add_rule_button.connect("pressed", _on_add_rule_button_pressed)
	remove_rule_button.connect("pressed", _on_remove_rule_button_pressed)
	save_rule_button.connect("pressed", _on_save_rule_button_pressed)
	rules_list.connect("item_selected", _on_rule_selected)
	rule_type_option.connect("item_selected", _on_rule_type_changed)

func load_rules_list():
	rules_list.clear()
	
	# Add each rule to the list
	for rule in schedule_manager.current_organization.overtime_rules:
		rules_list.add_item(rule.name)
	
	# Clear rule details panel
	clear_rule_details()
	
	# Disable remove button if no rules
	remove_rule_button.disabled = rules_list.get_item_count() == 0

func setup_rule_type_dropdown():
	rule_type_option.clear()
	
	# Add rule types
	rule_type_option.add_item("Daily")
	rule_type_option.set_item_metadata(0, "daily")
	
	rule_type_option.add_item("Weekly")
	rule_type_option.set_item_metadata(1, "weekly")
	
	rule_type_option.add_item("Pay Period")
	rule_type_option.set_item_metadata(2, "pay_period")
	
	rule_type_option.add_item("Consecutive Days")
	rule_type_option.set_item_metadata(3, "consecutive_days")

func clear_rule_details():
	rule_name_edit.text = ""
	rule_type_option.select(0)  # Default to daily
	threshold_spin.value = 8  # Default to 8 hours
	multiplier_spin.value = 1.5  # Default to time and a half
	
	selected_rule_idx = -1
	save_rule_button.disabled = true

func _on_add_rule_button_pressed():
	# Create a new rule with default values
	var new_rule = {
		"id": "rule_" + str(randi()),
		"name": "New OT Rule",
		"type": "daily",
		"threshold": 8,
		"multiplier": 1.5
	}
	
	# Add to organization
	schedule_manager.current_organization.add_overtime_rule(new_rule)
	schedule_manager.save_organization()
	
	# Reload rules list
	load_rules_list()
	
	# Select the new rule
	for i in range(rules_list.get_item_count()):
		if rules_list.get_item_text(i) == new_rule.name:
			rules_list.select(i)
			_on_rule_selected(i)
			break

func _on_remove_rule_button_pressed():
	var selected_idx = rules_list.get_selected_items()[0]
	
	# Create confirmation dialog
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Are you sure you want to remove this overtime rule?"
	confirm_dialog.get_ok_button().connect("pressed", _confirm_remove_rule.bind(selected_idx))
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func _confirm_remove_rule(idx):
	# Remove rule from organization
	schedule_manager.current_organization.overtime_rules.remove_at(idx)
	schedule_manager.save_organization()
	
	# Reload rules list
	load_rules_list()
	
	emit_signal("config_saved", "Overtime rule removed")

func _on_rule_selected(idx):
	selected_rule_idx = idx
	var rule = schedule_manager.current_organization.overtime_rules[idx]
	
	# Update details panel
	rule_name_edit.text = rule.name
	
	# Set rule type
	var type_idx = -1
	for i in range(rule_type_option.get_item_count()):
		if rule_type_option.get_item_metadata(i) == rule.type:
			type_idx = i
			break
	
	if type_idx >= 0:
		rule_type_option.select(type_idx)
	else:
		rule_type_option.select(0)  # Default to first option (daily)
	
	# Set threshold and multiplier
	threshold_spin.value = rule.threshold
	multiplier_spin.value = rule.multiplier
	
	save_rule_button.disabled = false

func _on_rule_type_changed(idx):
	var rule_type = rule_type_option.get_item_metadata(idx)
	
	# Update threshold label and default value based on rule type
	match rule_type:
		"daily":
			threshold_spin.value = 8
			$HSplitContainer/RuleDetailsPanel/ScrollContainer/VBoxContainer/ThresholdSection/ThresholdLabel.text = "Hours per Day:"
		"weekly":
			threshold_spin.value = 40
			$HSplitContainer/RuleDetailsPanel/ScrollContainer/VBoxContainer/ThresholdSection/ThresholdLabel.text = "Hours per Week:"
		"pay_period":
			threshold_spin.value = 80  # Assuming bi-weekly
			$HSplitContainer/RuleDetailsPanel/ScrollContainer/VBoxContainer/ThresholdSection/ThresholdLabel.text = "Hours per Pay Period:"
		"consecutive_days":
			threshold_spin.value = 6
			$HSplitContainer/RuleDetailsPanel/ScrollContainer/VBoxContainer/ThresholdSection/ThresholdLabel.text = "Number of Days:"

func _on_save_rule_button_pressed():
	if selected_rule_idx >= 0:
		var rule = schedule_manager.current_organization.overtime_rules[selected_rule_idx]
		
		# Update rule details
		rule.name = rule_name_edit.text
		rule.type = rule_type_option.get_item_metadata(rule_type_option.get_selected_id())
		rule.threshold = threshold_spin.value
		rule.multiplier = multiplier_spin.value
		
		# Save changes
		schedule_manager.save_organization()
		
		# Reload rules list to reflect name changes
		load_rules_list()
		
		emit_signal("config_saved", "Overtime rule")

func get_config_data():
	return schedule_manager.current_organization.overtime_rules.duplicate(true)

func import_config_data(data):
	if data is Array:
		# Replace existing rules with imported ones
		schedule_manager.current_organization.overtime_rules = data.duplicate(true)
		schedule_manager.save_organization()
		
		# Reload rules list
		load_rules_list()
