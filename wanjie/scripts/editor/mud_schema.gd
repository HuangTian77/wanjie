## MUD编辑器 - 数据表定义
## 全面复刻ME项目的30+数据表结构
class_name MudSchema
extends RefCounted

# === 表分组定义 ===
const TABLE_GROUPS := {
	"地图系统": ["Citys", "CityWays", "CityObjects", "MapEnter"],
	"交互对象": ["Goods", "GoodsAction", "GoodsUse", "GoodsTagName"],
	"角色NPC": ["NPC", "NPCCombat"],
	"技能系统": ["Skill", "SkillTagName", "Slot"],
	"属性系统": ["Property", "PropertyAction", "PropertyValue", "PropertyTagName", "CombatProperty"],
	"剧情任务": ["Story", "Question", "Drop"],
	"游戏机制": ["RandomAction", "Exchange", "ObjectAutoRun", "CommonAction", "OnlineFunc"],
	"系统配置": ["Navigation", "Setting", "GameInfo", "LuaExport", "customdata"]
}

# === 所有表定义 {表名: {fields: {字段名: {type, desc}}, desc, icon}} ===
const TABLES := {
	"Citys": {
		"desc": "城市/场景地图", "icon": "🏰",
		"fields": {
			"id": {"type": "int", "desc": "ID"},
			"name": {"type": "string", "desc": "名称"},
			"desc": {"type": "text", "desc": "描述"}
		}
	},
	"CityWays": {
		"desc": "城市通路连接", "icon": "🛤",
		"fields": {
			"id": {"type": "int", "desc": "ID"},
			"from": {"type": "int", "desc": "起点ID"},
			"to": {"type": "int", "desc": "终点ID"},
			"direct": {"type": "int", "desc": "方向(0双向/1单向)"},
			"failDesc": {"type": "text", "desc": "通行失败描述"}
		}
	},
	"CityObjects": {
		"desc": "城市中的物件", "icon": "📦",
		"fields": {
			"cityID": {"type": "int", "desc": "城市ID"},
			"objectID": {"type": "int", "desc": "物件ID"}
		}
	},
	"MapEnter": {
		"desc": "出生点/入口", "icon": "🚪",
		"fields": {
			"mapID": {"type": "int", "desc": "地图ID"},
			"cityID": {"type": "int", "desc": "城市ID"}
		}
	},
	"Goods": {
		"desc": "交互对象", "icon": "📦",
		"fields": {
			"id": {"type": "int", "desc": "ID"},
			"name": {"type": "string", "desc": "名称"},
			"desc": {"type": "text", "desc": "描述"},
			"note": {"type": "string", "desc": "备注"}
		}
	},
	"GoodsAction": {
		"desc": "对象交互动作(对话)", "icon": "💬",
		"fields": {
			"id": {"type": "int", "desc": "ID"},
			"objectID": {"type": "int", "desc": "对象ID"},
			"actionName": {"type": "string", "desc": "动作名"},
			"actionCount": {"type": "int", "desc": "触发次数"}
		}
	},
	"GoodsUse": {
		"desc": "物品/装备详细", "icon": "🎒",
		"fields": {
			"id": {"type": "int", "desc": "ID"},
			"name": {"type": "string", "desc": "名称"},
			"desc": {"type": "text", "desc": "描述"},
			"tagID": {"type": "int", "desc": "分类ID"},
			"weight": {"type": "int", "desc": "权重"},
			"equip": {"type": "bool", "desc": "可装备"},
			"destory": {"type": "bool", "desc": "使用后销毁"},
			"consume": {"type": "bool", "desc": "可消耗"}
		}
	},
	"GoodsTagName": {
		"desc": "物品分类标签", "icon": "🏷",
		"fields": {
			"id": {"type": "int", "desc": "ID"},
			"name": {"type": "string", "desc": "分类名"},
			"weight": {"type": "int", "desc": "排序权重"}
		}
	},
	"NPC": {
		"desc": "NPC/敌人", "icon": "👤",
		"fields": {
			"id": {"type": "int", "desc": "ID"},
			"name": {"type": "string", "desc": "名称"},
			"skillID": {"type": "int", "desc": "技能ID"}
		}
	},
	"NPCCombat": {
		"desc": "战役/副本", "icon": "⚔",
		"fields": {
			"id": {"type": "int", "desc": "ID"},
			"name": {"type": "string", "desc": "名称"},
			"desc": {"type": "text", "desc": "描述"}
		}
	},
	"Skill": {
		"desc": "技能", "icon": "⚡",
		"fields": {
			"id": {"type": "int", "desc": "ID"},
			"name": {"type": "string", "desc": "名称"},
			"desc": {"type": "text", "desc": "描述"},
			"tagID": {"type": "int", "desc": "分类ID"}
		}
	},
	"SkillTagName": {
		"desc": "技能分类标签", "icon": "🏷",
		"fields": {
			"id": {"type": "int", "desc": "ID"},
			"name": {"type": "string", "desc": "分类名"},
			"weight": {"type": "int", "desc": "排序权重"}
		}
	},
	"Slot": {
		"desc": "装备插槽", "icon": "🔲",
		"fields": {
			"id": {"type": "int", "desc": "ID"},
			"name": {"type": "string", "desc": "插槽名"},
			"slotNum": {"type": "int", "desc": "插槽数量"}
		}
	},
	"Property": {
		"desc": "属性定义", "icon": "📊",
		"fields": {
			"id": {"type": "int", "desc": "ID"},
			"tagID": {"type": "int", "desc": "分类ID"},
			"name": {"type": "string", "desc": "属性名"},
			"weight": {"type": "int", "desc": "优先级"},
			"desc": {"type": "text", "desc": "描述"},
			"min": {"type": "int", "desc": "最小值"},
			"max": {"type": "int", "desc": "最大值"}
		}
	},
	"PropertyAction": {
		"desc": "属性触发效果", "icon": "🔥",
		"fields": {
			"propertyID": {"type": "int", "desc": "属性ID"}
		}
	},
	"PropertyValue": {
		"desc": "属性值映射", "icon": "📈",
		"fields": {
			"id": {"type": "int", "desc": "属性ID"},
			"desc": {"type": "text", "desc": "默认描述"}
		}
	},
	"PropertyTagName": {
		"desc": "属性分类标签", "icon": "🏷",
		"fields": {
			"id": {"type": "int", "desc": "ID"},
			"name": {"type": "string", "desc": "分类名"},
			"weight": {"type": "int", "desc": "排序权重"}
		}
	},
	"CombatProperty": {
		"desc": "战斗属性展示", "icon": "🗡",
		"fields": {
			"propertyID": {"type": "int", "desc": "属性ID"},
			"weight": {"type": "int", "desc": "排序权重"}
		}
	},
	"Story": {
		"desc": "剧情/故事", "icon": "📜",
		"fields": {
			"id": {"type": "int", "desc": "ID"},
			"title": {"type": "string", "desc": "标题"},
			"content": {"type": "text", "desc": "内容"}
		}
	},
	"Question": {
		"desc": "问答/选择题", "icon": "❓",
		"fields": {
			"id": {"type": "int", "desc": "ID"},
			"title": {"type": "string", "desc": "标题"},
			"content": {"type": "text", "desc": "内容"}
		}
	},
	"Drop": {
		"desc": "掉落/奖励表", "icon": "💎",
		"fields": {
			"id": {"type": "int", "desc": "ID"},
			"type": {"type": "int", "desc": "类型"},
			"selNum": {"type": "int", "desc": "选择数量"},
			"selType": {"type": "int", "desc": "选择模式(1选N/2全得)"}
		}
	},
	"RandomAction": {
		"desc": "随机事件", "icon": "🎲",
		"fields": {
			"id": {"type": "int", "desc": "ID"},
			"name": {"type": "string", "desc": "事件名"}
		}
	},
	"Navigation": {
		"desc": "导航栏配置", "icon": "🧭",
		"fields": {
			"id": {"type": "int", "desc": "ID"},
			"name": {"type": "string", "desc": "名称"},
			"type": {"type": "int", "desc": "类型"},
			"weight": {"type": "int", "desc": "排序"}
		}
	},
	"Exchange": {
		"desc": "交易/兑换", "icon": "💱",
		"fields": {
			"id": {"type": "int", "desc": "ID"},
			"name": {"type": "string", "desc": "名称"},
			"desc": {"type": "text", "desc": "描述"},
			"type": {"type": "int", "desc": "类型"}
		}
	},
	"ObjectAutoRun": {
		"desc": "资源自动生成", "icon": "⏳",
		"fields": {
			"id": {"type": "int", "desc": "ID"},
			"name": {"type": "string", "desc": "名称"},
			"desc": {"type": "text", "desc": "描述"},
			"type": {"type": "int", "desc": "类型"},
			"autoStart": {"type": "bool", "desc": "自动启动"},
			"productID": {"type": "int", "desc": "产品ID"},
			"productCount": {"type": "int", "desc": "产量"},
			"productTime": {"type": "int", "desc": "周期(秒)"},
			"countMax": {"type": "int", "desc": "最大库存"},
			"getCount": {"type": "int", "desc": "每次获取量"}
		}
	},
	"CommonAction": {
		"desc": "通用逻辑动作", "icon": "⚙",
		"fields": {
			"id": {"type": "int", "desc": "ID"}
		}
	},
	"OnlineFunc": {
		"desc": "多人互动功能", "icon": "👥",
		"fields": {
			"id": {"type": "int", "desc": "ID"}
		}
	},
	"Setting": {
		"desc": "游戏设置", "icon": "⚙",
		"fields": {
			"key": {"type": "string", "desc": "设置键"},
			"value": {"type": "string", "desc": "设置值"}
		}
	},
	"GameInfo": {
		"desc": "游戏基本信息", "icon": "🎮",
		"fields": {
			"name": {"type": "string", "desc": "游戏名"},
			"version": {"type": "string", "desc": "版本号"}
		}
	},
	"LuaExport": {
		"desc": "Lua脚本导出", "icon": "📝",
		"fields": {
			"id": {"type": "int", "desc": "ID"}
		}
	},
	"customdata": {
		"desc": "自定义数据", "icon": "📋",
		"fields": {}
	}
}

# === 表顺序 ===
const TABLE_ORDER := [
	"Citys", "CityWays", "CityObjects", "MapEnter",
	"Goods", "GoodsAction", "GoodsUse", "GoodsTagName",
	"NPC", "NPCCombat",
	"Skill", "SkillTagName", "Slot",
	"Property", "PropertyAction", "PropertyValue", "PropertyTagName", "CombatProperty",
	"Story", "Question", "Drop",
	"RandomAction", "Exchange", "ObjectAutoRun", "CommonAction", "OnlineFunc",
	"Navigation", "Setting", "GameInfo", "LuaExport", "customdata"
]

# === 工具函数 ===

## 获取表的显示名称
static func get_display_name(table_key: String) -> String:
	if TABLES.has(table_key):
		var t: Dictionary = TABLES[table_key]
		var icon_val: Variant = t.get("icon") if t.has("icon") else "📄"
		var desc_val: Variant = t.get("desc") if t.has("desc") else table_key
		return "%s %s" % [icon_val, desc_val]
	return table_key

## 获取表的字段列表
static func get_field_names(table_key: String) -> Array:
	if TABLES.has(table_key):
		var t: Dictionary = TABLES[table_key]
		var fields_val: Variant = t.get("fields") if t.has("fields") else {}
		if fields_val is Dictionary:
			return (fields_val as Dictionary).keys()
	return []

## 获取字段类型
static func get_field_type(table_key: String, field_name: String) -> String:
	if TABLES.has(table_key):
		var t: Dictionary = TABLES[table_key]
		var fields_val: Variant = t.get("fields") if t.has("fields") else {}
		if fields_val is Dictionary:
			var f: Dictionary = fields_val as Dictionary
			if f.has(field_name):
				var fd: Variant = f.get(field_name)
				if fd is Dictionary:
					var type_val: Variant = (fd as Dictionary).get("type")
					if type_val is String:
						return type_val as String
	return "string"

## 创建默认条目
static func create_default_entry(table_key: String) -> Dictionary:
	var entry := {}
	var field_names: Array = get_field_names(table_key)
	for fn in field_names:
		var fn_str: String = fn as String
		var ft: String = get_field_type(table_key, fn_str)
		match ft:
			"int": entry[fn_str] = 0
			"bool": entry[fn_str] = false
			"text": entry[fn_str] = ""
			_: entry[fn_str] = ""
	return entry

## 获取表所属分组
static func get_table_group(table_key: String) -> String:
	for group_name in TABLE_GROUPS:
		var tables_in_group: Variant = TABLE_GROUPS[group_name]
		if tables_in_group is Array:
			if (tables_in_group as Array).has(table_key):
				return group_name as String
	return "其他"
