class_name LineImporter
extends Node

# LineImporter - Utility to import shift patterns from spreadsheets
# This script handles importing XLS or CSV files and converting them to shift lines

var schedule_manager: ScheduleManager
var file_dialog: FileDialog
var date_dialog: AcceptDialog
var start_date_picker: Control
var site_selector: OptionButton
var classification_selector: OptionButton

# Initialize with schedule manager reference
func init(p_schedule_manager: ScheduleManager):
	schedule_manager = p_schedule_manager
	create_dialogs()

# Create necessary UI dialogs
func create_dialogs():
	# Create file selection dialog
	file_dialog = FileDialog.new()
	file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	file_dialog.access = FileDialog.ACCESS_FILESYSTEM
	file_dialog.filters = ["*.csv; CSV Files", "*.xls, *.xlsx; Excel Files"]
	file_dialog.title = "Import Shift Lines"
	file_dialog.size = Vector2(800, 600)
	file_dialog.file_selected.connect(_on_file_selected)
	get_tree().root.add_child(file_dialog)
	
	# Create date selection dialog
	date_dialog = AcceptDialog.new()
	date_dialog.title = "Set Start Date and Settings"
	date_dialog.size = Vector2(500, 300)
	
	var dialog_container = VBoxContainer.new()
	dialog_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 15)
	
	# Date picker section
	var date_section = VBoxContainer.new()
	var date_label = Label.new()
	date_label.text = "Select start date for first shift:"
	date_section.add_child(date_label)
	
	# Load and add date picker
	var date_picker_scene = load("res://scenes/ui/config/date_picker.tscn")
	start_date_picker = date_picker_scene.instantiate()
	
	# Initialize with current date
	var current_date = Time.get_datetime_dict_from_system()
	var date_str = "%04d-%02d-%02d" % [current_date.year, current_date.month, current_date.day]
	start_date_picker.selected_date = date_str
	
	date_section.add_child(start_date_picker)
	dialog_container.add_child(date_section)
	
	# Site selection
	var site_section = VBoxContainer.new()
	var site_label = Label.new()
	site_label.text = "Select site:"
	site_section.add_child(site_label)
	
	site_selector = OptionButton.new()
	site_section.add_child(site_selector)
	dialog_container.add_child(site_section)
	
	# Classification selection
	var class_section = VBoxContainer.new()
	var class_label = Label.new()
	class_label.text = "Select classification:"
	class_section.add_child(class_label)
	
	classification_selector = OptionButton.new()
	class_section.add_child(classification_selector)
	dialog_container.add_child(class_section)
	
	# Hint text
	var hint_label = Label.new()
	hint_label.text = "Note: First row of the file should contain line names.\nD = Day shift, E = Evening shift, N = Night shift"
	hint_label.theme_override_colors.font_color = Color(0.6, 0.6, 0.6)
	dialog_container.add_child(hint_label)
	
	date_dialog.add_child(dialog_container)
	date_dialog.confirmed.connect(_on_date_dialog_confirmed)
	get_tree().root.add_child(date_dialog)

# Populate site and classification selectors
func populate_selectors():
	# Clear current options
	site_selector.clear()
	classification_selector.clear()
	
	# Add sites
	for site_id in schedule_manager.current_schedule.sites:
		var site = schedule_manager.current_schedule.sites[site_id]
		site_selector.add_item(site.name)
		site_selector.set_item_metadata(site_selector.item_count - 1, site.id)
	
	# Add classifications
	for classification in schedule_manager.current_organization.classifications:
		classification_selector.add_item(classification)
	
	# Select first options by default
	if site_selector.item_count > 0:
		site_selector.select(0)
	
	if classification_selector.item_count > 0:
		classification_selector.select(0)

# Show the file selection dialog
func show_import_dialog():
	populate_selectors()
	file_dialog.popup_centered()

# Handle file selection
func _on_file_selected(path: String):
	# Store the selected path for later use
	var selected_path = path
	
	# Show the date selector dialog
	date_dialog.popup_centered()
	
	# Pass the path to the date confirmed callback
	date_dialog.custom_meta = {"selected_path": selected_path}

# Handle date dialog confirmation
func _on_date_dialog_confirmed():
	var selected_path = date_dialog.custom_meta.selected_path
	
	# Get selected settings
	var start_date_str = start_date_picker.selected_date
	var site_id = site_selector.get_item_metadata(site_selector.selected)
	var classification = classification_selector.get_item_text(classification_selector.selected)
	
	# Parse start date
	var date_parts = start_date_str.split("-")
	var start_date = {
		"year": int(date_parts[0]),
		"month": int(date_parts[1]),
		"day": int(date_parts[2]),
		"hour": 0,
		"minute": 0,
		"second": 0
	}
	
	# Process the file based on its extension
	var ext = selected_path.get_extension().to_lower()
	
	if ext == "csv":
		process_csv_file(selected_path, start_date, site_id, classification)
	elif ext == "xls" or ext == "xlsx":
		process_excel_file(selected_path, start_date, site_id, classification)
	else:
		show_error("Unsupported file type. Please select a CSV or Excel file.")

# Process CSV file
func process_csv_file(file_path: String, start_date: Dictionary, site_id: String, classification: String):
	# Load the file content
	var file = FileAccess.open(file_path, FileAccess.READ)
	if not file:
		show_error("Failed to open file: " + file_path)
		return
	
	var content = file.get_as_text()
	file.close()
	
	# Parse CSV
	var lines = []
	var rows = content.split("\n")
	
	# Parse header row for line names
	var header = rows[0].split(",")
	
	# Process each row (skipping header)
	for i in range(1, rows.size()):
		var row = rows[i].strip_edges()
		if row.is_empty():
			continue
			
		var columns = row.split(",")
		if columns.size() < 2:
			continue
			
		var line_name = columns[0].strip_edges()
		var shift_pattern = []
		
		for j in range(1, columns.size()):
			var cell_value = columns[j].strip_edges().to_upper()
			if cell_value in ["D", "E", "N"]:
				shift_pattern.append(cell_value)
		
		if not shift_pattern.is_empty():
			lines.append({
				"name": line_name,
				"pattern": shift_pattern
			})
	
	create_shift_lines(lines, start_date, site_id, classification)

# Process Excel file
func process_excel_file(file_path: String, start_date: Dictionary, site_id: String, classification: String):
	# Load the file content
	var file_data = FileAccess.get_file_as_bytes(file_path)
	if file_data.is_empty():
		show_error("Failed to read file: " + file_path)
		return
	
	# Parse Excel using SheetJS
	var workbook = null
	
	# Use try/catch since Excel parsing might fail
	var result = {
		"success": true,
		"error": ""
	}
	
	# Try to parse the Excel file using the built-in XLSX library
	# This has to be done with JavaScript and a callback pattern
	var js_code = """
	try {
		const data = new Uint8Array(%s);
		const workbook = XLSX.read(data, {type: 'array'});
		
		// Get first sheet
		const sheet_name = workbook.SheetNames[0];
		const sheet = workbook.Sheets[sheet_name];
		
		// Convert to JSON
		const json_data = XLSX.utils.sheet_to_json(sheet, {header: 1});
		
		// Format data for GDScript
		const formatted_data = [];
		
		// Skip empty rows
		for (let i = 1; i < json_data.length; i++) {
			const row = json_data[i];
			if (row && row.length > 1) {
				const line_name = String(row[0] || '').trim();
				const pattern = [];
				
				for (let j = 1; j < row.length; j++) {
					const cell = String(row[j] || '').trim().toUpperCase();
					if (['D', 'E', 'N'].includes(cell)) {
						pattern.push(cell);
					}
				}
				
				if (pattern.length > 0) {
					formatted_data.push({
						name: line_name,
						pattern: pattern
					});
				}
			}
		}
		
		result.data = formatted_data;
	} catch (e) {
		result.success = false;
		result.error = e.toString();
	}
	""" % [Array(file_data)]
	
	# Show loading indicator
	var loading_dialog = AcceptDialog.new()
	loading_dialog.title = "Processing Excel File"
	loading_dialog.dialog_text = "Reading Excel file, please wait..."
	loading_dialog.exclusive = true
	get_tree().root.add_child(loading_dialog)
	loading_dialog.popup_centered()
	
	# Allow UI to update
	await get_tree().process_frame
	
	# Execute JavaScript to parse Excel
	JavaScriptBridge.eval(js_code, true)
	
	# Close loading dialog
	loading_dialog.hide()
	loading_dialog.queue_free()
	
	# Check for errors
	if not result.success:
		show_error("Failed to parse Excel file: " + result.error)
		return
	
	# Process the parsed data
	var lines = result.data
	create_shift_lines(lines, start_date, site_id, classification)

# Create shift lines from the imported data
func create_shift_lines(lines_data, start_date: Dictionary, site_id: String, classification: String):
	var created_count = 0
	var error_count = 0
	
	# Process each line
	for line_data in lines_data:
		var line_name = line_data.name
		var pattern = line_data.pattern
		
		if pattern.is_empty():
			error_count += 1
			continue
		
		# Create a new shift line
		var line = ShiftLine.new("", line_name)
		line.site_id = site_id
		line.classification = classification
		line.pattern_length = pattern.size()
		line.start_date = start_date
		
		# Add each shift to the pattern
		for day_offset in range(pattern.size()):
			var shift_code = pattern[day_offset]
			var shift_name
			var start_time
			var end_time
			
			match shift_code:
				"D": # Day shift
					shift_name = "Day"
					start_time = "07:00" 
					end_time = "15:00"
				"E": # Evening shift
					shift_name = "Evening"
					start_time = "15:00"
					end_time = "23:00"
				"N": # Night shift
					shift_name = "Night"
					start_time = "23:00"
					end_time = "07:00"
				_:
					continue # Skip invalid codes
			
			line.add_pattern_shift(day_offset, shift_name, start_time, end_time)
		
		# Only add the line if it has shifts
		if line.rotation_pattern.size() > 0:
			schedule_manager.current_schedule.add_shift_line(line)
			created_count += 1
		else:
			error_count += 1
	
	# Save changes
	schedule_manager.save_schedule()
	
	# Show results
	var results_dialog = AcceptDialog.new()
	results_dialog.title = "Import Results"
	results_dialog.dialog_text = "Created %d shift lines.\n%d lines had errors and were skipped." % [created_count, error_count]
	get_tree().root.add_child(results_dialog)
	results_dialog.popup_centered()

# Show error message
func show_error(message: String):
	var error_dialog = AcceptDialog.new()
	error_dialog.title = "Import Error"
	error_dialog.dialog_text = message
	get_tree().root.add_child(error_dialog)
	error_dialog.popup_centered()
