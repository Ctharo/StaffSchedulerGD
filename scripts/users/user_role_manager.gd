class_name UserRoleManager extends Node

signal role_changed(new_role)
signal permission_denied(action, reason)

enum UserRole {
	STAFF,         # Regular staff
	SUPERVISOR,    # Supervisor/Team lead  
	MANAGER,       # Department manager
	ADMIN          # System administrator
}

# Permission definitions
var permissions = {
	"view_schedule": [UserRole.STAFF, UserRole.SUPERVISOR, UserRole.MANAGER, UserRole.ADMIN],
	"view_own_shifts": [UserRole.STAFF, UserRole.SUPERVISOR, UserRole.MANAGER, UserRole.ADMIN],
	"view_all_shifts": [UserRole.SUPERVISOR, UserRole.MANAGER, UserRole.ADMIN],
	
	"edit_own_availability": [UserRole.STAFF, UserRole.SUPERVISOR, UserRole.MANAGER, UserRole.ADMIN],
	"edit_own_info": [UserRole.STAFF, UserRole.SUPERVISOR, UserRole.MANAGER, UserRole.ADMIN],
	
	"edit_schedule": [UserRole.SUPERVISOR, UserRole.MANAGER, UserRole.ADMIN],
	"assign_shifts": [UserRole.SUPERVISOR, UserRole.MANAGER, UserRole.ADMIN],
	"create_shift_offer": [UserRole.SUPERVISOR, UserRole.MANAGER, UserRole.ADMIN],
	
	"manage_employees": [UserRole.MANAGER, UserRole.ADMIN],
	"manage_sites": [UserRole.MANAGER, UserRole.ADMIN],
	
	"configure_system": [UserRole.ADMIN],
	"manage_organization": [UserRole.ADMIN]
}

var current_user_id: String = ""
var current_role: UserRole = UserRole.STAFF

func _ready():
	# Load saved role from persistent storage
	_load_user_role()

func set_user(user_id: String, role: UserRole):
	current_user_id = user_id
	current_role = role
	
	# Save to persistent storage
	_save_user_role()
	
	# Notify listeners
	emit_signal("role_changed", role)

func get_role_name(role: UserRole) -> String:
	match role:
		UserRole.STAFF:
			return "Staff"
		UserRole.SUPERVISOR:
			return "Supervisor"
		UserRole.MANAGER:
			return "Manager"
		UserRole.ADMIN:
			return "Administrator"
		_:
			return "Unknown"

func has_permission(action: String) -> bool:
	if not permissions.has(action):
		push_warning("Unknown permission requested: " + action)
		return false
	
	return current_role in permissions[action]

func check_permission(action: String, show_error: bool = true) -> bool:
	if has_permission(action):
		return true
	
	if show_error:
		emit_signal("permission_denied", action, "You don't have permission to " + 
			_get_action_description(action) + ".")
	
	return false

func _get_action_description(action: String) -> String:
	# Convert action names to readable descriptions
	match action:
		"view_schedule":
			return "view the schedule"
		"view_own_shifts":
			return "view your shifts"
		"view_all_shifts":
			return "view all staff shifts"
		"edit_own_availability":
			return "edit your availability"
		"edit_own_info":
			return "edit your information"
		"edit_schedule":
			return "edit the schedule"
		"assign_shifts":
			return "assign shifts"
		"create_shift_offer":
			return "create shift offerings"
		"manage_employees":
			return "manage employees"
		"manage_sites":
			return "manage sites"
		"configure_system":
			return "configure system settings"
		"manage_organization":
			return "manage organization settings"
		_:
			return action.replace("_", " ")

func _save_user_role():
	var config = ConfigFile.new()
	config.set_value("user", "id", current_user_id)
	config.set_value("user", "role", current_role)
	config.save("user://user_role.cfg")

func _load_user_role():
	var config = ConfigFile.new()
	
	if config.load("user://user_role.cfg") == OK:
		current_user_id = config.get_value("user", "id", "")
		current_role = config.get_value("user", "role", UserRole.STAFF)
	else:
		# Default to staff
		current_user_id = ""
		current_role = UserRole.STAFF
