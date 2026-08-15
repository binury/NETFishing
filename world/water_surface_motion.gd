class_name WaterSurfaceMotion
extends MeshInstance3D

const DEFAULT_AMPLITUDE: float = 0.055
const DEFAULT_CYCLE_SECONDS: float = 7.0
const DEFAULT_SECONDARY_SWELL: float = 0.18
const DEFAULT_PHASE_OFFSET: float = 0.0

@export_range(0.0, 0.2, 0.005, "suffix:m") var amplitude: float = (
	DEFAULT_AMPLITUDE
)
@export_range(1.0, 30.0, 0.1, "suffix:s") var cycle_seconds: float = (
	DEFAULT_CYCLE_SECONDS
)
@export_range(0.0, 0.5, 0.01) var secondary_swell: float = (
	DEFAULT_SECONDARY_SWELL
)
@export_range(0.0, TAU, 0.01, "radians") var phase_offset: float = 0.0

var _base_height: float


func _ready() -> void:
	_base_height = position.y
	set_process(amplitude > 0.0)


func _process(_delta: float) -> void:
	position.y = _base_height + calculate_height_offset(
		_current_time_seconds(),
		amplitude,
		cycle_seconds,
		secondary_swell,
		phase_offset,
	)


func set_motion_enabled(enabled: bool) -> void:
	set_process(enabled and amplitude > 0.0)
	if not enabled:
		position.y = _base_height


static func get_default_height_offset() -> float:
	return calculate_height_offset(
		_current_time_seconds(),
		DEFAULT_AMPLITUDE,
		DEFAULT_CYCLE_SECONDS,
		DEFAULT_SECONDARY_SWELL,
		DEFAULT_PHASE_OFFSET,
	)


static func calculate_height_offset(
	time_seconds: float,
	motion_amplitude: float,
	motion_cycle_seconds: float,
	motion_secondary_swell: float,
	motion_phase_offset: float,
) -> float:
	var safe_cycle := maxf(motion_cycle_seconds, 0.001)
	var phase := (
		fposmod(time_seconds, safe_cycle) / safe_cycle * TAU
		+ motion_phase_offset
	)
	var swell := (
		sin(phase)
		+ sin(phase * 2.0 + 1.1) * motion_secondary_swell
	) / (1.0 + motion_secondary_swell)
	return swell * motion_amplitude


static func _current_time_seconds() -> float:
	return float(Time.get_ticks_msec()) * 0.001
