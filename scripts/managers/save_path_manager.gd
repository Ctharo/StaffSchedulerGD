class_name SavePathManager extends Node

# Resolves paths differently depending on environment
# Handles backup and recovery operations

enum SaveEnvironment {
	PRODUCTION,  # Normal app running from exported package
	DEVELOPMENT, # Running from Godot editor
	TEST         # Testing environment with separate save location
}

# Current environment mode
var current_environment: int = SaveEnvironment.PRODUCTION

# Base paths for different environments
var production_path: String = "user://"
var development_path: String = "user://dev/"
var test_path: String = "user://test/"

# Backup settings
var max_backups: int = 5
var create_backups: bool = true

# Initialize with automatic environment detection
func _init() -> void:
	# Auto-detect if we're running in the editor
	if OS.has_feature("editor"):
		current_environment = SaveEnvironment.DEVELOPMENT
		print_debug("Running in DEVELOPMENT mode")
	else:
		print_debug("Running in PRODUCTION mode")

# Get the appropriate base path for the current environment
func get_base_path() -> String:
	match current_environment:
		SaveEnvironment.PRODUCTION:
			return production_path
		SaveEnvironment.DEVELOPMENT:
			return development_path
		SaveEnvironment.TEST:
			return test_path
		_:
			return production_path

# Resolve a resource path for the current environment
func resolve_path(resource_name: String) -> String:
	# Ensure directories exist
	var base = get_base_path()
	var dir = DirAccess.open("user://")
	
	if not dir.dir_exists(base.trim_prefix("user://")):
		dir.make_dir_recursive(base.trim_prefix("user://"))
	
	return base + resource_name

# Create a backup of a resource file
func create_backup(resource_path: String) -> bool:
	if not create_backups:
		return true
		
	var full_path = resolve_path(resource_path)
	
	if not FileAccess.file_exists(full_path):
		return false
		
	# Create backup with timestamp
	var timestamp = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var backup_path = full_path + "." + timestamp + ".bak"
	
	var dir = DirAccess.open("user://")
	var error = dir.copy(full_path, backup_path)
	
	if error == OK:
		# Manage maximum backups - remove oldest if needed
		_cleanup_old_backups(resource_path)
		return true
	
	return false

# Delete oldest backups if we exceed the maximum
func _cleanup_old_backups(resource_path: String) -> void:
	var base_path = resolve_path(resource_path)
	var dir = DirAccess.open("user://")
	
	# Find all backup files for this resource
	var backups = []
	if dir.open("user://"):
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.begins_with(resource_path) and file_name.ends_with(".bak"):
				backups.append(file_name)
			file_name = dir.get_next()
	
	# Sort by date (oldest first)
	backups.sort()
	
	# Remove oldest backups if we have too many
	while backups.size() > max_backups:
		var oldest = backups[0]
		dir.remove(oldest)
		backups.remove_at(0)

# Return list of available backups for a resource
func get_available_backups(resource_path: String) -> Array:
	var base_path = resolve_path(resource_path)
	var dir = DirAccess.open("user://")
	
	var backups = []
	if dir.open("user://"):
		dir.list_dir_begin()
		var file_name = dir.get_next()
		
		while file_name != "":
			if file_name.begins_with(resource_path) and file_name.ends_with(".bak"):
				# Extract timestamp from filename
				var timestamp = file_name.substr(
					resource_path.length() + 1, 
					file_name.length() - resource_path.length() - 5
				)
				backups.append({
					"filename": file_name,
					"timestamp": timestamp
				})
			file_name = dir.get_next()
	
	# Sort by date (newest first)
	backups.sort_custom(func(a, b): return a["timestamp"] > b["timestamp"])
	
	return backups

# Restore from a backup
func restore_from_backup(resource_path: String, backup_filename: String) -> bool:
	var full_path = resolve_path(resource_path)
	var backup_path = "user://" + backup_filename
	
	if not FileAccess.file_exists(backup_path):
		return false
	
	# Create a backup of current file before restoring
	create_backup(resource_path)
	
	# Copy backup to main file
	var dir = DirAccess.open("user://")
	return dir.copy(backup_path, full_path) == OK

# Show the current save location (for debugging)
func get_absolute_save_path() -> String:
	# This will show the actual OS path for the current environment
	var test_file = "temp_location_check.txt"
	var test_path = resolve_path(test_file)
	
	# Create a temporary file
	var file = FileAccess.open(test_path, FileAccess.WRITE)
	file.store_string("test")
	file.close()
	
	# Get the OS path
	var os_path = ProjectSettings.globalize_path(test_path)
	
	# Clean up
	var dir = DirAccess.open("user://")
	dir.remove(test_path)
	
	return os_path.replace(test_file, "")
