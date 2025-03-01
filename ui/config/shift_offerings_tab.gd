extends VBoxContainer

signal config_saved(section_name)

var schedule_manager: ScheduleManager

# UI References
@onready var tiers_list = $HSplitContainer/TiersPanel/TiersList
@onready var add_tier_button = $HSplitContainer/TiersPanel/AddTierButton
@onready var remove_tier_button = $HSplitContainer/TiersPanel/RemoveTierButton
@onready var tier_name_edit = $HSplitContainer/TierDetailsPanel/ScrollContainer/VBoxContainer/NameSection/NameEdit
@onready var priority_spin = $HSplitContainer/TierDetailsPanel/ScrollContainer/VBoxContainer/PrioritySection/PrioritySpin
@onready var advance_days_spin = $HSplitContainer/TierDetailsPanel/ScrollContainer/VBoxContainer/AdvanceDaysSection/AdvanceDaysSpin
@onready var auto_resolve_spin = $HSplitContainer/TierDetailsPanel/ScrollContainer/VBoxContainer/AutoResolveSection/AutoResolveSpin
@onready var conditions_container = $HSplitContainer/TierDetailsPanel/ScrollContainer/VBoxContainer/ConditionsSection/ConditionsContainer
@onready var add_condition_button = $HSplitContainer/TierDetailsPanel/ScrollContainer/VBoxContainer/ConditionsSection/AddConditionButton
@onready var save_tier_button = $HSplitContainer/TierDetailsPanel/ScrollContainer/VBoxContainer/SaveSection/SaveButton

# Currently selected tier
var selected_tier_idx = -1

func init(manager: ScheduleManager):
	schedule_manager = manager
	load_tiers_list()
	
	# Connect signals
	add_tier_button.connect("pressed", _on_add_tier_button_pressed)
	remove_tier_button.connect("pressed", _on_remove_tier_button_pressed)
	save_tier_button.connect("pressed", _on_save_tier_button_pressed)
	tiers_list.connect("item_selected", _on_tier_selected)
	add_condition_button.connect("pressed", _on_add_condition_button_pressed)

func load_tiers_list():
	tiers_list.clear()
	
	# Add each tier to the list
	for tier in schedule_manager.current_organization.shift_offering_rules:
		tiers_list.add_item(tier.name)
	
	# Clear tier details panel
	clear_tier_details()
	
	# Disable remove button if no tiers
	remove_tier_button.disabled = tiers_list.get_item_count() == 0

func clear_tier_details():
	tier_name_edit.text = ""
	priority_spin.value = 1
	advance_days_spin.value = 7
	auto_resolve_spin.value = 24
	
	# Clear conditions
	for child in conditions_container.get_children():
		child.queue_free()
	
	selected_tier_idx = -1
	save_tier_button.disabled = true

func _on_add_tier_button_pressed():
	# Create a new tier with default values
	var new_tier = {
		"id": "tier_" + str(randi()),
		"name": "New Offering Tier",
		"priority": 1,
		"conditions": [],
		"advance_days": 7,
		"hours_until_auto_resolve": 24
	}
	
	# Add to organization
	schedule_manager.current_organization.add_shift_offering_rule(new_tier)
	schedule_manager.save_organization()
	
	# Reload tiers list
	load_tiers_list()
	
	# Select the new tier
	for i in range(tiers_list.get_item_count()):
		if tiers_list.get_item_text(i) == new_tier.name:
			tiers_list.select(i)
			_on_tier_selected(i)
			break

func _on_remove_tier_button_pressed():
	var selected_idx = tiers_list.get_selected_items()[0]
	
	# Create confirmation dialog
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Are you sure you want to remove this offering tier?"
	confirm_dialog.get_ok_button().connect("pressed", _confirm_remove_tier.bind(selected_idx))
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func _confirm_remove_tier(idx):
	# Remove tier from organization
	schedule_manager.current_organization.shift_offering_rules.remove_at(idx)
	schedule_manager.save_organization()
	
	# Reload tiers list
	load_tiers_list()
	
	emit_signal("config_saved", "Offering tier removed")

func _on_tier_selected(idx):
	selected_tier_idx = idx
	var tier = schedule_manager.current_organization.shift_offering_rules[idx]
	
	# Update details panel
	tier_name_edit.text = tier.name
	priority_spin.value = tier.priority
	advance_days_spin.value = tier.advance_days
	auto_resolve_spin.value = tier.hours_until_auto_resolve
	
	# Clear old conditions
	for child in conditions_container.get_children():
		child.queue_free()
	
	# Add condition editors
	for condition in tier.conditions:
		add_condition_editor(condition)
	
	save_tier_button.disabled = false

func _on_add_condition_button_pressed():
	add_condition_editor({})

func add_condition_editor(condition: Dictionary):
	var editor = load("res://ConditionEditor.tscn").instantiate()
	conditions_container.add_child(editor)
	
	# Set initial values if we have them
	if not condition.is_empty():
		editor.set_condition(condition)
	
	# Add remove button
	var remove_button = Button.new()
	remove_button.text = "X"
	remove_button.connect("pressed", _remove_condition_editor.bind(editor))
	editor.add_child(remove_button)

func _remove_condition_editor(editor):
	editor.queue_free()

func _on_save_tier_button_pressed():
	if selected_tier_idx >= 0:
		var tier = schedule_manager.current_organization.shift_offering_rules[selected_tier_idx]
		
		# Update tier details
		tier.name = tier_name_edit.text
		tier.priority = priority_spin.value
		tier.advance_days = advance_days_spin.value
		tier.hours_until_auto_resolve = auto_resolve_spin.value
		
		# Update conditions
		tier.conditions.clear()
		for child in conditions_container.get_children():
			if child.has_method("get_condition"):
				var condition = child.get_condition()
				if not condition.is_empty():
					tier.conditions.append(condition)
		
		# Save changes
		schedule_manager.save_organization()
		
		# Reload tiers list to reflect name changes
		load_tiers_list()
		
		emit_signal("config_saved", "Offering tier")

func get_config_data():
	return schedule_manager.current_organization.shift_offering_rules.duplicate(true)

func import_config_data(data):
	if data is Array:
		# Replace existing tiers with imported ones
		schedule_manager.current_organization.shift_offering_rules = data.duplicate(true)
		schedule_manager.save_organization()
		
		# Reload tiers list
		load_tiers_list()
