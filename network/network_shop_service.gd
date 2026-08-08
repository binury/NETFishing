class_name NetworkShopService
extends Node

const FishingShopStockType = preload(
	"res://economy/fishing_shop_stock.gd"
)
const ItemDataType = preload("res://items/item_data.gd")
const OwnedItemType = preload("res://items/owned_item.gd")
const ArtShopStockType = preload("res://economy/art_shop_stock.gd")

const SHOP_ID: StringName = &"main_fishing_shop"
const REEL_PRODUCT_ID: StringName = &"reel_speed_upgrade"
const BARRIER_PRODUCT_ID: StringName = &"barrier_power_upgrade"
const COOLER_PRODUCT_ID: StringName = &"cooler_capacity_upgrade"
const MAX_LEDGER_ENTRIES_PER_PEER: int = 64

signal local_purchase_pending(request_id: String)
signal local_purchase_finished(
	request_id: String,
	accepted: bool,
	message: String,
	product_id: StringName,
	category: int,
	quantity: int,
	total_cost: int,
)

var _session: NetworkSession
var _spawn_service: PlayerSpawnService
var _network_fishing: NetworkFishingService
var _interaction: FishingShopInteraction
var _wallet: PlayerWallet
var _bag: PlayerBag
var _item_catalog: ItemCatalog
var _upgrades: PlayerFishingUpgrades
var _cooler_capacity: PlayerCoolerCapacity
var _art_unlocks: PlayerArtUnlocks
var _save_manager: PlayerSaveManager
var _request_ledgers: Dictionary[int, Dictionary] = {}
var _pending_by_peer: Dictionary[int, String] = {}
var _result_owners: Dictionary[String, int] = {}
var _acknowledged_results: Dictionary[String, bool] = {}
var _received_results: Dictionary[String, bool] = {}
var _applied_results: Dictionary[String, bool] = {}
var _pending_local_request: Dictionary = {}
var _reservations: PlayerAssetReservationService


func setup(
	session: NetworkSession,
	spawn_service: PlayerSpawnService,
	network_fishing: NetworkFishingService,
	interaction: FishingShopInteraction,
	wallet: PlayerWallet,
	bag: PlayerBag,
	item_catalog: ItemCatalog,
	upgrades: PlayerFishingUpgrades,
	cooler_capacity: PlayerCoolerCapacity,
	art_unlocks: PlayerArtUnlocks,
	save_manager: PlayerSaveManager,
	reservations: PlayerAssetReservationService,
) -> void:
	_session = session
	_spawn_service = spawn_service
	_network_fishing = network_fishing
	_interaction = interaction
	_wallet = wallet
	_bag = bag
	_item_catalog = item_catalog
	_upgrades = upgrades
	_cooler_capacity = cooler_capacity
	_art_unlocks = art_unlocks
	_save_manager = save_manager
	_reservations = reservations
	if not _session.peer_removed.is_connected(_on_peer_removed):
		_session.peer_removed.connect(_on_peer_removed)
	if not _session.state_changed.is_connected(_on_session_state_changed):
		_session.state_changed.connect(_on_session_state_changed)


func can_request_purchase() -> bool:
	return (
		_session != null
		and _session.is_gameplay_session_active()
		and (
			_session.is_host()
			or _session.supports_server_capability(
				NetworkShopProtocol.CAPABILITY
			)
		)
	)


func can_request_art_purchase() -> bool:
	return (
		can_request_purchase()
		and (
			_session.is_host()
			or _session.supports_server_capability(
				NetworkShopProtocol.ART_CAPABILITY
			)
		)
	)


func is_local_purchase_pending() -> bool:
	return not _pending_local_request.is_empty()


func request_supply(item_id: StringName) -> String:
	var owned: int = _bag.get_quantity(item_id) if _bag != null else 0
	var item: ItemDataType = (
		_item_catalog.get_item_by_id(item_id)
		if _item_catalog != null else null
	)
	var quantity: int = FishingShopStockType.get_purchase_quantity(
		item_id,
		owned,
		item.max_stack if item != null else FishingShopStockType.WORM_MAX_STACK,
	)
	return _request_purchase(
		item_id,
		NetworkShopProtocol.ProductCategory.SUPPLY,
		quantity,
		owned
	)


func request_reel_speed_upgrade() -> String:
	return _request_purchase(
		REEL_PRODUCT_ID,
		NetworkShopProtocol.ProductCategory.REEL_SPEED_UPGRADE,
		1,
		_upgrades.get_reel_speed_level() if _upgrades != null else 0
	)


func request_barrier_power_upgrade() -> String:
	return _request_purchase(
		BARRIER_PRODUCT_ID,
		NetworkShopProtocol.ProductCategory.BARRIER_POWER_UPGRADE,
		1,
		_upgrades.get_barrier_power_level() if _upgrades != null else 0
	)


func request_cooler_capacity_upgrade() -> String:
	return _request_purchase(
		COOLER_PRODUCT_ID,
		NetworkShopProtocol.ProductCategory.COOLER_CAPACITY_UPGRADE,
		1,
		_cooler_capacity.get_level() if _cooler_capacity != null else 0
	)


func request_art_kit() -> String:
	return _request_purchase(
		ArtShopStockType.ART_KIT_ITEM_ID,
		NetworkShopProtocol.ProductCategory.ART_KIT,
		1,
		_bag.get_quantity(ArtShopStockType.ART_KIT_ITEM_ID)
		if _bag != null else 0,
	)


func request_art_upgrade(product_id: StringName) -> String:
	if (
		_bag == null
		or not _bag.owns_item(ArtShopStockType.ART_KIT_ITEM_ID)
	):
		local_purchase_finished.emit(
			"",
			false,
			"Own an Art Kit before buying upgrades.",
			product_id,
			NetworkShopProtocol.ProductCategory.ART_UPGRADE,
			0,
			0,
		)
		return ""
	return _request_purchase(
		product_id,
		NetworkShopProtocol.ProductCategory.ART_UPGRADE,
		1,
		_art_unlocks.get_unlock_mask() if _art_unlocks != null else 0,
	)


func _request_purchase(
	product_id: StringName,
	category: int,
	quantity: int,
	current_state: int,
) -> String:
	if is_local_purchase_pending():
		local_purchase_finished.emit(
			"", false, "Purchasing…", product_id, category, 0, 0
		)
		return ""
	if not can_request_purchase():
		local_purchase_finished.emit(
			"",
			false,
			"Purchases are not supported by this server.",
			product_id,
			category,
			0,
			0
		)
		return ""
	if (
		category in [
			NetworkShopProtocol.ProductCategory.ART_KIT,
			NetworkShopProtocol.ProductCategory.ART_UPGRADE,
		]
		and not can_request_art_purchase()
	):
		local_purchase_finished.emit(
			"", false, "Art supplies require a newer server.",
			product_id, category, 0, 0,
		)
		return ""
	var request_id: String = _new_id("shop")
	var request: Dictionary = {
		"request_id": request_id,
		"session_id": _session.get_session_id(),
		"shop_id": str(SHOP_ID),
		"product_id": str(product_id),
		"category": category,
		"quantity": quantity,
		"wallet_balance": _wallet.get_balance() if _wallet != null else 0,
		"current_state": current_state,
	}
	if (
		category == NetworkShopProtocol.ProductCategory.SUPPLY
		and FishingShopStockType.is_bait_topoff(product_id)
	):
		request["bait_unlocked"] = (
			_bag != null and _bag.is_bait_unlocked(product_id)
		)
	_pending_local_request = request.duplicate(true)
	local_purchase_pending.emit(request_id)
	if _session.is_host():
		_handle_purchase_request(_session.get_local_peer_id(), request)
	else:
		submit_purchase_request.rpc_id(1, request)
	return request_id


@rpc(
	"any_peer",
	"call_remote",
	"reliable",
	NetworkShopProtocol.RELIABLE_CHANNEL
)
func submit_purchase_request(data: Dictionary) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if (
		_session == null
		or not _session.is_host()
		or not _session.is_authenticated_peer(sender_id)
	):
		return
	_handle_purchase_request(sender_id, data)


func _handle_purchase_request(peer_id: int, data: Dictionary) -> void:
	var validation_error: String = NetworkShopProtocol.validate_request(data)
	var request_id: String = str(data.get("request_id", ""))
	var ledger: Dictionary = _request_ledgers.get(peer_id, {})
	if (
		not request_id.is_empty()
		and request_id.length() <= NetworkShopProtocol.MAX_ID_LENGTH
		and ledger.has(request_id)
	):
		_send_result(peer_id, ledger[request_id])
		return
	if not validation_error.is_empty():
		_record_and_send(
			peer_id,
			_rejected_result(data, validation_error)
		)
		return
	if str(data["session_id"]) != _session.get_session_id():
		_record_and_send(
			peer_id,
			_rejected_result(data, "Purchase could not be completed.")
		)
		return
	if (
		_pending_by_peer.has(peer_id)
		and _pending_by_peer[peer_id] != request_id
	):
		_record_and_send(
			peer_id,
			_rejected_result(data, "A purchase is already pending.")
		)
		return
	if not _is_shop_available_for_peer(peer_id):
		var avatar: Player = _spawn_service.get_avatar(peer_id)
		var message: String = (
			"The shop is unavailable."
			if avatar == null or _interaction == null
			else "Move closer to the shop."
		)
		_record_and_send(peer_id, _rejected_result(data, message))
		return
	var result: Dictionary = _build_authoritative_result(peer_id, data)
	_pending_by_peer[peer_id] = request_id
	_record_and_send(peer_id, result)


func _build_authoritative_result(
	peer_id: int,
	request: Dictionary,
) -> Dictionary:
	var product_id := StringName(str(request["product_id"]))
	var category: int = request["category"]
	var quantity: int = request["quantity"]
	var wallet_balance: int = request["wallet_balance"]
	var current_state: int = request["current_state"]
	var cost: int = -1
	var resulting_state: int = current_state
	var rejection: String = ""
	if StringName(str(request["shop_id"])) != SHOP_ID:
		rejection = "The shop is unavailable."
	elif quantity < 1:
		rejection = "Purchase could not be completed."
	else:
		match category:
			NetworkShopProtocol.ProductCategory.SUPPLY:
				var item: ItemDataType = _item_catalog.get_item_by_id(
					product_id
				) if _item_catalog != null else null
				var bait_topoff: bool = (
					FishingShopStockType.is_bait_topoff(product_id)
				)
				if (
					item == null
					or not item.is_valid()
					or product_id not in (
						FishingShopStockType.get_stock_item_ids()
					)
					or (item.category != ItemDataType.Category.CONSUMABLE and not bait_topoff)
					or not item.stackable
					or (not item.usable and not bait_topoff)
					or current_state >= item.max_stack
					or current_state + quantity > item.max_stack
				):
					rejection = (
						"Your Bag is full."
						if item != null and current_state >= item.max_stack
						else "Purchase could not be completed."
					)
				else:
					var expected_quantity: int = (
						FishingShopStockType.get_purchase_quantity(
							product_id, current_state, item.max_stack
						)
					)
					if quantity != expected_quantity:
						rejection = "Purchase could not be completed."
					else:
						cost = FishingShopStockType.get_purchase_cost(
							product_id,
							quantity,
							bool(request.get("bait_unlocked", true)),
						)
						if cost < 0:
							rejection = "Purchase could not be completed."
						resulting_state = current_state + quantity
			NetworkShopProtocol.ProductCategory.ROD:
				rejection = "This item is not sold here."
			NetworkShopProtocol.ProductCategory.REEL_SPEED_UPGRADE:
				if (
					product_id != REEL_PRODUCT_ID
					or current_state
					>= PlayerFishingUpgrades.MAX_REEL_SPEED_LEVEL
				):
					rejection = "Upgrade is already at maximum."
				else:
					cost = (
						PlayerFishingUpgrades.REEL_SPEED_COSTS[
							current_state
						]
					)
					resulting_state = current_state + 1
			NetworkShopProtocol.ProductCategory.BARRIER_POWER_UPGRADE:
				if (
					product_id != BARRIER_PRODUCT_ID
					or current_state
					>= PlayerFishingUpgrades.MAX_BARRIER_POWER_LEVEL
				):
					rejection = "Upgrade is already at maximum."
				else:
					cost = (
						PlayerFishingUpgrades.BARRIER_POWER_COSTS[
							current_state
						]
					)
					resulting_state = current_state + 1
			NetworkShopProtocol.ProductCategory.COOLER_CAPACITY_UPGRADE:
				if (
					product_id != COOLER_PRODUCT_ID
					or current_state >= PlayerCoolerCapacity.MAX_LEVEL
				):
					rejection = "Upgrade is already at maximum."
				else:
					cost = (
						PlayerCoolerCapacity.EXPANSION_COSTS[
							current_state
						]
					)
					resulting_state = current_state + 1
			NetworkShopProtocol.ProductCategory.ART_KIT:
				var art_item: ItemDataType = _item_catalog.get_item_by_id(
					product_id
				) if _item_catalog != null else null
				cost = ArtShopStockType.get_price(product_id)
				if (
					product_id != ArtShopStockType.ART_KIT_ITEM_ID
					or art_item == null
					or not art_item.is_valid()
					or art_item.category != ItemDataType.Category.TOOL
					or art_item.stackable
					or not art_item.equippable
					or not art_item.hotbar_allowed
					or current_state != 0
				):
					rejection = (
						"Art Kit already owned."
						if current_state > 0
						else "Purchase could not be completed."
					)
				else:
					resulting_state = 1
			NetworkShopProtocol.ProductCategory.ART_UPGRADE:
				cost = ArtShopStockType.get_price(product_id)
				if (
					not PlayerArtUnlocks.is_product_id(product_id)
					or current_state < 0
					or (current_state & ~PlayerArtUnlocks.ALL_UNLOCK_MASK) != 0
					or PlayerArtUnlocks.resulting_mask(
						current_state, product_id
					) == current_state
				):
					rejection = "Upgrade is already unlocked."
				else:
					resulting_state = PlayerArtUnlocks.resulting_mask(
						current_state, product_id
					)
	if rejection.is_empty() and (cost < 0 or wallet_balance < cost):
		rejection = "Not enough fish coin."
	if not rejection.is_empty():
		return _rejected_result(request, rejection)
	return {
		"result_id": _new_id("shop_result"),
		"request_id": str(request["request_id"]),
		"session_id": _session.get_session_id(),
		"target_peer_id": peer_id,
		"accepted": true,
		"product_id": str(product_id),
		"category": category,
		"quantity": quantity,
		"total_cost": cost,
		"expected_wallet": wallet_balance,
		"expected_state": current_state,
		"resulting_state": resulting_state,
		"message": "Purchase complete.",
	}


func _rejected_result(request: Dictionary, message: String) -> Dictionary:
	var request_id: String = str(request.get("request_id", ""))
	if (
		request_id.is_empty()
		or request_id.length() > NetworkShopProtocol.MAX_ID_LENGTH
	):
		request_id = "invalid"
	var category: int = clampi(
		int(request.get("category", 0)),
		0,
		NetworkShopProtocol.ProductCategory.size() - 1
	)
	return {
		"result_id": _new_id("shop_result"),
		"request_id": request_id,
		"session_id": _session.get_session_id() if _session != null else "",
		"target_peer_id": 0,
		"accepted": false,
		"product_id": str(request.get("product_id", "invalid")).left(
			NetworkShopProtocol.MAX_ID_LENGTH
		),
		"category": category,
		"quantity": 0,
		"total_cost": 0,
		"expected_wallet": maxi(int(request.get("wallet_balance", 0)), 0),
		"expected_state": maxi(int(request.get("current_state", 0)), 0),
		"resulting_state": maxi(int(request.get("current_state", 0)), 0),
		"message": message.left(NetworkShopProtocol.MAX_MESSAGE_LENGTH),
	}


func _record_and_send(peer_id: int, result: Dictionary) -> void:
	result["target_peer_id"] = peer_id
	var request_id: String = result["request_id"]
	var ledger: Dictionary = _request_ledgers.get(peer_id, {})
	ledger[request_id] = result.duplicate(true)
	_bound_dictionary(ledger)
	_request_ledgers[peer_id] = ledger
	_result_owners[str(result["result_id"])] = peer_id
	_bound_dictionary(_result_owners)
	_send_result(peer_id, result)


func _send_result(peer_id: int, result: Dictionary) -> void:
	if peer_id == _session.get_local_peer_id():
		_apply_purchase_result(result)
	else:
		receive_purchase_result.rpc_id(peer_id, result)


@rpc(
	"authority",
	"call_remote",
	"reliable",
	NetworkShopProtocol.RELIABLE_CHANNEL
)
func receive_purchase_result(data: Dictionary) -> void:
	_apply_purchase_result(data)


func _apply_purchase_result(data: Dictionary) -> void:
	if (
		not NetworkShopProtocol.validate_result(data)
		or _session == null
		or str(data["session_id"]) != _session.get_session_id()
		or int(data["target_peer_id"]) != _session.get_local_peer_id()
	):
		return
	var result_id: String = data["result_id"]
	if _received_results.has(result_id):
		_acknowledge_result(data, _applied_results.has(result_id), "")
		return
	if (
		_pending_local_request.is_empty()
		or str(data["request_id"])
		!= str(_pending_local_request.get("request_id", ""))
	):
		return
	if not bool(data["accepted"]):
		_received_results[result_id] = true
		_bound_dictionary(_received_results)
		_finish_local_purchase(data, false, str(data["message"]))
		_acknowledge_result(data, false, str(data["message"]))
		return
	var validation_message: String = _validate_local_result(data)
	if not validation_message.is_empty():
		_fail_local_apply(data, validation_message)
		return
	var wallet_snapshot: int = _wallet.get_balance()
	var bag_snapshot: Array[OwnedItemType] = _bag.get_all_items()
	var bait_unlock_snapshot: Array[StringName] = (
		_bag.get_unlocked_bait_ids()
	)
	var reel_snapshot: int = _upgrades.get_reel_speed_level()
	var barrier_snapshot: int = _upgrades.get_barrier_power_level()
	var cooler_snapshot: int = _cooler_capacity.get_level()
	var art_snapshot: int = _art_unlocks.get_unlock_mask()
	var applied: bool = _apply_local_product(data)
	if not applied or not _save_manager.save_if_dirty():
		_bag.replace_all_items(bag_snapshot)
		_bag.replace_unlocked_bait_ids(bait_unlock_snapshot)
		_upgrades.restore_levels(reel_snapshot, barrier_snapshot)
		_cooler_capacity.restore_level(cooler_snapshot)
		_art_unlocks.restore_mask(art_snapshot)
		_wallet.restore_balance(wallet_snapshot)
		_save_manager.save_if_dirty()
		_fail_local_apply(data, "Purchase could not be completed.")
		return
	_applied_results[result_id] = true
	_bound_dictionary(_applied_results)
	_received_results[result_id] = true
	_bound_dictionary(_received_results)
	_finish_local_purchase(data, true, "Purchase complete.")
	_acknowledge_result(data, true, "")


func _validate_local_result(data: Dictionary) -> String:
	if (
		_wallet == null
		or _bag == null
		or _upgrades == null
		or _cooler_capacity == null
		or _art_unlocks == null
		or _save_manager == null
		or _wallet.get_balance() != int(data["expected_wallet"])
		or str(data["product_id"])
		!= str(_pending_local_request.get("product_id", ""))
		or int(data["category"])
		!= int(_pending_local_request.get("category", -1))
		or int(data["quantity"])
		!= int(_pending_local_request.get("quantity", -1))
	):
		return "Purchase could not be completed."
	var category: int = data["category"]
	var product_id := StringName(str(data["product_id"]))
	var expected_state: int = data["expected_state"]
	var cost: int = data["total_cost"]
	if (
		_reservations != null
		and _reservations.get_available_fish_coin() < cost
	):
		return "Reserved in a letter."
	var resulting_state: int = int(data["resulting_state"])
	if (
		category != NetworkShopProtocol.ProductCategory.ART_UPGRADE
		and resulting_state != expected_state + int(data["quantity"])
	):
		return "Purchase could not be completed."
	if not _wallet.can_afford(cost):
		return "Not enough fish coin."
	match category:
		NetworkShopProtocol.ProductCategory.SUPPLY:
			var item: ItemDataType = (
				_item_catalog.get_item_by_id(product_id)
				if _item_catalog != null else null
			)
			var bait_unlocked: bool = _bag.is_bait_unlocked(product_id)
			if (
				item == null
				or _bag.get_quantity(product_id) != expected_state
				or int(data["quantity"]) != FishingShopStockType.get_purchase_quantity(
					product_id, expected_state, item.max_stack
				)
			):
				return "Purchase could not be completed."
			if cost != FishingShopStockType.get_purchase_cost(
				product_id, int(data["quantity"]), bait_unlocked
			):
				return "Purchase could not be completed."
			if not _bag.can_add_item(product_id, data["quantity"]):
				return "Your Bag is full."
		NetworkShopProtocol.ProductCategory.REEL_SPEED_UPGRADE:
			if _upgrades.get_reel_speed_level() != expected_state:
				return "Purchase could not be completed."
			if _upgrades.get_next_reel_speed_cost() != cost:
				return "Purchase could not be completed."
		NetworkShopProtocol.ProductCategory.BARRIER_POWER_UPGRADE:
			if _upgrades.get_barrier_power_level() != expected_state:
				return "Purchase could not be completed."
			if _upgrades.get_next_barrier_power_cost() != cost:
				return "Purchase could not be completed."
		NetworkShopProtocol.ProductCategory.COOLER_CAPACITY_UPGRADE:
			if _cooler_capacity.get_level() != expected_state:
				return "Purchase could not be completed."
			if _cooler_capacity.get_next_cost() != cost:
				return "Purchase could not be completed."
		NetworkShopProtocol.ProductCategory.ART_KIT:
			if (
				product_id != ArtShopStockType.ART_KIT_ITEM_ID
				or _bag.get_quantity(product_id) != expected_state
				or not _bag.can_add_item(product_id, 1)
				or cost != ArtShopStockType.ART_KIT_PRICE
			):
				return "Purchase could not be completed."
		NetworkShopProtocol.ProductCategory.ART_UPGRADE:
			if (
				_art_unlocks.get_unlock_mask() != expected_state
				or not PlayerArtUnlocks.is_product_id(product_id)
				or resulting_state != PlayerArtUnlocks.resulting_mask(
					expected_state, product_id
				)
				or cost != ArtShopStockType.UPGRADE_PRICE
			):
				return "Purchase could not be completed."
		_:
			return "Purchase could not be completed."
	return ""


func _apply_local_product(data: Dictionary) -> bool:
	var category: int = data["category"]
	var product_id := StringName(str(data["product_id"]))
	match category:
		NetworkShopProtocol.ProductCategory.SUPPLY:
			return (
				_wallet.debit(data["total_cost"])
				and _bag.add_item(product_id, data["quantity"])
			)
		NetworkShopProtocol.ProductCategory.REEL_SPEED_UPGRADE:
			return _upgrades.purchase_reel_speed(_wallet)
		NetworkShopProtocol.ProductCategory.BARRIER_POWER_UPGRADE:
			return _upgrades.purchase_barrier_power(_wallet)
		NetworkShopProtocol.ProductCategory.COOLER_CAPACITY_UPGRADE:
			return _cooler_capacity.purchase(_wallet)
		NetworkShopProtocol.ProductCategory.ART_KIT:
			return (
				_wallet.debit(int(data["total_cost"]))
				and _bag.add_item(product_id, 1)
			)
		NetworkShopProtocol.ProductCategory.ART_UPGRADE:
			return _art_unlocks.purchase_product(
				product_id, _wallet, int(data["total_cost"])
			)
	return false


func _fail_local_apply(data: Dictionary, message: String) -> void:
	_finish_local_purchase(data, false, message)
	_acknowledge_result(data, false, message)


func _finish_local_purchase(
	data: Dictionary,
	accepted: bool,
	message: String,
) -> void:
	_pending_local_request.clear()
	local_purchase_finished.emit(
		str(data["request_id"]),
		accepted,
		message,
		StringName(str(data["product_id"])),
		int(data["category"]),
		int(data["quantity"]),
		int(data["total_cost"])
	)


func _acknowledge_result(
	data: Dictionary,
	applied: bool,
	message: String,
) -> void:
	if _session.is_host():
		_handle_acknowledgement(
			_session.get_local_peer_id(),
			str(data["result_id"]),
			str(data["request_id"]),
			applied,
			message
		)
	else:
		acknowledge_purchase_result.rpc_id(
			1,
			str(data["result_id"]),
			str(data["request_id"]),
			applied,
			message.left(NetworkShopProtocol.MAX_MESSAGE_LENGTH)
		)


@rpc(
	"any_peer",
	"call_remote",
	"reliable",
	NetworkShopProtocol.RELIABLE_CHANNEL
)
func acknowledge_purchase_result(
	result_id: String,
	request_id: String,
	applied: bool,
	message: String,
) -> void:
	var sender_id: int = multiplayer.get_remote_sender_id()
	if (
		_session == null
		or not _session.is_host()
		or not _session.is_authenticated_peer(sender_id)
	):
		return
	_handle_acknowledgement(
		sender_id, result_id, request_id, applied, message
	)


func _handle_acknowledgement(
	peer_id: int,
	result_id: String,
	request_id: String,
	_applied: bool,
	message: String,
) -> void:
	if (
		result_id.is_empty()
		or result_id.length() > NetworkShopProtocol.MAX_ID_LENGTH
		or request_id.is_empty()
		or request_id.length() > NetworkShopProtocol.MAX_ID_LENGTH
		or message.length() > NetworkShopProtocol.MAX_MESSAGE_LENGTH
		or _result_owners.get(result_id, 0) != peer_id
	):
		return
	_acknowledged_results[result_id] = true
	_bound_dictionary(_acknowledged_results)
	if _pending_by_peer.get(peer_id, "") == request_id:
		_pending_by_peer.erase(peer_id)


func _is_shop_available_for_peer(peer_id: int) -> bool:
	if (
		_session == null
		or not _session.is_host()
		or not _session.is_gameplay_session_active()
		or _spawn_service == null
		or _interaction == null
		or not is_instance_valid(_interaction)
	):
		return false
	var avatar: Player = _spawn_service.get_avatar(peer_id)
	return (
		avatar != null
		and not avatar.is_water_recovery_active()
		and (
			_network_fishing == null
			or not _network_fishing.has_peer_attempt(peer_id)
		)
		and _interaction.is_avatar_in_range(avatar)
	)


func _on_peer_removed(peer_id: int) -> void:
	_request_ledgers.erase(peer_id)
	_pending_by_peer.erase(peer_id)
	for result_id: String in _result_owners.keys():
		if _result_owners[result_id] == peer_id:
			_result_owners.erase(result_id)
			_acknowledged_results.erase(result_id)


func _on_session_state_changed(state: NetworkSession.State) -> void:
	if state in [
		NetworkSession.State.INACTIVE,
		NetworkSession.State.DISCONNECTING,
		NetworkSession.State.CONNECTION_FAILED,
		NetworkSession.State.SERVER_LOST,
	]:
		var had_pending: bool = is_local_purchase_pending()
		_clear_session_state()
		if had_pending:
			local_purchase_finished.emit(
				"",
				false,
				"Connection lost.",
				StringName(),
				0,
				0,
				0
			)


func _clear_session_state() -> void:
	_request_ledgers.clear()
	_pending_by_peer.clear()
	_result_owners.clear()
	_acknowledged_results.clear()
	_received_results.clear()
	_applied_results.clear()
	_pending_local_request.clear()


func _bound_dictionary(values: Dictionary) -> void:
	while values.size() > MAX_LEDGER_ENTRIES_PER_PEER:
		values.erase(values.keys().front())


func _new_id(prefix: String) -> String:
	return "%s:%s" % [
		prefix,
		Crypto.new().generate_random_bytes(16).hex_encode(),
	]
