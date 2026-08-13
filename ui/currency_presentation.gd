class_name CurrencyPresentation
extends RefCounted

const ICON_PATH: String = (
	"res://items/icons/shop/32_currency.png"
)
const AMOUNT_SCENE: PackedScene = preload(
	"res://ui/components/currency_amount.tscn"
)


static func instantiate_amount(
	value: int,
	icon_size: float = 18.0,
) -> CurrencyAmount:
	var display := AMOUNT_SCENE.instantiate() as CurrencyAmount
	display.icon_size = icon_size
	display.amount = value
	return display


static func bbcode_amount(value: int, icon_size: int = 18) -> String:
	return "[img=%dx%d]%s[/img] %d" % [
		icon_size,
		icon_size,
		ICON_PATH,
		value,
	]
