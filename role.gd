class_name Role extends Resource

@export var id: String
@export var name: String
@export var description: String = ""
@export var department_id: String = ""
@export var requires_certification: bool = false
@export var certification_type: String = ""

func _init(p_id: String = "", p_name: String = "") -> void:
	id = p_id if p_id else str(randi())
	name = p_name
