
require('luvit');

-- 为了加载打包在一起的页面相关文件
if global_debug then
	require('init')({'.', 'ui.pkg'});
else
	require('init')({'.', 'func.spk', 'ui.pkg'});
end
------------------------------------

require('mfc');
mfc.init('main');

function errormsg(msg)
	print(debug.traceback(string.format('%s 脚本错误: %s', os.date('%Y%m%d %H:%M:%S'),msg)));
end

local luvi = require('luvi');
_G.process = require('process').globalProcess();

local uv = require('uv');
mfc.set_loop_func(function()
		uv.run('nowait');
	end);

--不同同时启动两个客户端
local win32process = require('win32process');
local fn  = string.lower(uv.exepath());
local pid = win32process.currentPID();
for id, v in pairs(win32process.enumProcess()) do
	if  pid ~= id and v == fn then
		return;
	end
end
---------------

--定时垃圾收集
--初始化逻辑代码目录
require('./app');

--初始化界面相关的全局信息
require('bundle://res/uiinit');

SetInfo('title', 'MUD游戏编辑工具');
--如果需要登录的话，在这里添加登录窗口

--主界面
local fn = 'bundle://loader/main.html';
mfc.NewWindow(fn, false);
mfc.loop();

local uv = require('uv');
uv.stop();
uv.run('once');
