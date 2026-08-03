## AI对话酒馆管理器 - 管理角色卡、世界书、对话上下文和Prompt组装
## 基于GDD_AI对话酒馆设计文档实现
extends Node

# === 信号 ===
signal dialog_started(character_id: String)
signal dialog_ended(character_id: String)
signal message_added(role: String, content: String)
signal context_updated()

# === 数据 ===
var current_character: Dictionary = {}
var world_books: Dictionary = {}  # world_id -> world_data
var dialog_history: Array = []  # 当前对话历史
var max_context_tokens: int = 4096
var system_prompt_template: String = ""

# === 角色卡结构 ===
# {
#   "id": "character_001",
#   "name": "角色名",
#   "avatar": "res://assets/avatars/xxx.png",
#   "personality": "性格描述",
#   "background": "背景故事",
#   "greeting": "开场白",
#   "example_dialogs": ["示例对话1", "示例对话2"],
#   "world_id": "关联的世界书ID",
#   "tags": ["标签1", "标签2"]
# }

func _ready() -> void:
	_init_system_prompt()

# === 公共API ===

## 开始与角色的对话
func start_dialog(character: Dictionary) -> void:
	current_character = character
	dialog_history.clear()
	
	# 添加角色开场白
	if character.has("greeting") and character["greeting"] != "":
		dialog_history.append({
			"role": "assistant",
			"content": character["greeting"]
		})
	
	dialog_started.emit(str(character.get("id", "")))

## 结束当前对话
func end_dialog() -> void:
	if current_character.size() > 0:
		dialog_ended.emit(str(current_character.get("id", "")))
	current_character = {}
	dialog_history.clear()

## 发送玩家消息并获取AI回复
func send_message(player_text: String) -> String:
	if current_character.is_empty():
		return ""
	
	# 添加玩家消息
	dialog_history.append({"role": "user", "content": player_text})
	message_added.emit("user", player_text)
	
	# 组装完整prompt
	var messages := _build_context_messages()
	var system_prompt := _build_system_prompt()
	
	# 调用LLM（使用autoload的LLMClient单例）
	var response: String = await LLMClient.chat(messages, system_prompt)
	
	if response != "":
		dialog_history.append({"role": "assistant", "content": response})
		message_added.emit("assistant", response)
	
	return response

## 注册世界书
func register_world(world_id: String, world_data: Dictionary) -> void:
	world_books[world_id] = world_data

## 加载世界书
func load_world_book(world_id: String) -> Dictionary:
	if world_books.has(world_id):
		return world_books[world_id]
	return {}

## 获取对话历史
func get_dialog_history() -> Array:
	return dialog_history.duplicate()

## 清除对话历史
func clear_history() -> void:
	dialog_history.clear()
	context_updated.emit()

# === Prompt组装 ===

func _init_system_prompt() -> void:
	system_prompt_template = """你是一个角色扮演AI，扮演以下角色与玩家互动。

## 角色信息
名称：{name}
性格：{personality}
背景：{background}

## 世界设定
{world_setting}

## 规则
1. 始终保持角色一致性，用角色的语气和方式说话
2. 根据角色的性格和背景做出合理反应
3. 回复应简洁有力，通常不超过3段
4. 适当使用动作描写（用*号包裹）
5. 不要代替玩家做出决定或行动
"""

func _build_system_prompt() -> String:
	var prompt := system_prompt_template
	prompt = prompt.replace("{name}", str(current_character.get("name", "未知")))
	prompt = prompt.replace("{personality}", str(current_character.get("personality", "友善")))
	prompt = prompt.replace("{background}", str(current_character.get("background", "无特殊背景")))
	
	# 加载关联世界书
	var world_id: String = current_character.get("world_id", "")
	var world_setting := "无特定世界设定"
	if world_id != "" and world_books.has(world_id):
		var world: Dictionary = world_books[world_id]
		world_setting = str(world.get("description", "无描述"))
		if world.has("lore"):
			world_setting += "\n\n传说：" + str(world["lore"])
		if world.has("rules"):
			world_setting += "\n\n规则：" + str(world["rules"])
	
	prompt = prompt.replace("{world_setting}", world_setting)
	return prompt

func _build_context_messages() -> Array:
	var messages: Array = []
	var total_tokens_estimate := 0
	
	# 添加示例对话（如果有）
	if current_character.has("example_dialogs"):
		for example in current_character["example_dialogs"]:
			messages.append({"role": "system", "content": "示例: " + example})
			total_tokens_estimate += _estimate_tokens(example)
	
	# 从历史消息中构建上下文（限制token）
	var context_messages: Array = []
	for i in range(dialog_history.size() - 1, -1, -1):
		var msg = dialog_history[i]
		var msg_tokens := _estimate_tokens(msg["content"])
		if total_tokens_estimate + msg_tokens > max_context_tokens:
			break
		context_messages.push_front(msg)
		total_tokens_estimate += msg_tokens
	
	messages.append_array(context_messages)
	return messages

func _estimate_tokens(text: String) -> int:
	# 粗略估算：中文约1.5字/token，英文约4字符/token
	return int(text.length() / 1.5)
