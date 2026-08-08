## LLM客户端 - 多供应商云端LLM API集成
## 支持: OpenAI / DeepSeek / 通义千问 / 其他兼容OpenAI格式的API
extends Node

# === 供应商配置 ===
# 每个供应商的预设配置
const PROVIDERS := {
	"openai": {
		"name": "OpenAI",
		"base_url": "https://api.openai.com/v1",
		"models": ["gpt-4o", "gpt-4o-mini", "gpt-4.1", "gpt-4.1-mini"],
		"default_model": "gpt-4o-mini",
		"key_prefix": "sk-",
	},
	"deepseek": {
		"name": "DeepSeek",
		"base_url": "https://api.deepseek.com/v1",
		"models": ["deepseek-chat", "deepseek-reasoner"],
		"default_model": "deepseek-chat",
		"key_prefix": "sk-",
	},
	"qwen": {
		"name": "通义千问",
		"base_url": "https://dashscope.aliyuncs.com/compatible-mode/v1",
		"models": ["qwen-turbo", "qwen-plus", "qwen-max"],
		"default_model": "qwen-plus",
		"key_prefix": "sk-",
	},
	"moonshot": {
		"name": "Moonshot (Kimi)",
		"base_url": "https://api.moonshot.cn/v1",
		"models": ["moonshot-v1-8k", "moonshot-v1-32k", "moonshot-v1-128k"],
		"default_model": "moonshot-v1-8k",
		"key_prefix": "sk-",
	},
	"zhipu": {
		"name": "智谱AI (GLM)",
		"base_url": "https://open.bigmodel.cn/api/paas/v4",
		"models": ["glm-4-flash", "glm-4", "glm-4-plus"],
		"default_model": "glm-4-flash",
		"key_prefix": "",
	},
	"custom": {
		"name": "自定义",
		"base_url": "",
		"models": [],
		"default_model": "",
		"key_prefix": "",
	},
}

# === 当前配置 ===
@export var active_provider: String = "deepseek"
@export var api_keys: Dictionary = {}  # provider -> api_key
@export var custom_base_url: String = ""
@export var custom_model: String = ""
@export var max_tokens: int = 2048
@export var temperature: float = 0.8
@export var timeout: float = 60.0

# === 信号 ===
signal response_received(text: String, provider: String, model: String)
signal response_error(error: String, provider: String)
signal stream_chunk(text: String)
signal stream_finished()
signal provider_switched(provider: String)

# === 内部状态 ===
var _current_model: String = ""

func _ready() -> void:
	_load_config()
	_current_model = get_current_model()

# === 配置管理 ===

func _load_config() -> void:
	var config := ConfigFile.new()
	var path := "user://llm_config.ini"
	if config.load(path) == OK:
		active_provider = config.get_value("llm", "active_provider", "deepseek")
		max_tokens = config.get_value("llm", "max_tokens", 2048)
		temperature = config.get_value("llm", "temperature", 0.8)
		custom_base_url = config.get_value("llm", "custom_base_url", "")
		custom_model = config.get_value("llm", "custom_model", "")
		# 加载已保存的API keys（优先 secrets.ini，兼容旧 llm_config.ini）
		var secrets := ConfigFile.new()
		if secrets.load("user://secrets.ini") == OK:
			for provider in PROVIDERS.keys():
				var key: String = secrets.get_value("api_keys", provider, "")
				if key != "":
					api_keys[provider] = key
		for provider in PROVIDERS.keys():
			var key: String = config.get_value("api_keys", provider, "")
			if key != "" and not api_keys.has(provider):
				api_keys[provider] = key

func save_config() -> void:
	var config := ConfigFile.new()
	config.set_value("llm", "active_provider", active_provider)
	config.set_value("llm", "max_tokens", max_tokens)
	config.set_value("llm", "temperature", temperature)
	config.set_value("llm", "custom_base_url", custom_base_url)
	config.set_value("llm", "custom_model", custom_model)
	config.save("user://llm_config.ini")
	# API keys 写入独立 secrets 文件（与主配置分离，降低误共享/误提交风险）
	var secrets := ConfigFile.new()
	for provider in api_keys:
		secrets.set_value("api_keys", provider, api_keys[provider])
	secrets.save("user://secrets.ini")

# === 公共API ===

## 设置当前使用的供应商
func set_provider(provider: String) -> void:
	if PROVIDERS.has(provider):
		active_provider = provider
		_current_model = get_current_model()
		provider_switched.emit(provider)

## 设置某个供应商的API Key
func set_api_key(provider: String, key: String) -> void:
	api_keys[provider] = key
	save_config()

## 获取当前供应商名称
func get_provider_name() -> String:
	if PROVIDERS.has(active_provider):
		return str(PROVIDERS[active_provider]["name"])
	return active_provider

## 获取当前使用的模型
func get_current_model() -> String:
	if active_provider == "custom":
		return custom_model
	if PROVIDERS.has(active_provider):
		return str(PROVIDERS[active_provider]["default_model"])
	return ""

## 获取当前供应商的API Base URL
func get_base_url() -> String:
	if active_provider == "custom":
		return custom_base_url
	if PROVIDERS.has(active_provider):
		return str(PROVIDERS[active_provider]["base_url"])
	return ""

## 获取当前供应商的API Key
func get_api_key() -> String:
	return str(api_keys.get(active_provider, ""))

## 检查当前配置是否可用
func is_configured() -> bool:
	var key := get_api_key()
	var model := get_current_model()
	return key != "" and model != ""

## 获取所有供应商列表
func get_available_providers() -> Array:
	var result := []
	for key in PROVIDERS:
		result.append({
			"id": key,
			"name": PROVIDERS[key]["name"],
			"models": PROVIDERS[key]["models"],
		})
	return result

## 发送聊天消息（非流式）
func chat(messages: Array, system_prompt: String = "") -> String:
	if not is_configured():
		response_error.emit("未配置API Key或模型", active_provider)
		return ""

	var request_body := _build_request(messages, system_prompt, false)
	return await _send_request(request_body)

## 发送聊天消息（流式）
func chat_stream(messages: Array, system_prompt: String = "") -> void:
	if not is_configured():
		response_error.emit("未配置API Key或模型", active_provider)
		return

	var request_body := _build_request(messages, system_prompt, true)
	await _send_stream_request(request_body)

## 生成文本（简单接口）
func generate(prompt: String, system_prompt: String = "") -> String:
	var messages := []
	if system_prompt != "":
		messages.append({"role": "system", "content": system_prompt})
	messages.append({"role": "user", "content": prompt})
	return await chat(messages)

## 测试连接 - 发送简单消息验证API是否可用
func test_connection() -> String:
	if not is_configured():
		return "错误: 未配置API Key"
	var result := await generate("请回复'连接成功'四个字", "")
	if result == "":
		return "错误: 请求失败"
	return "成功: " + result

# === 内部方法 ===

func _build_request(messages: Array, system_prompt: String, stream: bool) -> Dictionary:
	var full_messages := []
	if system_prompt != "":
		full_messages.append({"role": "system", "content": system_prompt})
	full_messages.append_array(messages)

	return {
		"model": get_current_model(),
		"messages": full_messages,
		"stream": stream,
		"max_tokens": max_tokens,
		"temperature": temperature,
	}

func _send_request(body: Dictionary) -> String:
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = timeout

	var json_body := JSON.stringify(body)
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer " + get_api_key(),
	]

	var url := get_base_url() + "/chat/completions"
	http.request(url, headers, HTTPClient.METHOD_POST, json_body)
	var result = await http.request_completed
	http.queue_free()

	if result[0] == HTTPRequest.RESULT_SUCCESS:
		var json := JSON.new()
		var err := json.parse(result[3].get_string_from_utf8())
		if err != OK:
			response_error.emit("JSON解析失败", active_provider)
			return ""
		var data = json.data
		if data and data.has("choices") and data["choices"].size() > 0:
			var text: String = data["choices"][0]["message"]["content"]
			response_received.emit(text, active_provider, get_current_model())
			return text
		elif data and data.has("error"):
			response_error.emit(data["error"].get("message", "未知错误"), active_provider)
		return ""
	else:
		response_error.emit("HTTP请求失败: " + str(result[0]), active_provider)
		return ""

func _send_stream_request(body: Dictionary) -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.timeout = timeout

	var json_body := JSON.stringify(body)
	var headers := [
		"Content-Type: application/json",
		"Authorization: Bearer " + get_api_key(),
	]

	var url := get_base_url() + "/chat/completions"
	http.request(url, headers, HTTPClient.METHOD_POST, json_body)
	var result = await http.request_completed
	http.queue_free()

	if result[0] == HTTPRequest.RESULT_SUCCESS:
		var raw_text: String = result[3].get_string_from_utf8()
		var full_text := _parse_sse_stream(raw_text)
		stream_finished.emit()
		response_received.emit(full_text, active_provider, get_current_model())
	else:
		response_error.emit("HTTP流式请求失败: " + str(result[0]), active_provider)

func _parse_sse_stream(raw_text: String) -> String:
	var lines := raw_text.split("\n")
	var full_text := ""
	for line in lines:
		if not line.begins_with("data: "):
			continue
		var json_str := line.substr(6).strip_edges()
		if json_str == "[DONE]":
			break
		var json := JSON.new()
		if json.parse(json_str) != OK:
			continue
		var data = json.data
		if data and data.has("choices") and data["choices"].size() > 0:
			var delta = data["choices"][0].get("delta", {})
			if delta.has("content"):
				var chunk: String = delta["content"]
				full_text += chunk
				stream_chunk.emit(chunk)
	return full_text
