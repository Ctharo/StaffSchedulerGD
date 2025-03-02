class_name PermissionGuard extends Control

@export var required_permission: String = ""
@export var hide_when_denied: bool = true
@export var disable_when_denied: bool = false
@export var show_permission_tooltip: bool = true

var role_manager: UserRoleManager

func _ready():
	# Find role manager in the tree
	role_manager = _find_role_manager()
	
	if role_manager:
		# Connect to role changed signal
		role_manager.connect("role_changed", _on_role_changed)
		
		# Initial check
		_check_permission()
	else:
		push_warning("PermissionGuard: No UserRoleManager found in the scene tree")
		visible = true

func _find_role_manager() -> UserRoleManager:
	var node = self
	while node:
		node = node.get_parent()
		if node is UserRoleManager:
			return node
		
		# Check children of parent nodes too
		if node:
			for child in node.get_children():
				if child is UserRoleManager:
					return child
	
	# Try to find in autoloads
	if Engine.has_singleton("UserRoleManager"):
		return Engine.get_singleton("UserRoleManager")
	
	return null

func _on_role_changed(_new_role):
	_check_permission()

func _check_permission():
	if not role_manager or required_permission.is_empty():
		return
	
	var has_permission = role_manager.has_permission(required_permission)
	var target = get_parent()
	
	if has_permission:
		# Grant access
		if hide_when_denied:
			target.visible = true
		
		if disable_when_denied:
			if target is BaseButton:
				target.disabled = false
			elif target.has_method("set_editable"):
				target.set_editable(true)
				
		if show_permission_tooltip:
			target.tooltip_text = ""
	else:
		# Deny access
		if hide_when_denied:
			target.visible = false
		
		if disable_when_denied:
			if target is BaseButton:
				target.disabled = true
			elif target.has_method("set_editable"):
				target.set_editable(false)
		
		if show_permission_tooltip and not hide_when_denied:
			target.tooltip_text = "You don't have permission to " + \
				role_manager._get_action_description(required_permission)
