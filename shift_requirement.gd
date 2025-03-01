class_name ShiftRequirement extends Resource

@export var id: String
@export var shift_name: String  # "Day", "Evening", "Night"
@export var site_id: String  # "RHH" or "HH"
@export var requirements: Dictionary = {}  # {"RN": 1, "LPN": 0, "CA": 2}
@export var start_time: String
@export var end_time: String

func _init(p_id: String = "", p_shift_name: String = "", p_site_id: String = "") -> void:
	id = p_id if p_id else str(randi())
	shift_name = p_shift_name
	site_id = p_site_id
	
func get_required_count(classification: String) -> int:
	return requirements.get(classification, 0)
	
func set_required_count(classification: String, count: int) -> void:
	requirements[classification] = count
