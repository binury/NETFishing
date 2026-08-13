extends Node

## Enforces NETfishing's nearest-neighbor-only artwork policy at runtime.
##
## Godot uses separate texture-filter enums for CanvasItem and 3D materials.
## Applying both here prevents imported models, dynamically created controls,
## and Sprite3D presentations from silently falling back to linear sampling.


func _enter_tree() -> void:
	get_tree().node_added.connect(_on_node_added)
	call_deferred("_enforce_existing_tree")


func _on_node_added(node: Node) -> void:
	enforce_node(node)
	# Some runtime presenters assign their mesh or material immediately after
	# add_child(). Recheck once deferred so those resources are covered too.
	call_deferred("_enforce_deferred_node", weakref(node))


func _enforce_existing_tree() -> void:
	enforce_subtree(get_tree().root)


func _enforce_deferred_node(node_ref: WeakRef) -> void:
	var node := node_ref.get_ref() as Node
	if node != null:
		enforce_node(node)


static func enforce_subtree(node: Node) -> void:
	enforce_node(node)
	for child: Node in node.get_children():
		enforce_subtree(child)


static func enforce_node(node: Node) -> void:
	if node is CanvasItem:
		(node as CanvasItem).texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if node is SpriteBase3D:
		(node as SpriteBase3D).texture_filter = (
			BaseMaterial3D.TEXTURE_FILTER_NEAREST
		)
	if node is GeometryInstance3D:
		var geometry := node as GeometryInstance3D
		enforce_material(geometry.material_override)
		enforce_material(geometry.material_overlay)
	if node is MeshInstance3D:
		enforce_mesh((node as MeshInstance3D).mesh)
	if node is MultiMeshInstance3D:
		var multimesh := (node as MultiMeshInstance3D).multimesh
		if multimesh != null:
			enforce_mesh(multimesh.mesh)
	if node is GPUParticles3D:
		var particles := node as GPUParticles3D
		for pass_index: int in particles.draw_passes:
			enforce_mesh(particles.get_draw_pass_mesh(pass_index))
	if node is CPUParticles3D:
		enforce_mesh((node as CPUParticles3D).mesh)


static func enforce_mesh(mesh: Mesh) -> void:
	if mesh == null:
		return
	for surface_index: int in mesh.get_surface_count():
		enforce_material(mesh.surface_get_material(surface_index))


static func enforce_material(material: Material) -> void:
	if material is BaseMaterial3D:
		(material as BaseMaterial3D).texture_filter = (
			BaseMaterial3D.TEXTURE_FILTER_NEAREST
		)
