class_name TestWorld
extends Node3D

const FishingShopInteractionType = preload(
	"res://world/fishing_shop_interaction.gd"
)

@onready var _water_trigger: PlayerWaterTrigger = %PlayerWaterTrigger
@onready var _safe_respawn_points: Node3D = %SafeRespawnPoints
@onready var _fishing_shop: FishingShopInteractionType = %FishingShopInteraction


func get_player_water_trigger() -> PlayerWaterTrigger:
	return _water_trigger


func get_safe_respawn_points() -> Array[SafeRespawnPoint]:
	var points: Array[SafeRespawnPoint] = []
	for child: Node in _safe_respawn_points.get_children():
		var point: SafeRespawnPoint = child as SafeRespawnPoint
		if point != null:
			points.append(point)
	return points


func get_fishing_shop() -> FishingShopInteractionType:
	return _fishing_shop
