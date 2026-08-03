## 经济系统数据模型
## 对应GDD §3.4 经济系统
class_name EconomySystemData
extends Resource

## 货币定义
@export var currencies: Array[Dictionary] = []
# 每个currency: {id, name, type, icon, max_supply, inflation_rate}
# type: universal/faction_local/token

## 资源定义
@export var resources: Array[Dictionary] = []
# 每个resource: {id, name, category, stack_limit, decay, decay_rate}
# category: material/consumable/equipment/quest_item

## 市场定义
@export var markets: Array[Dictionary] = []
# 每个market: {id, name, location, goods: [{item, base_price, demand_factor, supply_ratio}],
#   price_update_interval, barter_enabled, barter_rate}

## 交易规则
@export var trade_rules: Dictionary = {}
# {barter_enabled, barter_rate, faction_discount_formula, smuggling: {enabled, risk_factor, penalty}}

## 产出定义
@export var production_rules: Array[Dictionary] = []
# 每个rule: {resource, sources: [{type, formula, interval, action, requires}]}

## 添加货币
func add_currency(currency_id: String, currency_name: String, currency_type: String = "universal") -> void:
	currencies.append({
		"id": currency_id,
		"name": currency_name,
		"type": currency_type,
		"icon": "",
		"max_supply": -1,
		"inflation_rate": 0.02
	})

## 添加资源
func add_resource(resource_id: String, res_name: String, category: String = "material") -> void:
	resources.append({
		"id": resource_id,
		"name": res_name,
		"category": category,
		"stack_limit": 999,
		"decay": false,
		"decay_rate": 0.0
	})

## 添加市场
func add_market(market_id: String, market_name: String, location: String = "") -> void:
	markets.append({
		"id": market_id,
		"name": market_name,
		"location": location,
		"goods": [],
		"price_update_interval": "6h",
		"barter_enabled": true,
		"barter_rate": 0.8
	})

## 为市场添加商品
func add_market_good(market_id: String, item_id: String, base_price: float, demand: float = 1.0) -> void:
	for m in markets:
		if m["id"] == market_id:
			m["goods"].append({
				"item": item_id,
				"base_price": base_price,
				"demand_factor": demand,
				"supply_ratio": 0.5
			})
			return

## 获取货币名称
func get_currency_name(currency_id: String) -> String:
	for c in currencies:
		if c["id"] == currency_id:
			return c["name"]
	return currency_id

## 获取资源名称
func get_resource_name(resource_id: String) -> String:
	for r in resources:
		if r["id"] == resource_id:
			return r["name"]
	return resource_id

## 计算市场价格
func calculate_market_price(market_id: String, item_id: String) -> float:
	for m in markets:
		if m["id"] == market_id:
			for g in m["goods"]:
				if g["item"] == item_id:
					return g["base_price"] * g["demand_factor"] * (1.0 - g["supply_ratio"])
	return 0.0
