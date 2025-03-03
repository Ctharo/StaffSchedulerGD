extends VBoxContainer

signal config_saved(section_name)

var schedule_manager: ScheduleManager

# UI References
@onready var sites_list = %SitesList
@onready var site_id_edit = %IDEdit
@onready var site_name_edit = %NameEdit
@onready var site_address_edit = %AddressEdit
@onready var site_phone_edit = %PhoneEdit
@onready var add_site_button = %AddSiteButton
@onready var remove_site_button = %RemoveSiteButton
@onready var save_site_button = %SaveButton

# Currently selected site
var selected_site: Site

func init(manager: ScheduleManager):
	schedule_manager = manager
	
	ensure_schedule_exists()
	
	load_sites_list()
	
func ensure_schedule_exists():
	# Make sure the schedule exists
	if schedule_manager.current_schedule == null:
		schedule_manager.current_schedule = Schedule.new()
		schedule_manager.save_schedule()
	
	# Make sure sites dictionary exists
	if schedule_manager.current_schedule.sites == null:
		schedule_manager.current_schedule.sites = {}
		schedule_manager.save_schedule()

func load_sites_list():
	sites_list.clear()
	
	if schedule_manager.current_schedule == null or schedule_manager.current_schedule.sites == null:
		clear_site_details()
		remove_site_button.disabled = true
		return
	
	# Add each site to the list
	for site_id in schedule_manager.current_schedule.sites:
		var site = schedule_manager.current_schedule.sites[site_id]
		sites_list.add_item(site.name + " (" + site.id + ")")
		sites_list.set_item_metadata(sites_list.get_item_count() - 1, site.id)
	
	# Clear site details panel
	clear_site_details()
	
	# Disable remove button if no sites
	remove_site_button.disabled = sites_list.get_item_count() == 0

func clear_site_details():
	site_id_edit.text = ""
	site_name_edit.text = ""
	site_address_edit.text = ""
	site_phone_edit.text = ""
	selected_site = null
	save_site_button.disabled = true

func _on_add_site_button_pressed():
	# Create a new empty site
	var new_site = Site.new("", "New Site")
	
	# Add to schedule
	schedule_manager.current_schedule.add_site(new_site)
	schedule_manager.save_schedule()
	
	# Reload sites list
	load_sites_list()
	
	# Select the new site
	for i in range(sites_list.get_item_count()):
		if sites_list.get_item_metadata(i) == new_site.id:
			sites_list.select(i)
			_on_site_selected(i)
			break

func _on_remove_site_button_pressed():
	var selected_idx = sites_list.get_selected_items()[0]
	var site_id = sites_list.get_item_metadata(selected_idx)
	
	# Create confirmation dialog
	var confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.dialog_text = "Are you sure you want to delete this site? This will also remove any shifts and requirements associated with the site."
	confirm_dialog.get_ok_button().connect("pressed", _confirm_remove_site.bind(site_id))
	add_child(confirm_dialog)
	confirm_dialog.popup_centered()

func _confirm_remove_site(site_id):
	# Remove site from schedule
	var sites = schedule_manager.current_schedule.sites
	if sites.has(site_id):
		sites.erase(site_id)
		
		# TODO: Also remove related shifts, requirements, etc.
		
		schedule_manager.save_schedule()
		
		# Reload sites list
		load_sites_list()
		
		emit_signal("config_saved", "Site removed")

func _on_site_selected(idx):
	var site_id = sites_list.get_item_metadata(idx)
	selected_site = schedule_manager.current_schedule.sites[site_id]
	
	# Update details panel
	site_id_edit.text = selected_site.id
	site_name_edit.text = selected_site.name
	site_address_edit.text = selected_site.address
	site_phone_edit.text = selected_site.phone
	
	save_site_button.disabled = false

func _on_save_site_button_pressed():
	if selected_site:
		# Update site details
		selected_site.id = site_id_edit.text
		selected_site.name = site_name_edit.text
		selected_site.address = site_address_edit.text
		selected_site.phone = site_phone_edit.text
		
		# Save changes
		schedule_manager.save_schedule()
		
		# Reload sites list to reflect any name changes
		load_sites_list()
		
		emit_signal("config_saved", "Site")

func get_config_data():
	var sites_data = []
	
	for site_id in schedule_manager.current_schedule.sites:
		var site = schedule_manager.current_schedule.sites[site_id]
		sites_data.append({
			"id": site.id,
			"name": site.name,
			"address": site.address,
			"phone": site.phone
		})
	
	return sites_data

func import_config_data(data):
	if data is Array:
		# Clear existing sites first
		schedule_manager.current_schedule.sites.clear()
		
		# Add imported sites
		for site_data in data:
			var site = Site.new(
				site_data.get("id", ""),
				site_data.get("name", "")
			)
			site.address = site_data.get("address", "")
			site.phone = site_data.get("phone", "")
			
			schedule_manager.current_schedule.add_site(site)
		
		# Save changes
		schedule_manager.save_schedule()
		
		# Reload sites list
		load_sites_list()
