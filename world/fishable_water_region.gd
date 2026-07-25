class_name FishableWaterRegion
extends Area3D

const FishPoolType = preload("res://fish/fish_pool.gd")

@export var location_tags: Array[StringName] = []
@export var fish_pool: FishPoolType
@export var selection_priority: int = 0
