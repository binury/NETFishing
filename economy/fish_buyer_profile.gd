class_name FishBuyerProfile
extends Resource

@export var id: StringName
@export var display_name: String
@export var animal_name_singular: String
@export var animal_name_plural: String
@export_range(0.0, 10.0, 0.01) var payout_multiplier: float = 1.0
@export_multiline var sale_message_template: String


func is_valid() -> bool:
	return (
		not id.is_empty()
		and not display_name.is_empty()
		and payout_multiplier >= 0.0
		and is_finite(payout_multiplier)
	)


func get_offer(base_value: int) -> int:
	if not is_valid() or base_value < 0:
		return -1
	var offer: int = roundi(float(base_value) * payout_multiplier)
	return maxi(offer, 0)


func get_sale_message(
	fish_name: String,
	payout: int,
) -> String:
	if not sale_message_template.is_empty():
		return sale_message_template.format(
			{
				"fish": fish_name,
				"payout": payout,
			}
		)
	var buyer_name: String = animal_name_plural
	if buyer_name.is_empty():
		buyer_name = display_name
	return "You sold your %s to the %s for $%d." % [
		fish_name,
		buyer_name,
		payout,
	]
