class_name NotificationPanel extends Control

signal notification_selected(notification)
signal dismissed(notification_id)
signal all_dismissed

var notification_manager: NotificationManager
var is_showing: bool = false
var filter_read: bool = false
var filter_type: int = -1  # -1 means no filter

# UI References
@onready var panel_container = $PanelContainer
@onready var notification_list = $PanelContainer/VBoxContainer/ScrollContainer/NotificationList
@onready var header_label = $PanelContainer/VBoxContainer/HeaderContainer/HeaderLabel
@onready var dismiss_all_button = $PanelContainer/VBoxContainer/HeaderContainer/DismissAllButton
@onready var filter_button = $PanelContainer/VBoxContainer/HeaderContainer/FilterButton
@onready var empty_label = $PanelContainer/VBoxContainer/EmptyLabel

func _ready():
	# Hide initially
	visible = false
	modulate.a = 0
	
	# Connect buttons
	dismiss_all_button.connect("pressed", _on_dismiss_all_pressed)
	filter_button.connect("pressed", _on_filter_button_pressed)
	
	# Ensure panel closes when clicked outside
	gui_input.connect(_on_panel_gui_input)

func initialize(manager: NotificationManager):
	notification_manager = manager
	
	# Connect signals
	notification_manager.connect("notification_received", _on_notification_received)
	notification_manager.connect("notification_dismissed", _on_notification_dismissed)
	notification_manager.connect("notifications_updated", _on_notifications_updated)
	
	# Initial update
	update_notification_list()

func show_panel():
	if is_showing:
		return
		
	visible = true
	is_showing = true
	
	# Animate in
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.2)
	
	# Update notifications
	update_notification_list()

func hide_panel():
	if not is_showing:
		return
		
	is_showing = false
	
	# Animate out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): visible = false)

func toggle_panel():
	if is_showing:
		hide_panel()
	else:
		show_panel()

func update_notification_list():
	# Clear current list
	notification_list.clear()
	
	# Get filtered notifications
	var notifications = notification_manager.get_notifications(filter_read, filter_type)
	
	# Update header
	header_label.text = "Notifications (" + str(notifications.size()) + ")"
	
	# Show/hide empty message
	empty_label.visible = notifications.is_empty()
	
	# Disable dismiss all button if no notifications
	dismiss_all_button.disabled = notifications.is_empty()
	
	# Add notifications to list
	for notification in notifications:
		var item_text = notification.title
		
		# Create item
		var item_idx = notification_list.add_item(item_text)
		notification_list.set_item_metadata(item_idx, notification.id)
		
		# Set icon based on type
		var icon_path = _get_icon_path_for_type(notification.type)
		if ResourceLoader.exists(icon_path):
			notification_list.set_item_icon(item_idx, load(icon_path))
		
		# Set font color based on read status
		if notification.read:
			notification_list.set_item_custom_fg_color(item_idx, Color(0.5, 0.5, 0.5))
		
		# Connect item activation
		notification_list.item_activated.connect(_on_notification_activated)

func _get_icon_path_for_type(type: int) -> String:
	var icon_path = "res://resources/icons/"
	
	match type:
		NotificationManager.NotificationType.INFO:
			return icon_path + "info_icon.png"
		NotificationManager.NotificationType.WARNING:
			return icon_path + "warning_icon.png"
		NotificationManager.NotificationType.ALERT:
			return icon_path + "alert_icon.png"
		NotificationManager.NotificationType.SHIFT_OFFER:
			return icon_path + "shift_offer_icon.png"
		NotificationManager.NotificationType.OVERTIME:
			return icon_path + "overtime_icon.png"
		NotificationManager.NotificationType.TIME_OFF:
			return icon_path + "time_off_icon.png"
		NotificationManager.NotificationType.SCHEDULE:
			return icon_path + "schedule_icon.png"
		NotificationManager.NotificationType.ASSIGNMENT:
			return icon_path + "assignment_icon.png"
		_:
			return icon_path + "info_icon.png"

func _on_notification_received(_notification):
	if is_showing:
		update_notification_list()

func _on_notification_dismissed(notification_id):
	if is_showing:
		# Either update the list or remove the specific item
		for i in range(notification_list.get_item_count()):
			if notification_list.get_item_metadata(i) == notification_id:
				if filter_read:
					notification_list.set_item_custom_fg_color(i, Color(0.5, 0.5, 0.5))
				else:
					notification_list.remove_item(i)
				break
				
		# Update header count
		var notifications = notification_manager.get_notifications(filter_read, filter_type)
		header_label.text = "Notifications (" + str(notifications.size()) + ")"
		
		# Update empty state
		empty_label.visible = notification_list.get_item_count() == 0
		dismiss_all_button.disabled = notification_list.get_item_count() == 0

func _on_notifications_updated(_count):
	if is_showing:
		update_notification_list()

func _on_notification_activated(idx):
	var notification_id = notification_list.get_item_metadata(idx)
	
	# Find the notification
	for notification in notification_manager.notifications:
		if notification.id == notification_id:
			emit_signal("notification_selected", notification)
			
			# Mark as read
			notification.read = true
			notification_list.set_item_custom_fg_color(idx, Color(0.5, 0.5, 0.5))
			notification_manager.save_notifications()
			break

func _on_dismiss_all_pressed():
	notification_manager.dismiss_all_notifications()
	emit_signal("all_dismissed")
	
	# Update UI
	update_notification_list()

func _on_filter_button_pressed():
	# Show filter popup
	var popup = PopupMenu.new()
	
	# Add filter options
	popup.add_check_item("Show Read Notifications", 0)
	popup.set_item_checked(0, filter_read)
	
	popup.add_separator("Filter By Type", 1)
	
	popup.add_radio_check_item("All Types", 2)
	popup.set_item_checked(2, filter_type == -1)
	
	popup.add_radio_check_item("Info", 3)
	popup.set_item_checked(3, filter_type == NotificationManager.NotificationType.INFO)
	
	popup.add_radio_check_item("Warnings", 4)
	popup.set_item_checked(4, filter_type == NotificationManager.NotificationType.WARNING)
	
	popup.add_radio_check_item("Alerts", 5)
	popup.set_item_checked(5, filter_type == NotificationManager.NotificationType.ALERT)
	
	popup.add_radio_check_item("Shift Offers", 6)
	popup.set_item_checked(6, filter_type == NotificationManager.NotificationType.SHIFT_OFFER)
	
	popup.add_radio_check_item("Overtime", 7)
	popup.set_item_checked(7, filter_type == NotificationManager.NotificationType.OVERTIME)
	
	popup.add_radio_check_item("Time Off", 8)
	popup.set_item_checked(8, filter_type == NotificationManager.NotificationType.TIME_OFF)
	
	# Connect signal
	popup.id_pressed.connect(_on_filter_option_selected)
	
	# Show popup
	add_child(popup)
	popup.position = filter_button.global_position + Vector2(0, filter_button.size.y)
	popup.popup()

func _on_filter_option_selected(id):
	match id:
		0:  # Show Read Notifications
			filter_read = !filter_read
		2:  # All Types
			filter_type = -1
		3:  # Info
			filter_type = NotificationManager.NotificationType.INFO
		4:  # Warnings
			filter_type = NotificationManager.NotificationType.WARNING
		5:  # Alerts
			filter_type = NotificationManager.NotificationType.ALERT
		6:  # Shift Offers
			filter_type = NotificationManager.NotificationType.SHIFT_OFFER
		7:  # Overtime
			filter_type = NotificationManager.NotificationType.OVERTIME
		8:  # Time Off
			filter_type = NotificationManager.NotificationType.TIME_OFF
	
	# Update the list
	update_notification_list()

func _on_panel_gui_input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		# Check if click was outside the panel
		if not panel_container.get_global_rect().has_point(get_global_mouse_position()):
			hide_panel()
