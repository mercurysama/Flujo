class_name FlowId
extends RefCounted


static func create() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()
