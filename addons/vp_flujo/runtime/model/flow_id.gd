@tool
class_name FlowId
extends RefCounted


static func create() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()


static func is_valid(value: String) -> bool:
	return value.length() == 32 and has_only_hexadecimal_characters(value)


static func has_only_hexadecimal_characters(value: String) -> bool:
	for character_index: int in value.length():
		if "0123456789abcdef".find(value.substr(character_index, 1).to_lower()) == -1:
			return false
	return true
