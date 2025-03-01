extends PanelContainer

# UI References
@onready var condition_type_option = $HBoxContainer/ConditionTypeOption
@onready var condition_value_option = $HBoxContainer/ConditionValueOption

func _ready():
	setup_condition_types()
	
	# Connect signals
	condition_type_option.connect("item_selected", _on_condition_type_changed)

func setup_condition_types():
	condition_type_option.clear()
	
	condition_type_option.add_item("Status")
	condition_type_option.set_item_metadata(0, "status")
	
	condition_type_option.add_item("Pay Type")
	condition_type_option.set_item_metadata(1, "pay_type")
	
	condition_type_option.add_item("Split Shift")
	condition_type_option.set_item_metadata(2, "split_shift")
	
	# Set default
	condition_type_option.select(0)
	_on_condition_type_changed(0)

func _on_condition_type_changed(idx):
	var condition_type = condition_type_option.get_item_metadata(idx)
	
	condition_value_option.clear()
	
	match condition_type:
		"status":
			condition_value_option.add_item("Full Time")
			condition_value_option.set_item_metadata(0, "full_time")
			
			condition_value_option.add_item("Part Time")
			condition_value_option.set_item_metadata(1, "part_time")
			
			condition_value_option.add_item("Casual")
			condition_value_option.set_item_metadata(2, "casual")
		
		"pay_type":
			condition_value_option.add_item("Straight")
			condition_value_option.set_item_metadata(0, "straight")
			
			condition_value_option.add_item("Overtime")
			condition_value_option.set_item_metadata(1, "overtime")
		
		"split_shift":
			condition_value_option.add_item("True")
			condition_value_option.set_item_metadata(0, true)
			
			condition_value_option.add_item("False")
			condition_value_option.set_item_metadata(1, false)
	
	condition_value_option.select(0)

func get_condition() -> Dictionary:
	var condition = {}
	
	var type_key = condition_type_option.get_item_metadata(condition_type_option.get_selected_id())
	var value = condition_value_option.get_item_metadata(condition_value_option.get_selected_id())
	
	condition[type_key] = value
	
	return condition

func set_condition(condition: Dictionary) -> void:
	for key in condition:
		# Find the condition type
		var type_idx = -1
		for i in range(condition_type_option.get_item_count()):
			if condition_type_option.get_item_metadata(i) == key:
				type_idx = i
				break
		
		if type_idx >= 0:
			condition_type_option.select(type_idx)
			_on_condition_type_changed(type_idx)
			
			# Find the value
			var value = condition[key]
			var value_idx = -1
			
			for i in range(condition_value_option.get_item_count()):
				if condition_value_option.get_item_metadata(i) == value:
					value_idx = i
					break
			
			if value_idx >= 0:
				condition_value_option.select(value_idx)
		
		break  # Only process the first key
