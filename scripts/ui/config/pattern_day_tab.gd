extends PanelContainer

var day_number: int = 0
var day_name: String = "Day"

# UI References
@onready var day_label = $VBoxContainer/DayLabel
@onready var shift_option = $VBoxContainer/ShiftOption
@onready var time_container = $VBoxContainer/TimeContainer
@onready var start_time_edit = $VBoxContainer/TimeContainer/StartTimeEdit
@onready var end_time_edit = $VBoxContainer/TimeContainer/EndTimeEdit

func _ready():
	day_label.text = "Day " + str(day_number + 1) + " (" + day_name + ")"
	
	# Set up shift types
	shift_option.clear()
	shift_option.add_item("Off")
	shift_option.add_item("Day")
	shift_option.add_item("Evening")
	shift_option.add_item("Night")
	
	# Connect signals
	shift_option.connect("item_selected", _on_shift_type_changed)
	
	# Default to Off
	shift_option.select(0)
	_on_shift_type_changed(0)

func _on_shift_type_changed(idx):
	var shift_name = shift_option.get_item_text(idx)
	
	# Show/hide time inputs based on shift type
	time_container.visible = shift_name != "Off"
	
	# Set default times based on shift type
	if shift_name != "Off":
		match shift_name:
			"Day":
				start_time_edit.text = "07:00"
				end_time_edit.text = "19:00"
			"Evening":
				start_time_edit.text = "15:00"
				end_time_edit.text = "23:00"
			"Night":
				start_time_edit.text = "23:00"
				end_time_edit.text = "07:00"

func get_shift_name() -> String:
	return shift_option.get_item_text(shift_option.get_selected_id())

func get_start_time() -> String:
	return start_time_edit.text

func get_end_time() -> String:
	return end_time_edit.text

func set_shift_name(name: String) -> void:
	for i in range(shift_option.get_item_count()):
		if shift_option.get_item_text(i) == name:
			shift_option.select(i)
			_on_shift_type_changed(i)
			break

func set_shift_times(start_time: String, end_time: String) -> void:
	start_time_edit.text = start_time
	end_time_edit.text = end_time
