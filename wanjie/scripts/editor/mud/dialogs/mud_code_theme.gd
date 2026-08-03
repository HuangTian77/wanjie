## mud_code_theme.gd
## MUD 编辑器代码主题（迁移 ME/lexers 语法高亮 + 公式模板）
##
## 来源：
##   配色  <- ME/lexers/themes/dark.lua（Scintillua 暗色主题）
##   词法  <- ME/lexers/lua.lua / json.lua（关键字/函数/库/字符串/注释规则）
##   模板  <- ME loader/dialogs/editproperty.lua（属性公式模板 clickAddFunctionTemplate）
##            edit skill.lua（技能公式模板 formula_tamplate / formula_tamplate_back）
##
## 用途：为各编辑对话框中的脚本/公式/JSON 字段提供 Godot CodeEdit 语法高亮，
##       以及「公式模板」插入按钮的模板内容。
class_name MudCodeTheme
extends RefCounted

# ===================== 暗色主题配色（ME dark.lua） =====================
const C_BG := Color8(0x1A, 0x1A, 0x1A)        # black 编辑器背景
const C_FG := Color8(0x99, 0x99, 0x99)        # light_grey 默认文本
const C_COMMENT := Color8(0x66, 0x66, 0x66)   # dark_grey 注释
const C_CONSTANT := Color8(0x99, 0x4D, 0x4D)  # red 常量
const C_FUNCTION := Color8(0x4D, 0x99, 0xE6)  # blue 函数
const C_KEYWORD := Color8(0xCC, 0xCC, 0xCC)   # dark_white 关键字
const C_LABEL := Color8(0xE6, 0x99, 0x4D)     # orange 标签
const C_NUMBER := Color8(0x4D, 0x99, 0x99)    # teal 数字
const C_OPERATOR := Color8(0x99, 0x99, 0x4D)  # yellow 运算符
const C_STRING := Color8(0x4D, 0x99, 0x4D)    # green 字符串
const C_TYPE := Color8(0x99, 0x99, 0xE6)      # lavender 库/类型
const C_VARIABLE := Color8(0x80, 0xCC, 0xFF)  # light_blue 变量

# ===================== Lua 词法集合（ME lua.lua） =====================
const LUA_KEYWORDS: Array = [
	"and", "break", "do", "else", "elseif", "end", "false", "for", "function",
	"goto", "if", "in", "local", "nil", "not", "or", "repeat", "return", "then",
	"true", "until", "while",
]

const LUA_FUNCTIONS: Array = [
	"assert", "collectgarbage", "dofile", "error", "getmetatable", "ipairs",
	"load", "loadfile", "next", "pairs", "pcall", "print", "rawequal", "rawget",
	"rawlen", "rawset", "require", "select", "setmetatable", "tonumber",
	"tostring", "type", "xpcall", "self",
]

const LUA_CONSTANTS: Array = ["_G", "_VERSION"]

const LUA_LIBRARIES: Array = [
	"coroutine", "package", "string", "table", "math", "bit32", "io", "os",
	"debug",
]

# MUD 运行时注入的全局函数（脚本公式中常用）
const MUD_FORMULA_FUNCS: Array = [
	"getProperty", "range", "getPropertyValue", "addPropertyValue", "P", "TP",
	"SP", "trace",
]


# ===================== 高亮器工厂 =====================

## 构建 Lua 语法高亮器
static func make_lua_highlighter() -> CodeHighlighter:
	var hl := CodeHighlighter.new()
	hl.number_color = C_NUMBER
	hl.symbol_color = C_OPERATOR
	hl.function_color = C_FUNCTION
	hl.member_variable_color = C_VARIABLE
	for kw in LUA_KEYWORDS:
		hl.add_keyword_color(kw, C_KEYWORD)
	for fn in LUA_FUNCTIONS:
		hl.add_keyword_color(fn, C_FUNCTION)
	for cn in LUA_CONSTANTS:
		hl.add_keyword_color(cn, C_CONSTANT)
	for lb in LUA_LIBRARIES:
		hl.add_keyword_color(lb, C_TYPE)
	for fn in MUD_FORMULA_FUNCS:
		hl.add_keyword_color(fn, C_FUNCTION)
	# 注释（-- 行注释；[[ ]] 块注释/长字符串）
	hl.add_color_region("--", "", C_COMMENT, true)
	hl.add_color_region("[[", "]]", C_STRING)
	# 字符串
	hl.add_color_region("\"", "\"", C_STRING)
	hl.add_color_region("'", "'", C_STRING)
	return hl


## 构建 JSON 语法高亮器
static func make_json_highlighter() -> CodeHighlighter:
	var hl := CodeHighlighter.new()
	hl.number_color = C_NUMBER
	hl.symbol_color = C_OPERATOR
	hl.function_color = C_FUNCTION
	for kw in ["true", "false", "null"]:
		hl.add_keyword_color(kw, C_CONSTANT)
	hl.add_color_region("\"", "\"", C_STRING)
	return hl


## 按语言名取高亮器（lua/json）
static func make_highlighter(lang: String) -> CodeHighlighter:
	if lang == "json":
		return make_json_highlighter()
	return make_lua_highlighter()


# ===================== CodeEdit 工厂 / 应用 =====================

## 将主题应用到已有 CodeEdit（设置配色 + 高亮器）
static func apply_to(ce: CodeEdit, lang: String = "lua") -> void:
	ce.add_theme_color_override("font_color", C_FG)
	ce.add_theme_color_override("background_color", C_BG)
	ce.add_theme_color_override("caret_color", C_FG)
	ce.add_theme_color_override("font_selected_color", C_FG)
	ce.add_theme_color_override("selection_color", Color8(0x33, 0x33, 0x33))
	ce.add_theme_color_override("current_line_color", Color8(0x33, 0x33, 0x33))
	ce.add_theme_color_override("line_number_color", C_COMMENT)
	ce.syntax_highlighter = make_highlighter(lang)


## 创建一个已套用主题的 CodeEdit（用于脚本/公式/JSON 字段）
static func make_code_edit(lang: String = "lua", min_h: float = 160.0) -> CodeEdit:
	var ce := CodeEdit.new()
	ce.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ce.size_flags_vertical = Control.SIZE_EXPAND_FILL
	ce.custom_minimum_size = Vector2(0, min_h)
	ce.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	ce.indent_size = 4
	ce.indent_use_spaces = true
	ce.draw_tabs = true
	ce.gutters_draw_line_numbers = true
	ce.highlight_current_line = true
	ce.add_theme_font_size_override("font_size", 13)
	apply_to(ce, lang)
	return ce


# ===================== 公式 / 脚本模板 =====================

## 属性计算公式模板（ME editproperty.lua clickAddFunctionTemplate）
const TPL_PROPERTY_FORMULA: String = """-- 获取属性的函数名：getProperty()，可以传入属性的 ID 作为参数
-- 建议为字符串（用单引号括起来），可以获取高亮支持
-- 例子为根据经验值计算等级的公式

-- 定义一个经验值的变量，假设经验值的属性的 ID 为 1，则
local exp = getProperty('1')

-- 得到经验值和等级的关系，^ 是幂的意思，10^2 表示 10 × 10，10^3 表示 10 × 10 × 10
local lvl = exp^0.9 / 100

-- 返回等级
return lvl
"""

## 技能公式模板（ME editskill.lua formula_tamplate：目标队列版）
const TPL_SKILL_TARGET: String = """-- 可使用的对象数据：
--      targetList: 目标队列，可能是多个
--      attacker: 攻击者
-- 对象的函数：
--      getPropertyValue(key): 获取对象的属性数据
--      addPropertyValue(key, value): 修改某个属性的数据
-- 对象属性：
--      isDead: 对象是否死亡的标志，boolean 值
-- 通用函数：
--      range(a, b): 随机返回 a, b 之间的数，闭区间，包括 a 或者 b 的值

-- 返回日志
local logList = {};

-- 迭代敌方的对象列表，都打一次
for i,v in pairs(targetList) do
    -- 获取攻击方的攻击区间
    local valueA1 = attacker:getPropertyValue('攻击上限');
    local valueA2 = attacker:getPropertyValue('攻击下限');
    local valueA = range(valueA1, valueA2);

    -- 获取防御方的防御数据区间
    local valueD1 = v:getPropertyValue('防御上限');
    local valueD2 = v:getPropertyValue('防御下限');
    local valueD = range(valueD1, valueD2);

    -- 计算伤害
    local valueAdd = -math.max((valueA - valueD), 0);
    local propertyID = '生命值临时';
    v:addPropertyValue(propertyID, valueAdd);

    -- 判断目标是否死亡
    local valueDes = v:getPropertyValue(propertyID);
    if valueDes <= 0 then
        v.isDead = true;
    end

    local valueChangedLog = {id = propertyID, valueDes = valueDes, valueChanged = valueAdd};
    local targetLog = {targetID = v._userid, value = {valueChangedLog}, isDead = v.isDead};
    table.insert(logList, targetLog);
end

return logList;
"""

## 技能公式模板（ME editskill.lua formula_tamplate_back：P/TP/SP 简版）
const TPL_SKILL_SIMPLE: String = """-- 可使用的对象有 master - 技能使用方， target - 目标对象
-- 获取行动方属性的函数 P(property)，得到行动方的力量属性为 P('力量')
-- 获取目标方属性的函数为 TP(property)，得到目标的防御力属性为 TP('防御力')
-- 设置对应对象的属性函数为 SP(object, property, value)

-- 计算输出伤害值
local value = P('力量') * P('等级') * 0.2

-- 保证伤害值至少为 1
if value <= 1 then value = 1 end

-- 计算伤害值
local damage = value - TP('防御力')

-- 保负值
if damage < 0 then
    damage = 0
end

-- 计算最终的血量
local hp = TP('生命值临时') - damage

-- 设置目标的最终血量
SP(target, '生命值临时', hp)
"""

## 通用脚本模板（事件回调等）
const TPL_GENERIC_SCRIPT: String = """-- 事件回调脚本
-- 可使用 trace(msg) 输出调试日志（需在全局配置开启『测试输出』）

local function on_event(name, data)
    trace('事件触发: ' .. tostring(name))
    return true
end

return on_event
"""


## 按类别返回模板列表 [{name, code}]
## kind: property / skill / generic
static func get_templates(kind: String) -> Array:
	match kind:
		"property":
			return [{"name": "属性计算公式（经验→等级）", "code": TPL_PROPERTY_FORMULA}]
		"skill":
			return [
				{"name": "技能公式（目标队列版）", "code": TPL_SKILL_TARGET},
				{"name": "技能公式（P/TP/SP 简版）", "code": TPL_SKILL_SIMPLE},
			]
		_:
			return [{"name": "通用事件回调脚本", "code": TPL_GENERIC_SCRIPT}]


## 构建「公式模板」按钮（弹出菜单选择模板并插入到目标 CodeEdit/TextEdit 末尾）
## 返回已连接好的 Button，调用方 add_child 即可。
static func make_template_button(target: TextEdit, kind: String) -> Button:
	var btn := Button.new()
	btn.text = "公式模板"
	btn.pressed.connect(func():
		var menu := PopupMenu.new()
		var tpls: Array = get_templates(kind)
		for i in tpls.size():
			menu.add_item((tpls[i] as Dictionary)["name"], i)
		menu.id_pressed.connect(func(id: int):
			if id >= 0 and id < tpls.size():
				var code: String = (tpls[id] as Dictionary)["code"]
				if target.text.strip_edges().is_empty():
					target.text = code
				else:
					target.text = target.text + "\n" + code
		)
		btn.get_tree().root.add_child(menu)
		menu.position = Vector2i(btn.global_position) + Vector2i(0, int(btn.size.y))
		menu.popup()
		menu.visibility_changed.connect(func():
			if not menu.visible:
				menu.queue_free()
		)
	)
	return btn
