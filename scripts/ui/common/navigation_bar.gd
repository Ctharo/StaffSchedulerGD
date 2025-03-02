extends PanelContainer

signal back_pressed
signal home_pressed

@onready var back_button = $HBoxContainer/BackButton
@onready var home_button = $HBoxContainer/HomeButton
@onready var screen_title = $HBoxContainer/ScreenTitle

var nav_manager: NavigationManager

func _ready():
	# Connect button signals
	back_button.connect("pressed", _on_back_button_pressed)
	home_button.connect("pressed", _on_home_button_pressed)
	
	# Initially disable back button
	back_button.disabled = true

func initialize(p_nav_manager: NavigationManager):
	nav_manager = p_nav_manager
	
	# Connect to navigation manager signals
	nav_manager.connect("navigation_stack_updated", _on_navigation_stack_updated)

func set_screen_title(title: String):
	screen_title.text = title

func _on_back_button_pressed():
	emit_signal("back_pressed")

func _on_home_button_pressed():
	emit_signal("home_pressed")

func _on_navigation_stack_updated(stack: Array):
	# Enable back button only if we have somewhere to go back to
	var can_go_back = not stack.is_empty()
	
	# Also consider if we have unsaved changes
	var can_navigate = true
	if nav_manager:
		can_navigate = nav_manager.can_navigate_away_from_current()
	
	back_button.disabled = not (can_go_back and can_navigate)
