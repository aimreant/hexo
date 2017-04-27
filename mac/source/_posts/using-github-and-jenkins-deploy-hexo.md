title: [小题大做] Github + Jenkins 实现自动化部署 hexo 博客静态文件
categories: CI
tags: [jenkins,hexo,blog]
date: 2017-04-27 09:49:38
---

*使用jenkins来部署hexo简直就是小题大做，但是偶尔这样小题大做还真有折腾的乐趣*



## 背景

[jianyujianyu.com](https://www.jianyujianyu.com)之前是使用typecho做博客的。

原因很简单，wordpress太重，hexo很轻没错，可是这个没有后台管理（听说可以折腾成有后台管理的），每次写完博客都要deploy一下的hexo，我真心要不起。

而现在[jianyujianyu.com](https://www.jianyujianyu.com)是hexo了，经过也很简单，就是因为CA证书过期了，换证书的时候弄砸了，本着顺便过滤一波辣鸡博客的心思，重新弄，这次选择了hexo，不为什么，人生的选择就是这么奇妙。

那怎么不自己手写一个？说得好！不过我才不要。

用hexo不是不行，是要考虑deploy的事，或者，我换台电脑写博客，我没有这个hexo的node环境，我也不想登录服务器用着vim来写，比如我现在就安静在公司电脑上写博客。在这样的情况下，怎么deploy呢？在从前，wordpress和typecho有着后台管理，这个问题根本是不存在的。

想着想着，一拍脑袋，就直接用jenkins了，然后把代码放在github，包括hexo的整个文件夹。至于为啥用github而不用coding甚至是github pages，never mind。

设计的deploy过程很简单：

- 我先clone了github上的hexo文件夹，添加了md文章，然后push
- github整理好代码就通知jenkins：我这里资源更新了，大爷快来玩啊
- jenkins收到消息，兽性大发地下了github上的代码
- 拥有hexo环境的jenkins直接执行hexo g，产生了分泌物，也就是静态文件，在这里就是[jianyujianyu.com](https://www.jianyujianyu.com)的html网页内容（hexo/public）
- 待定的nginx直接将用户请求拉向[jianyujianyu.com](https://www.jianyujianyu.com)的hexo/public文件夹即可

简单地设计完，便是动手开始。

<!-- more -->



## 环境准备

*所有操作都是在Ubuntu的root用户下进行的，其他环境自行处理或转换*

### Java、Tomcat和Jenkins

jenkins是java的美好产物，为了后面调试起来简单，使用tomcat容器来装着这产物，而不是直接用apt下载。

（如果为了快捷，也可以只下载java和jenkins，然后通过`java -jar jenkins.war`来运行。不推荐。）

因此我们首先安装J8。

```
add-apt-repository ppa:webupd8team/java
apt update
apt install oracle-java8-installer
```

之后是安装tomcat。对应着J8，选tomcat8。先去[tomcat官网](http://tomcat.apache.org/)下载包，然后解压。

```
wget http://apache.mirror.rafal.ca/tomcat/tomcat-8/v8.5.14/bin/apache-tomcat-8.5.14.tar.gz
tar zxvf apache-tomcat-8.5.14.tar.gz
```

接着是上[jenkins官网](jenkins.io)下载jenkins的war包。

```
wget http://ftp-chi.osuosl.org/pub/jenkins/war-stable/2.46.1/jenkins.war
```

war包就放在tomcat文件夹的webroot下即可。

然后启动tomcat，进入tomcat文件夹的bin下，启动：

```
./startup.sh
```

接下来就可以尝试通过网页登录tomcat以及jenkins了。在浏览器中打开http://服务器的ip:8080，

![tomcat主页](https://oda3wj69k.qnssl.com/BaiduHi_2017-4-25_19-45-36.png)

然后打开http://服务器的ip:8080/jenkins，根据知识安装jenkins环境，安装推荐环境即可，不需要自己选择，因为推荐环境已经包含了我们需要的插件。***如果要nginx反向代理tomcat，推荐先做完后面nginx的反向代理再安装jenkins***。

按照提示输入password，然后选择推荐安装：

![](https://oda3wj69k.qnssl.com/BaiduHi_2017-4-26_11-23-43.png)

![](https://oda3wj69k.qnssl.com/BaiduHi_2017-4-26_11-28-19.png)

正在安装，要等一下

![](https://oda3wj69k.qnssl.com/BaiduHi_2017-4-26_11-28-30.png)

账号密码以及权限的事自行考虑

![](https://oda3wj69k.qnssl.com/BaiduHi_2017-4-26_12-20-38.png)



### Nodejs、NPM和hexo

hexo是nodejs的产物，因此搭建nodejs环境是必须的。而安装nodejs推荐在[官网](https://nodejs.org/en/)上下载源码编译，不然apt得到的都是旧的，没办法，node这两年发展得太快了。

```
wget https://nodejs.org/dist/v6.10.2/node-v6.10.2.tar.gz
tar zxvf node-v6.10.2.tar.gz
cd node-v6.10.2
./configure
make
make install
```

make可自行通过参数-j来加速编译。

安装好了node，npm也接着来了，如果在安装过程中觉得npm下载太慢可以是用[淘宝镜像](http://npm.taobao.org/)，使用方法自行查询。

然后照着[hexo官方文档](https://hexo.io/docs/)的方法安装hexo已经相关环境

```
npm install hexo-cli -g
hexo init hexo
cd hexo
npm install
```

hexo的命令很简单，有了hexo的环境之后可以通过命令生成静态文件或者启动临时服务器：

```
hexo g # generate static file
hexo s # start a server
```

在生成静态文件后，将nginx配置到hexo/public下面，请求即可到达；在启动hexo临时服务器后，即可访问http://服务器的ip:4000/jenkins。

至此，hexo环境已经是完成了。

如果说还有什么需要在这一步做的话， 那应该就是将代码push到git上，这个事我就不多说了。



### Nginx

安装nginx十分简单，但是在这次的实验中，nginx地位也不算低，80或者443端口要配置到hexo/public下，最好还要给tomcat配置反向代理。在以后的安全和优化方面，nginx需要配置的也不少。

安装nginx也就一句

```
apt install nginx
```

然后便是对配置的修改（我直接改default配置文件，别的方法自行实施）

```
vim /etc/nginx/sites-available/default
```

在开放80或者443的端口的server里面配置好root，例：

```
root /var/www/hexo/public;
```

推荐给tomcat上个反向代理，

```
upstream tomcat  {
        server  127.0.0.1:8080;
}

server {
        listen 11111;
        listen [::]:11111;

        location / {
                #try_files $uri $uri/ =404;
                proxy_pass   http://tomcat;
                proxy_redirect  off;
                proxy_set_header Host $host:$server_port;
                proxy_set_header X-Real-IP $remote_addr;
                proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                proxy_set_header Request-Url $request_uri;
        }
}
```

以上需要注意的是proxy_set_header需要配置好，不然后面可能无法跳转到对的路径。



## 配置Github和Jenkins

### 创建job

![创建job](https://oda3wj69k.qnssl.com/Screen%20Shot%202017-04-25%20at%2010.43.29%20PM.png)

点击create new jobs，选择freestyle，填好job名字。

![选择freestyle](https://oda3wj69k.qnssl.com/Screen%20Shot%202017-04-25%20at%2010.44.11%20PM.png)

创建了job以后，jenkins紧接着就是让你配置jenkins，如果这次不配置也没什么，因为创建的job已经保存好了。



### 配置密钥

如果我在github上的代码库是私密的而不是公开的，那么jenkins想要拉取到我的代码必须要有相应的私钥。至于哪一台机上的公钥私钥没什么所谓，重要的是github上有一台机的公钥，而jenkins上应该也有这台机的私钥。当然前提是github上的代码库是私密的，公开的无所谓。

先在Jenkins添加私钥。

![创建一个证书](https://oda3wj69k.qnssl.com/Screen%20Shot%202017-04-25%20at%2010.48.36%20PM.png)

![](https://oda3wj69k.qnssl.com/Screen%20Shot%202017-04-25%20at%2010.48.56%20PM.png)

![填入git平台的公钥对应的私钥](https://oda3wj69k.qnssl.com/Screen%20Shot%202017-04-25%20at%2010.52.30%20PM.png)

查出private key往上填就行，为了保密我就不填真实username了。至于怎么生成key，自行查找ssh-keygen命令，或者参考类似[Github的文档](https://help.github.com/articles/connecting-to-github-with-ssh/)。



### 配置WebHook

配置webhook是在github上完成的。webhook的存在意义就是github上发生了特定事件，然后会告诉请求jenkins，以便让jenkins去拉代码进行下一步操作。

例如，现在要配置的，就是每次将代码push上去后，就触发jenkins的操作。

![](https://oda3wj69k.qnssl.com/BaiduHi_2017-4-26_10-29-15.png)

打码处理。

![](https://oda3wj69k.qnssl.com/BaiduHi_2017-4-26_10-33-0.png)



### 配置job

之前的环境都搭建好了，配置刚才创建的job就是关键的一步了。

首先是要配置github project

![](https://oda3wj69k.qnssl.com/Screen%20Shot%202017-04-26%20at%2011.49.16%20PM.png)

而在源码管理里面，必须要填一个可行的、同时有权限的配置，失败则如下图，必须做到没有错误提醒

![](https://oda3wj69k.qnssl.com/Screen%20Shot%202017-04-26%20at%2011.53.25%20PM.png)

browser也顺便一填

![](https://oda3wj69k.qnssl.com/Screen%20Shot%202017-04-26%20at%2011.53.34%20PM.png)

而在Build Triggers里面必须要选Github hook trigger，勾选了jenkins才会接受github发来的请求

![](https://oda3wj69k.qnssl.com/Screen%20Shot%202017-04-26%20at%2011.49.53%20PM.png)

最后在Build，也就是构建的这部分，也填上，推荐使用shell，毕竟现在玩这些都是linux了

![](https://oda3wj69k.qnssl.com/Screen%20Shot%202017-04-26%20at%2011.51.15%20PM.png)

选择shell后，可以在文本框里面填自己部署要用到的命令，如下面的例子，cd、删除、拷贝等命令都可以。

需要注意的是，某些命令没有，这个可以通过不断的测试来检验。

![](https://oda3wj69k.qnssl.com/Screen%20Shot%202017-04-26%20at%2011.52.21%20PM.png)

至此已经配置好了jenkins上的job，接下来就是调试了。



## 调试

调试很简单。先把代码clone下来本地，然后稍稍改动一个无关文件，再push，之后便是感受是否这套环境是否能自动化部署。

![](https://oda3wj69k.qnssl.com/Screen%20Shot%202017-04-27%20at%2012.11.57%20AM.png)

push成功后，github hook会通知所填写的jenkins，如果jenkins没有调起job，则有可能是hook或者配置job里面的Github hook trigger没有填写正确。

如果是成功调起，在jenkins的hexo的job页面，左下角会看到有类似`#1`的

![](https://oda3wj69k.qnssl.com/Screen%20Shot%202017-04-27%20at%2012.12.20%20AM.png)

想要查看错误日志，点击左上角的Github Hook Log或者Console Output，即可根据这些日志对配置进行调整。

![](https://oda3wj69k.qnssl.com/Screen%20Shot%202017-04-27%20at%2012.12.57%20AM.png)



若有错误之处请指出，更多地关注[煎鱼](http://www.jianyujianyu.com)。