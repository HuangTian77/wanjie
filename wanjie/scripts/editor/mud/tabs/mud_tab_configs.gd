## MUD编辑器 - 标签页配置（复刻 ME loader/inner/inner_panel_*.html 的表单字段与按钮）
## 配置驱动：每个标签页由若干子标签(subtab)组成，每个子标签对应一张内部表，
## 并定义表单字段(form)与操作按钮(buttons)。构建逻辑见 mud_tab_builder.gd。
##
## 子标签结构:
##   label   子标签显示名
##   table   内部表名
##   noun    名词（用于生成 新增X/更新X/删除X 按钮文本）
##   buttons 操作按钮数组 [{"action":..,"label":..?}]
##           action: add/copy/edit/export/import/update/delete
##           edit 可用 label 覆盖（默认"高级编辑"）
##   form    表单字段数组 [{"field","label","type", ...}]
##           type: readonly/text/int/decimal/textarea/select/checkbox
##           readonly 可选 map(值映射) 或 join(关联解析)
##           select 需 from_table/value_field/label_field（从表加载选项）
class_name MudTabConfigs
extends RefCounted

## 值映射常量（与 mud_table_widget.gd DISPLAY 保持一致）
const MAP_TRIGGER: Dictionary = {0: "无", 1: "条件", 2: "脚本"}
const MAP_COND_CFG: Dictionary = {0: "无", 1: "配置", 2: "脚本"}
const MAP_RAND: Dictionary = {1: "概率随机", 2: "权重分配", 3: "脚本逻辑"}
const MAP_TRADE: Dictionary = {0: "普通", 1: "合成", 2: "分解"}
const MAP_REWARD: Dictionary = {1: "随机概率", 2: "权重分配"}
const MAP_STORY: Dictionary = {0: "配置", 1: "脚本"}
const MAP_GEN_TYPE: Dictionary = {1: "采集", 2: "制造"}
const MAP_GEN_DATA: Dictionary = {1: "配置", 2: "脚本"}
const MAP_PATH_STATUS: Dictionary = {0: "正常", 1: "隐藏"}
const MAP_YESNO: Dictionary = {0: "否", 1: "是"}

## === 15 个标签页配置（顺序即标签顺序，对应 main.html 的 strip） ===
const TABS: Array = [
	# ---- 1. 地图（5 子标签） ----
	{
		"name": "地图",
		"subtabs": [
			{
				"label": "地图", "table": "map", "noun": "地图",
				"buttons": [{"action": "add"}, {"action": "update"}, {"action": "delete"}],
				"form": [
					{"field": "id", "label": "ID", "type": "readonly"},
					{"field": "name", "label": "名称", "type": "text"},
					{"field": "width", "label": "宽", "type": "int"},
					{"field": "height", "label": "高", "type": "int"},
					{"field": "desc", "label": "描述", "type": "textarea"},
					{"field": "note", "label": "备注", "type": "textarea"},
				],
			},
			{
				"label": "场景节点", "table": "scene", "noun": "场景",
				"buttons": [{"action": "edit", "label": "互动编辑"}, {"action": "update"}, {"action": "delete"}],
				"form": [
					{"field": "id", "label": "场景ID", "type": "readonly"},
					{"field": "name", "label": "场景名称", "type": "text"},
					{"field": "et_type", "label": "进入触发", "type": "readonly", "map": MAP_TRIGGER},
					{"field": "lt_type", "label": "离开触发", "type": "readonly", "map": MAP_TRIGGER},
					{"field": "desc", "label": "描述", "type": "textarea"},
					{"field": "note", "label": "备注", "type": "textarea"},
				],
			},
			{
				"label": "路径", "table": "linkpath", "noun": "路径",
				"buttons": [{"action": "edit", "label": "互动编辑"}, {"action": "update"}, {"action": "delete", "label": "删除路径"}],
				"form": [
					{"field": "id", "label": "路径ID", "type": "readonly"},
					{"field": "passcond_type", "label": "通过触发", "type": "readonly", "map": MAP_TRIGGER},
					{"field": "status_editable", "label": "可开合", "type": "select", "options": MAP_YESNO},
					{"field": "status", "label": "状态", "type": "select", "options": MAP_PATH_STATUS},
					{"field": "direct", "label": "出口方向", "type": "readonly", "map": MudSchemaInternal.DIRECTION_NAMES},
					{"field": "startpot", "label": "出口", "type": "readonly", "join": "start_name"},
					{"field": "endpot", "label": "入口", "type": "readonly", "join": "end_name"},
					{"field": "note", "label": "备注", "type": "textarea"},
				],
			},
			{
				"label": "场景对象", "table": "object", "noun": "对象",
				"buttons": [{"action": "export"}, {"action": "import"}, {"action": "update", "label": "更新信息"}, {"action": "delete", "label": "删除对象"}],
				"form": [
					{"field": "id", "label": "对象ID", "type": "readonly"},
					{"field": "name", "label": "对象名称", "type": "text"},
					{"field": "desc", "label": "描述", "type": "textarea"},
					{"field": "note", "label": "备注", "type": "textarea"},
				],
			},
			{
				"label": "对象互动", "table": "module_talk", "noun": "互动",
				"buttons": [{"action": "edit", "label": "互动编辑"}, {"action": "export"}, {"action": "import"}, {"action": "update", "label": "更新信息"}, {"action": "delete", "label": "删除信息"}],
				"form": [
					{"field": "id", "label": "互动ID", "type": "readonly"},
					{"field": "name", "label": "互动名称", "type": "text"},
					{"field": "objid", "label": "对象", "type": "readonly", "join": "object_name"},
					{"field": "trigger_type", "label": "触发类型", "type": "readonly", "map": MAP_TRIGGER},
					{"field": "visible_cond_trigger_type", "label": "显示控制", "type": "readonly", "map": MAP_TRIGGER},
					{"field": "content", "label": "内容名称", "type": "textarea"},
					{"field": "note", "label": "备注", "type": "textarea"},
				],
			},
		],
	},
	# ---- 2. 交互 ----
	{
		"name": "交互",
		"subtabs": [
			{
				"label": "交互", "table": "alternation", "noun": "交互",
				"buttons": [{"action": "add"}, {"action": "edit", "label": "交互编辑"}, {"action": "export"}, {"action": "import"}, {"action": "update", "label": "更新信息"}, {"action": "delete", "label": "删除信息"}],
				"form": [
					{"field": "id", "label": "交互ID", "type": "readonly"},
					{"field": "name", "label": "标题", "type": "text"},
					{"field": "desc", "label": "内容", "type": "textarea"},
					{"field": "note", "label": "备注", "type": "textarea"},
				],
			},
		],
	},
	# ---- 3. 概率 ----
	{
		"name": "概率",
		"subtabs": [
			{
				"label": "概率", "table": "random", "noun": "概率",
				"buttons": [{"action": "add"}, {"action": "copy"}, {"action": "edit", "label": "详情编辑"}, {"action": "update", "label": "更新信息"}, {"action": "delete", "label": "删除信息"}],
				"form": [
					{"field": "id", "label": "ID", "type": "readonly"},
					{"field": "name", "label": "名称", "type": "text"},
					{"field": "cond_type", "label": "条件类型", "type": "readonly", "map": MAP_COND_CFG},
					{"field": "success_type", "label": "满足触发", "type": "readonly", "map": MAP_RAND},
					{"field": "fail_type", "label": "失败触发", "type": "readonly", "map": MAP_RAND},
					{"field": "note", "label": "备注", "type": "textarea"},
				],
			},
		],
	},
	# ---- 4. 逻辑 ----
	{
		"name": "逻辑",
		"subtabs": [
			{
				"label": "逻辑", "table": "logic", "noun": "逻辑",
				"buttons": [{"action": "add"}, {"action": "copy"}, {"action": "edit", "label": "逻辑编辑"}, {"action": "update"}, {"action": "delete"}],
				"form": [
					{"field": "id", "label": "ID", "type": "readonly"},
					{"field": "name", "label": "名称", "type": "text"},
					{"field": "note", "label": "备注", "type": "textarea"},
				],
			},
		],
	},
	# ---- 5. 属性（2 子标签） ----
	{
		"name": "属性",
		"subtabs": [
			{
				"label": "属性表", "table": "property", "noun": "属性",
				"buttons": [{"action": "add"}, {"action": "edit", "label": "高级编辑"}, {"action": "export"}, {"action": "import"}, {"action": "update"}, {"action": "delete"}],
				"form": [
					{"field": "id", "label": "属性ID", "type": "readonly"},
					{"field": "typeid", "label": "分类", "type": "select", "from_table": "property_type", "value_field": "id", "label_field": "name"},
					{"field": "name", "label": "属性名称", "type": "text"},
					{"field": "priority", "label": "排序权重", "type": "int"},
					{"field": "desc", "label": "描述", "type": "textarea"},
					{"field": "note", "label": "备注", "type": "textarea"},
				],
			},
			{
				"label": "分类表", "table": "property_type", "noun": "分类",
				"buttons": [{"action": "add"}, {"action": "update"}, {"action": "delete"}],
				"form": [
					{"field": "id", "label": "ID", "type": "readonly"},
					{"field": "name", "label": "分类名称", "type": "text"},
					{"field": "priority", "label": "显示优先级", "type": "int"},
					{"field": "visible", "label": "可见", "type": "checkbox"},
					{"field": "desc", "label": "描述", "type": "textarea"},
				],
			},
		],
	},
	# ---- 6. 插槽（2 子标签） ----
	{
		"name": "插槽",
		"subtabs": [
			{
				"label": "插槽部位", "table": "slot", "noun": "槽位",
				"buttons": [{"action": "add"}, {"action": "update", "label": "更新信息"}, {"action": "delete", "label": "删除槽位"}],
				"form": [
					{"field": "id", "label": "槽位ID", "type": "readonly"},
					{"field": "name", "label": "槽位名称", "type": "text"},
					{"field": "cnt", "label": "插孔数量", "type": "int"},
					{"field": "note", "label": "备注", "type": "textarea"},
				],
			},
			{
				"label": "槽位模板", "table": "slot_template", "noun": "模板",
				"buttons": [{"action": "add"}, {"action": "edit", "label": "编辑模板"}, {"action": "update", "label": "更新信息"}, {"action": "delete", "label": "删除模板"}],
				"form": [
					{"field": "id", "label": "模板ID", "type": "readonly"},
					{"field": "name", "label": "模板名称", "type": "text"},
					{"field": "note", "label": "备注", "type": "textarea"},
				],
			},
		],
	},
	# ---- 7. 技能（2 子标签） ----
	{
		"name": "技能",
		"subtabs": [
			{
				"label": "技能表", "table": "skill", "noun": "技能",
				"buttons": [{"action": "add"}, {"action": "edit", "label": "技能编辑"}, {"action": "export"}, {"action": "import"}, {"action": "update", "label": "更新信息"}, {"action": "delete", "label": "删除信息"}],
				"form": [
					{"field": "id", "label": "ID", "type": "readonly"},
					{"field": "name", "label": "名称", "type": "text"},
					{"field": "typeid", "label": "分类", "type": "select", "from_table": "skill_type", "value_field": "id", "label_field": "name"},
					{"field": "desc", "label": "描述", "type": "textarea"},
					{"field": "note", "label": "备注", "type": "textarea"},
				],
			},
			{
				"label": "分类表", "table": "skill_type", "noun": "分类",
				"buttons": [{"action": "add"}, {"action": "update", "label": "更新信息"}, {"action": "delete", "label": "删除信息"}],
				"form": [
					{"field": "id", "label": "ID", "type": "readonly"},
					{"field": "name", "label": "名称", "type": "text"},
					{"field": "priority", "label": "排序权重", "type": "int"},
					{"field": "visible", "label": "可见", "type": "checkbox"},
					{"field": "note", "label": "备注", "type": "textarea"},
				],
			},
		],
	},
	# ---- 8. 物品（2 子标签） ----
	{
		"name": "物品",
		"subtabs": [
			{
				"label": "物品表", "table": "item", "noun": "物品",
				"buttons": [{"action": "add"}, {"action": "copy"}, {"action": "edit", "label": "编辑详情"}, {"action": "export"}, {"action": "import"}, {"action": "update"}, {"action": "delete"}],
				"form": [
					{"field": "id", "label": "物品ID", "type": "readonly"},
					{"field": "typeid", "label": "分类", "type": "select", "from_table": "item_type", "value_field": "typeid", "label_field": "name"},
					{"field": "feature_equip", "label": "可装备", "type": "checkbox"},
					{"field": "feature_consume", "label": "可消耗", "type": "checkbox"},
					{"field": "feature_destory", "label": "可销毁", "type": "checkbox"},
					{"field": "name", "label": "物品名称", "type": "text"},
					{"field": "desc", "label": "描述", "type": "textarea"},
					{"field": "note", "label": "备注", "type": "textarea"},
				],
			},
			{
				"label": "分类表", "table": "item_type", "noun": "分类",
				"buttons": [{"action": "add"}, {"action": "update"}, {"action": "delete"}],
				"form": [
					{"field": "id", "label": "ID", "type": "readonly"},
					{"field": "typeid", "label": "分类ID", "type": "int"},
					{"field": "name", "label": "分类名称", "type": "text"},
					{"field": "visible", "label": "可见", "type": "checkbox"},
					{"field": "feature_equip", "label": "可装备", "type": "checkbox"},
					{"field": "feature_consume", "label": "可消耗", "type": "checkbox"},
					{"field": "feature_destory", "label": "可销毁", "type": "checkbox"},
					{"field": "priority", "label": "显示优先级", "type": "int"},
					{"field": "desc", "label": "描述", "type": "textarea"},
				],
			},
		],
	},
	# ---- 9. 生产 ----
	{
		"name": "生产",
		"subtabs": [
			{
				"label": "生产", "table": "generator", "noun": "生产",
				"buttons": [{"action": "add"}, {"action": "copy"}, {"action": "edit", "label": "生产编辑"}, {"action": "update"}, {"action": "delete"}],
				"form": [
					{"field": "id", "label": "ID", "type": "readonly"},
					{"field": "name", "label": "名称", "type": "text"},
					{"field": "type", "label": "生产类型", "type": "readonly", "map": MAP_GEN_TYPE},
					{"field": "data_type", "label": "数据类型", "type": "readonly", "map": MAP_GEN_DATA},
					{"field": "cond_open_type", "label": "开启条件", "type": "readonly", "map": MAP_COND_CFG},
					{"field": "trigger_open_type", "label": "开启触发", "type": "readonly", "map": MAP_COND_CFG},
					{"field": "cond_get_type", "label": "领取条件", "type": "readonly", "map": MAP_COND_CFG},
					{"field": "trigger_get_type", "label": "领取触发", "type": "readonly", "map": MAP_COND_CFG},
					{"field": "note", "label": "备注", "type": "textarea"},
				],
			},
		],
	},
	# ---- 10. 交易 ----
	{
		"name": "交易",
		"subtabs": [
			{
				"label": "交易", "table": "trade", "noun": "交易",
				"buttons": [{"action": "add"}, {"action": "edit", "label": "交易编辑"}, {"action": "update"}, {"action": "delete"}],
				"form": [
					{"field": "id", "label": "ID", "type": "readonly"},
					{"field": "name", "label": "名称", "type": "text"},
					{"field": "type", "label": "类型", "type": "readonly", "map": MAP_TRADE},
					{"field": "desc", "label": "描述", "type": "textarea"},
					{"field": "note", "label": "备注", "type": "textarea"},
				],
			},
		],
	},
	# ---- 11. 奖励 ----
	{
		"name": "奖励",
		"subtabs": [
			{
				"label": "奖励", "table": "reward", "noun": "奖励",
				"buttons": [{"action": "add"}, {"action": "copy"}, {"action": "edit", "label": "详情编辑"}, {"action": "update", "label": "更新信息"}, {"action": "delete", "label": "删除信息"}],
				"form": [
					{"field": "id", "label": "奖励ID", "type": "readonly"},
					{"field": "name", "label": "名称", "type": "text"},
					{"field": "type", "label": "类型", "type": "readonly", "map": MAP_REWARD},
					{"field": "note", "label": "备注", "type": "textarea"},
				],
			},
		],
	},
	# ---- 12. 战役（3 子标签） ----
	{
		"name": "战役",
		"subtabs": [
			{
				"label": "战役列表", "table": "campaign", "noun": "战役",
				"buttons": [{"action": "add"}, {"action": "copy"}, {"action": "edit", "label": "战役编辑"}, {"action": "export"}, {"action": "import"}, {"action": "update", "label": "更新信息"}, {"action": "delete", "label": "删除战役"}],
				"form": [
					{"field": "id", "label": "战役ID", "type": "readonly"},
					{"field": "name", "label": "战役名称", "type": "text"},
					{"field": "desc", "label": "战役描述", "type": "textarea"},
					{"field": "note", "label": "战役备注", "type": "textarea"},
				],
			},
			{
				"label": "敌人对象", "table": "enemy", "noun": "敌人",
				"buttons": [{"action": "add"}, {"action": "copy"}, {"action": "edit", "label": "详情编辑"}, {"action": "export"}, {"action": "import"}, {"action": "update", "label": "更新信息"}, {"action": "delete", "label": "删除对象"}],
				"form": [
					{"field": "id", "label": "敌人ID", "type": "readonly"},
					{"field": "name", "label": "敌人名称", "type": "text"},
					{"field": "desc", "label": "敌人描述", "type": "textarea"},
					{"field": "note", "label": "敌人备注", "type": "textarea"},
				],
			},
			{
				"label": "敌人模板", "table": "enemy_template", "noun": "模板",
				"buttons": [{"action": "add"}, {"action": "copy"}, {"action": "edit", "label": "详情编辑"}, {"action": "update", "label": "更新信息"}, {"action": "delete", "label": "删除对象"}],
				"form": [
					{"field": "id", "label": "模板ID", "type": "readonly"},
					{"field": "name", "label": "模板名称", "type": "text"},
					{"field": "note", "label": "模板备注", "type": "textarea"},
				],
			},
		],
	},
	# ---- 13. 剧情 ----
	{
		"name": "剧情",
		"subtabs": [
			{
				"label": "剧情", "table": "story", "noun": "剧情",
				"buttons": [{"action": "add"}, {"action": "edit", "label": "剧情编辑"}, {"action": "update"}, {"action": "delete"}],
				"form": [
					{"field": "id", "label": "剧情ID", "type": "readonly"},
					{"field": "name", "label": "剧情名称", "type": "text"},
					{"field": "dtype", "label": "类型", "type": "readonly", "map": MAP_STORY},
					{"field": "note", "label": "备注", "type": "textarea"},
				],
			},
		],
	},
	# ---- 14. 充值 ----
	{
		"name": "充值",
		"subtabs": [
			{
				"label": "充值", "table": "payment", "noun": "充值",
				"buttons": [{"action": "add"}, {"action": "edit", "label": "充值编辑"}, {"action": "update"}, {"action": "delete"}],
				"form": [
					{"field": "id", "label": "ID", "type": "readonly"},
					{"field": "name", "label": "名称", "type": "text"},
					{"field": "price", "label": "价格", "type": "decimal"},
					{"field": "desc", "label": "描述", "type": "textarea"},
					{"field": "note", "label": "备注", "type": "textarea"},
				],
			},
		],
	},
	# ---- 15. 数据 ----
	{
		"name": "数据",
		"subtabs": [
			{
				"label": "数据", "table": "custom_data", "noun": "数据",
				"buttons": [{"action": "add"}, {"action": "copy"}, {"action": "edit", "label": "数据编辑"}, {"action": "update", "label": "更新信息"}, {"action": "delete", "label": "删除数据"}],
				"form": [
					{"field": "id", "label": "ID", "type": "readonly"},
					{"field": "kname", "label": "键名", "type": "text"},
					{"field": "name", "label": "名称", "type": "text"},
					{"field": "note", "label": "备注", "type": "textarea"},
				],
			},
		],
	},
]
