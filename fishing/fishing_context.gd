class_name FishingContext
extends RefCounted

const CalendarSeasonType = preload("res://world/calendar_season.gd")

var location_tags: Array[StringName] = []
var water_type: WaterType.Type = WaterType.Type.FRESH_WATER
var active_event_tags: Array[StringName] = []
var active_bait_tags: Array[StringName] = []
var is_night: bool = false
var is_day_night_transition: bool = false
var is_raining: bool = false
var is_foggy: bool = false
var season: int = CalendarSeasonType.UNKNOWN
