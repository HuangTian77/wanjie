local config = {};

--结束状态
local overStatus = {
    dataError = 1,
    sucess = 2,
    chessFull = 3,
};
config['overStatus'] = overStatus;

--桌子状态
local tableStatus = {
    onStartRoundReady = 5,      --开始 准备阶段
    onGame = 6,     --游戏中
    onGameEnd = 7,       --结束
};
config['tableStatus'] = tableStatus;

config['onReadyTimeOut'] = -1;
config['onRoundReadyTimeOut'] = -1;
config['onGameTimeOut'] = 180; --整局游戏时间
return config;