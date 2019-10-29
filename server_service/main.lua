local skynet = require "skynet"

skynet.start(function()
    skynet.error("Server start")  -- log
	if not skynet.getenv "daemon" then
		local console = skynet.newservice("console")
	end
	skynet.newservice("debug_console",8000)  -- 启动新服务

	local proto = skynet.uniqueservice "protoloader"  -- 启动一个唯一服务
	skynet.call(proto, "lua", "load", {
		"proto.c2s",
		"proto.s2c",
    })

	local db_service = skynet.newservice("simpledb")
	skynet.call(db_service, "lua", "start",{
		host = skynet.getenv("mongo_host"),
		db_name = skynet.getenv("db_name"),
	})


	local watchdog = skynet.newservice("watchdog")
	skynet.call(watchdog, "lua", "start", {
			port = 8888,
			maxclient = max_client,
			nodelay = true,
	})
	skynet.error("Watchdog listen on", 8888)
	skynet.exit()
end)
