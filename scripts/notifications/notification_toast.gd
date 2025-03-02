class_name NotificationToast extends Control

signal dismissed(notification_id)
signal action_triggered(notification_id, action_type)

@export var auto_dismiss_time: float = 5.0
@export var show_animation_time: float = 0.3
@export var dismiss_animation_time: float = 0.2

var notification_data: Dictionary
var is_showing: bool = false
var dismiss_timer: Timer

# UI References
@onready var title_label = $PanelContainer/VBoxContainer/HBoxContainer/VBoxContainer/TitleLabel
@onready var message_label = $PanelContainer/VBoxContainer/MessageLabel
@onready var icon_texture = $PanelContainer/VBoxContainer/HBoxContainer/IconTexture
@onready var dismiss_button = $PanelContainer/VBoxContainer/HBoxContainer/DismissButton
@onready var action_button = $PanelContainer/VBoxContainer/ActionButton

func _ready():
	# Set up dismiss timer
	dismiss_timer = Timer.new()
	dismiss_timer.one_shot = true
	add_child(dismiss_timer)
	dismiss_timer.timeout.connect(_on_dismiss_timer_timeout)
	
	# Connect buttons
	dismiss_button.connect("pressed", _on_dismiss_button_pressed)
	action_button.connect("pressed", _on_action_button_pressed)
	
	# Initial state
	modulate.a = 0
	visible = false

func show_notification(notification: Dictionary):
	notification_data = notification
	
	# Set content
	title_label.text = notification.title
	message_label.text = notification.message
	
	# Set appropriate icon based on notification type
	set_notification_icon(notification.type)
	
	# Show/hide action button based on action data
	action_button.visible = not notification.action_data.is_empty()
	if action_button.visible:
		action_button.text = notification.action_data.get("button_text", "View")
	
	# Show the toast
	visible = true
	is_showing = true
	
	# Animate in
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 1.0, show_animation_time)
	tween.tween_property(self, "position:y", position.y + 10, show_animation_time).from(position.y)
	
	# Start auto-dismiss timer if enabled
	if auto_dismiss_time > 0:
		dismiss_timer.start(auto_dismiss_time)

func dismiss():
	if not is_showing:
		return
		
	is_showing = false
	
	# Stop timer if running
	if dismiss_timer.time_left > 0:
		dismiss_timer.stop()
	
	# Animate out
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, dismiss_animation_time)
	tween.tween_property(self, "position:y", position.y - 10, dismiss_animation_time)
	tween.tween_callback(func(): visible = false)
	
	# Emit signal
	emit_signal("dismissed", notification_data.id)

func set_notification_icon(type: int):
	var icon_path = "res://resources/icons/"
	
	match type:
		NotificationManager.NotificationType.INFO:
			icon_path += "info_icon.png"
		NotificationManager.NotificationType.WARNING:
			icon_path += "warning_icon.png"
		NotificationManager.NotificationType.ALERT:
			icon_path += "alert_icon.png"
		NotificationManager.NotificationType.SHIFT_OFFER:
			icon_path += "shift_offer_icon.png"
		NotificationManager.NotificationType.OVERTIME:
			icon_path += "overtime_icon.png"
		NotificationManager.NotificationType.TIME_OFF:
			icon_path += "time_off_icon.png"
		NotificationManager.NotificationType.SCHEDULE:
			icon_path += "schedule_icon.png"
		NotificationManager.NotificationType.ASSIGNMENT:
			icon_path += "assignment_icon.png"
		_:
			icon_path += "info_icon.png"
	
	# Load icon
	var icon = load(icon_path)
	if icon:
		icon_texture.texture = icon

func _on_dismiss_button_pressed():
	dismiss()

func _on_dismiss_timer_timeout():
	dismiss()

func _on_action_button_pressed():
	var action_type = notification_data.action_data.get("action_type", "view")
	emit_signal("action_triggered", notification_data.id, action_type)
	dismiss()
