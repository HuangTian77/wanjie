## 经济引擎 - 管理剧本运行时的经济系统
extends RefCounted

var economy_data: EconomySystemData = null
var player_inventory: Dictionary = {}  # {item_id: quantity}
var player_currencies: Dictionary = {}  # {currency_id: amount}
var market_prices: Dictionary = {}  # {market_id: {item_id: current_price}}

func _init(ed: EconomySystemData = null, inv: Dictionary = {}, cur: Dictionary = {}) -> void:
	economy_data = ed
	player_inventory = inv
	player_currencies = cur
	_initialize_market_prices()

## 外部初始化接口
func init(ed: EconomySystemData, inv: Dictionary, cur: Dictionary) -> void:
	economy_data = ed
	player_inventory = inv
	player_currencies = cur
	_initialize_market_prices()

func _initialize_market_prices() -> void:
	if economy_data == null: return
	for m in economy_data.markets:
		var mid: String = m["id"]
		if not market_prices.has(mid):
			market_prices[mid] = {}
		for g in m.get("goods", []):
			var item: String = g.get("item", "")
			market_prices[mid][item] = g.get("base_price", 0.0) * g.get("demand_factor", 1.0) * (1.0 - g.get("supply_ratio", 0.5))

func load_from_dict(state: Dictionary) -> void:
	player_inventory = state.get("resources", {})
	player_currencies = state.get("currencies", {})
	market_prices = state.get("market_prices", {})

func to_dict() -> Dictionary:
	return {"currencies": player_currencies, "resources": player_inventory, "market_prices": market_prices}

## 获取物品价格
func get_price(market_id: String, item_id: String) -> float:
	if market_prices.has(market_id):
		return market_prices[market_id].get(item_id, 0.0)
	return 0.0

## 设置市场价（刷新/波动用）
func set_price(market_id: String, item_id: String, price: float) -> void:
	if not market_prices.has(market_id):
		market_prices[market_id] = {}
	market_prices[market_id][item_id] = price

## 购买物品
func buy(market_id: String, item_id: String, quantity: int = 1, currency_id: String = "gold") -> bool:
	var price := get_price(market_id, item_id) * quantity
	if player_currencies.get(currency_id, 0) < price:
		return false
	player_currencies[currency_id] -= price
	player_inventory[item_id] = player_inventory.get(item_id, 0) + quantity
	return true

## 出售物品
func sell(market_id: String, item_id: String, quantity: int = 1, currency_id: String = "gold") -> bool:
	if player_inventory.get(item_id, 0) < quantity:
		return false
	var price := get_price(market_id, item_id) * quantity * 0.5  # 半价出售
	player_inventory[item_id] -= quantity
	if player_inventory[item_id] <= 0:
		player_inventory.erase(item_id)
	player_currencies[currency_id] = player_currencies.get(currency_id, 0) + price
	return true

## 更新市场价格（模拟供需变化）
func update_market_prices() -> void:
	if economy_data == null: return
	for m in economy_data.markets:
		var mid: String = m["id"]
		if not market_prices.has(mid):
			continue
		for g in m.get("goods", []):
			var item: String = g.get("item", "")
			var base: float = float(g.get("base_price", 10.0))
			var demand: float = float(g.get("demand_factor", 1.0))
			var fluctuation := randf_range(-0.1, 0.1)
			var old_price: float = float(market_prices[mid].get(item, base))
			var new_price: float = maxf(base * 0.5, old_price * (1.0 + fluctuation) * demand)
			market_prices[mid][item] = minf(new_price, base * 3.0)

## 添加货币
func add_currency(currency_id: String, amount: int) -> void:
	player_currencies[currency_id] = player_currencies.get(currency_id, 0) + amount

## 添加物品
func add_item(item_id: String, quantity: int = 1) -> void:
	player_inventory[item_id] = player_inventory.get(item_id, 0) + quantity

## 移除物品
func remove_item(item_id: String, quantity: int = 1) -> bool:
	if player_inventory.get(item_id, 0) < quantity:
		return false
	player_inventory[item_id] -= quantity
	if player_inventory[item_id] <= 0:
		player_inventory.erase(item_id)
	return true
