class_name ConnectionRoute
extends RefCounted

enum Kind {
	DIRECT,
}

var kind: Kind = Kind.DIRECT
var direct_endpoint: ConnectionEndpoint
var display_description: String = ""


static func direct(endpoint: ConnectionEndpoint) -> ConnectionRoute:
	var route := ConnectionRoute.new()
	route.kind = Kind.DIRECT
	route.direct_endpoint = endpoint
	route.display_description = (
		endpoint.normalized_display if endpoint != null else ""
	)
	return route


func is_valid() -> bool:
	return kind == Kind.DIRECT and direct_endpoint != null and direct_endpoint.is_valid()
