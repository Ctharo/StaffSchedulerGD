class_name NotificationManager extends Node

signal notification_received(notification)
signal notification_dismissed(notification_id)
signal notifications_updated(count)

enum NotificationType {
	INFO,          # General information
	WARNING,       # Warning that requires attention
	ALERT,         # Critical alert
	SHIFT_OFFER,   # Shift being offered
	OVERTIME,      # Overtime opportunity
	TIME_OFF,      # Time off request
	SCHEDULE,      # Schedule changes
	ASSIGNMENT     # Shift assignment
}

enum Role {
	STAFF,         # Regular staff
	SUPERVISOR,    # Supervisor/Team lead  
	MANAGER,       # Department manager
	ADMIN          # System administrator
}

var notifications = []
var next_id = 1

# Role-based notification preferences
var role_preferences = {
	Role.STAFF: {
		NotificationType.INFO: true,
		NotificationType.WARNING: true,
		NotificationType.ALERT: true,
		NotificationType.SHIFT_OFFER: true,
		NotificationType.OVERTIME: true,
		NotificationType.TIME_OFF: false,
		NotificationType.SCHEDULE: true,
		NotificationType.ASSIGNMENT: true
	},
	Role.SUPERVISOR: {
		NotificationType.INFO: true,
		NotificationType.WARNING: true,
		NotificationType.ALERT: true,
		NotificationType.SHIFT_OFFER: true,
		NotificationType.OVERTIME: true,
		NotificationType.TIME_OFF: true,
		NotificationType.SCHEDULE: true,
		NotificationType.ASSIGNMENT: true
	},
	Role.MANAGER: {
		NotificationType.INFO: true,
		NotificationType.WARNING: true,
		NotificationType.ALERT: true,
		NotificationType.SHIFT_OFFER: true,
		NotificationType.OVERTIME: true,
		NotificationType.TIME_OFF: true,
		NotificationType.SCHEDULE: true,
		NotificationType.ASSIGNMENT: true
	},
	Role.ADMIN: {
		NotificationType.INFO: true,
		NotificationType.WARNING: true,
		NotificationType.ALERT: true,
		NotificationType.SHIFT_OFFER: true,
		NotificationType.OVERTIME: true,
		NotificationType.TIME_OFF: true,
		NotificationType.SCHEDULE: true,
		NotificationType.ASSIGNMENT: true
	}
}

# Current user's role
var current_user_role = Role.STAFF

func _ready():
	# Load any saved notifications
	load_notifications()

func add_notification(title: String, message: String, type: NotificationType, 
		target_roles: Array = [], action_data: Dictionary = {}, 
		expiry_time: float = 0) -> int:
	
	var notification = {
		"id": next_id,
		"title": title,
		"message": message,
		"type": type,
		"target_roles": target_roles,
		"created": Time.get_unix_time_from_system(),
		"read": false,
		"action_data": action_data,
		"expiry": expiry_time > 0,
		"expiry_time": Time.get_unix_time_from_system() + expiry_time if expiry_time > 0 else 0
	}
	
	# Add notification
	notifications.append(notification)
	next_id += 1
	
	# Check if notification should be shown to current user
	if should_show_to_user(notification):
		emit_signal("notification_received", notification)
	
	save_notifications()
	emit_signal("notifications_updated", get_unread_count())
	
	return notification.id

func dismiss_notification(notification_id: int) -> bool:
	for i in range(notifications.size()):
		if notifications[i].id == notification_id:
			notifications[i].read = true
			emit_signal("notification_dismissed", notification_id)
			save_notifications()
			emit_signal("notifications_updated", get_unread_count())
			return true
	return false

func dismiss_all_notifications():
	var dismissed_count = 0
	
	for notification in notifications:
		if not notification.read:
			notification.read = true
			emit_signal("notification_dismissed", notification.id)
			dismissed_count += 1
	
	if dismissed_count > 0:
		save_notifications()
		emit_signal("notifications_updated", get_unread_count())

func get_notifications(include_read: bool = false, filter_type: int = -1) -> Array:
	var filtered = []
	var current_time = Time.get_unix_time_from_system()
	
	for notification in notifications:
		# Skip if read notifications are not requested
		if notification.read and not include_read:
			continue
		
		# Skip expired notifications
		if notification.expiry and notification.expiry_time < current_time:
			continue
			
		# Apply type filter if specified
		if filter_type >= 0 and notification.type != filter_type:
			continue
			
		# Include if it should be shown to current user
		if should_show_to_user(notification):
			filtered.append(notification)
	
	return filtered

func get_unread_count() -> int:
	var count = 0
	var current_time = Time.get_unix_time_from_system()
	
	for notification in notifications:
		if not notification.read and \
		   (!notification.expiry or notification.expiry_time >= current_time) and\
		   should_show_to_user(notification):
			count += 1
	
	return count

func should_show_to_user(notification) -> bool:
	# Check if notification should be shown based on user role and preferences
	
	# If no target roles specified, show to all roles
	if notification.target_roles.is_empty():
		return role_preferences[current_user_role].get(notification.type, true)
	
	# If target roles specified, check if current role is included
	if current_user_role in notification.target_roles:
		return role_preferences[current_user_role].get(notification.type, true)
	
	return false

func set_user_role(role: Role):
	current_user_role = role
	# Update notification counts when role changes
	emit_signal("notifications_updated", get_unread_count())

func save_notifications():
	# Save to persistent storage
	var save_data = []
	for notification in notifications:
		# Don't save expired notifications
		if notification.expiry and notification.expiry_time < Time.get_unix_time_from_system():
			continue
			
		save_data.append(notification)
	
	# Save to file
	var config = ConfigFile.new()
	config.set_value("notifications", "data", save_data)
	config.set_value("notifications", "next_id", next_id)
	config.save("user://notifications.cfg")

func load_notifications():
	var config = ConfigFile.new()
	
	if config.load("user://notifications.cfg") == OK:
		notifications = config.get_value("notifications", "data", [])
		next_id = config.get_value("notifications", "next_id", 1)
		emit_signal("notifications_updated", get_unread_count())

func clean_expired_notifications():
	var current_time = Time.get_unix_time_from_system()
	var original_count = notifications.size()
	
	# Remove expired notifications
	notifications = notifications.filter(func(notification):
		return !notification.expiry or notification.expiry_time >= current_time
	)
	
	# Save if any were removed
	if original_count != notifications.size():
		save_notifications()
		emit_signal("notifications_updated", get_unread_count())
