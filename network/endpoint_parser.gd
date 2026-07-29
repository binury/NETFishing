class_name EndpointParser
extends RefCounted

const DEFAULT_PORT: int = 7777


static func parse(value: String, default_port: int = DEFAULT_PORT) -> ConnectionEndpoint:
	var result := ConnectionEndpoint.new()
	result.original_display = value.strip_edges()
	result.port = default_port
	if default_port < 1 or default_port > 65535:
		result.error_message = "The configured default port is invalid."
		return result
	var input: String = result.original_display
	if input.is_empty():
		result.error_message = "Enter a hostname or IP address."
		return result

	var host: String = ""
	var port_text: String = ""
	if input.begins_with("["):
		var closing: int = input.find("]")
		if closing < 0:
			result.error_message = "The IPv6 address is missing a closing bracket."
			return result
		host = input.substr(1, closing - 1).strip_edges()
		var suffix: String = input.substr(closing + 1).strip_edges()
		if not suffix.is_empty():
			if not suffix.begins_with(":") or suffix.length() == 1:
				result.error_message = "Use [IPv6]:port for an IPv6 port."
				return result
			port_text = suffix.substr(1).strip_edges()
	elif input.contains("[") or input.contains("]"):
		result.error_message = "IPv6 brackets are malformed."
		return result
	else:
		var colon_count: int = input.count(":")
		if colon_count == 1:
			var separator: int = input.rfind(":")
			host = input.substr(0, separator).strip_edges()
			port_text = input.substr(separator + 1).strip_edges()
		else:
			# Zero colons is a hostname/IPv4 host. More than one is a raw
			# IPv6 host; an explicit port for it must use brackets.
			host = input.strip_edges()

	if host.is_empty():
		result.error_message = "The hostname or IP address is empty."
		return result
	if host.contains(" ") or host.contains("\t") or host.contains("\n"):
		result.error_message = "The hostname or IP address contains whitespace."
		return result
	if not port_text.is_empty():
		if not port_text.is_valid_int():
			result.error_message = "The port must be a number from 1 to 65535."
			return result
		result.port = int(port_text)
		if result.port < 1 or result.port > 65535:
			result.error_message = "The port must be from 1 to 65535."
			return result

	result.host = host.to_lower()
	var is_ipv6: bool = result.host.contains(":")
	result.normalized_display = (
		"[%s]:%d" % [result.host, result.port]
		if is_ipv6
		else "%s:%d" % [result.host, result.port]
	)
	return result
