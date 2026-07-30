class_name PlayerVisualPresenter
extends RefCounted

const PlayerScene: PackedScene = preload("res://player/player.tscn")


static func instantiate_visuals() -> Node3D:
	var source: Player = PlayerScene.instantiate()
	var visuals := source.get_node("Visuals") as Node3D
	var presentation := visuals.duplicate(
		Node.DUPLICATE_SIGNALS
		| Node.DUPLICATE_GROUPS
		| Node.DUPLICATE_SCRIPTS
		| Node.DUPLICATE_USE_INSTANTIATION
	) as Node3D
	source.free()
	presentation.name = "PlayerVisuals"
	return presentation


static func apply_appearance(
	_visuals: Node3D,
	snapshot: Dictionary,
) -> void:
	# Gameplay and preview deliberately share this presentation seam. Modular
	# visual parts can be applied here without coupling Profile to Player.
	if not CharacterCustomizationCatalog.validate_snapshot(snapshot):
		return
