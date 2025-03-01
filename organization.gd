class_name Organization extends Resource

@export var id: String
@export var name: String
@export var industry_type: String = "healthcare"  # healthcare, retail, manufacturing, etc.

# Overtime Rules
@export var overtime_rules: Array = []
# Example structure:
# [
#   {
#     "id": "daily_ot",
#     "name": "Daily OT",
#     "type": "daily",
#     "threshold": 8,  # hours
#     "multiplier": 1.5
#   },
#   {
#     "id": "weekly_ot",
#     "name": "Weekly OT",
#     "type": "weekly",
#     "threshold": 40,  # hours
#     "multiplier": 1.5
#   },
#   {
#     "id": "consecutive_days",
#     "name": "Consecutive Days",
#     "type": "consecutive_days",
#     "threshold": 6,  # days
#     "multiplier": 2.0
#   }
# ]

# Pay Period Settings
@export var pay_period_type: String = "biweekly"  # weekly, biweekly, semimonthly, monthly
@export var pay_period_start_day: int = 0  # 0 = Sunday, 6 = Saturday
@export var pay_period_start_date: Dictionary  # For the first pay period

# Shift Offering Rules
@export var shift_offering_rules: Array = []
# Example structure:
# [
#   {
#     "id": "tier1",
#     "name": "Straight Time Casuals",
#     "priority": 1,
#     "conditions": [
#       {"status": "casual", "pay_type": "straight"}
#     ],
#     "advance_days": 14,
#     "hours_until_auto_resolve": 72
#   },
#   {
#     "id": "tier2",
#     "name": "Straight Time Part-Time",
#     "priority": 2,
#     "conditions": [
#       {"status": "part_time", "pay_type": "straight"}
#     ],
#     "advance_days": 10,
#     "hours_until_auto_resolve": 48
#   },
#   {
#     "id": "tier3",
#     "name": "Overtime for Anyone",
#     "priority": 3,
#     "conditions": [
#       {"pay_type": "overtime"}
#     ],
#     "advance_days": 7,
#     "hours_until_auto_resolve": 24
#   },
#   {
#     "id": "tier4",
#     "name": "Split Shift Offering",
#     "priority": 4,
#     "conditions": [
#       {"split_shift": true}
#     ],
#     "advance_days": 3,
#     "hours_until_auto_resolve": 8
#   }
# ]

# Classification Types
@export var classifications: Array = []  # ["RN", "LPN", "CA"] for healthcare, etc.

# Site Types
@export var site_types: Array = []  # ["RHH", "HH"] for hospice, etc.

func _init(p_id: String = "", p_name: String = "") -> void:
	id = p_id if p_id else str(randi())
	name = p_name

func get_overtime_rule(rule_id: String) -> Dictionary:
	for rule in overtime_rules:
		if rule.id == rule_id:
			return rule
	return {}

func get_shift_offering_tier(tier_id: String) -> Dictionary:
	for tier in shift_offering_rules:
		if tier.id == tier_id:
			return tier
	return {}

func add_overtime_rule(rule: Dictionary) -> void:
	overtime_rules.append(rule)

func add_shift_offering_rule(rule: Dictionary) -> void:
	shift_offering_rules.append(rule)

func set_industry_defaults(industry: String) -> void:
	industry_type = industry
	
	# Set defaults based on industry
	match industry:
		"healthcare":
			classifications = ["RN", "LPN", "CA"]
			
			# Default OT rules for healthcare
			overtime_rules = [
				{
					"id": "daily_ot",
					"name": "Daily OT",
					"type": "daily",
					"threshold": 8,
					"multiplier": 1.5
				},
				{
					"id": "weekly_ot",
					"name": "Weekly OT",
					"type": "weekly",
					"threshold": 40,
					"multiplier": 1.5
				},
				{
					"id": "pay_period_ot",
					"name": "Pay Period OT",
					"type": "pay_period",
					"threshold": 80,  # for biweekly
					"multiplier": 1.5
				}
			]
			
			# Default shift offering rules for healthcare
			shift_offering_rules = [
				{
					"id": "tier1",
					"name": "Straight Time Casuals",
					"priority": 1,
					"conditions": [
						{"status": "casual", "pay_type": "straight"}
					],
					"advance_days": 14,
					"hours_until_auto_resolve": 72
				},
				{
					"id": "tier2",
					"name": "Straight Time Part-Time",
					"priority": 2,
					"conditions": [
						{"status": "part_time", "pay_type": "straight"}
					],
					"advance_days": 10,
					"hours_until_auto_resolve": 48
				},
				{
					"id": "tier3",
					"name": "Overtime for Anyone",
					"priority": 3,
					"conditions": [
						{"pay_type": "overtime"}
					],
					"advance_days": 7,
					"hours_until_auto_resolve": 24
				},
				{
					"id": "tier4",
					"name": "Split Shift Offering",
					"priority": 4,
					"conditions": [
						{"split_shift": true}
					],
					"advance_days": 3,
					"hours_until_auto_resolve": 8
				}
			]
		
		"retail":
			# Set defaults for retail industry
			classifications = ["Manager", "Supervisor", "Associate"]
			# ...and so on
			
		"manufacturing":
			# Set defaults for manufacturing industry
			classifications = ["Operator", "Technician", "Supervisor"]
			# ...and so on
			
	return
