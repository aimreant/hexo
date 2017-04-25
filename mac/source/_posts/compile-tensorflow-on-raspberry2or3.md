title: 在树莓派2或3中编译谷歌深度学习框架TensorFlow
categories: 人工智能
tags: [RPi,TF]
date: 2016-10-15 05:59:00
---


*积尘多年的树莓派2B一直都是用于WEB打洞（ngrok+Wetty），一天突发奇想的煎鱼我，想结合最近研究的DL给树莓派点任务跑跑。然而，首先我得有一个树莓派的TF环境。*

## 需要做好的准备
- 树莓派2或3B
- 一张已经装好Raspbian的SD卡（推荐16G）
- 树莓派能联网（有的可能需要FQ）
- 一个外置U盘，用作SWAP（要无驱，不然你就得想怎么装驱动）
- 很多很多的折腾时间（心理准备哈哈）

<!-- more -->

## 梗概
本篇文章专门针对运行着Raspbian 8.0 (jessie)的树莓派3B。在树莓派2上应该是可行的，但可能会有一些小问题。（所有操作默认是root用户，权限问题请自行注意。）

按照计划，我们将会安装：

1. 32位的Protobuf
2. 对树莓派比较友好的Bazel
3. 用Bazel编译TensorFlow

## 编译

### 安装基本依赖
更新源：

```
apt-get update
```

Protobuf的依赖：

```
apt-get install autoconf automake libtool maven
```

Bazel的依赖：

```
apt-get install pkg-config zip g++ zlib1g-dev unzip
```

TensorFlow的依赖：

```
# 对于Python 2.7的
apt-get install python-pip python-numpy swig python-dev
pip install wheel

# 对于Python 3.3+的
apt-get install python3-pip python3-numpy swig python3-dev
pip3 install wheel
```

最后，为了你的文件能整洁点，建议你建一个文件夹来管理这次所用到的所有文件：

```
mkdir tf
cd tf
```

### 编译Protobuf
克隆Protobuf库：

```
git clone https://github.com/google/protobuf.git
```

然后进入文件夹，编译（这里需要花费一点时间）：

```
cd protobuf
git checkout d5fb408d
./autogen.sh
./configure --prefix=/usr
make -j 4
make install
```

注：autogen.sh脚本中有一段代码是为了下载google的gmock，若连不上或者网络太慢可以使用一下办法：

```
cd protobuf
git checkout d5fb408d
apt-get install google-gmock
autoreconf -f -i -Wall,no-obsolete
rm -rf autom4te.cache config.h.in~
./configure --prefix=/usr
make -j 4
make install
```

编译完成了之后，进入java文件用maven来建立项目：

```
cd java
mvn package
```

注：这次用maven慢也没啥办法了，国内的OSCHINA源好像是不做了
新注：找到了阿里云的源，速度快多了，在/etc/maven/settings.xml中的mirrors标签中添加：

```
  <mirror>
   <id>nexus-aliyun</id>
   <mirrorOf>central</mirrorOf>
   <name>Nexus aliyun</name>
   <url>http://maven.aliyun.com/nexus/content/groups/public</url>
  </mirror>
```

当你做完以上这些，你就会发现多了两个新文件：

- /usr/bin/protoc
- protobuf/java/core/target/protobuf-java-3.0.0-beta2.jar

### 编译Bazel
首先退出上两级，然后克隆Bazel库：

```
cd ../..
git clone https://github.com/bazelbuild/bazel.git
```

然后进入bazel文件夹并切换版本：

```
cd bazel
git checkout 0.2.1
```

将之前提出的生成的两个文件复制进来，注意名字（至于为啥是这样的名字，估计是不想改某些文件）

```
cp /usr/bin/protoc third_party/protobuf/protoc-linux-arm32.exe
cp ../protobuf/java/target/protobuf-java-3.0.0-beta-2.jar third_party/protobuf/protobuf-java-3.0.0-beta-1.jar
```

在编译Bazel之前，我们需要需要为这次编译设置javac的最大堆大小，否则我们会得到OutOfMemoryError错误。因此，我们需要修改一个小文件bazel/scripts/bootstrap/compile.sh：

```
vim scripts/bootstrap/compile.sh
```

去到128行，你会看见这样一段代码：

```
run "${JAVAC}" -classpath "${classpath}" -sourcepath "${sourcepath}" \
      -d "${output}/classes" -source "$JAVA_VERSION" -target "$JAVA_VERSION" \
      -encoding UTF-8 "@${paramfile}"
```

在这段代码的最后加上一个参数`-J-Xmx500M`，意思就是设置了Java最大堆大小为500M，修改后如下：

```
run "${JAVAC}" -classpath "${classpath}" -sourcepath "${sourcepath}" \
      -d "${output}/classes" -source "$JAVA_VERSION" -target "$JAVA_VERSION" \
      -encoding UTF-8 "@${paramfile}" -J-Xmx500M
```

然后让我们开始愉快地编译Bazel吧：

```
./compile.sh      
```

编译完成后移动可执行文件：

```
mkdir /usr/local/bin
cp output/bazel /usr/local/bin/bazel
```

然后先确认一下Bazel是否已经成功安装了，我们是运行一下，它应该会出现帮助信息的：

```
bazel

Usage: bazel <command> <options> ...

Available commands:
  analyze-profile     Analyzes build profile data.
  build               Builds the specified targets.
  canonicalize-flags  Canonicalizes a list of bazel options.
  clean               Removes output files and optionally stops the server.
  dump                Dumps the internal state of the bazel server process.
  fetch               Fetches external repositories that are prerequisites to the targets.
  help                Prints help for commands, or the index.
  info                Displays runtime info about the bazel server.
  mobile-install      Installs targets to mobile devices.
  query               Executes a dependency graph query.
  run                 Runs the specified target.
  shutdown            Stops the bazel server.
  test                Builds and runs the specified test targets.
  version             Prints version information for bazel.

Getting more help:
  bazel help <command>
                   Prints help and options for <command>.
  bazel help startup_options
                   Options for the JVM hosting bazel.
  bazel help target-syntax
                   Explains the syntax for specifying targets.
  bazel help info-keys
                   Displays a list of keys used by the info command.
```    

如果bazel命令没有问题，那我们就可以移动到上一级，继续下一步了：

```
cd ..
```

### 安装一个编译需要的SWAP
              
想要成功编译Tensorflow，树莓派需要更多的内存空间（原来就只有1G），因此我们需要建立一个SWAP空间来扩展一下运行内存，找一个1G以上的闲置U盘吧。

先插入你的U盘，找一下设备的路径`/dev/XXX`：

```
blkid
```

举个例子，我的U盘设备的路径是`/dev/sda1`。找到你的设备的路径后，卸载（推出）它而后格式化它：

```
umount /dev/XXX
mkswap /dev/XXX
```

现在我们需要查询那个U盘的SWAP分区的UUID：

```
blkid
```

用查询到的UUID修改/etc/fstab文件，这样做才可以加载U盘中的SWAP分区：

```
vim /etc/fstab
# 加入下面这行，替换XX文本
UUID=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX none swap sw,pri=5 0 0
```

保存文件后，运行一下命令以激活SWAP分区：

```
swapon -a
```

注：如果出错了，就试一下修改/etc/fstab，用`/dev/XXX`替换`UUID=XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX`：

```
/dev/XXX none swap sw,pri=5 0 0
```

好了，现在就已经加载了SWAP分区了，不过先别忘记你的`/dev/XXX`，迟点还要在卸载它的时候用上。

### 编译Tensorflow
终于到了这一步了，克隆tensorflow库然后进入，并执行替换：

```
git clone --recurse-submodules https://github.com/tensorflow/tensorflow
cd tensorflow
grep -Rl 'lib64'| xargs sed -i 's/lib64/lib/g'
```

而后我们需要删除`tensorflow/core/platform/platform.h`中特定的一行：

```
vim tensorflow/core/platform/platform.h
```

删除`#define IS_MOBILE_PLATFORM`：

```
#elif defined(__arm__)
#define PLATFORM_POSIX
...
#define IS_MOBILE_PLATFORM   <----- 删除这一行
```

以上这样做就是为了让tensorflow认为我们的树莓派是一个手机（TF有手机版本）

然后我们开始配置编译（终于用到之前的Bazel）：
注：如果是Python3的用户，请填写`/usr/bin/python3`

```
./configure

Please specify the location of python. [Default is /usr/bin/python]: /usr/bin/python
Do you wish to build TensorFlow with Google Cloud Platform support? [y/N] N
Do you wish to build TensorFlow with GPU support? [y/N] N
```

然后我们就正式开始编译Tensorflow了，**注意了，这要用很长很长很长很长的时间编译！**（n小时吧）。

```
bazel build -c opt --copt="-mfpu=neon" --local_resources 1024,1.0,1.0 --verbose_failures tensorflow/tools/pip_package:build_pip_package
```

注：以上这个编译语句只用了一个核，作者曾试过用4个核，但似乎会有锁。如果你想试试的话（你想怎么样都行，不关我事），可以修改一下参数（四核）：

```
bazel build -c opt --copt="-mfpu=neon" --local_resources 1024,4.0,1.0 --verbose_failures tensorflow/tools/pip_package:build_pip_package
```

当你第二天起床醒来看到编译完成了，是时候该用上编译出来的二进制可执行文件来生成一个Python wheel了：

```
bazel-bin/tensorflow/tools/pip_package/build_pip_package /tmp/tensorflow_pkg
```

然后用pip（3）来安装它：

```
pip install /tmp/tensorflow_pkg/tensorflow-0.9-cp27-none-linux_armv7l.whl
```

### 清理残局
是时候该关闭SWAP分区了，如果你已经不需要了：

```
swapoff /dev/XXX
```

然后在`/etc/fstab`中删除或注释掉之前你写出来的那一行，然后重启即可。

**嗯，终于完成了。**


[原文链接](https://github.com/samjabrahams/tensorflow-on-raspberry-pi/blob/master/GUIDE.md)
若有错误之处请指出，更多地关注[煎鱼](http://www.jianyujianyu.com)。









