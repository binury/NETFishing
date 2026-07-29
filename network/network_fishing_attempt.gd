class_name NetworkFishingAttempt
extends RefCounted

enum Phase {
	CASTING,
	WAITING_FOR_BITE,
	FIGHTING,
	PENDING_CAPACITY,
	CAUGHT,
	ESCAPED,
	CANCELLED,
}

var owner_peer_id: int = 0
var request_id: String = ""
var attempt_id: String = ""
var result_id: String = ""
var session_id: String = ""
var phase: Phase = Phase.CASTING
var origin: Vector3
var target: Vector3
var bobber_position: Vector3
var fish_id: StringName
var encounter_seed: int = 0
var bite_time_remaining: float = 0.0
var withdrawal_progress: float = 0.0
var reel_speed: float = 0.0
var barrier_damage: int = 1
var input_held: bool = false
var last_input_sequence: int = 0
var catch_payload: Dictionary = {}
var capacity_nonce: String = ""
var capacity_deadline: float = 0.0
var controller: CatchController


func is_terminal() -> bool:
	return phase in [Phase.CAUGHT, Phase.ESCAPED, Phase.CANCELLED]
