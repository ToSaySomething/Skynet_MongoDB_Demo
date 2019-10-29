skynet_mongodb_sproto

[代码地址](https://github.com/ToSaySomething/Skynet_MongoDB_Demo)
自己写的一个服务端与客户端交互（sproto长连接）操作客户端的小demo

1、网关服务：服务端与客户端交互参考：云风 skynet/examples的watchdog.lua agent.lua

2、客户端参考 client.lua

3、config 的 path文档目录参考：云风 [skynet_sample](https://github.com/cloudwu/skynet_sample)  也可以自己修改很简单的

4、我加了与mongodb交互的功能、也把sproto协议写出来了，主要的内容代码已注释
     mongodb的接口源码：mongo.lua 里面已经封装了bson decode 和 encode
（使用参考test/testmongodb.lua）

问题：其中有个有关watchdog的心跳包问题：
    这里师傅跟我分析了一下，如果服务端每5s发心跳（云风的代码就是demo这样子写的），上万人的服务器是不是会炸掉呢？？ 所以这个心跳包的逻辑放客户端是不是更好一点？？
    更好的框架参考：skynet_sample/src/service_package.c （这个是云风大佬写的新的，更好用）
