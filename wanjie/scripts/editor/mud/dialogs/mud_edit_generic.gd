## mud_edit_generic.gd
## 通用模式驱动编辑对话框（阶段5：覆盖其余 13 个表）
##
## 依据 MudSchemaInternal 的字段定义自动构建表单：
##   int   → 若 desc 括号内含枚举(如"类型(0普通1合成2分解)")则 OptionButton，否则 SpinBox
##   decimal→ SpinBox(step 0.01)
##   string → LineEdit
##   text/script → TextEdit（script 更高）
##   json  → TextEdit + JSON 校验按钮
## 直接编辑 schema 字段原值，因此与 mud_export 各 load_* 完全兼容（导出读取相同字段）。
## 适用于：alternation/reward/story/enemy/enemy_template/campaign/slot_template/
##         random/trade/generator/payment/logic/custom_data/script_pluggin 等。
class_name MudEditGeneric
extends MudEditDialogBase

# field_name -> {ctrl: Control, ftype: String}
var _ctrls: Dictionary = {}


func _build_body() -> void:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)

	for fn_v in MudSchemaInternal.get_field_names(_table):
		var fn: String = fn_v as String
		if fn == "id":
			continue
		var meta: Dictionary = MudSchemaInternal.get_field(_table, fn)
		_build_field(box, fn, str(meta.get("type", "string")), str(meta.get("desc", fn)))


func _build_field(box: VBoxContainer, fn: String, ftype: String, fdesc: String) -> void:
	match ftype:
		"int":
			var opts: Array = _parse_enum_options(fdesc)
			if opts.size() >= 2:
				var ob := make_select(opts, 0)
				_add_labeled(box, fdesc + "：", ob)
				_ctrls[fn] = {"ctrl": ob, "ftype": "enum"}
			else:
				var sb := SpinBox.new()
				sb.min_value = -2147483647
				sb.max_value = 2147483647
				_add_labeled(box, fdesc + "：", sb)
				_ctrls[fn] = {"ctrl": sb, "ftype": "int"}
		"decimal":
			var sb := SpinBox.new()
			sb.min_value = -1000000000.0
			sb.max_value = 1000000000.0
			sb.step = 0.01
			_add_labeled(box, fdesc + "：", sb)
			_ctrls[fn] = {"ctrl": sb, "ftype": "decimal"}
		"string":
			var le := LineEdit.new()
			_add_labeled(box, fdesc + "：", le)
			_ctrls[fn] = {"ctrl": le, "ftype": "string"}
		"text", "script", "json":
			var wrap := VBoxContainer.new()
			wrap.add_theme_constant_override("separation", 2)
			box.add_child(wrap)
			wrap.add_child(make_label(fdesc + "："))
			var te: TextEdit
			var mh: float = 130.0 if ftype == "script" else (110.0 if ftype == "json" else 80.0)
			if ftype == "script":
				te = MudCodeTheme.make_code_edit("lua", mh)
			elif ftype == "json":
				te = MudCodeTheme.make_code_edit("json", mh)
			else:
				te = TextEdit.new()
				te.custom_minimum_size = Vector2(0, mh)
			wrap.add_child(te)
			var bar := HBoxContainer.new()
			bar.add_theme_constant_override("separation", 6)
			wrap.add_child(bar)
			if ftype == "json":
				var vb := Button.new()
				vb.text = "JSON 校验"
				vb.pressed.connect(func(): _validate_json(te))
				bar.add_child(vb)
			elif ftype == "script":
				var vb := Button.new()
				vb.text = "语法校验"
				vb.pressed.connect(func(): _validate_lua(te))
				bar.add_child(vb)
				bar.add_child(MudCodeTheme.make_template_button(te, _template_kind()))
			_ctrls[fn] = {"ctrl": te, "ftype": ftype}


# ===================== 枚举解析 =====================

## 根据当前表选择公式模板类别（战斗相关表用技能公式模板）
func _template_kind() -> String:
	match _table:
		"enemy", "enemy_template", "random", "campaign", "generator", "skill":
			return "skill"
		"property":
			return "property"
		_:
			return "generic"

## 从字段 desc 的括号内解析枚举选项。
## 例："类型(0普通1合成2分解)" → [["普通",0],["合成",1],["分解",2]]
## 不足 2 个选项时返回空数组（调用方退回 SpinBox）。
func _parse_enum_options(desc: String) -> Array:
	var lp: int = desc.find("(")
	if lp < 0:
		lp = desc.find("（")
	if lp < 0:
		return []
	var rp: int = desc.find(")", lp)
	if rp < 0:
		rp = desc.find("）", lp)
	if rp < 0:
		return []
	var inner: String = desc.substr(lp + 1, rp - lp - 1)
	var opts: Array = []
	var i: int = 0
	var n: int = inner.length()
	while i < n:
		if inner[i].is_valid_int():
			var j: int = i
			while j < n and inner[j].is_valid_int():
				j += 1
			var num: int = inner.substr(i, j - i).to_int()
			var k: int = j
			while k < n and not inner[k].is_valid_int():
				k += 1
			var label: String = inner.substr(j, k - j)
			label = label.replace("/", "").replace("，", "").replace(",", "").strip_edges()
			if not label.is_empty():
				opts.append([label, num])
			i = k
		else:
			i += 1
	return opts


# ===================== 校验 =====================

func _validate_json(te: TextEdit) -> void:
	var s: String = te.text.strip_edges()
	if s.is_empty():
		te.placeholder_text = "JSON 校验：空（合法）✓"
		return
	var parsed: Variant = JSON.parse_string(s)
	if parsed == null:
		te.placeholder_text = "JSON 校验：解析失败 ✗"
	else:
		te.placeholder_text = "JSON 校验：格式正确 ✓"


func _validate_lua(te: TextEdit) -> void:
	var ok: bool = _check_lua_balance(te.text)
	te.placeholder_text = "语法校验：" + ("括号/关键字配对正常 ✓" if ok else "存在未配对的括号或关键字 ✗")


func _check_lua_balance(s: String) -> bool:
	var paren: int = 0
	for ch in s:
		if ch == "(":
			paren += 1
		elif ch == ")":
			paren -= 1
		if paren < 0:
			return false
	if paren != 0:
		return false
	var fns: int = _count_word(s, "function") + _count_word(s, "if") + _count_word(s, "for") + _count_word(s, "while")
	var ends: int = _count_word(s, "end")
	return ends <= fns + 1


func _count_word(s: String, w: String) -> int:
	var c: int = 0
	var i: int = s.find(w)
	while i >= 0:
		c += 1
		i = s.find(w, i + w.length())
	return c


# ===================== 加载 / 收集 =====================

func _load(row: Dictionary) -> void:
	clear_header()
	var tdesc: String = str(MudSchemaInternal.get_table(_table).get("desc", _table))
	var nm: String = str(row.get("name", ""))
	add_header(tdesc + "：", nm if not nm.is_empty() else ("#" + str(row.get("id", ""))))
	add_header("ID：", str(row.get("id", "")))
	if row.has("note"):
		add_header("备注：", str(row.get("note", "")))

	for fn in _ctrls:
		var rec: Dictionary = _ctrls[fn]
		var ctrl: Control = rec["ctrl"]
		var ftype: String = rec["ftype"]
		var val: Variant = row.get(fn)
		match ftype:
			"enum":
				_select_by_id(ctrl as OptionButton, int(val) if val != null else 0)
			"int":
				(ctrl as SpinBox).value = float(int(val)) if val != null else 0.0
			"decimal":
				(ctrl as SpinBox).value = float(val) if (val != null and str(val).is_valid_float()) else 0.0
			"string":
				(ctrl as LineEdit).text = "" if val == null else str(val)
			"text", "script", "json":
				(ctrl as TextEdit).text = "" if val == null else str(val)


func _collect() -> Dictionary:
	var out: Dictionary = {}
	for fn in _ctrls:
		var rec: Dictionary = _ctrls[fn]
		var ctrl: Control = rec["ctrl"]
		var ftype: String = rec["ftype"]
		match ftype:
			"enum":
				out[fn] = (ctrl as OptionButton).get_selected_id()
			"int":
				out[fn] = int((ctrl as SpinBox).value)
			"decimal":
				out[fn] = (ctrl as SpinBox).value
			"string":
				out[fn] = (ctrl as LineEdit).text
			"text", "script":
				out[fn] = (ctrl as TextEdit).text
			"json":
				out[fn] = (ctrl as TextEdit).text.strip_edges()
	return out
