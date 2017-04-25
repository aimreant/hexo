title: 在树莓派2上Nginx并发1W到底有多难
categories: Raspberry
tags: [后台,Raspberry,闲聊]
date: 2016-05-13 07:47:00
---


## 道听途说后的感想
总能得知Nginx的最大并发量能去到10W！简直吓到我，也不知道是我弱鸡还是我没弄过，反正10W的并发量我是没有弄过出来。不过嘛，说不定一台好CPU、大内存、高IO、高优化的服务器随便就可以上十万了，怎么说也是XEON的CPU然后来个几百几十G的内存是吧。那么在性能那么低的树莓派上并发量又能去到多少呢？网友总会说用树莓派当服务器还是算了吧，就这烂性能。这我也深有体会，在上面搭建的MC服务器简直没法玩啊！好吧，毕竟只是个值一两百块钱的板子而已：

- CPU：4核，性能大概只相当于196MHZ的i3（网友反映的）
- 内存：1G，简直不够用好吧！
- 硬盘IO：十几M每秒吧，其实就是SD卡的IO

你看看这性能：
1.根本不能指望SD的IO能干嘛，换句话来说，传统数据库的读写、SWAP的换出换入等和外存有关的都不能实现（这样会拖时间而且换入换出的时候CPU根本承受不了！）
2.因为上面的原因，几乎所有的东西都得堆在内存，1G的内存
3.CPU很low，超频了也不过是零点几、零点零几的提升，如果还不用多线程榨干它简直大逆不道

其实看到这配置估计就有很多人会说：欸，你这不是傻嘛，这么点可怜的性能怎么提升也不可能有什么效果的，还不如去用真·服务器去。其实我主要是不太想这个东西积尘了，也想折腾一下这方面的而已。

<!-- more -->

## 除掉Raspbian的限制

### 修改最大连接数 somaxconn
echo 50000 > /proc/sys/net/core/somaxconn
### 加快tcp连接的回收
echo 1 > /proc/sys/net/ipv4/tcp_tw_recycle

### tcp重用
echo 1 > /proc/sys/net/ipv4/tcp_tw_reuse 
### 修改成不做洪水抵遇
echo 0 > /proc/sys/net/ipv4/tcp_syncookies

### 修改系统的打开文件数的限制
ulimit -n 50000

直接用脚本一次性写入即可（毕竟我更喜欢做个懒人）
![](http://source.jianyujianyu.com/2016-05-13-14631237005719.jpg)

p.s.其实上面的那个50000是有点夸张而已，树莓派那么低的性能。。

当然还有很多各种各样的参数，我也不做详细解读，例如：
fs.file-max = 999999
net.ipv4.tcp_tw_reuse = 1
net.ipv4.tcp_keepalive_time = 600
net.ipv4.tcp_fin_timeout = 30
net.ipv4.tcp_max_tw_buckets = 5000
net.ipv4.ip_local_port_range = 1024    61000
net.ipv4.tcp_rmem = 4096 32768 262142
net.ipv4.tcp_wmem = 4096 32768 262142
net.core.netdev_max_backlog = 8096
net.core.rmem_default = 262144
net.core.wmem_default = 262144
net.core.rmem_max = 2097152
net.core.wmem_max = 2097152
net.ipv4.tcp_syncookies = 1
net.ipv4.tcp_max_syn.backlog=1024
参数值可以忽略。


## 修改Nginx的配置
这一步本来是最重要的，但是由于性能的原因，也就只能尽量了。

### 修改worker_processes并绑定CPU
尽量地多线程处理请求，并且在低性能CPU中一个worker绑定一个CPU，将切换worker的资源消耗最小化：
![](http://source.jianyujianyu.com/2016-05-13-14631243899899.jpg)


### 修改worker_rlimit_nofile配置
也就是修改nginx的最高打开文件数
### 修改worker_connections
修改Nginx的每个worker的最大连接数

![](http://source.jianyujianyu.com/2016-05-13-14631242372230.jpg)

### 负载均衡的上游服务器
开8个，用Python的Tornado（如果要连Tomcat的话，要自己调好参数，不然会拒绝大部分请求的，而且还有控制好tomcat不断飙升的占用内存，树莓派的1G承受不住！）
![](http://source.jianyujianyu.com/2016-05-13-14631246342501.jpg)


## 后台搭建
已经说过了用Python的Tornado做后台，直接就可以用它的demo中的blog来测试，选用blog原因如下：
- 具有前端模板的渲染
- 具有后台数据的提取
- 具有登录鉴权系统

这样的后台，虽然小并且简陋，但是与大部分实际应用相类似，因此选用。而且也特意不用缓存，这样子直接测它的性能。blog大概就是这个样子的：（其实挺丑的，测试数据请忽略）
![](http://source.jianyujianyu.com/2016-05-13-14631248722938.jpg)


## 使用ApacheBench测试
接下来就是使用ab测试了，而且是用树莓派本身来发出请求测试，这样可以忽略网络的作用（其实是因为我手头上没有linux设备，Mac测试浮动太大- -）。

ab -c 8000 -n 50000  http://127.0.0.1/
（根本不敢用1万的并发量好吧！）

结果如图：
![](http://source.jianyujianyu.com/2016-05-13-14631251132157.jpg)

可以看出来：
- 5万请求中有一千多的失败（对于这样的“服务器”已经很好了！！）
- 用时好慢
- 看到Processing和Waiting的时间直接人都崩溃了好吗

可以看得出来树莓派不能干这事（怎么感觉只是在自己打自己脸而已），别说1万，8000或者5000都难，所以就不要用树莓派来做服务器啦~（搭建集群的土豪请忽略）



若有错误之处请指出，更多地关注[煎鱼](http://www.jianyujianyu.com)。





