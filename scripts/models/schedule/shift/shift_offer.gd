class_name ShiftOffer extends Resource

signal response_received

@export var id: String
@export var shift_id: String
@export var offering_tier: String  # "tier1", "tier2", etc.
@export var offered_to_employee_ids: Array = []
@export var responses: Dictionary = {}  # {employee_id: "accepted", "declined", "no_response"}
@export var created_date: Dictionary
@export var expires_date: Dictionary
@export var status: String = "open"  # open, filled, expired, cancelled
@export var is_split_offer: bool = false
@export var split_segments: Array = []  # For split shift offers

func _init(p_id: String = "", p_shift_id: String = "") -> void:
	id = p_id if p_id else str(randi())
	shift_id = p_shift_id
	created_date = Time.get_datetime_dict_from_system()

func offer_to_employee(employee_id: String) -> void:
	if not employee_id in offered_to_employee_ids:
		offered_to_employee_ids.append(employee_id)
		responses[employee_id] = "no_response"

func record_response(employee_id: String, response: String) -> void:
	if employee_id in offered_to_employee_ids:
		responses[employee_id] = response
		response_received.emit()

func get_accepted_employee_id() -> String:
	for employee_id in responses:
		if responses[employee_id] == "accepted":
			return employee_id
	return ""

func create_split_offer(segments: Array) -> void:
	is_split_offer = true
	split_segments = segments

func has_expired() -> bool:
	var now = Time.get_datetime_dict_from_system()
	return TimeUtility.compare_dates(expires_date, now) < 0
