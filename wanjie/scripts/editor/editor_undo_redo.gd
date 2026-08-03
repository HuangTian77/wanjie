## 编辑器统一撤销重做管理器 - 对标 Godot 4.7.1 UndoRedo
## 基于快照的行动栈: 每次操作记录 {action, before, after}
## 支持: commit(提交操作) / undo / redo / 历史列表 / 容量上限
class_name EditorUndoRedo
extends RefCounted

signal history_changed

## 历史容量上限
const MAX_HISTORY := 100

## 行动栈: [{action: String, "before": Variant, "after": Variant}]
var _actions: Array = []
## 当前位置: -1 = 空, 否则指向最后已应用的行动索引
var _position: int = -1

## 提交一次操作 (记录前后快照), 截断当前位置之后的redo栈
func commit(action_text: String, before: Variant, after: Variant) -> void:
	# 截断redo部分
	if _position < _actions.size() - 1:
		_actions.resize(_position + 1)
	_actions.append({
		"action": action_text,
		"before": _deep_dup(before),
		"after": _deep_dup(after),
	})
	# 容量限制
	while _actions.size() > MAX_HISTORY:
		_actions.pop_front()
	_position = _actions.size() - 1
	history_changed.emit()

## 撤销: 返回应恢复的 before 快照; 无可撤销返回 {valid=false}
func undo() -> Dictionary:
	if _position < 0:
		return {"valid": false}
	var action: Dictionary = _actions[_position]
	_position -= 1
	history_changed.emit()
	return {"valid": true, "state": _deep_dup(action["before"]), "action": action["action"]}

## 重做: 返回应恢复的 after 快照; 无可重做返回 {valid=false}
func redo() -> Dictionary:
	if _position >= _actions.size() - 1:
		return {"valid": false}
	_position += 1
	var action: Dictionary = _actions[_position]
	history_changed.emit()
	return {"valid": true, "state": _deep_dup(action["after"]), "action": action["action"]}

func can_undo() -> bool:
	return _position >= 0

func can_redo() -> bool:
	return _position < _actions.size() - 1

## 获取历史条目 [{"action": String, "current": bool}] (从旧到新)
func get_history() -> Array:
	var result: Array = []
	for i in _actions.size():
		result.append({
			"action": _actions[i]["action"],
			"current": i == _position,
			"undone": i > _position,
		})
	return result

## 清空历史
func clear() -> void:
	_actions.clear()
	_position = -1
	history_changed.emit()

func get_action_count() -> int:
	return _actions.size()

## 计算跳转到指定历史条目所需的步数 (正=重做, 负=撤销, 0=不动)
func steps_to_entry(index: int) -> int:
	return index - _position

func _deep_dup(v: Variant) -> Variant:
	if v is Dictionary:
		return (v as Dictionary).duplicate(true)
	elif v is Array:
		return (v as Array).duplicate(true)
	return v
