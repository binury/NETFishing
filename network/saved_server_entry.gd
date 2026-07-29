class_name SavedServerEntry
extends RefCounted

enum Kind {
	SAVED,
	RECENT,
}

var kind: Kind = Kind.SAVED
var entry_id: String = ""
var display_name: String = ""
var route_kind: String = "DIRECT"
var host: String = ""
var normalized_host: String = ""
var port: int = EndpointParser.DEFAULT_PORT
var normalized_endpoint: String = ""
var favorite: bool = false
var created_at_unix: int = 0
var updated_at_unix: int = 0
var last_success_at_unix: int = 0
var last_result_code: String = ""
var last_observed_server_name: String = ""
var last_observed_protocol_version: int = 0
var last_observed_player_count: int = 0
var last_observed_max_players: int = 0


static func from_dictionary(
	data: Dictionary,
	entry_kind: Kind,
) -> SavedServerEntry:
	var entry := SavedServerEntry.new()
	entry.kind = entry_kind
	entry.entry_id = str(data.get("entry_id", ""))
	entry.display_name = str(data.get("display_name", ""))
	entry.route_kind = str(data.get("route_kind", "DIRECT"))
	entry.host = str(data.get("host", ""))
	entry.normalized_host = str(data.get("normalized_host", entry.host))
	entry.port = int(data.get("port", EndpointParser.DEFAULT_PORT))
	entry.normalized_endpoint = str(data.get("normalized_endpoint", ""))
	entry.favorite = bool(data.get("favorite", false))
	entry.created_at_unix = int(data.get("created_at_unix", 0))
	entry.updated_at_unix = int(data.get("updated_at_unix", 0))
	entry.last_success_at_unix = int(data.get("last_success_at_unix", 0))
	entry.last_result_code = str(data.get("last_result_code", ""))
	entry.last_observed_server_name = str(
		data.get("last_observed_server_name", "")
	)
	entry.last_observed_protocol_version = int(
		data.get("last_observed_protocol_version", 0)
	)
	entry.last_observed_player_count = int(
		data.get("last_observed_player_count", 0)
	)
	entry.last_observed_max_players = int(
		data.get("last_observed_max_players", 0)
	)
	return entry


func to_dictionary() -> Dictionary:
	return {
		"entry_id": entry_id,
		"display_name": display_name,
		"route_kind": route_kind,
		"host": host,
		"normalized_host": normalized_host,
		"port": port,
		"normalized_endpoint": normalized_endpoint,
		"favorite": favorite,
		"created_at_unix": created_at_unix,
		"updated_at_unix": updated_at_unix,
		"last_success_at_unix": last_success_at_unix,
		"last_result_code": last_result_code,
		"last_observed_server_name": last_observed_server_name,
		"last_observed_protocol_version": last_observed_protocol_version,
		"last_observed_player_count": last_observed_player_count,
		"last_observed_max_players": last_observed_max_players,
	}


func get_endpoint() -> ConnectionEndpoint:
	var endpoint_text: String = (
		"[%s]:%d" % [host, port]
		if host.contains(":")
		else "%s:%d" % [host, port]
	)
	return EndpointParser.parse(endpoint_text)
