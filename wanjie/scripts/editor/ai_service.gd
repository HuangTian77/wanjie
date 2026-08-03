## AI服务抽象层
## 提供统一的LLM API调用接口，支持多种后端(OpenAI兼容API / 本地模型)
## 异步请求，信号驱动，非阻塞
class_name AIService
extends RefCounted

signal request_completed(result: Dictionary)
signal request_failed(error_msg: String)
signal stream_token(token: String)

## 服务商配置
enum Provider { OPENAI_COMPATIBLE, LOCAL_OLLAMA, MOCK }

var _provider: int = Provider.MOCK
var _api_url: String = "http://localhost:11434/v1/chat/completions"
var _api_key: String = ""
var _model: String = "qwen2.5:7b"
var _http: HTTPRequest = null
var _host_node: Node = null  # 用于挂载HTTPRequest节点
var _pending_context: Dictionary = {}  # 当前请求的上下文信息

## 初始化服务
func init(host_node: Node, config: Dictionary = {}) -> void:
	_host_node = host_node
	_provider = config.get("provider", Provider.MOCK)
	_api_url = config.get("api_url", _api_url)
	_api_key = config.get("api_key", "")
	_model = config.get("model", _model)
	# 创建HTTP请求节点
	_http = HTTPRequest.new()
	_http.timeout = 60.0
	_http.request_completed.connect(_on_http_completed)
	host_node.add_child(_http)

## 发送聊天补全请求
## messages: [{"role": "system"/"user"/"assistant", "content": "..."}]
## context: 附加上下文(会随信号返回)
func chat_completion(messages: Array, context: Dictionary = {}) -> void:
	_pending_context = context
	if _provider == Provider.MOCK:
		_mock_response(messages, context)
		return
	var headers: PackedStringArray = ["Content-Type: application/json"]
	if _api_key != "":
		headers.append("Authorization: Bearer %s" % _api_key)
	var body: Dictionary = {
		"model": _model,
		"messages": messages,
		"temperature": context.get("temperature", 0.7),
		"max_tokens": context.get("max_tokens", 2048),
	}
	if context.get("json_mode", false):
		body["response_format"] = {"type": "json_object"}
	var json_body: String = JSON.stringify(body)
	var err := _http.request(_api_url, headers, HTTPClient.METHOD_POST, json_body)
	if err != OK:
		request_failed.emit("HTTP请求发送失败: %s" % error_string(err))

## 发送结构化输出请求(强制JSON Schema)
func structured_completion(system_prompt: String, user_prompt: String, schema_hint: String, context: Dictionary = {}) -> void:
	var messages: Array = [
		{"role": "system", "content": system_prompt + "\n\n你必须以JSON格式输出，结构参考：\n" + schema_hint},
		{"role": "user", "content": user_prompt},
	]
	context["json_mode"] = true
	chat_completion(messages, context)

## 获取当前配置摘要
func get_config_summary() -> String:
	match _provider:
		Provider.OPENAI_COMPATIBLE: return "OpenAI兼容 | %s | %s" % [_api_url, _model]
		Provider.LOCAL_OLLAMA: return "本地Ollama | %s" % [_model]
		Provider.MOCK: return "模拟模式 (无实际AI调用)"
	return "未知"

## 是否已配置真实AI后端
func is_real_backend() -> bool:
	return _provider != Provider.MOCK

## 更新配置
func update_config(config: Dictionary) -> void:
	if config.has("provider"): _provider = config["provider"]
	if config.has("api_url"): _api_url = config["api_url"]
	if config.has("api_key"): _api_key = config["api_key"]
	if config.has("model"): _model = config["model"]

## === 内部方法 ===

func _on_http_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		request_failed.emit("网络错误: result=%d" % result)
		return
	if response_code != 200:
		var err_text: String = body.get_string_from_utf8().left(200)
		request_failed.emit("API错误 [%d]: %s" % [response_code, err_text])
		return
	var json_text: String = body.get_string_from_utf8()
	var parsed = JSON.parse_string(json_text)
	if parsed == null:
		request_failed.emit("JSON解析失败")
		return
	var choices: Array = parsed.get("choices", [])
	if choices.is_empty():
		request_failed.emit("API返回空choices")
		return
	var content: String = choices[0].get("message", {}).get("content", "")
	var usage: Dictionary = parsed.get("usage", {})
	request_completed.emit({
		"content": content,
		"usage": usage,
		"context": _pending_context,
	})

## 模拟响应(开发/测试用)
func _mock_response(messages: Array, context: Dictionary) -> void:
	var feature: String = context.get("feature", "general")
	var mock_content := ""
	match feature:
		"worldview_gen":
			mock_content = JSON.stringify({
				"era": "蒸汽觉醒纪元",
				"timeline": ["发现蒸汽能量", "第一座机械城建立", "三大城邦形成"],
				"factions": [
					{"name": "铁炉城", "trait": "工业至上"},
					{"name": "翠风谷", "trait": "自然平衡"},
					{"name": "晶蓝港", "trait": "贸易自由"},
				],
				"rules": "魔法能量源自蒸汽核心，使用代价为机械部件损耗",
				"note": "[模拟输出] 配置真实AI后端后可获得完整生成结果",
			}, "  ")
		"event_gen":
			mock_content = JSON.stringify({
				"name": "背叛的代价",
				"trigger_type": "condition",
				"description": "当玩家与铁炉城关系降至敌对时触发",
				"choices": [
					{"text": "揭露阴谋", "consequence": "获得铁炉城通缉，但赢得翠风谷信任"},
					{"text": "沉默离开", "consequence": "失去所有城邦信任，获得独行侠标记"},
				],
				"note": "[模拟输出] 配置真实AI后端后可获得完整生成结果",
			}, "  ")
		"economy_analysis":
			mock_content = "【经济平衡分析报告(模拟)】\n\n" + \
				"1. 通胀风险: 中等 - 金币产出/消耗比约1.3:1\n" + \
				"2. 资源枯竭: 低风险 - 矿石储备可支撑约200游戏日\n" + \
				"3. 收支平衡: 玩家平均时收入略高于支出，建议增加高级消耗点\n\n" + \
				"[模拟输出] 配置真实AI后端后可获得深度分析"
		"ability_gen":
			mock_content = JSON.stringify({
				"schools": [
					{"name": "蒸汽锻造", "skills": ["强化装甲", "蒸汽冲击", "过载核心"]},
					{"name": "自然共鸣", "skills": ["治愈之風", "荆棘护体", "生命链接"]},
				],
				"note": "[模拟输出] 配置真实AI后端后可获得完整技能树",
			}, "  ")
		_:
			mock_content = "[AI助手模拟回复]\n\n已收到您的请求。当前为模拟模式，未连接真实AI后端。\n\n" + \
				"请在设置中配置:\n- API地址 (如 http://localhost:11434/v1/chat/completions)\n- 模型名称 (如 qwen2.5:7b)\n\n配置完成后即可获得真实AI辅助。"
	# 模拟延迟（host 在树内用 timer，否则同步回调，避免 null 崩溃）
	var tree: SceneTree = null
	if _host_node != null:
		tree = _host_node.get_tree()
	if tree != null:
		tree.create_timer(0.3).timeout.connect(func():
			request_completed.emit({
				"content": mock_content,
				"usage": {"prompt_tokens": 0, "completion_tokens": 0},
				"context": context,
			})
		)
	else:
		request_completed.emit({
			"content": mock_content,
			"usage": {},
			"context": context,
		})
