class_name FlowFSMDataValidator
extends RefCounted

## Exclude live Godot instances and unbounded nested data from snapshots.
const MAX_DEPTH: int = 8
const MAX_ENTRIES: int = 256
const MAX_JSON_LENGTH: int = 65536


static func valid_dictionary(value: Dictionary) -> bool:
	if not valid(value):
		return false
	return JSON.stringify(value).length() <= MAX_JSON_LENGTH


static func valid(value: Variant, depth: int = 0) -> bool:
	if depth > MAX_DEPTH:
		return false
	match typeof(value):
		TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING:
			return true
		TYPE_FLOAT:
			return is_finite(float(value))
		TYPE_ARRAY:
			var array: Array = value as Array
			if array.size() > MAX_ENTRIES:
				return false
			for child: Variant in array:
				if not valid(child, depth + 1):
					return false
			return true
		TYPE_DICTIONARY:
			var dictionary: Dictionary = value as Dictionary
			if dictionary.size() > MAX_ENTRIES:
				return false
			for key: Variant in dictionary.keys():
				if typeof(key) != TYPE_STRING or not valid(dictionary[key], depth + 1):
					return false
			return true
	return false
