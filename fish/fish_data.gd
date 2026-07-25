class_name FishData
extends Resource

const CatchDifficultyProfileType = preload(
	"res://fishing/catch_difficulty_profile.gd"
)

@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var catch_profile: CatchDifficultyProfileType
