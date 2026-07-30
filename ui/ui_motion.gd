class_name UIMotion
extends RefCounted

const BUBBLE_VERTICAL_SPEED: float = 420.0
const BUBBLE_TRANSITION_OVERLAP_DELAY: float = 0.05
const UTILITY_ENTER_DURATION: float = 0.19
const UTILITY_EXIT_DURATION: float = 0.15
const UTILITY_ENTER_SCALE: float = 0.97


static func bubble_duration(distance: float) -> float:
	return maxf(absf(distance) / BUBBLE_VERTICAL_SPEED, 0.08)
