skynet_mongodb_sproto

自己写的一个服务端与客户端交互（sproto长连接）操作客户端的小demo

网关服务：服务端与客户端交互参考：云风skynet/examples的watchdog.lua agent.lua  

客户端参考 client.lua

config的path文档目录参考：云风skynet_sample  https://github.com/cloudwu/skynet_sample 也可以自己修改很简单的

我加了与mongodb交互的功能、也把sproto协议写出来了



其中有个有关watchdog的心跳包问题：

​		这里师傅跟我分析了一下，如果服务端每5s发心跳（云风的代码就是demo这样子写的），上万人的服务器是不是会炸掉呢？？ 所以这个心跳包的逻辑放客户端是不是更好一点？？