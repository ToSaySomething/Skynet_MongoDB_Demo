local PATH,IP = ...

IP = IP or "127.0.0.1"

package.cpath = "../skynet/luaclib/?.so"
package.path = "../skynet/lualib/?.lua;../skynet/examples/?.lua"

if _VERSION ~= "Lua 5.3" then
	error "Use lua 5.3"
end

local socket = require "clientsocket"
local proto = require "proto"
local sproto = require "sproto"

local fd = assert(socket.connect("127.0.0.1", 8888))
local host
local request

local function register(name)
	local f = assert(io.open(name .. ".s2c.sproto"))  -- 客户端的协议文件
	local t = f:read "a"
	f:close()
	host = sproto.parse(t):host "package"      -- host 用来解析读取的数据
	local f = assert(io.open(name .. ".c2s.sproto")) -- 服务端的协议文件
	local t = f:read "a"
	f:close()
	request = host:attach(sproto.parse(t)) --
end

local function send_package(fd, pack)
	local package = string.pack(">s2", pack)
	socket.send(fd, package)
end

local function unpack_package(text)
	local size = #text
	if size < 2 then
		return nil, text
	end
	local s = text:byte(1) * 256 + text:byte(2)
	if size < s+2 then
		return nil, text
	end

	return text:sub(3,2+s), text:sub(3+s)
end

local function recv_package(last)
	local result
	result, last = unpack_package(last)
	if result then
		return result, last
	end
	local r = socket.recv(fd)
	if not r then
		return nil, last
	end
	if r == "" then
		error "Server closed"
	end
	return unpack_package(last .. r)
end

local session = 0

local function send_request(name, args)
	session = session + 1
	local str = request(name, args, session)
	send_package(fd, str)
	print("Request:", session)
end

local last = ""

local function print_request(name, args)
	print("REQUEST", name)
	if args then
		for k,v in pairs(args) do
			print(k,v)
		end
	end
end

local function print_response(session, args)
	print("RESPONSE", session)
	if args then
		for k,v in pairs(args) do
			print(k,v)
		end
	end
end

local function print_package(t, ...)
	if t == "REQUEST" then
		print_request(...)
	else
		assert(t == "RESPONSE")
		print_response(...)
	end
end

local function dispatch_package() -- 每次记录最后一次心跳
	while true do
		local v
		v, last = recv_package(last) 
		if not v then
			break
		end

		print_package(host:dispatch(v))
	end
end

-- 主逻辑
register(string.format("../proto/%s", "proto"))
while true do
	dispatch_package() -- 接受服务端的心跳包保证不断开
	local cmd = socket.readstdin()
	if cmd then
		if cmd == "quit" then
			send_request("quit")
		end
		if cmd == "in" then
			print ("| insert | :  admin, 123456")
			send_request("insert", { id = "admin",pass = "12345" })
--			print ("| insert | :  root, 123456")
--			send_request("insert", { id = "admin",pass = "12345" })
		end
		if cmd == "find" then
			print ("| findone | :  admin")
			send_request("findone", { id = "admin"})
		end
		if cmd == "de" then
			print ("| delete | :  admin")
			send_request("delete", { id = "admin"})
		end
		if cmd == "update" then
			print ("| update | :  admin admin")
			send_request("update", { id = "admin",pass = "admin"})
		end
	else
		socket.usleep(100)
	end
end
