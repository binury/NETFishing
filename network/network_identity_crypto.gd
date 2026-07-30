class_name NetworkIdentityCrypto
extends RefCounted

const ALGORITHM: String = "RSA-3072-SHA256"
const FINGERPRINT_LENGTH: int = 64
const MAX_PUBLIC_KEY_BYTES: int = 8192
const MAX_SIGNATURE_BYTES: int = 1024
const DOMAIN_PREFIX: String = "NETFISHING"
const IDENTITY_VERSION: String = "identity_v1"


static func normalize_public_pem(value: String) -> String:
	var normalized := value.replace("\r\n", "\n").replace("\r", "\n").strip_edges()
	return normalized + "\n" if not normalized.is_empty() else ""


static func fingerprint_public_pem(value: String) -> String:
	var normalized := normalize_public_pem(value)
	return normalized.sha256_text() if not normalized.is_empty() else ""


static func valid_fingerprint(value: Variant) -> bool:
	if typeof(value) != TYPE_STRING:
		return false
	var text := str(value)
	if text.length() != FINGERPRINT_LENGTH:
		return false
	for character: String in text:
		if character not in "0123456789abcdef":
			return false
	return true


static func format_fingerprint(value: String, groups: int = 5) -> String:
	if not valid_fingerprint(value):
		return "Unavailable"
	var visible := value.left(clampi(groups, 1, 8) * 4).to_upper()
	var parts := PackedStringArray()
	for offset: int in range(0, visible.length(), 4):
		parts.append(visible.substr(offset, 4))
	return "-".join(parts)


static func compact_suffix(value: String) -> String:
	return value.right(6).to_upper() if valid_fingerprint(value) else "??????"


static func secure_id(byte_count: int = 16) -> String:
	return Crypto.new().generate_random_bytes(byte_count).hex_encode()


static func canonical_bytes(domain: String, fields: Array) -> PackedByteArray:
	var output := PackedByteArray()
	_append_string(output, DOMAIN_PREFIX)
	_append_string(output, IDENTITY_VERSION)
	_append_string(output, domain)
	for value: Variant in fields:
		match typeof(value):
			TYPE_STRING, TYPE_STRING_NAME:
				output.append(1)
				_append_string(output, str(value))
			TYPE_INT:
				output.append(2)
				_append_i64(output, int(value))
			TYPE_BOOL:
				output.append(3)
				output.append(1 if bool(value) else 0)
			TYPE_PACKED_BYTE_ARRAY:
				output.append(4)
				_append_bytes(output, value)
			_:
				return PackedByteArray()
	return output


static func digest(domain: String, fields: Array) -> PackedByteArray:
	var bytes := canonical_bytes(domain, fields)
	if bytes.is_empty():
		return PackedByteArray()
	var context := HashingContext.new()
	if context.start(HashingContext.HASH_SHA256) != OK:
		return PackedByteArray()
	context.update(bytes)
	return context.finish()


static func sign_fields(
	private_key: CryptoKey, domain: String, fields: Array
) -> PackedByteArray:
	if private_key == null:
		return PackedByteArray()
	var value := digest(domain, fields)
	return (
		Crypto.new().sign(HashingContext.HASH_SHA256, value, private_key)
		if not value.is_empty() else PackedByteArray()
	)


static func verify_fields(
	public_key: CryptoKey,
	domain: String,
	fields: Array,
	signature: PackedByteArray,
) -> bool:
	if (
		public_key == null
		or signature.is_empty()
		or signature.size() > MAX_SIGNATURE_BYTES
	):
		return false
	var value := digest(domain, fields)
	return (
		not value.is_empty()
		and Crypto.new().verify(
			HashingContext.HASH_SHA256, value, signature, public_key
		)
	)


static func load_public_key(public_pem: String) -> CryptoKey:
	var normalized := normalize_public_pem(public_pem)
	if normalized.is_empty() or normalized.to_utf8_buffer().size() > MAX_PUBLIC_KEY_BYTES:
		return null
	var key := CryptoKey.new()
	return key if key.load_from_string(normalized, true) == OK else null


static func _append_string(output: PackedByteArray, value: String) -> void:
	_append_bytes(output, value.to_utf8_buffer())


static func _append_bytes(output: PackedByteArray, value: PackedByteArray) -> void:
	_append_u32(output, value.size())
	output.append_array(value)


static func _append_u32(output: PackedByteArray, value: int) -> void:
	for shift: int in [24, 16, 8, 0]:
		output.append((value >> shift) & 0xff)


static func _append_i64(output: PackedByteArray, value: int) -> void:
	for shift: int in [56, 48, 40, 32, 24, 16, 8, 0]:
		output.append((value >> shift) & 0xff)
