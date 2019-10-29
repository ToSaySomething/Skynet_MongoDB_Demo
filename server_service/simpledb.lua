local skynet = require "skynet"
require "skynet.manager"	-- import skynet.register
local mongo = require "mongo" 
local bsonlib = require "bson" 

local M = {}

local db_client 
local db 

function M.start(conf)
	db_client = mongo.client(conf)
	db_client:getDB(conf.db_name)
	db = db_client[conf.db_name]
end

function M.findone(name, ...)
	skynet.error("-- mongo findone -- ")
	return true, db[name]:findOne(...)
end

function M.find(name, query, selector)
	skynet.error("-- mongo find -- ")
	return true,db[name]:find(query, selector)
end

function M.update(name, ...)
	skynet.error("-- mongo update -- ")
	local collection = db[name]
	collection:update(...)
    local r = db:runCommand("getLastError")
	if r.err ~= bsonlib.null then
		return false, r.err	
	end
	if r.n <= 0 then
        skynet.error("mongodb update "..name.." failed")
	end
	return true, r.err
end

function M.insert(name, ...)
	skynet.error("-- mongo insert -- ")
	local collection = db[name]
	collection:safe_insert(...)
    local r = db:runCommand("getLastError")
	local ok = r and r.ok == 1 and r.err == bsonlib.null
        if not ok then
            skynet.error(v.." failed: ", r.err, name)
    end
    return ok, r.err
end

function M.delete(name, ...)
	skynet.error("-- mongo delete -- ")
	local collection = db[name]
	collection:delete(...)
    local r = db:runCommand("getLastError")
	local ok = r and r.ok == 1 and r.err == bsonlib.null
        if not ok then
            skynet.error(v.." failed: ", r.err, name, ...)
    end
    return ok, r.err
end

skynet.start(function()
	skynet.dispatch("lua", function(session, address, cmd, ...)
		local f = M[cmd]
		assert(f)
		skynet.error(f)
		if session == 0 then
			f(...)
		else
			skynet.ret(skynet.pack(f(...)))
		end
	end)
	skynet.register "simpledb"
end)
