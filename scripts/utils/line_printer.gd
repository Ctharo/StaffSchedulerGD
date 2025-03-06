class_name LinePrinter extends Node

# Line Printer - Utility to generate PDFs of shift lines with assigned staff
# Requires the godot-pdf extension: https://github.com/timothyqiu/godot-pdf

signal print_completed(success: bool, path: String)
signal print_progress(current: int, total: int)

var schedule_manager: ScheduleManager
var organization_name: String = "Staff Schedule"
var pdf_save_path: String = "user://shift_lines.pdf"
var date_range_start: Dictionary
var date_range_end: Dictionary
var selected_site_id: String = ""
var selected_classification: String = ""
var print_dialog: FileDialog

# Colors for shift types
const SHIFT_COLORS = {
	"Day": Color(0.95, 0.95, 0.8),     # Light yellow
	"Evening": Color(0.8, 0.8, 0.95),  # Light blue
	"Night": Color(0.7, 0.7, 0.8),     # Dark blue-gray
	"Off": Color(0.9, 0.9, 0.9)        # Light gray
}

# Initialize with schedule manager reference
func init(p_schedule_manager: ScheduleManager):
	schedule_manager = p_schedule_manager
	
	# Set organization name
	if schedule_manager and schedule_manager.current_organization:
		organization_name = schedule_manager.current_organization.name
	
	# Create print dialog
	_create_print_dialog()
	
	# Set default date range to current month
	var current_date = Time.get_datetime_dict_from_system()
	
	# Start of month
	date_range_start = current_date.duplicate()
	date_range_start.day = 1
	
	# End of month
	date_range_end = current_date.duplicate()
	date_range_end.day = TimeUtility.days_in_month(current_date.year, current_date.month)

# Create file save dialog
func _create_print_dialog():
	print_dialog = FileDialog.new()
	print_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	print_dialog.access = FileDialog.ACCESS_FILESYSTEM
	print_dialog.filters = ["*.pdf; PDF Files"]
	print_dialog.title = "Save Line Schedule PDF"
	print_dialog.size = Vector2(800, 600)
	print_dialog.file_selected.connect(_on_file_selected)
	get_tree().root.add_child(print_dialog)

# Shows print setup dialog
func show_print_dialog(default_filename: String = ""):
	if default_filename.is_empty():
		var current_date = Time.get_datetime_dict_from_system()
		default_filename = "schedule_%04d_%02d.pdf" % [current_date.year, current_date.month]
	
	print_dialog.current_path = default_filename
	print_dialog.popup_centered()

# Handle file selection
func _on_file_selected(path: String):
	pdf_save_path = path
	
	# Now show date range selection dialog
	_show_print_options_dialog()

# Show print options dialog (date range, site, classification)
func _show_print_options_dialog():
	var dialog = AcceptDialog.new()
	dialog.title = "Print Options"
	dialog.size = Vector2(600, 500)
	
	var scroll = ScrollContainer.new()
	var container = VBoxContainer.new()
	scroll.add_child(container)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 15)
	
	# Date range selection
	var date_section = VBoxContainer.new()
	var date_label = Label.new()
	date_label.text = "Select date range:"
	date_section.add_child(date_label)
	
	var date_grid = GridContainer.new()
	date_grid.columns = 2
	
	var start_label = Label.new()
	start_label.text = "Start Date:"
	date_grid.add_child(start_label)
	
	# Load and add start date picker
	var date_picker_scene = load("res://scenes/ui/config/date_picker.tscn")
	var start_date_picker = date_picker_scene.instantiate()
	
	# Initialize with first day of current month
	var current_date = Time.get_datetime_dict_from_system()
	var start_date_str = "%04d-%02d-01" % [current_date.year, current_date.month]
	start_date_picker.selected_date = start_date_str
	date_grid.add_child(start_date_picker)
	
	var end_label = Label.new()
	end_label.text = "End Date:"
	date_grid.add_child(end_label)
	
	# Load and add end date picker
	var end_date_picker = date_picker_scene.instantiate()
	
	# Initialize with last day of current month
	var end_day = TimeUtility.days_in_month(current_date.year, current_date.month)
	var end_date_str = "%04d-%02d-%02d" % [current_date.year, current_date.month, end_day]
	end_date_picker.selected_date = end_date_str
	date_grid.add_child(end_date_picker)
	
	date_section.add_child(date_grid)
	container.add_child(date_section)
	
	# Site selection
	var site_section = VBoxContainer.new()
	var site_label = Label.new()
	site_label.text = "Select site (optional):"
	site_section.add_child(site_label)
	
	var site_selector = OptionButton.new()
	site_selector.add_item("All Sites")
	site_selector.set_item_metadata(0, "")
	
	var idx = 1
	for site_id in schedule_manager.current_schedule.sites:
		var site = schedule_manager.current_schedule.sites[site_id]
		site_selector.add_item(site.name)
		site_selector.set_item_metadata(idx, site.id)
		idx += 1
	
	site_section.add_child(site_selector)
	container.add_child(site_section)
	
	# Classification selection
	var class_section = VBoxContainer.new()
	var class_label = Label.new()
	class_label.text = "Select classification (optional):"
	class_section.add_child(class_label)
	
	var classification_selector = OptionButton.new()
	classification_selector.add_item("All Classifications")
	classification_selector.set_item_metadata(0, "")
	
	idx = 1
	for classification in schedule_manager.current_organization.classifications:
		classification_selector.add_item(classification)
		classification_selector.set_item_metadata(idx, classification)
		idx += 1
	
	class_section.add_child(classification_selector)
	container.add_child(class_section)
	
	# Print options
	var options_section = VBoxContainer.new()
	var options_label = Label.new()
	options_label.text = "Display options:"
	options_section.add_child(options_label)
	
	var show_empty_checkbox = CheckBox.new()
	show_empty_checkbox.text = "Show unassigned lines"
	show_empty_checkbox.button_pressed = true
	options_section.add_child(show_empty_checkbox)
	
	var color_shifts_checkbox = CheckBox.new()
	color_shifts_checkbox.text = "Use colors for shift types"
	color_shifts_checkbox.button_pressed = true
	options_section.add_child(color_shifts_checkbox)
	
	container.add_child(options_section)
	
	dialog.add_child(scroll)
	
	# Add confirmation handler
	dialog.confirmed.connect(
		func():
			# Parse start date
			var start_parts = start_date_picker.selected_date.split("-")
			date_range_start = {
				"year": int(start_parts[0]),
				"month": int(start_parts[1]),
				"day": int(start_parts[2]),
				"hour": 0,
				"minute": 0,
				"second": 0
			}
			
			# Parse end date
			var end_parts = end_date_picker.selected_date.split("-")
			date_range_end = {
				"year": int(end_parts[0]),
				"month": int(end_parts[1]),
				"day": int(end_parts[2]),
				"hour": 23,
				"minute": 59,
				"second": 59
			}
			
			# Get site and classification
			selected_site_id = site_selector.get_item_metadata(site_selector.selected)
			if classification_selector.selected > 0:
				selected_classification = classification_selector.get_item_text(classification_selector.selected)
			else:
				selected_classification = ""
			
			# Create PDF
			var options = {
				"show_empty_lines": show_empty_checkbox.button_pressed,
				"use_colors": color_shifts_checkbox.button_pressed
			}
			
			# Start the PDF generation
			generate_pdf(options)
	)
	
	get_tree().root.add_child(dialog)
	dialog.popup_centered()

# Generate the PDF with shift lines
func generate_pdf(options: Dictionary = {}):
	# Create PDF document
	var pdf = PDF.new()
	
	# Add a loading dialog
	var loading_dialog = AcceptDialog.new()
	loading_dialog.title = "Generating PDF"
	loading_dialog.dialog_text = "Generating shift line PDF..."
	loading_dialog.exclusive = true
	get_tree().root.add_child(loading_dialog)
	loading_dialog.popup_centered()
	
	# Allow UI to update
	await get_tree().process_frame
	
	# Get filtered shift lines
	var filtered_lines = _get_filtered_lines(options)
	
	# Set up the PDF document
	_setup_pdf_document(pdf)
	
	# Process each line
	var current_line = 0
	var total_lines = filtered_lines.size()
	
	for line in filtered_lines:
		# Update progress
		current_line += 1
		emit_signal("print_progress", current_line, total_lines)
		
		# Update loading dialog text
		loading_dialog.dialog_text = "Processing line %d of %d..." % [current_line, total_lines]
		await get_tree().process_frame
		
		# Add the line to the PDF
		_add_line_to_pdf(pdf, line, options)
	
	# Save the PDF
	var result = pdf.save(pdf_save_path)
	
	# Close loading dialog
	loading_dialog.hide()
	loading_dialog.queue_free()
	
	if result == OK:
		# Show success message
		var success_dialog = AcceptDialog.new()
		success_dialog.title = "PDF Generated"
		success_dialog.dialog_text = "PDF file successfully saved to:\n%s" % pdf_save_path
		get_tree().root.add_child(success_dialog)
		success_dialog.popup_centered()
		
		emit_signal("print_completed", true, pdf_save_path)
	else:
		# Show error message
		var error_dialog = AcceptDialog.new()
		error_dialog.title = "PDF Generation Failed"
		error_dialog.dialog_text = "Failed to save PDF file to:\n%s" % pdf_save_path
		get_tree().root.add_child(error_dialog)
		error_dialog.popup_centered()
		
		emit_signal("print_completed", false, pdf_save_path)

# Get filtered shift lines based on selection criteria
func _get_filtered_lines(options: Dictionary) -> Array:
	var filtered_lines = []
	var show_empty_lines = options.get("show_empty_lines", true)
	
	for line_id in schedule_manager.current_schedule.shift_lines:
		var line = schedule_manager.current_schedule.shift_lines[line_id]
		
		# Filter by site if specified
		if not selected_site_id.is_empty() and line.site_id != selected_site_id:
			continue
		
		# Filter by classification if specified
		if not selected_classification.is_empty() and line.classification != selected_classification:
			continue
		
		# Filter empty lines if option is disabled
		if not show_empty_lines and line.assigned_employee_id.is_empty():
			continue
		
		filtered_lines.append(line)
	
	# Sort lines by site, classification, and name
	filtered_lines.sort_custom(
		func(a, b):
			# First sort by site
			if a.site_id != b.site_id:
				return a.site_id < b.site_id
			
			# Then by classification
			if a.classification != b.classification:
				return a.classification < b.classification
			
			# Finally by name
			return a.name < b.name
	)
	
	return filtered_lines

# Set up the PDF document with metadata and styles
func _setup_pdf_document(pdf: PDF):
	# Set metadata
	pdf.set_title("Shift Line Schedule - %s" % organization_name)
	pdf.set_author("Staff Scheduler")
	pdf.set_creator("Staff Scheduler by Ctharo")
	
	# Set up page size (A4 landscape)
	pdf.set_page_size(PDF.PageSize.A4)
	pdf.set_page_orientation(PDF.PageOrientation.LANDSCAPE)
	
	# Add first page
	pdf.add_page()
	
	# Add header
	_add_header(pdf)

# Add header to the PDF
func _add_header(pdf: PDF):
	# Add organization name as title
	pdf.set_font("Helvetica", "B", 16)
	pdf.set_text_color(0, 0, 0)
	pdf.cell(0, 10, "Shift Line Schedule - %s" % organization_name, 0, 1, PDF.Align.CENTER)
	
	# Add date range
	pdf.set_font("Helvetica", "", 12)
	var date_range_text = "Period: %s to %s" % [
		_format_date(date_range_start),
		_format_date(date_range_end)
	]
	pdf.cell(0, 10, date_range_text, 0, 1, PDF.Align.CENTER)
	
	# Add filters if any
	var filters = []
	if not selected_site_id.is_empty():
		var site_name = "Unknown Site"
		if schedule_manager.current_schedule.sites.has(selected_site_id):
			site_name = schedule_manager.current_schedule.sites[selected_site_id].name
		filters.append("Site: %s" % site_name)
	
	if not selected_classification.is_empty():
		filters.append("Classification: %s" % selected_classification)
	
	if not filters.is_empty():
		pdf.cell(0, 10, "Filters: %s" % ", ".join(filters), 0, 1, PDF.Align.CENTER)
	
	# Add generation date
	var current_date = Time.get_datetime_dict_from_system()
	pdf.set_font("Helvetica", "I", 8)
	pdf.set_text_color(128, 128, 128)
	pdf.cell(0, 5, "Generated on: %s" % _format_date(current_date), 0, 1, PDF.Align.RIGHT)
	
	# Add some space
	pdf.ln(10)

# Add a single line to the PDF
func _add_line_to_pdf(pdf: PDF, line: ShiftLine, options: Dictionary):
	var use_colors = options.get("use_colors", true)
	
	# Get the employee assigned to this line
	var employee_name = "Unassigned"
	var employee_info = ""
	
	if not line.assigned_employee_id.is_empty():
		if schedule_manager.current_schedule.employees.has(line.assigned_employee_id):
			var employee = schedule_manager.current_schedule.employees[line.assigned_employee_id]
			employee_name = employee.get_full_name()
			employee_info = " (%s, %s)" % [employee.classification, employee.employment_status.capitalize()]
	
	# Line header
	pdf.set_font("Helvetica", "B", 12)
	pdf.set_text_color(0, 0, 0)
	pdf.set_fill_color(230, 230, 230)
	pdf.cell(0, 8, "%s - %s%s" % [line.name, employee_name, employee_info], 1, 1, PDF.Align.LEFT, true)
	
	# Calculate date range for this pattern
	var pattern_days = line.pattern_length
	if pattern_days <= 0:
		pattern_days = 14  # Default to two weeks if not specified
	
	var days_to_display = TimeUtility.days_between(date_range_start, date_range_end) + 1
	days_to_display = min(days_to_display, 31) # Limit to avoid too many columns
	
	# Create column headers
	_add_date_headers(pdf, days_to_display)
	
	# Calculate start date for pattern
	var pattern_start_date = line.start_date
	if pattern_start_date.is_empty():
		pattern_start_date = date_range_start
	
	# Create pattern row
	_add_pattern_row(pdf, line, pattern_start_date, days_to_display, use_colors)
	
	# Add some space after this line
	pdf.ln(5)

# Add date headers to the PDF
func _add_date_headers(pdf: PDF, days_to_display: int):
	var start_date = date_range_start
	
	# Set up column widths
	var date_width = 20
	var first_col_width = 50  # Width of the "Date" label column
	
	# Create header row
	pdf.set_font("Helvetica", "B", 8)
	pdf.set_text_color(0, 0, 0)
	pdf.set_fill_color(200, 200, 200)
	
	# First column
	pdf.cell(first_col_width, 6, "Date", 1, 0, PDF.Align.CENTER, true)
	
	# Date columns
	for i in range(days_to_display):
		var date = TimeUtility.add_days_to_date(start_date, i)
		var date_text = "%d/%d" % [date.day, date.month]
		
		# Highlight weekends
		var is_weekend = date.weekday == 0 or date.weekday == 6  # Sunday or Saturday
		if is_weekend:
			pdf.set_fill_color(220, 220, 220)
		else:
			pdf.set_fill_color(200, 200, 200)
		
		pdf.cell(date_width, 6, date_text, 1, 0, PDF.Align.CENTER, true)
	
	pdf.ln()
	
	# Create day of week row
	pdf.set_font("Helvetica", "", 8)
	
	# First column
	pdf.cell(first_col_width, 6, "Day", 1, 0, PDF.Align.CENTER, true)
	
	# Day of week columns
	for i in range(days_to_display):
		var date = TimeUtility.add_days_to_date(start_date, i)
		var day_names = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
		var day_text = day_names[date.weekday]
		
		# Highlight weekends
		var is_weekend = date.weekday == 0 or date.weekday == 6  # Sunday or Saturday
		if is_weekend:
			pdf.set_fill_color(220, 220, 220)
		else:
			pdf.set_fill_color(200, 200, 200)
		
		pdf.cell(date_width, 6, day_text, 1, 0, PDF.Align.CENTER, true)
	
	pdf.ln()

# Add pattern row to the PDF
func _add_pattern_row(pdf: PDF, line: ShiftLine, pattern_start_date: Dictionary, days_to_display: int, use_colors: bool):
	var start_date = date_range_start
	
	# Set up column widths
	var date_width = 20
	var first_col_width = 50  # Width of the "Shift" label column
	
	# Create shift row
	pdf.set_font("Helvetica", "", 10)
	pdf.set_text_color(0, 0, 0)
	
	# First column
	pdf.cell(first_col_width, 8, "Shift", 1, 0, PDF.Align.CENTER)
	
	# Get rotation pattern
	var rotation_pattern = line.rotation_pattern
	
	# Shift columns
	for i in range(days_to_display):
		var date = TimeUtility.add_days_to_date(start_date, i)
		
		# Calculate pattern day
		var days_since_start = TimeUtility.days_between(pattern_start_date, date)
		var pattern_day = days_since_start % line.pattern_length
		
		# Find shift for this day
		var shift_name = "Off"
		var start_time = ""
		var end_time = ""
		
		for pattern in rotation_pattern:
			if pattern.day_offset == pattern_day:
				shift_name = pattern.shift_name
				start_time = pattern.start_time
				end_time = pattern.end_time
				break
		
		# Display shift type
		var shift_text = shift_name
		if shift_name != "Off" and not start_time.is_empty() and not end_time.is_empty():
			shift_text = _format_shift_code(shift_name)
		
		# Color cell based on shift type if enabled
		if use_colors and SHIFT_COLORS.has(shift_name):
			var color = SHIFT_COLORS[shift_name]
			pdf.set_fill_color(
				int(color.r * 255),
				int(color.g * 255),
				int(color.b * 255)
			)
			pdf.cell(date_width, 8, shift_text, 1, 0, PDF.Align.CENTER, true)
		else:
			pdf.cell(date_width, 8, shift_text, 1, 0, PDF.Align.CENTER)
	
	pdf.ln()

# Format date for display
func _format_date(date: Dictionary) -> String:
	var month_names = ["January", "February", "March", "April", "May", "June", 
					  "July", "August", "September", "October", "November", "December"]
	
	return "%s %d, %d" % [month_names[date.month - 1], date.day, date.year]

# Format shift code
func _format_shift_code(shift_name: String) -> String:
	match shift_name:
		"Day":
			return "D"
		"Evening":
			return "E"
		"Night":
			return "N"
		_:
			return shift_name.substr(0, 1)

# Print all shift lines to PDF
func print_all_lines(options: Dictionary = {}):
	# Use current filters
	generate_pdf(options)
