class_name Site extends Resource

@export var id: String  # "RHH" or "HH"
@export var name: String  # "Rotary Hospice House" or "Home Hospice"
@export var address: String
@export var phone: String
@export var manager_employee_id: String

func _init(p_id: String = "", p_name: String = "") -> void:
	id = p_id
	name = p_name
