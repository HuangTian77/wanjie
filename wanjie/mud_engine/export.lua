local fs = require("fs")
local json = require("json")

local gd = require("bundle://app/libs/gamedata")

local path = require("luvi").path
local basepath = "../testsvr/data"

-- 解析条件到配置
local function parseCondition(cond)
    if type(cond) == "string" and cond ~= "" then
        cond = json.parse(cond)
    end

    if type(cond) ~= "table" then
        return
    end

    local c = {}
    for _, item in ipairs(cond) do
        local t = {}
        t.id = item.subtype
        t.type = item.type
        -- if item.type < 3 then
        -- 	t.id = string.format("%s:%s", item.type, item.subtype)
        -- end
        local value = tonumber(item.value)
        if item.condition == "gt" then
            t.min = value
        elseif item.condition == "lt" then
            t.max = value
        elseif item.condition == "eq" then
            t.min, t.max = value, value
        end
        table.insert(c, t)
    end

    return (#c > 0) and c or nil
end

-- 获取触发结果数据
local function getResult(item)
    local r
    -- if item.type >= 3 then
    -- 	r = {type = item.type, id = item.subtype, value = tonumber(item.value)}
    -- else
    -- 	r = {type = item.type, id = string.format("%s:%s", item.type, item.subtype), value = tonumber(item.value)}
    -- end
    r = {type = item.type, id = item.subtype, value = tonumber(item.value) or item.value, ops = item.ops}
    return r
end

-- 解析触发结果
local function getResultData(result)
    if type(result) == "string" and result ~= "" then
        result = json.parse(result)
    end

    local rt = {}
    if type(result) == "table" then
        for _, item in ipairs(result) do
            local r = getResult(item)

            if r then
                table.insert(rt, r)
            end
        end
    end

    return (#rt > 0) and rt or nil
end

-- 生成 need 或者 visible 的条件数据，带 ops
local function generateNeedOrVisibleData(tp, cond, ops)
    if not cond or cond == "" then
        return
    end
    local r = {
        ops = ops or 0,
        need = (tp == 1) and parseCondition(cond) or nil,
        needFunc = (tp == 2) and cond or nil
    }

    if r.need or r.needFunc then
        return r
    end
end

local function generateResultData(tp, result, desc)
    if (not result or result == "") and (not desc or desc == "") then
        return
    end
    local r = {
        addValue = (tp == 1) and getResultData(result) or nil,
        func = (tp == 2) and result or nil,
        desc = desc
    }

    if r.addValue or r.func or r.desc then
        return r
    end
end

--生成导出文件全路径
local function CP(fn)
    return path.join(basepath, fn)
end

--生成数据
local nameDataDic = {}
local function writeFileSync(name, data)
    fs.writeFileSync(CP(name .. ".txt"), json.encode(data))
    nameDataDic[name] = data
end

--读取地点任务列表
local function loadCityObjects()
    local r1 = gd.query("select * from scene_object")

    local so = {}
    for k, v in ipairs(r1 or {}) do
        if v.sceneid then
            local ctrl = json.parse(v.ctrl or "")
            table.insert(
                so,
                {
                    cityID = v.sceneid,
                    objectID = v.objid,
                    visible = ctrl and generateNeedOrVisibleData(ctrl.trigger, ctrl.cond, ctrl.cond_ops) or nil
                }
            )
        end
    end
    writeFileSync("CityObjects", so)
end

--读取地点
-- local scene = gd.query("select id, name, desc, enter_trigger as enterFunc, leave_trigger as leaveFunc from scene")
-- writeFileSync("Citys", scene)
local function loadCitys()
    local r = gd.getAllScene()
    local t = {}
    for _, row in ipairs(r) do
        table.insert(
            t,
            {
                id = row.id,
                name = row.name,
                desc = row.desc,
                enterNeed = generateNeedOrVisibleData(row.et_cond_type, row.enter_cond, row.et_cond_ops),
                leaveNeed = generateNeedOrVisibleData(row.lt_cond_type, row.leave_cond, row.lt_cond_ops),
                enterSuccess = generateResultData(row.et_type, row.enter_trigger),
                leaveSuccess = generateResultData(row.lt_type, row.leave_trigger),
                enterFail = generateResultData(row.et_fail_type, row.enter_trigger_fail),
                leaveFail = generateResultData(row.lt_fail_type, row.leave_trigger_fail)
            }
        )
    end
    writeFileSync("Citys", t)
end

--- 导出路径
local function loadCityWays()
    local r = gd.query("select * from linkpath")
    local t = {}
    for k, v in ipairs(r) do
        -- 通过鉴定失败错误提示
        local fail_desc = v.passcond_fail_desc
        if fail_desc == "" then
            fail_desc = nil
        end

        table.insert(
            t,
            {
                id = v.id,
                from = v.startpot,
                to = v.endpot,
                direct = v.direct,
                need = generateNeedOrVisibleData(v.passcond_type, v.passcond, v.passcond_ops),
                visible = generateNeedOrVisibleData(v.opencond_type, v.opencond, v.opencond_ops),
                failDesc = fail_desc
            }
        )
    end
    writeFileSync("CityWays", t)
end

---导出对话
local function loadGoodsAction()
    local r = gd.query("select * from module_talk")
    local t = {}
    for k, v in ipairs(r) do
        table.insert(
            t,
            {
                actionName = v.name,
                id = v.id,
                objectID = v.objid,
                need = generateNeedOrVisibleData(v.trigger_type, v.condition, v.cond_ops),
                success = generateResultData(v.succ_type, v.succ_trigger, v.content),
                fail = generateResultData(v.fail_type, v.fail_trigger, v.fail_desc),
                actionCount = v.trigger_count,
                visible = generateNeedOrVisibleData(v.visible_cond_trigger_type, v.visible_cond, v.visible_ops)
            }
        )
    end
    writeFileSync("GoodsAction", t)
end

--导出互动对象
local function loadGoods()
    local r = gd.query("select * from object")
    writeFileSync("Goods", r)
end

-- 获取以来数据
local function getPropertyDependent(script)
    if not script or script == "" then
        return
    end
    local r
    local change = {}
    local pkey = {}
    -- 兼容下 数字 和 属性名称的转换
    for prop in string.gmatch(script, [[getProperty%(['"]([^'"]+)['"]%)]]) do
        local propid = tonumber(prop)
        if propid then
            -- 去重
            pkey[prop] = true
        else
            -- 去重，这里先前后加上单引号，方便 sql 语句
            change["'" .. prop .. "'"] = true
        end
    end

    -- 得到 key 的数组
    local t = {}
    for key, _ in pairs(change) do
        table.insert(t, key)
    end

    if #t > 0 then
        -- 转换一次属性名称到 id
        local result = gd.query(string.format("Select id From property where name in (%s)", table.concat(t, ",")))
        for _, row in ipairs(result) do
            pkey[tostring(row.id)] = true
        end
    end

    -- 换个格式再来一次，纯数字的 key
    for prop in string.gmatch(script, [[getProperty%((%d+)%)]]) do
        -- 去重
        pkey[prop] = true
    end

    local dependent = {}
    for k, _ in pairs(pkey) do
        table.insert(dependent, tostring(k))
    end

    if #dependent > 0 then
        r = json.stringify(dependent)
    end
    return r
end

--导出属性
local function loadProperty()
    local r = gd.query("select * from property")
    local t = {}
    local t1 = {}
    local t2 = {}
    for _, v in ipairs(r) do
        -- 属性的主类型是1
        local mid
        if v.master < 1 then
            -- 临时属性增加上限属性id
            -- mid = "1:" .. v.link_prop
            mid = v.link_prop
        end
        local func = (v.calc ~= "") and v.calc or nil
        -- 计算依赖
        local dependent
        if func then
            dependent = getPropertyDependent(func)
        end

        -- 上下限
        local min = 0
        local max = 2 ^ 31

        if v.range and v.range ~= "" then
            local range = json.parse(v.range)
            min = range.min
            max = range.max
        end

        table.insert(
            t,
            {
                -- id = "1:" .. v.id,
                id = v.id,
                tagID = v.typeid,
                name = v.name,
                weight = v.priority,
                desc = v.desc,
                -- visible = v.visible,
                func = func,
                min = min,
                max = max,
                preProperty = dependent,
                maxProperty = mid
            }
        )

        -- PropertyAction
        if v.trigger and v.trigger ~= "" then
            local data = {}
            local trigger = json.parse(v.trigger)
            for _, row in ipairs(trigger) do
                table.insert(
                    data,
                    {
                        value = row.tvalue,
                        success = {
                            addValue = row.result_type == 1 and getResultData(row.result) or "",
                            desc = "",
                            func = row.result_type == 2 and row.result or ""
                        }
                    }
                )
            end
            table.insert(
                t1,
                {
                    propertyID = v.id,
                    data = data
                }
            )
        end

        -- PropertyValue
        if v.dict and v.dict ~= "" then
            local data = json.parse(v.dict)
            local vdata = {}
            -- 整合过滤数据
            for _, row in ipairs(data.data) do
                if row.min and row.min ~= "" then
                    if not row.max or row.max == "" then
                        row.max = row.min
                    end
                    table.insert(vdata, row)
                end
            end

            table.insert(
                t2,
                {
                    id = v.id,
                    desc = data.default,
                    data = vdata
                }
            )
        end
    end
    writeFileSync("Property", t)
    writeFileSync("PropertyAction", t1)
    writeFileSync("PropertyValue", t2)
end

-- 技能分类导出
local function loadPropertyTagName()
    local r = gd.query("select id, name, priority as weight, visible from property_type")
    writeFileSync("PropertyTagName", r)
end

-- 导出物品分类表
local function loadGoodsTagName()
    local r = gd.query("select typeid as id, name, priority as weight, visible from item_type")
    writeFileSync("GoodsTagName", r)
end

-- 处理三大效果的数据
local function handleEffect(trigger, effect, cond, cond_ops)
    local r
    if effect and effect ~= "" then
        r = r or {}
        if trigger == 1 then
            r.addFunc = effect
        else
            local data = json.parse(effect)
            for _, v in ipairs(data) do
                -- 属性、物品在这里
                v.id = v.subtype
                v.subtype = nil
                if not v.ops then
                    v.ops = 1
                end
            end
            r.addValue = data
        end
    end

    if cond and cond ~= "" then
        r = r or {}
        r.need = generateNeedOrVisibleData(1, cond, cond_ops)
    end

    return r
end

-- 导出物品表
local function loadGoodsUse()
    local r = gd.getItem()
    local t = {}
    for _, row in ipairs(r) do
        -- 物品插槽
        local slot
        if row.slots and row.slots ~= "" then
            slot = json.parse(row.slots)
            for _, s in ipairs(slot) do
                s.slotNum = s.cnt
                s.cnt = nil
            end
        end
        -- 装备效果
        local equipValue = handleEffect(row.prop_equip_trigger_type, row.prop_equip, row.cond_equip, row.cond_equip_ops)

        -- 携带效果
        local carryValue = handleEffect(row.prop_carry_trigger_type, row.prop_carry, row.cond_carry, row.cond_carry_ops)

        -- 消耗效果
        local consumeValue =
            handleEffect(row.prop_consume_trigger_type, row.prop_consume, row.cond_consume, row.cond_consume_ops)

        -- 交互按钮
        local btns
        if row.alternation and row.alternation ~= "" then
            btns = {}
            local data = json.parse(row.alternation)
            for _, vdata in ipairs(data) do
                local btn = {}
                btn.text = vdata.name
                -- 显示控制
                if vdata.visible then
                    local v = vdata.visible
                    btn.visible = generateNeedOrVisibleData(v.type, v.value, v.ops)
                end
                -- 触发条件
                if vdata.trigger_cond then
                    local v = vdata.trigger_cond
                    btn.need = generateNeedOrVisibleData(v.type, v.value, v.ops)
                end
                -- 成功触发
                if vdata.trigger_succ then
                    local v = vdata.trigger_succ
                    btn.success = generateResultData(v.type, v.value)
                end
                -- 失败触发
                if vdata.trigger_fail then
                    local v = vdata.trigger_fail
                    btn.fail = generateResultData(v.type, v.value)
                end
                btn.success = btn.success or {}
                btn.success.desc = vdata.desc or ""
                btn.fail = btn.fail or {}
                btn.fail.desc = vdata.fail_desc or ""
                table.insert(btns, btn)
            end
        end

        table.insert(
            t,
            {
                -- id = "2:" .. row.id,
                id = row.id,
                name = row.name,
                desc = row.desc,
                tagID = row.typeid,
                weight = 100,
                equip = row.feature_equip,
                destory = row.feature_destory,
                consume = row.feature_consume,
                equipValue = equipValue,
                carryValue = carryValue,
                consumeValue = consumeValue,
                btns = btns,
                slot = slot
            }
        )
    end
    writeFileSync("GoodsUse", t)
end

-- 交互模块输出
local function loadQuestion()
    local r = gd.query("select id, name, desc, data from alternation")
    local t = {}
    for _, row in ipairs(r) do
        local data = json.parse(row.data or "")

        local btns = {}
        if data then
            for _, item in ipairs(data) do
                local btn = {}
                btn.text = item.name
                -- 处理显示数据
                if item.visible then
                    local vdata = item.visible
                    btn.visible = generateNeedOrVisibleData(vdata.type, vdata.value, vdata.ops)
                end
                -- 处理条件数据
                if item.trigger_cond then
                    local vdata = item.trigger_cond
                    btn.need = generateNeedOrVisibleData(vdata.type, vdata.value, vdata.ops)
                end
                -- 处理成功数据
                if item.trigger_succ then
                    local vdata = item.trigger_succ
                    btn.success = generateResultData(vdata.type, vdata.value)
                end
                -- 处理失败数据
                if item.trigger_fail then
                    local vdata = item.trigger_fail
                    btn.fail = generateResultData(vdata.type, vdata.value)
                end

                btn.success = btn.success or {}
                btn.success.desc = item.desc or ""
                btn.fail = btn.fail or {}
                btn.fail.desc = item.fail_desc or ""

                table.insert(btns, btn)
            end
        end

        table.insert(
            t,
            {
                id = row.id,
                title = row.name,
                content = row.desc,
                btns = btns
            }
        )
    end
    writeFileSync("Question", t)
end

-- 剧情数据
local function loadStory()
    local r = gd.query("select * from story")
    local t = {}
    for _, row in ipairs(r) do
        if row.dtype == 0 then
            -- 配置解析
            local data = json.parse(row.data or "")
            if data then
                local story = {}

                for line in string.gmatch(data.story, "%S+") do
                    table.insert(story, line)
                end

                data.id = row.id
                data.story = story
                table.insert(t, data)
            end
        elseif row.dtype == 1 then
            -- 脚本解析
            local data = loadstring(row.data)()
            if type(data) == "table" and data.story and #data.story > 0 then
                data.id = row.id
                table.insert(t, data)
            end
        end
    end
    writeFileSync("Story", t)
end

-- 奖励
local function loadDrop()
    local r = gd.query("select id, type, data from reward")
    local t = {}
    for _, item in ipairs(r) do
        if item.data and item.data ~= "" then
            local tp = item.type

            local data = json.parse(item.data)

            for _, config in ipairs(data.reward) do
                config.id = config.subtype
                -- if config.type < 3 then
                -- 	config.id = config.type .. ":" .. config.subtype
                -- end
                config.subtype = nil
            end

            table.insert(
                t,
                {
                    id = item.id,
                    data = data.reward,
                    type = tp,
                    selNum = data.count,
                    selType = data.duplicate and 1 or 2
                }
            )
        end
    end
    writeFileSync("Drop", t)
end

-- 敌人属性数据
local function loadNPC()
    local enemyDefaultSkill = gd.configGet("skill_default_enemy_skill") or -1
    local r = gd.query("select * from enemy")
    local t = {}
    for _, item in ipairs(r) do
        local property
        local script
        local skillID
        if item.type == 0 then
            if item.property then
                -- 属性，可能是空，比如玩家未配置
                if item.property and item.property ~= "" then
                    property = json.parse(item.property)
                    for _, prop in ipairs(property) do
                        -- prop.id = prop.type .. ":" .. prop.subtype
                        prop.id = prop.subtype
                        prop.class = nil
                        -- prop.type = nil
                        prop.subtype = nil
                    end
                end

                if item.skill and item.skill ~= "" then
                    local s = json.parse(item.skill)
                    if #s > 0 then
                        skillID = s[1]
                    end
                elseif enemyDefaultSkill > 0 then
                    -- 默认是第一个技能
                    skillID = enemyDefaultSkill
                end
            end
        else
            script = item.script
        end
        table.insert(
            t,
            {
                id = item.id,
                name = item.name,
                property = property,
                skillID = skillID,
                func = script
            }
        )
    end

    writeFileSync("NPC", t)
end
-- 战役数据

-- 默认战役失败的触发数据
local function loadNPCCombat()
    local default_fail_trigger = gd.configGet("campaign_default_fail_trigger")
    local r = gd.query("select id, name, desc, enemies, trigger from campaign;")
    local t = {}
    for _, item in ipairs(r) do
        local trigger = json.parse(item.trigger or {})
        local enemies = json.parse(item.enemies or {})

        -- 敌人设置
        local npcList = {}
        for _, enemy in ipairs(enemies) do
            table.insert(npcList, enemy)
        end

        -- 胜利触发
        local success
        if trigger.win then
            success = {}
            -- 胜利描述文字
            success.desc = trigger.win.desc or ""
            if trigger.win.control == 1 then
                -- 配置
                success.addValue = getResultData(trigger.win.data)
            elseif trigger.win.control == 2 then
                -- 脚本
                success.func = trigger.win.data
            end
        end

        -- 失败触发
        local fail
        if trigger.lose then
            fail = {}
            -- 胜利描述文字
            fail.desc = trigger.lose.desc
            if trigger.lose.control == 1 then
                -- 配置
                fail.addValue = getResultData(trigger.lose.data)
            elseif trigger.lose.control == 2 then
                -- 脚本
                fail.func = trigger.lose.data
            elseif default_fail_trigger and default_fail_trigger ~= "" then
                fail.addValue = getResultData(default_fail_trigger)
            end
        elseif default_fail_trigger and default_fail_trigger ~= "" then
            fail = {
                desc = "",
                addValue = getResultData(default_fail_trigger)
            }
        end

        table.insert(
            t,
            {
                id = item.id,
                name = item.name,
                desc = item.desc,
                npcList = npcList,
                success = success,
                fail = fail
            }
        )
    end
    writeFileSync("NPCCombat", t)
end

-- 技能导出
local function loadSkill()
    local r = gd.query("select * from skill")
    local t = {}
    for _, row in ipairs(r) do
        -- 插槽
        local slotData
        local slot
        if row.slots and row.slots ~= "" then
            slotData = string.gsub(row.slots, "cnt", "slotNum")
            slot = json.parse(slotData)
        end

        -- 对应的消耗，要根据触发值来生成对应的条件
        local consume = generateResultData(row.consume_type, row.consume_data)
        if row.consume_type == 1 then
            -- 生成条件
            if row.consume_data and row.consume_data ~= "" then
                local data = json.parse(row.consume_data)
                local need = {}
                for _, con in ipairs(data) do
                    local v = tonumber(con.value)
                    if v and v < 0 then
                        table.insert(
                            need,
                            {
                                ops = 0, -- 必须全部满足
                                type = con.type,
                                id = con.subtype,
                                min = math.abs(v)
                            }
                        )
                    end
                end
                if #need > 0 then
                    consume.need = need
                end
            end
        end

        table.insert(
            t,
            {
                id = row.id,
                name = row.name,
                desc = row.desc,
                func = row.data,
                -- 装配条件
                need = generateNeedOrVisibleData(row.equip_type, row.equip_data, row.equip_cond_ops),
                -- 固定消耗
                consume = consume,
                tagID = row.typeid,
                slot = slot
            }
        )
    end
    writeFileSync("Skill", t)
end

-- 技能分类导出
local function loadSkillTagName()
    local r = gd.query("select id, name, priority as weight, visible from skill_type")
    writeFileSync("SkillTagName", r)
end

-- 插槽导出
local function loadSlot()
    local r = gd.query("select id, name, cnt as slotNum from slot")
    writeFileSync("Slot", r)
end

-- 战斗设置属性展现导出
local function loadCombatProperty()
    local r = gd.configGet("campaign_property")
    if r and r ~= "" then
        r = json.parse(r)
        for idx, row in ipairs(r) do
            row.weight = idx
            row.propertyID = row.id
        end
    end
    writeFileSync("CombatProperty", r)
end

-- 出生点导出
local function loadMapEnter()
    local r = gd.configGet("game_born_point")
    local t = {
        {
            mapID = 1,
            cityID = r or 1
        }
    }
    writeFileSync("MapEnter", t)
end

-- 生成随机事件数据
local function generateRandomEventData(t, rdata)
    if not rdata or rdata == "" then
        return
    end

    local data = json.parse(rdata)
    if type(data.data) == "table" then
        for _, v in ipairs(data.data) do
            v.id = v.subtype
            v.subtype = nil
        end
    end

    local tp = t.type
    if tp == 1 then
        t.data = data.data
    elseif tp == 2 then
        t.data = data.data
        t.selType = data.duplicate and 1 or 2
        t.selNum = data.count
    elseif tp == 3 then
        t.func = data.data
    end
end

-- 随机事件
local function loadRandomAction()
    local r = gd.query("select * from random")
    local t = {}
    for _, row in ipairs(r) do
        local success = {}
        local tp = row.success_type
        success.type = tp
        generateRandomEventData(success, row.success)

        local fail = {}
        local tp = row.fail_type
        fail.type = tp
        generateRandomEventData(fail, row.fail)

        table.insert(
            t,
            {
                id = row.id,
                name = row.name,
                need = generateNeedOrVisibleData(row.cond_type, row.cond, row.cond_ops),
                success = success,
                fail = fail
            }
        )
    end
    writeFileSync("RandomAction", t)
end

-- 导航栏配置
local function loadNavigation()
    local r = gd.configGet("navigation")
    if not r or r == "" then
        r =
            '[{"type":1,"weight":1,"name":"角色","id":1},{"type":2,"weight":2,"name":"道具","id":2},{"type":3,"weight":3,"name":"技能","id":3}]'
    end
    writeFileSync("Navigation", json.parse(r))
end

local function generateExchangeData(data, direction)
    local r = {}
    if not data then
        return r
    end
    local key1 = "token"
    local key2 = "target"
    if direction == 1 then
        key1, key2 = key2, key1
    end
    local data = json.parse(data)
    for _, row in ipairs(data) do
        local t = {}
        if row[key1] then
            for _, item in ipairs(row[key1]) do
                item.id = item.subtype
                item.subtype = nil
            end
            t.from = row[key1]
        end
        if row[key2] then
            for _, item in ipairs(row[key2]) do
                item.id = item.subtype
                item.subtype = nil
            end
            t.to = row[key2]
        end
        table.insert(r, t)
    end

    return r
end

-- 导出交易模块数据
local function loadExchange()
    local r = gd.query("select * from trade")
    local t = {}
    for _, row in ipairs(r) do
        local buy
        local sale
        if row.type == 0 then
            buy = generateExchangeData(row.tradeout)
            sale = generateExchangeData(row.tradein, 1)
        end
        table.insert(
            t,
            {
                id = row.id,
                name = row.name,
                desc = row.desc,
                type = row.type + 1,
                buy = buy,
                sale = sale
            }
        )
    end
    writeFileSync("Exchange", t)
end

-- local function generateCondition(t, tp, data)
-- 	if tp == 1 then
-- 		-- 配置
-- 		t.need = parseCondition((data and data ~= "") and json.parse(data) or "")
-- 	elseif tp == 2 then
-- 		-- 脚本
-- 		t.needFunc = data
-- 	end
-- end

local function generateResult(t, tp, data)
    if tp == 1 then
        -- 配置
        t.addValue = getResultData((data and data ~= "") and json.parse(data) or "")
    elseif tp == 2 then
        -- 脚本
        t.addFunc = data
    end
end

-- 资源生产
local function loadObjectAutoRun()
    local r = gd.getGenerator()
    local t = {}
    for _, row in ipairs(r) do
        local data = json.parse(row.data)
        local start = {}
        start.need = generateNeedOrVisibleData(row.cond_open_type, row.cond_open, row.cond_open_ops)
        local prize = {}
        prize.need = generateNeedOrVisibleData(row.cond_get_type, row.cond_get, row.cond_get_ops)
        -- generateCondition(start, row.cond_open_type, row.cond_open)
        -- generateCondition(prize, row.cond_get_type, row.cond_get)
        generateResult(start, row.trigger_open_type, row.trigger_open)
        generateResult(prize, row.trigger_get_type, row.trigger_get)

        table.insert(
            t,
            {
                id = row.id,
                name = row.name,
                desc = row.desc,
                type = row.type,
                autoStart = row.auto_start,
                productID = data.subtype,
                goodsType = data.type,
                productCount = data.count,
                productTime = data.time * 60,
                countMax = data.volume,
                getCount = data.gain,
                start = start,
                prize = prize
            }
        )
    end
    writeFileSync("ObjectAutoRun", t)
end

-- 充值选项
local function loadPay()
    local r = gd.getPayment()
    local t = {}
    for _, row in ipairs(r) do
        table.insert(
            t,
            {
                id = row.id,
                name = row.name,
                price = row.price,
                desc = row.desc,
                addValue = getResultData(row.content)
            }
        )
    end
    writeFileSync("Pay", t)
end

-- 多人互动
local function loadOnlineFunc()
    local r = {
        {
            id = 1,
            func = gd.configGet("multiple_script")
        }
    }
    writeFileSync("OnlineFunc", r)
end

-- 分享奖励
local function loadSharePrize()
    local sr = gd.configGet("share_reward")
    if sr and sr ~= "" then
        local r = {
            {
                id = 1,
                addValue = getResultData(sr)
            }
        }
        writeFileSync("SharePrize", r)
    end
end

-- 逻辑
local function loadCommonAction()
    local r = gd.getLogic()
    local t = {}
    for _, item in ipairs(r) do
        local cond = json.parse(item.condition or "") or {}
        local success = json.parse(item.success or "") or {}
        local fail = json.parse(item.fail or "") or {}
        table.insert(
            t,
            {
                id = item.id,
                need = generateNeedOrVisibleData(cond.type, cond.data, cond.ops),
                success = generateResultData(success.type, success.data),
                fail = generateResultData(fail.type, fail.data)
            }
        )
    end
    writeFileSync("CommonAction", t)
end

-- 游戏名称
local function loadGameInfo()
    writeFileSync(
        "GameInfo",
        {
            {
                name = gd.configGet("game_title"),
                version = gd.configGet("game_version")
            }
        }
    )
end

-- 整体配置数据
local function loadSetting()
    -- 地图整体移动时间
    writeFileSync(
        "Setting",
        {
            {
                -- id = 1,
                key = "map_moveTime",
                -- 毫秒转化到秒
                value = tonumber(gd.configGet("map_move_time") or 300) / 1000
            },
            {
                key = "map_showMoveLog",
                value = tonumber(gd.configGet("map_move_show_log") or 1)
            },
            {
                key = "log_showTraceLog",
                value = tonumber(gd.configGet("game_debug_trace_log") or 1)
            },
            {
                key = "goods_useEquipTab",
                value = tonumber(gd.configGet("goods_use_equip_tab") or 1)
            }
        }
    )
end

-- 自定义数据
local function loadCustomData()
    local r = gd.query("select kname, type, data from custom_data")

    local t = {}
    for _, row in ipairs(r) do
        local value = row.data
        if row.type == 1 then
            value = json.parse(row.data)
        end
        t[row.kname] = value
    end

    writeFileSync("customdata", {t})
end

-- 插件数据导出
local function loadLuaExport()
    local r = gd.getScriptPluggin()
    local t = {}
    for i, row in ipairs(r) do
        table.insert(t, {id = i, func = row.data})
    end
    writeFileSync("LuaExport", t)
end

local _wrap = function(f)
    local r, err = pcall(f)
    if not r then
        p(err)
    end
end

local function loadAll()
    _wrap(loadCityObjects)
    _wrap(loadCitys)
    _wrap(loadCityWays)
    _wrap(loadGoodsAction)
    _wrap(loadGoods)
    _wrap(loadProperty)
    _wrap(loadPropertyTagName)
    _wrap(loadGoodsTagName)
    _wrap(loadGoodsUse)
    _wrap(loadQuestion)
    _wrap(loadStory)
    _wrap(loadDrop)
    _wrap(loadNPC)
    _wrap(loadNPCCombat)
    _wrap(loadSkill)
    _wrap(loadSkillTagName)
    _wrap(loadSlot)
    _wrap(loadCombatProperty)
    _wrap(loadMapEnter)
    _wrap(loadRandomAction)
    _wrap(loadNavigation)
    _wrap(loadExchange)
    _wrap(loadObjectAutoRun)
    _wrap(loadPay)
    _wrap(loadOnlineFunc)
    _wrap(loadSharePrize)
    _wrap(loadCommonAction)
    _wrap(loadGameInfo)
    _wrap(loadSetting)
    _wrap(loadCustomData)
    _wrap(loadLuaExport)
end

loadAll()

return {
    fileData = nameDataDic,
    loadAll = loadAll
}
