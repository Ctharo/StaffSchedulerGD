class_name Employee extends Resource

signal availability_changed
signal role_changed

# Basic employee information
@export var id: String
@export var first_name: String
@export var last_name: String
@export var email: String
@export var phone: String
@export var hire_date: Dictionary  # {year, month, day}
@export var classification: String  # "RN", "LPN", "CA" (Care Aide)
@export var department_id: String
@export var site_preferences: Array[String] = []  # "RHH", "HH" or both
@export var max_hours_per_week: int = 40
@export var hourly_rate: float = 0.0

# Employment status
@export var employment_status: String = "full_time"  # full_time, part_time, casual
@export var fte: float = 1.0  # Full-time equivalent (0.5 = half time)
@export var seniority_date: Dictionary  # For determining priority in some cases
@export var seniority_hours: float = 0.0  # Alternative seniority metric

# OT & Pay Settings
@export var ot_multiplier: float = 1.5  # Default overtime rate
@export var pay_grade: String = ""
@export var union_id: String = ""

# Assigned line (pattern) - can be empty for casual staff
@export var assigned_line_id: String = ""

# Availability tracking - Dictionary with weekday keys (0-6) and array of time ranges
# Format: { 0: [{"start": "09:00", "end": "17:00"}], 1: [...], ... }
@export var availability: Dictionary = {}

# Time off requests
@export var time_off_requests: Array = []

# Certifications with expiry dates
@export var certifications: Dictionary = {}  # { "cert_name": {date: Dictionary, status: String} }

func _init(p_id: String = "", p_first_name: String = "", p_last_name: String = "", p_classification: String = "") -> void:
	id = p_id if p_id else str(randi())
	first_name = p_first_name
	last_name = p_last_name
	classification = p_classification
	
	# Initialize empty availability for all days
	for day in range(7):
		availability[day] = []

func get_full_name() -> String:
	return first_name + " " + last_name
	
func get_classification_display() -> String:
	return classification + " - " + get_full_name()

func is_available(date: Dictionary, start_time: String, end_time: String) -> bool:
	# Check if date is in time off requests
	for request in time_off_requests:
		if TimeUtility.is_date_in_range(date, request.start_date, request.end_date):
			return false
	
	# Check regular availability for this weekday
	var weekday = date.weekday
	if not availability.has(weekday):
		return false
		
	for time_slot in availability[weekday]:
		if TimeUtility.is_time_overlapping(start_time, end_time, time_slot.start, time_slot.end):
			return true
			
	return false

func can_work_at_site(site_id: String) -> bool:
	return site_preferences.is_empty() or site_id in site_preferences

func set_classification(new_classification: String) -> void:
	classification = new_classification
	role_changed.emit()

func set_availability(weekday: int, time_slots: Array) -> void:
	availability[weekday] = time_slots
	availability_changed.emit()

func request_time_off(start_date: Dictionary, end_date: Dictionary, reason: String = "") -> Dictionary:
	var request = {
		"id": str(randi()),
		"start_date": start_date,
		"end_date": end_date,
		"reason": reason,
		"status": "pending"  # pending, approved, denied
	}
	time_off_requests.append(request)
	return request

func cancel_time_off_request(request_id: String) -> bool:
	for i in range(time_off_requests.size()):
		if time_off_requests[i].id == request_id:
			time_off_requests.remove_at(i)
			return true
	return false

func add_certification(cert_name: String, expiry_date: Dictionary) -> void:
	certifications[cert_name] = {
		"date": expiry_date,
		"status": "active"
	}
	
func is_certification_valid(cert_name: String) -> bool:
	if not certifications.has(cert_name):
		return false
		
	var cert = certifications[cert_name]
	if cert.status != "active":
		return false
		
	var now = Time.get_datetime_dict_from_system()
	return TimeUtility.compare_dates(cert.date, now) > 0
