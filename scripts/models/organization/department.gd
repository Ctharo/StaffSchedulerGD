class_name Department extends Resource

@export var id: String
@export var name: String
@export var manager_employee_id: String

func _init(p_id: String = "", p_name: String = "") -> void:
	id = p_id if p_id else str(randi())
	name = p_name
