--------------- 配置文件 -------------
return {
    otherinit = './wstart'; --websocket启动入口

	--日志配置和相关参数
    logconfig = 
    {
        maxPackage = 1000;    --最大数据包,每个请求的日志约5个包
        maxLength  = 10240;   --最大数据长度
        maxTime    = 10;      --最大缓存时间            
    };
    
    debug = true;		 --测试模式	 
    
--[[
    tls_config = {
        cert = module:load("certificate/server-cert.pem");
        key = module:load("certificate/server-key.pem");
        ca = module:load("certificate/server-key.pem");
    };
]]
    static_config = {
        {
            path = '/static/:path:';
            localpath = 'bundle://static';
        };
    };

    --websocket配置
    ws_port = 10060;     --监听端口
    --websocket路径与处理函数配置
	--path目录就是子游戏目录，会自动在app/games目录下进行加载
	--handle 不要修改
    ws_handle = {
        {path  = '/mud',            handle = 'bundle://app/userlink'};    
    };

	--游戏配置
	gameuser = 2;	--一桌游戏人数(当人数达到，自动开始)
    sub_gameid = 817; --子游戏id

    -- 保存玩家数据： true 存 DB，false 存本地文件
    user_data_readwriteDB = false;

	-- 机器人连接配置相关
	-- 游戏类型
    robot_gametype = 'tiaoyitiao';
	--机器人连接的内网地址
    robot_ws       = 'ws://127.0.0.1:10108/tiaoyitiao';
	--最长多少时间机器人进场(秒)(可以有小数)
    max_wait_time  = 3;  
    
    --redis服务器地址
    redis = {
		links = 1;
        ip    = '192.168.1.15';
        port  = 6381;
        --password = 'hellworld';
    };

    --业务代理服务器
    funproxy = {
		ip   = '127.0.0.1';
		port = 9999;
    };

}
