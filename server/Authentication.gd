class_name Authentication
extends RefCounted

const HASH_ALGORITHM := "sha256"
const SALT_BYTES := 16

static func create_password_hash(password: String) -> Dictionary:
	if password.is_empty():
		push_error("Password cannot be empty.")
		return {"salt": "", "hash": ""}

	var crypto := Crypto.new()
	var salt := crypto.generate_random_bytes(SALT_BYTES)
	var password_bytes := password.to_utf8_buffer()
	var input := salt + password_bytes
	var digest := _sha256_digest(input)

	return {
		"salt": salt.hex_encode(),
		"hash": digest.hex_encode(),
		"algorithm": HASH_ALGORITHM,
		"value": "%s:%s" % [salt.hex_encode(), digest.hex_encode()]
	}

static func verify_password(password: String, stored_value: String) -> bool:
	if password.is_empty() or stored_value.is_empty():
		return false

	var parts := stored_value.split(":", false, 2)
	if parts.size() != 2:
		return false

	var salt_hex := parts[0]
	var expected_hash_hex := parts[1]
	if salt_hex.length() == 0 or expected_hash_hex.length() == 0:
		return false

	var salt := PackedByteArray()
	for index in range(0, salt_hex.length(), 2):
		var chunk := salt_hex.substr(index, 2)
		if chunk.length() != 2:
			return false
		salt.append(chunk.hex_to_int())

	var password_bytes := password.to_utf8_buffer()
	var digest := _sha256_digest(salt + password_bytes)
	return digest.hex_encode() == expected_hash_hex

static func _sha256_digest(data: PackedByteArray) -> PackedByteArray:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data)
	return ctx.finish()
