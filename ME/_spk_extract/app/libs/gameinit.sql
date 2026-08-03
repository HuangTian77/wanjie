-- 数据库创建脚本 --

-- 全局数据配置表
create table config(name text primary key,
    value
);

-- 主地图
create table map (id integer primary key autoincrement,
    name, -- 地图名称，比如（中国、北京、杭州等）
    width integer default 10, -- 横向节点数目
    height integer default 10, -- 纵向节点数目
    desc, -- 地图描述
    note -- 备注
);

-- id 场景ID
-- name 名称 desc 详细描述 east,west...对应方位的地点
-- et_type 进入场景的触发类型 ( 0 - 无，1 - 条件，2 - 脚本)
-- enter_trigger 进入场景的触发
-- lt_type 离开场景的触发类型
-- leave_trigger 离开场景的触发
-- x, y  地图编辑器上的坐标位置
-- note 备注
create table scene (id integer primary key autoincrement,  
			name, 
			desc,
            et_cond_type integer default 0,
            et_cond_ops integer default 0,
            enter_cond text,

            lt_cond_ops integer default 0,
            lt_cond_type integer default 0,
            leave_cond text,
            et_type integer default 0,
            enter_trigger text,
            lt_type integer default 0,
            leave_trigger text,
            et_fail_type integer default 0,
            enter_trigger_fail text,
            lt_fail_type integer default 0,
            leave_trigger_fail text,
            x, 
            y, 
            note default '',
            mapid integer default 1);

-- 增加进场景和出场景的触发
alter table scene add column et_type integer default 0;
alter table scene add column enter_trigger text;
alter table scene add column lt_type integer default 0;
alter table scene add column leave_trigger text;
alter table scene add column lt_cond_ops integer default 0;
alter table scene add column lt_cond_type integer default 0;
alter table scene add column leave_cond text;
alter table scene add column et_cond_type integer default 0;
alter table scene add column et_cond_ops integer default 0;
alter table scene add column enter_cond text;
alter table scene add column et_fail_type integer default 0;
alter table scene add column enter_trigger_fail text;
alter table scene add column lt_fail_type integer default 0;
alter table scene add column leave_trigger_fail text;
alter table scene add mapid integer default 1;

-- 地点间路径
-- startpot 起点场景ID
-- endpot 方位  startpot->endpot 的方向 east, west...
-- to   终点场景ID
-- status 状态 0 正常 -1 不显示
-- opencond 打开路径的条件
-- opencond_type 开关触发类型
-- closecond 关闭路径的条件
-- passcond  通过路径的条件
-- passcond_type 通过路径触发的类型
create table linkpath (id integer primary key autoincrement,  
            startpot,
            direct, 
            endpot,
            status default 0,
            status_editable integer default 0,
            opencond,
            opencond_type,
            opencond_ops integer default 0,
            passcond,
            passcond_type,
            passcond_ops integer default 0,
            passcond_fail_desc,

            closecond,
            note);

-- 给原来的表增加一个 status_editable 列，兼容老的数据模式
alter table linkpath add column status_editable integer default 0;
-- 通过触发的类型
alter table linkpath add column passcond_type integer default 0;
-- 增加通过触发失败的错误提示
alter table linkpath add column passcond_fail_desc;
-- 开启触发的类型
alter table linkpath add column opencond_type integer default 0;
-- 条件的全与全或标志
alter table linkpath add column opencond_ops integer default 0;
alter table linkpath add column passcond_ops integer default 0;

-- 交互对象基础表
-- name 简称 desc 描述  note备注
create table object (id integer primary key autoincrement,
            name, desc, note);
            
        
-- 场景静态对象表
-- sceneid 场景ID
-- objid   对象ID
create table scene_object(id integer primary key autoincrement,
            sceneid integer not null,
            objid integer not null,
            ctrl);

-- 增加一个控制字段，内部是 json 的数据
alter table scene_object add column ctrl;
            
    
-- 交谈模块数据库
-- objid 对象id 
-- name 互动显示名称
-- status 状态(0-不激活，1-正常)
-- content 默认的交互文字
-- visible_cond 前置触发条件，可以是条件，可以是脚本
-- visible_cond_tigger_type 前置触发条件的类型，（0-无触发，1-条件控制，2-脚本控制） 
-- trigger_type 触发类型（0-无触发，1-条件控制，2-脚本控制）
-- trigger_count 触发的次数，默认为0表示不判断，如果是大于0的数字则表示会触发递减，到0后则互动不可见
-- condition 所需条件
-- succ_trigger 成功触发
-- fail_trigger 失败触发
-- fail_desc 失败后的文案，如果不配置，则默认显示 content
-- note备注
create table module_talk(id integer primary key autoincrement,
            objid,
            name,
            status default 1,
            content,
            visible_cond_ops integer default 0,
            visible_cond_trigger_type integer default 0,
            visible_cond,
            trigger_count integer default 0,
            trigger_type integer default 0,
            condition,
            cond_ops integer default 0,
            succ_type integer default 0,
            succ_trigger,
            fail_type integer default 0,
            fail_trigger,
            fail_desc,
            note);

-- 给原来的表增加一个 trigger_type 列，兼容老的数据模式
alter table module_talk add column trigger_type integer default 0;
alter table module_talk add column succ_type integer default 0;
alter table module_talk add column fail_type integer default 0;
-- 增加一个触发次数字段
alter table module_talk add column trigger_count integer default 0;
-- 增加一个触发失败提示文字字段
alter table module_talk add column fail_desc;
-- 增加一个控制是否显示当前互动的触发条件
alter table module_talk add column visible_cond;
-- 增加一个控制当前互动前置条件的触发类型
alter table module_talk add column visible_cond_trigger_type integer default 0;
-- 全或全与的标志
alter table module_talk add column visible_cond_ops integer default 0;
alter table module_talk add column cond_ops integer default 0;

-- 对象的属性
create table property(id integer primary key autoincrement,
            typeid integer default 1,
            name,   -- 属性的名称
            visible integer default 1, -- 游戏客户端是否可见属性，默认为 1，表示可见
            priority integer default 100, -- 排序权重，越小权重越高
            master integer default 1,   -- 默认主属性, 0 为子属性
            link_prop,  -- 属性关联
            range,  -- 取值范围
            calc, -- 计算公式
            trigger, -- 触发配置
            desc,
            dict,   -- 属性字典
            note
);

-- 增加属性表中的客户端可见与否的标志
alter table property add column visible integer default 1;
-- 增加物品在包裹中的排序权重重
alter table property add column priority integer default 100;
-- 增加属性的备注字段
alter table property add column note;
-- 主从关系
alter table property add column master integer default 1;
-- 属性关联，主属性会关联所有子属性，子属性会关联对应主属性，方便删除
alter table property add column link_prop;
-- 属性的取值范围
alter table property add column range;
-- 计算公式
alter table property add column calc;
-- 触发配置 
alter table property add column trigger;
-- 属性字典
alter table property add column dict;
-- 分类
alter table property add column typeid integer default 1;

-- 创建属性的分类表
create table property_type(id integer primary key autoincrement,
            typeid integer,
            priority integer default 100, -- 排序权重，数字越小权重越高
            name,
            desc,
            visible integer default 1, -- 0 - 不可见 1 - 可见
            note
);

-- 创建技能表
create table skill(id integer primary key autoincrement,
    typeid integer not null, -- 类型 id
    name, -- 技能显示名称
    desc, -- 技能描述
    data_type integer default 0, -- 数据类型（脚本 0、配置 1）
    data, -- 技能的数据
    slots, -- 技能槽位信息
    equip_cond_ops integer default 0,
    equip_type integer default 0, -- 装配条件（0 - 无，1 - 配置，2 - 脚本）
    equip_data, -- 装配条件
    consume_type, -- 消耗类型
    consume_data, -- 消耗配置
    note  -- 备注
);
-- 技能的装配类型
alter table skill add column equip_type integer default 0;
-- 技能的装配数据
alter table skill add column equip_data;
-- 技能的消耗类型
alter table skill add column consume_type integer default 0;
-- 技能的消耗数据
alter table skill add column consume_data;
-- 技能装备条件策略
alter table skill add column equip_cond_ops integer default 0;

-- 技能分类表
create table skill_type(id integer primary key autoincrement,
    name, -- 分类名称
    slots, -- 预制的槽位占用信息
    priority integer default 100, -- 排序权重
    visible integer default 1, -- 0 - 不可见 1 - 可见
    note  -- 分类备注
);

alter table skill_type add column priority integer default 100; -- 排序权重
alter table skill_type add column visible integer default 1; -- 可见 

-- 创建物品的分类表
create table item_type(id integer primary key autoincrement,
            typeid integer,
            priority integer default 100, -- 排序权重，数字越小权重越高
            name,
            desc,
            feature_equip integer default 0, -- 固定特性: 是否可装备
            feature_destory integer default 0, -- 固定特性：是否可销毁
            feature_consume integer default 0, -- 固定特性：是否可销毁
            slots,      -- 装备槽位信息
            visible integer default 1, -- 0 - 不可见 1 - 可见
            note
);
-- 固定特性
alter table item_type add column feature_equip integer default 0;
alter table item_type add column feature_destory integer default 0;
alter table item_type add column feature_consume integer default 0;
-- 槽位
alter table item_type add column slots;
alter table item_type add column visible integer default 1; -- 可见 

-- 物品的基础表
create table item(id integer primary key autoincrement,
            name, -- 物品名称
            typeid integer, -- 分类
            desc, -- 物品描述
            prop_equip, -- 装备属性
            prop_equip_trigger_type integer default 0, -- 装备效果的触发类型， 0 - 配置 1 - 脚本
            cond_equip_ops integer default 0,
            cond_equip, -- 装备属性起效条件
            prop_consume, -- 消耗属性
            cond_consume_ops integer default 0,
            cond_consume, -- 消耗属性起效条件
            prop_carry, -- 携带属性
            cond_carry_ops integer default 0,
            cond_carry, -- 携带属性起效条件
            alternation, -- 互动数据
            feature_equip integer default 0, -- 固定特性: 是否可装备
            feature_destory integer default 0, -- 固定特性：是否可销毁
            feature_consume integer default 0, -- 固定特性：是否可消耗
            slots, -- 槽位信息
            note
);

-- 增加三个位置的属性字段
alter table item add column prop_equip;
alter table item add column prop_consume;
alter table item add column prop_carry;
-- 增加三个效果的起效条件
alter table item add column cond_equip;
alter table item add column cond_consume;
alter table item add column cond_carry;
-- 增加三个条件策略
alter table item add column cond_equip_ops integer default 0;
alter table item add column cond_consume_ops integer default 0;
alter table item add column cond_carry_ops integer default 0;
-- 互动数据
alter table item add column alternation;
-- 固定特性
alter table item add column feature_equip integer default 0;
alter table item add column feature_destory integer default 0;
alter table item add column feature_consume integer default 0;
-- 槽位
alter table item add column slots;
-- 脚本
alter table item add column prop_equip_trigger_type integer default 0; -- 装备效果的触发类型， 0 - 配置 1 - 脚本

-- 交互模块
create table alternation(id integer primary key autoincrement,
    name, -- 交互模块名称
    desc, -- 描述
    data, -- 数据存储区域，内部包含了整个交互模块的内容，以 json 格式存储
    note  -- 交互模块备注
);

-- 奖励数据模块
create table reward(id integer primary key autoincrement,
    name, -- 奖励名称，触发的选择的时候区分
    type integer default 1, -- 类型，1 - 概率模式，2 - 权重模式
    data, -- 数据区，json 串数据
    note -- 备注
);

-- 奖励类型
alter table reward add column type integer default 1;

-- 故事情节数据
create table story(id integer primary key autoincrement,
    name, -- 故事情节的名称，可以做为一个标题
    data, -- 数据区域，直接以 json 结构存储
    dtype integer DEFAULT 0, -- 数据的类型，（0 - 无数据，1 - 配置数据，2 - 脚本配置）
    note -- 备注
);

-- 敌人对象数据
create table enemy(id integer primary key autoincrement,
    name, -- 敌人名称
    desc, -- 敌人描述
    property, -- 敌人属性
    skill, -- 敌人所带的技能,
    type integer default 0,
    script, -- 脚本
    note -- 备注
);

-- 敌人所携带的技能
alter table enemy add column skill;
-- 数据数据的格式 0 - 配置 1 - 脚本
alter table enemy add column type integer default 0;
-- 脚本内容
alter table enemy add column script;

-- 敌人模板数据，方便编辑器优化用户操作，不会导出数据到服务器
create table enemy_template(id integer primary key autoincrement,
    name, -- 模板名称
    property, -- 属性
    skill, -- 技能
    note -- 备注
);

-- 敌人所携带的技能
alter table enemy_template add column skill;

-- 战役数据
create table campaign(id integer primary key autoincrement,
    name, -- 战役名称
    desc, -- 战役描述
    enemies, -- 参与战斗的敌人列表
    trigger, -- 战役结束后的触发
    note -- 战役备注
);

-- 槽位表
create table slot(id integer primary key autoincrement,
    name, -- 插槽部位名称
    cnt integer default 0, -- 孔洞数量
    note -- 插槽描述
);
            
-- 槽位数据模板
create table slot_template(id integer primary key autoincrement,
    name, -- 插槽模板名称
    data, -- 数据，json 格式的，[{"id":1, "cnt":1},{"id":2, "cnt":2}]
    note -- 插槽模板描述
);

-- 概率模块
create table random(id integer primary key autoincrement,
    name, -- 模块名称
    cond_ops integer default 0, -- 条件策略
    cond_type integer default 0, -- 条件类型
    cond, -- 条件
    success_type integer default 1, -- 成功的概率触发类型(2 - 权重单产出 1 - 概率全随机, 3 - 脚本控制 )
    success,    -- 成功概率触发内容
    success_desc,   -- 成功概率触发后提示信息
    fail_type integer default 1, -- 失败的概率触发类型 (2 - 权重单产出 1 - 概率全随机, 3 - 脚本控制 )
    fail,   -- 失败概率触发内容
    fail_desc,  -- 失败概率触发后提示信息
    note   -- 备注
);

-- 条件配置策略
alter table random add column cond_ops integer default 0;

-- 交易模块
create table trade(id integer primary key autoincrement,
    name, -- 名称
    type integer default 0, -- 类型 ( 0 - 普通交易， 1 - 合成， 2 - 分解)
    desc, -- 描述
    tradein, -- 换入
    tradeout, -- 换出
    note -- 备注   
);

-- 生产模块
create table generator(id integer primary key autoincrement,
    name, -- 模块名称
    desc, -- 描述
    type integer default 1, -- 生产类型 (1 - 采集，2 - 制造)
    auto_start integer default 0, -- 自动开启标志
    cond_open_ops integer default 0,
    cond_open_type integer default 0, -- 条件类型
    cond_open, -- 条件内容
    cond_get_ops integer default 0,
    cond_get_type integer default 0, -- 条件类型
    cond_get, -- 条件内容
    trigger_open_type integer default 0,
    trigger_open,
    trigger_get_type integer default 0,
    trigger_get,
    data_type integer default 1, -- 类型 (1 - 配置，2 - 脚本)
    data, -- 数据
    note -- 备注
);

alter table generator add column cond_open_ops integer default 0;
alter table generator add column cond_get_ops integer default 0;

-- 充值模块
create table payment(id integer primary key autoincrement,
    name, -- 标题名称
    desc, -- 描述
    price decimal default 1, -- 价格
    currency text default 'CNY', -- 币种
    content, -- 购买的内容
    note -- 备注
);

-- 逻辑模块
create table logic(id integer primary key autoincrement,
    name, -- 标题
    note, -- 备注
    condition,   -- 条件
    success, -- 成功触发
    fail -- 失败触发
);

-- 自定义数据
create table custom_data(id integer primary key autoincrement,
    kname, -- 键值的名称
    name, -- 简易名称
    type integer default 0, -- 数据类型
    data, -- 数据
    note -- 备注
);

-- 脚本插件
create table script_pluggin(id integer primary key autoincrement,
    name,
    note,
    data
);

--创建唯一索引，防止数据重复
-- 道路
create unique index ui1 on linkpath(startpot, endpot, direct); 
create index i2 on module_talk(objid);

-- 属性名称索引，为了 id 和 name 能够互相映射
create unique index ui3 on property(name);

-- 分类表增加分类 typeid 的唯一索引
create unique index ui4 on item_type(typeid);

create unique index ui5 on config(name);

-- 场景对象关系表中同一个对象只允许被添加一次
create unique index ui6 on scene_object(sceneid, objid);

-- 自定义数据中的名称不允许重复
create unique index ui7 on custom_data(kname);