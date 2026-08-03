## 经济编辑面板
## 编辑货币、资源、市场数据
extends Control

## 经济数据引用
var economy_data: EconomySystemData = null
## 当前选中的索引
var _currency_idx: int = -1
var _resource_idx: int = -1
var _market_idx: int = -1

@onready var tab_bar: TabBar = %TabBar
@onready var currency_panel: HSplitContainer = %CurrencyPanel
@onready var resource_panel: HSplitContainer = %ResourcePanel
@onready var market_panel: HSplitContainer = %MarketPanel

@onready var currency_list: ItemList = %CurrencyList
@onready var currency_name_edit: LineEdit = %CurrencyNameEdit
@onready var currency_type_option: OptionButton = %CurrencyTypeOption
@onready var currency_supply_edit: SpinBox = %CurrencySupplyEdit
@onready var currency_inflation_edit: SpinBox = %CurrencyInflationEdit

@onready var resource_list: ItemList = %ResourceList
@onready var resource_name_edit: LineEdit = %ResourceNameEdit
@onready var resource_cat_option: OptionButton = %ResourceCatOption
@onready var resource_stack_edit: SpinBox = %ResourceStackEdit
@onready var resource_decay_toggle: CheckButton = %ResourceDecayToggle

@onready var market_list: ItemList = %MarketList
@onready var market_name_edit: LineEdit = %MarketNameEdit
@onready var market_loc_edit: LineEdit = %MarketLocEdit
@onready var goods_list: ItemList = %GoodsList

## 加载数据
func load_data(data: EconomySystemData) -> void:
	economy_data = data
	_refresh_all()

## 刷新所有列表
func _refresh_all() -> void:
	if economy_data == null:
		return
	_refresh_currencies()
	_refresh_resources()
	_refresh_markets()

## 刷新货币列表
func _refresh_currencies() -> void:
	currency_list.clear()
	for c in economy_data.currencies:
		currency_list.add_item(c.get("name", "未命名"))
	_currency_idx = -1
	_set_currency_detail_visible(false)

## 刷新资源列表
func _refresh_resources() -> void:
	resource_list.clear()
	for r in economy_data.resources:
		resource_list.add_item(r.get("name", "未命名"))
	_resource_idx = -1
	_set_resource_detail_visible(false)

## 刷新市场列表
func _refresh_markets() -> void:
	market_list.clear()
	for m in economy_data.markets:
		market_list.add_item(m.get("name", "未命名"))
	_market_idx = -1
	_set_market_detail_visible(false)

## 设置货币详情可见性
func _set_currency_detail_visible(vis: bool) -> void:
	currency_name_edit.editable = vis
	currency_type_option.disabled = not vis
	currency_supply_edit.editable = vis
	currency_inflation_edit.editable = vis

## 设置资源详情可见性
func _set_resource_detail_visible(vis: bool) -> void:
	resource_name_edit.editable = vis
	resource_cat_option.disabled = not vis
	resource_stack_edit.editable = vis
	resource_decay_toggle.disabled = not vis

## 设置市场详情可见性
func _set_market_detail_visible(vis: bool) -> void:
	market_name_edit.editable = vis
	market_loc_edit.editable = vis

## === TabBar切换 ===
func _on_tab_changed(tab: int) -> void:
	currency_panel.visible = (tab == 0)
	resource_panel.visible = (tab == 1)
	market_panel.visible = (tab == 2)

## === 货币操作 ===
func _on_add_currency_pressed() -> void:
	if economy_data == null:
		return
	var new_id := "currency_%d" % economy_data.currencies.size()
	economy_data.add_currency(new_id, "新货币", "universal")
	_refresh_currencies()

func _on_remove_currency_pressed() -> void:
	if economy_data == null or _currency_idx < 0 or _currency_idx >= economy_data.currencies.size():
		return
	economy_data.currencies.remove_at(_currency_idx)
	_refresh_currencies()

func _on_currency_selected(idx: int) -> void:
	_currency_idx = idx
	if idx < 0 or idx >= economy_data.currencies.size():
		_set_currency_detail_visible(false)
		return
	var c: Dictionary = economy_data.currencies[idx]
	_set_currency_detail_visible(true)
	currency_name_edit.text = c.get("name", "")
	var type_str: String = c.get("type", "universal")
	currency_type_option.selected = ["universal", "faction_local", "token"].find(type_str)
	currency_supply_edit.value = float(c.get("max_supply", -1))
	currency_inflation_edit.value = float(c.get("inflation_rate", 0.02))

func _on_currency_name_changed(text: String) -> void:
	if _currency_idx >= 0 and _currency_idx < economy_data.currencies.size():
		economy_data.currencies[_currency_idx]["name"] = text
		currency_list.set_item_text(_currency_idx, text)

func _on_currency_type_changed(idx: int) -> void:
	if _currency_idx >= 0 and _currency_idx < economy_data.currencies.size():
		var types := ["universal", "faction_local", "token"]
		if idx >= 0 and idx < types.size():
			economy_data.currencies[_currency_idx]["type"] = types[idx]

func _on_currency_supply_changed(value: float) -> void:
	if _currency_idx >= 0 and _currency_idx < economy_data.currencies.size():
		economy_data.currencies[_currency_idx]["max_supply"] = int(value)

func _on_currency_inflation_changed(value: float) -> void:
	if _currency_idx >= 0 and _currency_idx < economy_data.currencies.size():
		economy_data.currencies[_currency_idx]["inflation_rate"] = value

## === 资源操作 ===
func _on_add_resource_pressed() -> void:
	if economy_data == null:
		return
	var new_id := "res_%d" % economy_data.resources.size()
	economy_data.add_resource(new_id, "新资源", "material")
	_refresh_resources()

func _on_remove_resource_pressed() -> void:
	if economy_data == null or _resource_idx < 0 or _resource_idx >= economy_data.resources.size():
		return
	economy_data.resources.remove_at(_resource_idx)
	_refresh_resources()

func _on_resource_selected(idx: int) -> void:
	_resource_idx = idx
	if idx < 0 or idx >= economy_data.resources.size():
		_set_resource_detail_visible(false)
		return
	var r: Dictionary = economy_data.resources[idx]
	_set_resource_detail_visible(true)
	resource_name_edit.text = r.get("name", "")
	var cat_str: String = r.get("category", "material")
	resource_cat_option.selected = ["material", "consumable", "equipment", "quest_item"].find(cat_str)
	resource_stack_edit.value = float(r.get("stack_limit", 999))
	resource_decay_toggle.button_pressed = r.get("decay_enabled", false)

func _on_resource_name_changed(text: String) -> void:
	if _resource_idx >= 0 and _resource_idx < economy_data.resources.size():
		economy_data.resources[_resource_idx]["name"] = text
		resource_list.set_item_text(_resource_idx, text)

func _on_resource_cat_changed(idx: int) -> void:
	if _resource_idx >= 0 and _resource_idx < economy_data.resources.size():
		var cats := ["material", "consumable", "equipment", "quest_item"]
		if idx >= 0 and idx < cats.size():
			economy_data.resources[_resource_idx]["category"] = cats[idx]

func _on_resource_stack_changed(value: float) -> void:
	if _resource_idx >= 0 and _resource_idx < economy_data.resources.size():
		economy_data.resources[_resource_idx]["stack_limit"] = int(value)

func _on_resource_decay_changed(pressed: bool) -> void:
	if _resource_idx >= 0 and _resource_idx < economy_data.resources.size():
		economy_data.resources[_resource_idx]["decay_enabled"] = pressed

## === 市场操作 ===
func _on_add_market_pressed() -> void:
	if economy_data == null:
		return
	economy_data.markets.append({"name": "新市场", "location": "", "goods": []})
	_refresh_markets()

func _on_remove_market_pressed() -> void:
	if economy_data == null or _market_idx < 0 or _market_idx >= economy_data.markets.size():
		return
	economy_data.markets.remove_at(_market_idx)
	_refresh_markets()

func _on_market_selected(idx: int) -> void:
	_market_idx = idx
	if idx < 0 or idx >= economy_data.markets.size():
		_set_market_detail_visible(false)
		return
	var m: Dictionary = economy_data.markets[idx]
	_set_market_detail_visible(true)
	market_name_edit.text = m.get("name", "")
	market_loc_edit.text = m.get("location", "")
	_refresh_goods()

func _on_market_name_changed(text: String) -> void:
	if _market_idx >= 0 and _market_idx < economy_data.markets.size():
		economy_data.markets[_market_idx]["name"] = text
		market_list.set_item_text(_market_idx, text)

func _on_market_loc_changed(text: String) -> void:
	if _market_idx >= 0 and _market_idx < economy_data.markets.size():
		economy_data.markets[_market_idx]["location"] = text

## === 商品操作 ===
func _refresh_goods() -> void:
	goods_list.clear()
	if _market_idx < 0 or _market_idx >= economy_data.markets.size():
		return
	var goods: Array = economy_data.markets[_market_idx].get("goods", [])
	for g in goods:
		goods_list.add_item("%s (价格:%.1f)" % [g.get("item", "?"), g.get("base_price", 0.0)])

func _on_add_good_pressed() -> void:
	if _market_idx < 0 or _market_idx >= economy_data.markets.size():
		return
	var goods: Array = economy_data.markets[_market_idx].get("goods", [])
	goods.append({"item": "new_item", "base_price": 10.0, "demand_factor": 1.0})
	economy_data.markets[_market_idx]["goods"] = goods
	_refresh_goods()

func _on_remove_good_pressed() -> void:
	var sel := goods_list.get_selected_items()
	if sel.is_empty() or _market_idx < 0 or _market_idx >= economy_data.markets.size():
		return
	var goods: Array = economy_data.markets[_market_idx].get("goods", [])
	var idx: int = sel[0]
	if idx >= 0 and idx < goods.size():
		goods.remove_at(idx)
		economy_data.markets[_market_idx]["goods"] = goods
		_refresh_goods()

## 获取数据（数据直接写入引用）
func get_data() -> void:
	pass
