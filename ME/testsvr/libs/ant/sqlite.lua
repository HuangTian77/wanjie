
local sqlite3 = require('sqlite3');
local DB  = require('core').Emitter:extend();

--初始化数据库
function DB:initialize(fn)
    local db;
    if fn == ':memory:' then 
        db = sqlite3.open_memory();
    else
	    db = sqlite3.open(fn);
    end
    self._db = db;			
end

--判断数据库是否已经打开
function DB:isOpen()
    return self._db ~= nil;
end

--关闭数据库
function DB:close()
	self._db:close();
    self._db = nil;
end

--执行sql语句
--支持两个格式，数组方式或者以分号隔开的方式
--exec({sql1, sql2, ...})
--exec("sql1;sql2;...")
function DB:exec(sql)
	local t = sql;
	if type(sql) == 'string' then
		t = {};
		for s in string.gmatch(sql, '([^;]+)') do
			table.insert(t, s);
		end
	end

	local lasterr;
	local n = 0;
	for k, s in ipairs(t) do		
		local r, msg = self._db:exec(s);		
		if r == sqlite3.OK then
			n = n + 1;
		else			
			msg = msg or self._db:errmsg();
			lasterr = msg;
			self:emit('error', r, msg, s);
		end
	end
	return n, lasterr;
end

--查询数据库
--针对有返回结果的sql执行语句
function DB:query(sql)
	return self._db:nrows(sql);
end

function DB:backup(fn)
	local db2 = sqlite3.open(fn);
	self._db:backup(db2);
	db2:close();
end

function DB:loadFrom(fn)
	local db2 = sqlite3.open(fn);
	if db2 == nil then return false end;
	
	db2:backup(self._db);
	db2:close();
	return true;
end

--只返回查询的第一行
function DB:query_one(sql)    
	local r = self._db:nrows(sql);
	return r and r[1];
end

--获得最后插入的ID
function DB:last_insert_rowid()
    return self._db:last_insert_rowid();
end

--打开文件数据库
local function open(fn)
    return DB:new(fn);
end

--打开内存数据库
local function openMemory()
    return DB:new(':memory:');
end

return {
    open = open;
    openMemory = openMemory;
}