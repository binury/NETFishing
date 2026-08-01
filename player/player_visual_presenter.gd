class_name PlayerVisualPresenter
extends RefCounted

const PlayerScene: PackedScene = preload("res://player/player.tscn")


static func instantiate_visuals() -> Node3D:
	var source: Player = PlayerScene.instantiate()
	var visuals := source.get_node("Visuals") as Node3D
	var source_rod_attachment: Node = visuals.find_child(
		"FishingRodAttachment", true, false
	)
	var source_rod_parent: Node = null
	var source_rod_index: int = -1
	if source_rod_attachment != null:
		source_rod_parent = source_rod_attachment.get_parent()
		source_rod_index = source_rod_attachment.get_index()
		source_rod_attachment.owner = null
		source_rod_parent.remove_child(source_rod_attachment)
	var presentation := visuals.duplicate(
		Node.DUPLICATE_SIGNALS
		| Node.DUPLICATE_GROUPS
		| Node.DUPLICATE_SCRIPTS
		| Node.DUPLICATE_USE_INSTANTIATION
	) as Node3D
	if source_rod_attachment != null and source_rod_parent != null:
		source_rod_parent.add_child(source_rod_attachment)
		source_rod_parent.move_child(source_rod_attachment, source_rod_index)
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
