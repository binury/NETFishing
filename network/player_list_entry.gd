class_name PlayerListEntry
extends RefCounted

var peer_id := 0
var full_fingerprint := ""
var compact_fingerprint := ""
var display_name := ""
var is_host := false
var is_operator := false
var is_local_player := false
var continuity_state := ""
var ping_to_host_ms := -1
var muted := false
var blocked := false
var can_kick := false
var can_ban := false
var can_clear_art := false
var can_manage_operator := false
var revision := 0
