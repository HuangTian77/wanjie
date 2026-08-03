## mud_csv.gd
## MUD 编辑器 CSV 导入/导出工具（对应 ME app/libs/readcsv.lua + batchcsv.lua）
##
## 格式约定（与 ME 一致）：
##   首行 = 字段名（取自 MudSchemaInternal 的字段顺序）
##   其后每行 = 一条记录的各字段值
##   含逗号/引号/换行的值用双引号包裹，内部引号 doubled（"" 表示 "）
## 导入时按首行字段名映射写回内部表（替换整表），与 mud_export 导出管道兼容。
class_name MudCsv
extends RefCounted


# ===================== 导出 =====================

## 将一张内部表导出为 CSV 文本。
static func export_table(data: MudData, table: String) -> String:
	var fields: Array = MudSchemaInternal.get_field_names(table)
	var lines: Array = []
	# 表头
	var head: Array = []
	for f in fields:
		head.append(_escape(str(f)))
	lines.append(",".join(head))
	# 数据行
	for row_v in data.get_table(table):
		if not (row_v is Dictionary):
			continue
		var row: Dictionary = row_v as Dictionary
		var cells: Array = []
		for f in fields:
			var val: Variant = row.get(f)
			cells.append(_escape(_val_to_str(val)))
		lines.append(",".join(cells))
	return "\n".join(lines) + "\n"


## 导出到文件。返回是否成功。
static func export_to_file(data: MudData, table: String, path: String) -> bool:
	var csv: String = export_table(data, table)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(csv)
	f.close()
	return true


# ===================== 导入 =====================

## 从 CSV 文本导入到内部表（替换整表）。返回导入的记录数（-1 表示失败）。
## 首行字段名用于列映射；缺失字段用 schema 默认值；id 列保留。
static func import_table(data: MudData, table: String, csv_text: String) -> int:
	var rows: Array = parse_csv(csv_text)
	if rows.size() < 1:
		return -1
	var header: Array = rows[0]
	# 字段名 -> 列索引
	var col_of: Dictionary = {}
	for i in header.size():
		col_of[str(header[i]).strip_edges()] = i
	# 清空原表
	data.clear_table(table)
	var count: int = 0
	for r in range(1, rows.size()):
		var cells: Array = rows[r]
		# 跳过全空行
		var all_empty: bool = true
		for c in cells:
			if str(c).strip_edges() != "":
				all_empty = false
				break
		if all_empty:
			continue
		var rec: Dictionary = {}
		for f in MudSchemaInternal.get_field_names(table):
			if col_of.has(f):
				var idx: int = int(col_of[f])
				var raw: String = str(cells[idx]) if idx < cells.size() else ""
				rec[f] = _coerce(table, f, raw)
			else:
				rec[f] = MudSchemaInternal.get_field(table, f).get("default", "")
		data.add_row(table, rec)
		count += 1
	return count


## 从文件导入。返回记录数（-1 失败）。
static func import_from_file(data: MudData, table: String, path: String) -> int:
	if not FileAccess.file_exists(path):
		return -1
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return -1
	var text: String = f.get_as_text()
	f.close()
	return import_table(data, table, text)


# ===================== CSV 解析 =====================

## 解析 CSV 文本为二维数组（支持引号包裹、"" 转义、逗号与换行）。
static func parse_csv(text: String) -> Array:
	var result: Array = []
	var row: Array = []
	var field: String = ""
	var in_quote: bool = false
	var i: int = 0
	var n: int = text.length()
	while i < n:
		var ch: String = text[i]
		if in_quote:
			if ch == "\"":
				if i + 1 < n and text[i + 1] == "\"":
					field += "\""
					i += 2
					continue
				else:
					in_quote = false
					i += 1
					continue
			else:
				field += ch
				i += 1
				continue
		else:
			if ch == "\"":
				in_quote = true
				i += 1
				continue
			elif ch == ",":
				row.append(field)
				field = ""
				i += 1
				continue
			elif ch == "\r":
				i += 1
				continue
			elif ch == "\n":
				row.append(field)
				field = ""
				result.append(row)
				row = []
				i += 1
				continue
			else:
				field += ch
				i += 1
				continue
	# 收尾
	if field != "" or row.size() > 0:
		row.append(field)
		result.append(row)
	return result


# ===================== 内部辅助 =====================

## CSV 转义：含特殊字符时包裹双引号。
static func _escape(s: String) -> String:
	if s.find(",") >= 0 or s.find("\"") >= 0 or s.find("\n") >= 0 or s.find("\r") >= 0:
		return "\"" + s.replace("\"", "\"\"") + "\""
	return s


static func _val_to_str(v: Variant) -> String:
	if v == null:
		return ""
	return str(v)


## 按 schema 字段类型把 CSV 原始字符串转换为合适的值类型。
static func _coerce(table: String, field: String, raw: String) -> Variant:
	var meta: Dictionary = MudSchemaInternal.get_field(table, field)
	var ftype: String = str(meta.get("type", "string"))
	var t: String = raw.strip_edges()
	match ftype:
		"int":
			if t.is_valid_int():
				return t.to_int()
			if t.is_valid_float():
				return int(float(t))
			return 0
		"decimal":
			if t.is_valid_float():
				return t.to_float()
			return 0.0
		_:
			return raw
