## 临时验证脚本: UserData 持久化 + 离线恢复测试
extends SceneTree

func _initialize() -> void:
	# 1. to_dict/from_dict 往返
	var u := UserData.new()
	u.player_name = "测试旅者"
	u.shimo = 999
	u.jieshi = 7
	u.inspiration = 3
	u.creation_energy = 2
	u.recent_script_ids = ["a", "b"]
	u.created_script_ids = ["c"]
	u.achievements = ["ach_1"]
	u.ai_enabled = false
	u.difficulty_mode = "fixed_hard"
	u.animations_enabled = false
	u.font_size_preset = "large"
	u.last_recovery_time = 123456
	var d: Dictionary = u.to_dict()
	var u2 := UserData.from_dict(d)
	assert(u2.player_name == "测试旅者", "name 往返")
	assert(u2.shimo == 999 and u2.jieshi == 7, "货币往返")
	assert(u2.inspiration == 3 and u2.creation_energy == 2, "资源往返")
	assert(u2.recent_script_ids.size() == 2, "列表往返")
	assert(u2.ai_enabled == false and u2.difficulty_mode == "fixed_hard", "设置往返")
	assert(u2.last_recovery_time == 123456, "时间戳往返")
	print("PASS to_dict/from_dict roundtrip")

	# 2. 缺失字段兼容（旧存档）
	var old: Dictionary = {"player_name": "旧存档", "shimo": 5}
	var u3 := UserData.from_dict(old)
	assert(u3.player_name == "旧存档", "旧字段读取")
	assert(u3.shimo == 5, "旧字段读取2")
	assert(u3.jieshi == 50, "缺失字段用默认值")
	assert(u3.inspiration == 10, "缺失字段默认2")
	assert(u3.recent_script_ids.is_empty(), "缺失列表为空")
	print("PASS from_dict backward compat")

	# 3. GameManager 保存/加载
	var gm = load("res://scripts/autoload/game_manager.gd").new()
	gm.user_data = u
	gm._save_user_data()
	assert(FileAccess.file_exists(gm.USER_DATA_PATH), "文件应写入")
	var gm2 = load("res://scripts/autoload/game_manager.gd").new()
	gm2._initialize_user_data()
	assert(gm2.user_data != null, "应加载到 user_data")
	assert(gm2.user_data.player_name == "测试旅者", "加载后姓名一致")
	assert(gm2.user_data.shimo == 999, "加载后货币一致")
	print("PASS GameManager save/load")

	# 4. 离线恢复
	var gm3 = load("res://scripts/autoload/game_manager.gd").new()
	var u4 := UserData.new()
	u4.inspiration = 8
	u4.creation_energy = 4
	u4.last_recovery_time = int(Time.get_unix_time_from_system()) - 130  # 2分钟前
	gm3.user_data = u4
	gm3._recover_offline_resources()
	assert(u4.inspiration == 10, "灵感应补 2 点到上限")
	assert(u4.creation_energy == 5, "精力应补 2 点到上限")
	assert(u4.last_recovery_time > int(Time.get_unix_time_from_system()) - 5, "时间戳应更新")
	# 离线 10 分钟也不超上限
	var u5 := UserData.new()
	u5.inspiration = 3
	u5.last_recovery_time = int(Time.get_unix_time_from_system()) - 600
	var gm4 = load("res://scripts/autoload/game_manager.gd").new()
	gm4.user_data = u5
	gm4._recover_offline_resources()
	assert(u5.inspiration == 10, "长时间离线封顶到上限")
	print("PASS offline recovery")

	print("ALL_TESTS_PASSED")
	quit(0)
