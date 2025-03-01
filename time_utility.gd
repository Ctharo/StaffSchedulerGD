class_name TimeUtility extends RefCounted

static func is_date_in_range(date: Dictionary, start_date: Dictionary, end_date: Dictionary) -> bool:
	# Convert to unix timestamps for comparison
	var timestamp = Time.get_unix_time_from_datetime_dict(date)
	var start_timestamp = Time.get_unix_time_from_datetime_dict(start_date)
	var end_timestamp = Time.get_unix_time_from_datetime_dict(end_date)
	
	return timestamp >= start_timestamp and timestamp <= end_timestamp

static func same_date(date1: Dictionary, date2: Dictionary) -> bool:
	return date1.year == date2.year and date1.month == date2.month and date1.day == date2.day

static func parse_time_to_minutes(time_str: String) -> int:
	# Parse "HH:MM" format to minutes since midnight
	var parts = time_str.split(":")
	if parts.size() != 2:
		return -1
		
	var hours = int(parts[0])
	var minutes = int(parts[1])
	
	return hours * 60 + minutes

static func is_time_overlapping(start1: String, end1: String, start2: String, end2: String) -> bool:
	var start1_min = parse_time_to_minutes(start1)
	var end1_min = parse_time_to_minutes(end1)
	var start2_min = parse_time_to_minutes(start2)
	var end2_min = parse_time_to_minutes(end2)
	
	# Handle overnight shifts
	if end1_min < start1_min:
		end1_min += 24 * 60
	if end2_min < start2_min:
		end2_min += 24 * 60
	
	return max(start1_min, start2_min) < min(end1_min, end2_min)

static func calculate_hours_between(start_time: String, end_time: String) -> float:
	var start_minutes = parse_time_to_minutes(start_time)
	var end_minutes = parse_time_to_minutes(end_time)
	
	if end_minutes < start_minutes:  # Overnight shift
		end_minutes += 24 * 60
		
	return float(end_minutes - start_minutes) / 60.0

static func add_days_to_date(date: Dictionary, days: int) -> Dictionary:
	var unix_time = Time.get_unix_time_from_datetime_dict(date)
	unix_time += days * 86400  # 86400 seconds in a day
	return Time.get_datetime_dict_from_unix_time(unix_time)

static func get_week_start_date(date: Dictionary) -> Dictionary:
	# Get the previous Sunday
	var weekday = date.weekday  # 0=Sunday, 6=Saturday
	return add_days_to_date(date, -weekday)

static func days_between(date1: Dictionary, date2: Dictionary) -> int:
	var unix1 = Time.get_unix_time_from_datetime_dict(date1)
	var unix2 = Time.get_unix_time_from_datetime_dict(date2)
	
	return int((unix2 - unix1) / 86400)  # 86400 seconds in a day

static func compare_dates(date1: Dictionary, date2: Dictionary) -> int:
	var unix1 = Time.get_unix_time_from_datetime_dict(date1)
	var unix2 = Time.get_unix_time_from_datetime_dict(date2)
	
	if unix1 < unix2:
		return -1
	elif unix1 > unix2:
		return 1
	else:
		return 0

static func get_shift_name_from_time(start_time: String) -> String:
	var hour = int(start_time.split(":")[0])
	
	if hour >= 7 and hour < 15:
		return "Day"
	elif hour >= 15 and hour < 23:
		return "Evening"
	else:
		return "Night"

static func get_aligned_pay_period_start(date: Dictionary, period_type: String, start_day: int) -> Dictionary:
	# Returns the start date of the pay period containing the given date
	match period_type:
		"weekly":
			# Find the previous occurrence of start_day
			var day_diff = (date.weekday - start_day + 7) % 7
			return add_days_to_date(date, -day_diff)
			
		"biweekly":
			# Find the previous occurrence of start_day
			var day_diff = (date.weekday - start_day + 7) % 7
			var prev_period_start = add_days_to_date(date, -day_diff)
			
			# Check if this is the correct biweekly period or if we need to go back another week
			# This would require some knowledge of a reference biweekly date
			# For simplicity, we're assuming the current date's period is correct
			return prev_period_start
			
		"semimonthly":
			var result = date.duplicate()
			# First period: 1st to 15th, Second period: 16th to end of month
			if date.day <= 15:
				result.day = 1
			else:
				result.day = 16
			return result
			
		"monthly":
			var result = date.duplicate()
			result.day = 1
			return result
			
	return date.duplicate()  # Default fallback

static func get_next_pay_period_start(current_start: Dictionary, period_type: String, periods_ahead: int = 1) -> Dictionary:
	match period_type:
		"weekly":
			return add_days_to_date(current_start, 7 * periods_ahead)
			
		"biweekly":
			return add_days_to_date(current_start, 14 * periods_ahead)
			
		"semimonthly":
			var result = current_start.duplicate()
			
			# If starting on the 1st, next is the 16th
			if result.day == 1:
				result.day = 16
				if periods_ahead > 1:
					result = get_next_pay_period_start(result, period_type, periods_ahead - 1)
				return result
				
			# If starting on the 16th, next is the 1st of next month
			var days_in_month = days_in_month(result.year, result.month)
			var days_to_add = days_in_month - result.day + 1
			result = add_days_to_date(result, days_to_add)
			
			if periods_ahead > 1:
				result = get_next_pay_period_start(result, period_type, periods_ahead - 1)
			
			return result
			
		"monthly":
			var result = current_start.duplicate()
			for i in range(periods_ahead):
				result.month += 1
				if result.month > 12:
					result.month = 1
					result.year += 1
			return result
			
	return current_start.duplicate()  # Default fallback

static func get_pay_period_end(period_start: Dictionary, period_type: String) -> Dictionary:
	match period_type:
		"weekly":
			return add_days_to_date(period_start, 6)
			
		"biweekly":
			return add_days_to_date(period_start, 13)
			
		"semimonthly":
			var result = period_start.duplicate()
			
			# If starting on the 1st, end is the 15th
			if result.day == 1:
				result.day = 15
				return result
				
			# If starting on the 16th, end is the last day of the month
			result.day = days_in_month(result.year, result.month)
			return result
			
		"monthly":
			var result = period_start.duplicate()
			result.day = days_in_month(result.year, result.month)
			return result
			
	return period_start.duplicate()  # Default fallback

static func days_in_month(year: int, month: int) -> int:
	match month:
		2:  # February
			if (year % 4 == 0 and year % 100 != 0) or year % 400 == 0:
				return 29  # Leap year
			else:
				return 28
		4, 6, 9, 11:  # April, June, September, November
			return 30
		_:  # January, March, May, July, August, October, December
			return 31

static func add_hours_to_datetime(datetime: Dictionary, hours: int) -> Dictionary:
	var unix_time = Time.get_unix_time_from_datetime_dict(datetime)
	unix_time += hours * 3600  # 3600 seconds in an hour
	return Time.get_datetime_dict_from_unix_time(unix_time)
