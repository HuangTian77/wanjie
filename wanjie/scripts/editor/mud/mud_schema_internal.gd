## MUD编辑器 - 内部数据模式层（SQLite 模式）
## 完全对应 ME 项目 app/libs/gameinit.sql 的 28 张内部表结构。
## 这是编辑器内部使用的"双层数据架构"中的内层（SQLite 模式层），
## 字段比导出格式层（mud_schema.gd 的 Citys/Goods 等）更丰富。
## 导出时由 mud_export.gd（移植 export.lua）转换为客户消费的 JSON txt。
class_name MudSchemaInternal
extends RefCounted

## 内部模式版本号（存于 mud_data 的 _schema_version，用于导入兼容判断）
const SCHEMA_VERSION: int = 2

## === 28 张内部表完整字段定义 ===
## 结构: {表名: {desc, icon, fields: {字段名: {type, desc, default}}}}
## type 取值: int / string / text / json / script / decimal
##   - int    整数字段
##   - string 短文本
##   - text   长文本(多行)
##   - json   JSON 配置串(可能随类型字段在 配置/脚本 间切换)
##   - script Lua 脚本/公式
##   - decimal 小数
const TABLES: Dictionary = {
	# ---- 全局配置 ----
	"config": {
		"desc": "全局配置", "icon": "⚙",
		"fields": {
			"name": {"type": "string", "desc": "配置键", "default": ""},
			"value": {"type": "text", "desc": "配置值", "default": ""},
		}
	},
	# ---- 主地图 ----
	"map": {
		"desc": "地图", "icon": "🗺",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"name": {"type": "string", "desc": "地图名称", "default": ""},
			"width": {"type": "int", "desc": "横向节点数", "default": 10},
			"height": {"type": "int", "desc": "纵向节点数", "default": 10},
			"desc": {"type": "text", "desc": "地图描述", "default": ""},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 场景(地点) ----
	"scene": {
		"desc": "场景/地点", "icon": "🏰",
		"fields": {
			"id": {"type": "int", "desc": "场景ID", "default": 0},
			"name": {"type": "string", "desc": "名称", "default": ""},
			"desc": {"type": "text", "desc": "详细描述", "default": ""},
			"et_cond_type": {"type": "int", "desc": "进入条件类型(0无1条件2脚本)", "default": 0},
			"et_cond_ops": {"type": "int", "desc": "进入条件策略(0全与1全或)", "default": 0},
			"enter_cond": {"type": "json", "desc": "进入条件", "default": ""},
			"lt_cond_ops": {"type": "int", "desc": "离开条件策略", "default": 0},
			"lt_cond_type": {"type": "int", "desc": "离开条件类型", "default": 0},
			"leave_cond": {"type": "json", "desc": "离开条件", "default": ""},
			"et_type": {"type": "int", "desc": "进入触发类型(0无1配置2脚本)", "default": 0},
			"enter_trigger": {"type": "json", "desc": "进入触发", "default": ""},
			"lt_type": {"type": "int", "desc": "离开触发类型", "default": 0},
			"leave_trigger": {"type": "json", "desc": "离开触发", "default": ""},
			"et_fail_type": {"type": "int", "desc": "进入失败触发类型", "default": 0},
			"enter_trigger_fail": {"type": "json", "desc": "进入失败触发", "default": ""},
			"lt_fail_type": {"type": "int", "desc": "离开失败触发类型", "default": 0},
			"leave_trigger_fail": {"type": "json", "desc": "离开失败触发", "default": ""},
			"x": {"type": "int", "desc": "地图X坐标", "default": 0},
			"y": {"type": "int", "desc": "地图Y坐标", "default": 0},
			"note": {"type": "string", "desc": "备注", "default": ""},
			"mapid": {"type": "int", "desc": "所属地图ID", "default": 1},
		}
	},
	# ---- 地点间路径 ----
	"linkpath": {
		"desc": "路径", "icon": "🛤",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"startpot": {"type": "int", "desc": "起点场景ID", "default": 0},
			"direct": {"type": "string", "desc": "方向(east等8方向)", "default": ""},
			"endpot": {"type": "int", "desc": "终点场景ID", "default": 0},
			"status": {"type": "int", "desc": "状态(0正常1隐藏)", "default": 0},
			"status_editable": {"type": "int", "desc": "状态可编辑", "default": 0},
			"opencond": {"type": "json", "desc": "打开路径条件", "default": ""},
			"opencond_type": {"type": "int", "desc": "开关触发类型", "default": 0},
			"opencond_ops": {"type": "int", "desc": "开关条件策略", "default": 0},
			"passcond": {"type": "json", "desc": "通过路径条件", "default": ""},
			"passcond_type": {"type": "int", "desc": "通过触发类型", "default": 0},
			"passcond_ops": {"type": "int", "desc": "通过条件策略", "default": 0},
			"passcond_fail_desc": {"type": "string", "desc": "通过失败提示", "default": ""},
			"closecond": {"type": "json", "desc": "关闭路径条件", "default": ""},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 交互对象基础表 ----
	"object": {
		"desc": "交互对象", "icon": "📦",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"name": {"type": "string", "desc": "名称", "default": ""},
			"desc": {"type": "text", "desc": "描述", "default": ""},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 场景静态对象表 ----
	"scene_object": {
		"desc": "场景对象", "icon": "🧩",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"sceneid": {"type": "int", "desc": "场景ID", "default": 0},
			"objid": {"type": "int", "desc": "对象ID", "default": 0},
			"ctrl": {"type": "json", "desc": "显示控制(trigger/cond/cond_ops)", "default": ""},
		}
	},
	# ---- 交谈模块 ----
	"module_talk": {
		"desc": "对象互动/对话", "icon": "💬",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"objid": {"type": "int", "desc": "对象ID", "default": 0},
			"name": {"type": "string", "desc": "互动显示名称", "default": ""},
			"status": {"type": "int", "desc": "状态(0不激活1正常)", "default": 1},
			"content": {"type": "text", "desc": "默认交互文字", "default": ""},
			"visible_cond_ops": {"type": "int", "desc": "显示条件策略", "default": 0},
			"visible_cond_trigger_type": {"type": "int", "desc": "显示条件触发类型", "default": 0},
			"visible_cond": {"type": "json", "desc": "显示控制条件", "default": ""},
			"trigger_count": {"type": "int", "desc": "触发次数(0不判断)", "default": 0},
			"trigger_type": {"type": "int", "desc": "触发类型(0无1条件2脚本)", "default": 0},
			"condition": {"type": "json", "desc": "所需条件", "default": ""},
			"cond_ops": {"type": "int", "desc": "条件策略", "default": 0},
			"succ_type": {"type": "int", "desc": "成功触发类型", "default": 0},
			"succ_trigger": {"type": "json", "desc": "成功触发", "default": ""},
			"fail_type": {"type": "int", "desc": "失败触发类型", "default": 0},
			"fail_trigger": {"type": "json", "desc": "失败触发", "default": ""},
			"fail_desc": {"type": "text", "desc": "失败提示文字", "default": ""},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 对象属性 ----
	"property": {
		"desc": "属性", "icon": "📊",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"typeid": {"type": "int", "desc": "分类ID", "default": 1},
			"name": {"type": "string", "desc": "属性名称", "default": ""},
			"visible": {"type": "int", "desc": "客户端可见(0否1是)", "default": 1},
			"priority": {"type": "int", "desc": "排序权重(越小越高)", "default": 100},
			"master": {"type": "int", "desc": "主属性(1主0临时)", "default": 1},
			"link_prop": {"type": "int", "desc": "关联属性ID", "default": 0},
			"range": {"type": "json", "desc": "取值范围{min,max}", "default": ""},
			"calc": {"type": "script", "desc": "计算公式", "default": ""},
			"trigger": {"type": "json", "desc": "触发配置", "default": ""},
			"desc": {"type": "text", "desc": "描述", "default": ""},
			"dict": {"type": "json", "desc": "属性字典", "default": ""},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 属性分类 ----
	"property_type": {
		"desc": "属性分类", "icon": "🏷",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"typeid": {"type": "int", "desc": "分类ID", "default": 0},
			"priority": {"type": "int", "desc": "排序权重", "default": 100},
			"name": {"type": "string", "desc": "分类名称", "default": ""},
			"desc": {"type": "text", "desc": "描述", "default": ""},
			"visible": {"type": "int", "desc": "可见(0否1是)", "default": 1},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 技能 ----
	"skill": {
		"desc": "技能", "icon": "⚡",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"typeid": {"type": "int", "desc": "分类ID", "default": 0},
			"name": {"type": "string", "desc": "技能名称", "default": ""},
			"desc": {"type": "text", "desc": "技能描述", "default": ""},
			"data_type": {"type": "int", "desc": "数据类型(0脚本1配置)", "default": 0},
			"data": {"type": "script", "desc": "技能数据", "default": ""},
			"slots": {"type": "json", "desc": "技能槽位信息", "default": ""},
			"equip_cond_ops": {"type": "int", "desc": "装配条件策略", "default": 0},
			"equip_type": {"type": "int", "desc": "装配条件类型(0无1配置2脚本)", "default": 0},
			"equip_data": {"type": "json", "desc": "装配条件数据", "default": ""},
			"consume_type": {"type": "int", "desc": "消耗类型", "default": 0},
			"consume_data": {"type": "json", "desc": "消耗配置", "default": ""},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 技能分类 ----
	"skill_type": {
		"desc": "技能分类", "icon": "🏷",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"name": {"type": "string", "desc": "分类名称", "default": ""},
			"slots": {"type": "json", "desc": "预制槽位占用", "default": ""},
			"priority": {"type": "int", "desc": "排序权重", "default": 100},
			"visible": {"type": "int", "desc": "可见(0否1是)", "default": 1},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 物品分类 ----
	"item_type": {
		"desc": "物品分类", "icon": "🏷",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"typeid": {"type": "int", "desc": "分类ID", "default": 0},
			"priority": {"type": "int", "desc": "排序权重", "default": 100},
			"name": {"type": "string", "desc": "分类名称", "default": ""},
			"desc": {"type": "text", "desc": "描述", "default": ""},
			"feature_equip": {"type": "int", "desc": "可装备", "default": 0},
			"feature_destory": {"type": "int", "desc": "可销毁", "default": 0},
			"feature_consume": {"type": "int", "desc": "可消耗", "default": 0},
			"slots": {"type": "json", "desc": "装备槽位信息", "default": ""},
			"visible": {"type": "int", "desc": "可见(0否1是)", "default": 1},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 物品 ----
	"item": {
		"desc": "物品", "icon": "🎒",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"name": {"type": "string", "desc": "物品名称", "default": ""},
			"typeid": {"type": "int", "desc": "分类ID", "default": 0},
			"desc": {"type": "text", "desc": "物品描述", "default": ""},
			"prop_equip": {"type": "json", "desc": "装备属性效果", "default": ""},
			"prop_equip_trigger_type": {"type": "int", "desc": "装备效果触发类型(0配置1脚本)", "default": 0},
			"cond_equip_ops": {"type": "int", "desc": "装备条件策略", "default": 0},
			"cond_equip": {"type": "json", "desc": "装备生效条件", "default": ""},
			"prop_consume": {"type": "json", "desc": "消耗属性效果", "default": ""},
			"cond_consume_ops": {"type": "int", "desc": "消耗条件策略", "default": 0},
			"cond_consume": {"type": "json", "desc": "消耗生效条件", "default": ""},
			"prop_carry": {"type": "json", "desc": "携带属性效果", "default": ""},
			"cond_carry_ops": {"type": "int", "desc": "携带条件策略", "default": 0},
			"cond_carry": {"type": "json", "desc": "携带生效条件", "default": ""},
			"alternation": {"type": "json", "desc": "互动按钮数据", "default": ""},
			"feature_equip": {"type": "int", "desc": "可装备", "default": 0},
			"feature_destory": {"type": "int", "desc": "可销毁", "default": 0},
			"feature_consume": {"type": "int", "desc": "可消耗", "default": 0},
			"slots": {"type": "json", "desc": "槽位信息", "default": ""},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 交互模块 ----
	"alternation": {
		"desc": "交互模块", "icon": "❓",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"name": {"type": "string", "desc": "交互模块名称", "default": ""},
			"desc": {"type": "text", "desc": "描述", "default": ""},
			"data": {"type": "json", "desc": "交互按钮数据(JSON)", "default": ""},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 奖励 ----
	"reward": {
		"desc": "奖励", "icon": "💎",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"name": {"type": "string", "desc": "奖励名称", "default": ""},
			"type": {"type": "int", "desc": "类型(1概率2权重)", "default": 1},
			"data": {"type": "json", "desc": "奖励数据(JSON)", "default": ""},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 剧情 ----
	"story": {
		"desc": "剧情", "icon": "📜",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"name": {"type": "string", "desc": "剧情名称", "default": ""},
			"data": {"type": "json", "desc": "剧情数据(JSON/脚本)", "default": ""},
			"dtype": {"type": "int", "desc": "数据类型(0配置1脚本)", "default": 0},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 敌人 ----
	"enemy": {
		"desc": "敌人", "icon": "👹",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"name": {"type": "string", "desc": "敌人名称", "default": ""},
			"desc": {"type": "text", "desc": "敌人描述", "default": ""},
			"property": {"type": "json", "desc": "敌人属性", "default": ""},
			"skill": {"type": "json", "desc": "敌人技能", "default": ""},
			"type": {"type": "int", "desc": "类型(0配置1脚本)", "default": 0},
			"script": {"type": "script", "desc": "脚本", "default": ""},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 敌人模板(仅编辑器用,不导出) ----
	"enemy_template": {
		"desc": "敌人模板", "icon": "📋",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"name": {"type": "string", "desc": "模板名称", "default": ""},
			"property": {"type": "json", "desc": "属性", "default": ""},
			"skill": {"type": "json", "desc": "技能", "default": ""},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 战役 ----
	"campaign": {
		"desc": "战役", "icon": "⚔",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"name": {"type": "string", "desc": "战役名称", "default": ""},
			"desc": {"type": "text", "desc": "战役描述", "default": ""},
			"enemies": {"type": "json", "desc": "敌人列表", "default": ""},
			"trigger": {"type": "json", "desc": "胜负触发(win/lose)", "default": ""},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 插槽 ----
	"slot": {
		"desc": "插槽", "icon": "🔲",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"name": {"type": "string", "desc": "插槽部位名称", "default": ""},
			"cnt": {"type": "int", "desc": "孔洞数量", "default": 0},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 插槽模板(仅编辑器用,不导出) ----
	"slot_template": {
		"desc": "插槽模板", "icon": "📋",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"name": {"type": "string", "desc": "模板名称", "default": ""},
			"data": {"type": "json", "desc": "槽位数据(JSON)", "default": ""},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 概率模块 ----
	"random": {
		"desc": "概率事件", "icon": "🎲",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"name": {"type": "string", "desc": "模块名称", "default": ""},
			"cond_ops": {"type": "int", "desc": "条件策略", "default": 0},
			"cond_type": {"type": "int", "desc": "条件类型", "default": 0},
			"cond": {"type": "json", "desc": "条件", "default": ""},
			"success_type": {"type": "int", "desc": "成功触发类型(1概率2权重3脚本)", "default": 1},
			"success": {"type": "json", "desc": "成功触发内容", "default": ""},
			"success_desc": {"type": "text", "desc": "成功提示", "default": ""},
			"fail_type": {"type": "int", "desc": "失败触发类型", "default": 1},
			"fail": {"type": "json", "desc": "失败触发内容", "default": ""},
			"fail_desc": {"type": "text", "desc": "失败提示", "default": ""},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 交易 ----
	"trade": {
		"desc": "交易", "icon": "💱",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"name": {"type": "string", "desc": "名称", "default": ""},
			"type": {"type": "int", "desc": "类型(0普通1合成2分解)", "default": 0},
			"desc": {"type": "text", "desc": "描述", "default": ""},
			"tradein": {"type": "json", "desc": "换入", "default": ""},
			"tradeout": {"type": "json", "desc": "换出", "default": ""},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 生产 ----
	"generator": {
		"desc": "生产", "icon": "⏳",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"name": {"type": "string", "desc": "模块名称", "default": ""},
			"desc": {"type": "text", "desc": "描述", "default": ""},
			"type": {"type": "int", "desc": "生产类型(1采集2制造)", "default": 1},
			"auto_start": {"type": "int", "desc": "自动开启", "default": 0},
			"cond_open_ops": {"type": "int", "desc": "开启条件策略", "default": 0},
			"cond_open_type": {"type": "int", "desc": "开启条件类型", "default": 0},
			"cond_open": {"type": "json", "desc": "开启条件", "default": ""},
			"cond_get_ops": {"type": "int", "desc": "获取条件策略", "default": 0},
			"cond_get_type": {"type": "int", "desc": "获取条件类型", "default": 0},
			"cond_get": {"type": "json", "desc": "获取条件", "default": ""},
			"trigger_open_type": {"type": "int", "desc": "开启触发类型", "default": 0},
			"trigger_open": {"type": "json", "desc": "开启触发", "default": ""},
			"trigger_get_type": {"type": "int", "desc": "获取触发类型", "default": 0},
			"trigger_get": {"type": "json", "desc": "获取触发", "default": ""},
			"data_type": {"type": "int", "desc": "数据类型(1配置2脚本)", "default": 1},
			"data": {"type": "json", "desc": "产品数据", "default": ""},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 充值 ----
	"payment": {
		"desc": "充值", "icon": "💰",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"name": {"type": "string", "desc": "标题名称", "default": ""},
			"desc": {"type": "text", "desc": "描述", "default": ""},
			"price": {"type": "decimal", "desc": "价格", "default": 1},
			"currency": {"type": "string", "desc": "币种", "default": "CNY"},
			"content": {"type": "json", "desc": "购买内容", "default": ""},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 逻辑 ----
	"logic": {
		"desc": "逻辑", "icon": "🧠",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"name": {"type": "string", "desc": "标题", "default": ""},
			"note": {"type": "string", "desc": "备注", "default": ""},
			"condition": {"type": "json", "desc": "条件{type,data,ops}", "default": ""},
			"success": {"type": "json", "desc": "成功触发{type,data}", "default": ""},
			"fail": {"type": "json", "desc": "失败触发{type,data}", "default": ""},
		}
	},
	# ---- 自定义数据 ----
	"custom_data": {
		"desc": "自定义数据", "icon": "🗃",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"kname": {"type": "string", "desc": "键值名称", "default": ""},
			"name": {"type": "string", "desc": "简易名称", "default": ""},
			"type": {"type": "int", "desc": "数据类型(0文本1JSON)", "default": 0},
			"data": {"type": "text", "desc": "数据", "default": ""},
			"note": {"type": "string", "desc": "备注", "default": ""},
		}
	},
	# ---- 脚本插件 ----
	"script_pluggin": {
		"desc": "脚本插件", "icon": "📝",
		"fields": {
			"id": {"type": "int", "desc": "ID", "default": 0},
			"name": {"type": "string", "desc": "名称", "default": ""},
			"note": {"type": "string", "desc": "备注", "default": ""},
			"data": {"type": "script", "desc": "脚本数据", "default": ""},
		}
	},
}

## === 表顺序（与 gameinit.sql 创建顺序一致） ===
const TABLE_ORDER: Array = [
	"config", "map", "scene", "linkpath", "object", "scene_object", "module_talk",
	"property", "property_type", "skill", "skill_type", "item_type", "item",
	"alternation", "reward", "story", "enemy", "enemy_template", "campaign",
	"slot", "slot_template", "random", "trade", "generator", "payment",
	"logic", "custom_data", "script_pluggin",
]

## === 仅编辑器使用、不参与导出的表 ===
const EDITOR_ONLY_TABLES: Array = ["enemy_template", "slot_template"]

## === 唯一索引（对应 gameinit.sql 的 unique index，用于 CRUD 约束） ===
## 结构: {表名: [[字段...], ...]}
const UNIQUE_INDEXES: Dictionary = {
	"linkpath": [["startpot", "endpot", "direct"]],
	"property": [["name"]],
	"item_type": [["typeid"]],
	"config": [["name"]],
	"scene_object": [["sceneid", "objid"]],
	"custom_data": [["kname"]],
}

## === 8 个方向常量（linkpath.direct 取值） ===
const DIRECTIONS: Array = [
	"east", "south", "west", "north",
	"southeast", "southwest", "northeast", "northwest",
]

## 方向 → 中文显示
const DIRECTION_NAMES: Dictionary = {
	"east": "东", "south": "南", "west": "西", "north": "北",
	"southeast": "东南", "southwest": "西南", "northeast": "东北", "northwest": "西北",
}

# ===================== 工具函数 =====================

## 表是否存在
static func has_table(table_name: String) -> bool:
	return TABLES.has(table_name)

## 获取表定义
static func get_table(table_name: String) -> Dictionary:
	if TABLES.has(table_name):
		return TABLES[table_name] as Dictionary
	return {}

## 获取表显示名称
static func get_display_name(table_name: String) -> String:
	var t: Dictionary = get_table(table_name)
	if t.is_empty():
		return table_name
	var icon_val: Variant = t.get("icon", "📄")
	var desc_val: Variant = t.get("desc", table_name)
	return "%s %s" % [icon_val, desc_val]

## 获取表字段名列表（保持定义顺序）
static func get_field_names(table_name: String) -> Array:
	var t: Dictionary = get_table(table_name)
	if t.is_empty():
		return []
	var fields_val: Variant = t.get("fields", {})
	if fields_val is Dictionary:
		return (fields_val as Dictionary).keys()
	return []

## 获取字段定义 {type, desc, default}
static func get_field(table_name: String, field_name: String) -> Dictionary:
	var t: Dictionary = get_table(table_name)
	if t.is_empty():
		return {}
	var fields_val: Variant = t.get("fields", {})
	if fields_val is Dictionary:
		var f: Dictionary = fields_val as Dictionary
		if f.has(field_name):
			var fd: Variant = f[field_name]
			if fd is Dictionary:
				return fd as Dictionary
	return {}

## 获取字段类型
static func get_field_type(table_name: String, field_name: String) -> String:
	var fd: Dictionary = get_field(table_name, field_name)
	if fd.has("type"):
		var tv: Variant = fd["type"]
		if tv is String:
			return tv as String
	return "string"

## 获取字段默认值
static func get_field_default(table_name: String, field_name: String) -> Variant:
	var fd: Dictionary = get_field(table_name, field_name)
	if fd.has("default"):
		return fd["default"]
	# 无默认值时按类型给零值
	match get_field_type(table_name, field_name):
		"int": return 0
		"decimal": return 0.0
		_: return ""

## 创建一条带全部默认值的空记录
static func create_default_entry(table_name: String) -> Dictionary:
	var entry: Dictionary = {}
	for fn in get_field_names(table_name):
		var fn_str: String = fn as String
		entry[fn_str] = get_field_default(table_name, fn_str)
	return entry

## 是否为仅编辑器表（不导出）
static func is_editor_only(table_name: String) -> bool:
	return EDITOR_ONLY_TABLES.has(table_name)

## 获取表的唯一索引字段组列表
static func get_unique_indexes(table_name: String) -> Array:
	if UNIQUE_INDEXES.has(table_name):
		return UNIQUE_INDEXES[table_name] as Array
	return []

## 检查记录是否违反唯一索引（与已有行比较，排除自身）
## rows: Array[Dictionary], entry: 待检查记录, self_id: 自身id(更新时排除)
static func find_unique_conflict(table_name: String, rows: Array, entry: Dictionary, self_id: Variant = null) -> Dictionary:
	for group in get_unique_indexes(table_name):
		if not (group is Array):
			continue
		var fields: Array = group as Array
		if fields.is_empty():
			continue
		for row in rows:
			if not (row is Dictionary):
				continue
			var r: Dictionary = row as Dictionary
			# 排除自身
			if self_id != null and r.has("id") and r["id"] == self_id:
				continue
			var all_match: bool = true
			for f in fields:
				var f_str: String = f as String
				var ev: Variant = entry.get(f_str)
				var rv: Variant = r.get(f_str)
				if ev == null or rv == null or ev != rv:
					all_match = false
					break
			if all_match:
				return r
	return {}
