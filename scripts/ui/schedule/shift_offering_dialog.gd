# ui/schedule/shift_offering_dialog.gd
class_name ShiftOfferingDialog extends Window

signal offering_created

var schedule_manager: ScheduleManager
var shift: Shift

# UI References
@onready var shift_details_label = $VBoxContainer/ShiftDetailsLabel
@onready var tiers_list = $VBoxContainer/HSplitContainer/TiersPanel/TiersList
@onready var tier_details_container = $VBoxContainer/HSplitContainer/TierDetailsPanel/VBoxContainer
@onready var eligible_employees_list = $VBoxContainer/HSplitContainer/TierDetailsPanel/VBoxContainer/EligibleEmployeesPanel/EmployeesList
@onready var create_button = $VBoxContainer/ButtonsPanel/CreateButton
@onready var cancel_button = $VBoxContainer/ButtonsPanel/CancelButton

# Currently selected tier
var selected_tier_id: String = ""

func _ready():
	connect_signals()
	
func connect_signals():
	cancel_button.connect("pressed", _on_cancel_button_pressed)
	create_button.connect("pressed", _on_create_button_pressed)
	tiers_list.connect("item_selected", _on_tier_selected)

func initialize():
	# Update shift details
	shift_details_label.text = "Offer: %s at %s\n%s from %s to %s" % [
		shift.classification,
		shift.site_id,
		TimeUtility.format_date(shift.date),
		shift.start_time,
		shift.end_time
	]
	
	# Load offering tiers
	load_offering_tiers()
	
	# Disable create button until a tier is selected
	create_button.disabled = true

func load_offering_tiers():
	tiers_list.clear()
	
	# Get offering tiers from organization
	for tier in schedule_manager.current_organization.shift_offering_rules:
		tiers_list.add_item(tier.name)
		tiers_list.set_item_metadata(tiers_list.get_item_count() - 1, tier.id)

func _on_tier_selected(idx):
	var tier_id = tiers_list.get_item_metadata(idx)
	selected_tier_id = tier_id
	
	# Get tier details
	var tier = schedule_manager.current_organization.get_shift_offering_tier(tier_id)
	
	# Update details display
	# ...
	
	# Find eligible employees
	var eligible_employees = schedule_manager.find_eligible_employees_for_tier(shift, tier)
	
	# Update eligible employees list
	eligible_employees_list.clear()
	for employee in eligible_employees:
		eligible_employees_list.add_item(employee.get_full_name())
		eligible_employees_list.set_item_metadata(eligible_employees_list.get_item_count() - 1, employee.id)
	
	# Enable create button if there are eligible employees
	create_button.disabled = eligible_employees_list.get_item_count() == 0

func _on_create_button_pressed():
	if selected_tier_id.is_empty():
		return
	
	# Create shift offer
	var offer = schedule_manager.create_shift_offer(shift.id, selected_tier_id)
	
	if offer:
		emit_signal("offering_created")
		queue_free()
	else:
		# Show error
		var dialog = AcceptDialog.new()
		dialog.dialog_text = "Failed to create shift offering."
		add_child(dialog)
		dialog.popup_centered()

func _on_cancel_button_pressed():
	queue_free()
