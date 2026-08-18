class_name RuntimePerformanceProfile
extends RefCounted

const PROFILE_ENVIRONMENT_VARIABLE: String = (
	"NETFISHING_PERFORMANCE_PROFILE"
)
const LEGACY_LIGHT_ENVIRONMENT_VARIABLE: String = "NETFISHING_LOW_END"
const NORMAL_PROFILE: StringName = &"normal"
const LIGHT_PROFILE: StringName = &"light"
const NORMAL_WORLD_RENDER_SCALE: float = 1.0
const LIGHT_WORLD_RENDER_SCALE: float = 0.375

var _profile_name: StringName = NORMAL_PROFILE


static func from_environment() -> RuntimePerformanceProfile:
	return from_name(
		StringName(OS.get_environment(PROFILE_ENVIRONMENT_VARIABLE)),
		OS.get_environment(LEGACY_LIGHT_ENVIRONMENT_VARIABLE) == "1",
	)


static func from_name(
	profile_name: StringName,
	legacy_light_requested: bool = false,
) -> RuntimePerformanceProfile:
	var profile := RuntimePerformanceProfile.new()
	if profile_name == LIGHT_PROFILE or (
		profile_name.is_empty() and legacy_light_requested
	):
		profile._profile_name = LIGHT_PROFILE
	else:
		profile._profile_name = NORMAL_PROFILE
	return profile


func get_profile_name() -> StringName:
	return _profile_name


func is_light() -> bool:
	return _profile_name == LIGHT_PROFILE


func get_world_render_scale() -> float:
	return (
		LIGHT_WORLD_RENDER_SCALE
		if is_light()
		else NORMAL_WORLD_RENDER_SCALE
	)
