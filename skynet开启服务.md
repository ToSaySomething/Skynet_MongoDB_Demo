# **skynet 开始创建服务的流程**

## 一、skynet 中 main 的 start()

->main.lua

```lua
skynet.start(function()
    ...newservice()
...end)
```

–>  [ skynet_start.c ]  

```c
void 
skynet_start(struct skynet_config * config) {
    ....
    bootstrap(ctx, config->bootstrap);  // 启动bootstrap服务
    ...
}
```

​	一般默认，config->bootstrap项就是snlua bootstrap

## 二、newservice() 创建一个服务

–>  [ skynet.lua ]   --  **.launcher** 一个服务

```lua
function skynet.newservice(name, ...)
	return skynet.call(".launcher", "lua" , "LAUNCH", "snlua", name, ...)
end
```

–>  [ bootstrap.lua入口函数 ] 

```lua
local launcher = assert(skynet.launch("snlua","launcher")) skynet.name(".launcher", launcher)
```

–> [ manager.lua ] 

```lua
local c = require "skynet.core"
function skynet.launch(...)
	local addr = c.command("LAUNCH", table.concat({...}," "))
 .....
```

–> [ lua_skynet.c ] 

```c
lcommand(lua_State *L) {
    .....
    result = skynet_command(context, cmd, parm); 
    //  cmd应该是LAUNCH , parm应该是 snlua launcher
}
```

–> [ skynet_server.c ]

（1）skynet_command -》cmd_launch 

```c
static struct command_func cmd_funcs[] = {
	{ "LAUNCH", cmd_launch },
	...
	{ NULL, NULL },
};

const char * 
skynet_command(struct skynet_context * context, const char * cmd , const char * param) {
	struct command_func * method = &cmd_funcs[0];
	while(method->name) {
		if (strcmp(cmd, method->name) == 0) {
			return method->func(context, param);
		}
		++method;
	}
	return NULL;
}
```

（2）进入 cmd_launch 

```c
static const char *
cmd_launch(struct skynet_context * context, const char * param) {
	size_t sz = strlen(param);
	char tmp[sz+1];
	strcpy(tmp,param);
	char * args = tmp;
	char * mod = strsep(&args, " \t\r\n");
	args = strsep(&args, "\r\n");
	struct skynet_context * inst = skynet_context_new(mod,args);
	if (inst == NULL) {
		return NULL;
	} else {
		id_to_hex(context->result, inst->handle);
		return context->result;
	}
}
```

（3）skynet_context_new (mod,args);  

​	mod是snlua，args是“snlua launcher”，根据这个参数构造一个skynet_context 出来

```c
struct skynet_context * 
skynet_context_new(const char * name, const char *param) {
    struct skynet_module * mod = skynet_module_query(name); //① 获得snlua模块
    ..... // 创建消息队列等等
    void *inst = skynet_module_instance_create(mod); // ② 创建服务
    ....
    int r = skynet_module_instance_init(mod, inst, ctx, param); // ③ 初始化snlua
    ...
}
```

--> service.snlua.c

​	先看一下结构

```c
struct snlua {
    lua_State * L;
    struct skynet_context * ctx;
    size_t mem;
    size_t mem_report;
    size_t mem_limit;
};
```

​	语句①：获得snlua模块创建实例 snlua_create

```c
struct snlua *
snlua_create(void) {
    struct snlua * l = skynet_malloc(sizeof(*l));
    memset(l,0,sizeof(*l));
    l->mem_report = MEMORY_WARNING_REPORT;
    l->mem_limit = 0;
    l->L = lua_newstate(lalloc, l);
    return l;
}
```

​	语句③：初始化snlua 其实就是 snlua_init

```c
int
snlua_init(struct snlua *l, struct skynet_context *ctx, const char * args) {
    int sz = strlen(args);
    char * tmp = skynet_malloc(sz);
    memcpy(tmp, args, sz);
    skynet_callback(ctx, l , launch_cb); //回调
    const char * self = skynet_command(ctx, "REG", NULL);
    uint32_t handle_id = strtoul(self+1, NULL, 16);
    // it must be first message
    skynet_send(ctx, 0, handle_id, PTYPE_TAG_DONTCOPY,0, tmp, sz);
    return 0;
}
```

​	设置了当前模块的callback为 launch_cb，之后skynet_send消息，将由launch_cb处理

```c
static int
launch_cb(struct skynet_context * context, void *ud, int type, int session, uint32_t source , const void * msg, size_t sz) {
    assert(type == 0 && session == 0);
    struct snlua *l = ud;
    skynet_callback(context, NULL, NULL);
    int err = init_cb(l, context, msg, sz); //回调给lua层
    if (err) {
        skynet_command(context, "EXIT", NULL);
    }

    return 0;
}
```

​	launch_cb重置了服务的回调callback ，调用init_cb

```c
static int
init_cb(struct snlua *l, struct skynet_context *ctx, const char * args, size_t sz) {
    .... // 设置各种路径、栈数据
    const char * loader = optstring(ctx, "lualoader", "./lualib/loader.lua");
    int r = luaL_loadfile(L,loader);
    if (r != LUA_OK) {
        skynet_error(ctx, "Can't load %s : %s", loader, lua_tostring(L, -1));
        report_launcher_error(ctx);
        return 1;
    }
    lua_pushlstring(L, args, sz);
    r = lua_pcall(L,1,0,1); // 回调给lua层
    ....
}
```

--> skynet.lua

```lua
function skynet.start(start_func)
    c.callback(skynet.dispatch_message) --回调信息返回在这
    skynet.timeout(0, function()
        skynet.init_service(start_func)
    end)
end
```

​	即 启动了这个服务，即，这个服务挂载到消息队列（skynet_context的mq）里面 等待 消息的处理。