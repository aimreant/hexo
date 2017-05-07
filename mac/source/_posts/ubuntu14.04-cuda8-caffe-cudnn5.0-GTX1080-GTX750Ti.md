title: ubuntu14.04 + cuda8 + caffe + cudnn5.0 (GTX1080 + GTX750Ti)
categories: caffe
tags: [caffe]
date: 2017-03-10 03:15:59
---


*工作室的内网出了问题，不能修改以前写的文档，于是我便修改了放在个人网站*

## 版本
linux系统：Ubuntu 14.04.5 （64位）
显卡：GTX1080 + GTX750Ti
cuda: cuda_8.0.27_linux.run （传送门：https://developer.nvidia.com/cuda-toolkit）
显卡驱动：NVIDIA-Linux-x86_64-367.27.run （传送门：http://www.geforce.cn/drivers/results/104314）
cudnn：cudnn-5.1 ( for CUDA 8 rc) （传送门：https://developer.nvidia.com/cudnn）
BLAS：BLAS选用intel的MKL parallel_studio_xe_2016，或者Atlas

以下默认使用root用户，sudo已忽略

## 安装ubuntu：
**需要注意事项：**
ubuntu14.04默认开源驱动不兼容GTX1080，因此需要先拔掉GTX1080或将GTX750Ti置于PCI优先位置
在显示屏使用GTX750Ti的情况下，安装以及启动ubuntu

<!-- more -->

## 禁用nouveau驱动
按Ctrl+Alt+F1进入命令提示符,新建一个黑名单文件

`vim /etc/modprobe.d/blacklist-nouveau.conf`

输入

`blacklist nouveau options nouveau modset=0`

保存退出（:wq)
然后执行

`update-initramfs -u`

执行 `lspci | grep nouveau`查看是否有内容
如果没有内容 ，说明禁用成功，如果有内容，就重启一下再查看
`reboot`
重启后，进入登录界面的时候，不要登录进入桌面，直接按Ctrl+Alt+F1进入命令提示符。

## 安装CUDA和NVIDIA驱动
（目前使用最新的CUDA里面包含的NVIDIA驱动足矣）

`chmod 755 NVIDIA-Linux-x86_64-367.27.run  //获取权限 `
`./NVIDIA-Linux-x86_64-367.27.run  //安装驱动  `

安装后就可以用nvidia-smi命令查看显卡和驱动情况。

`chmod 755 cuda_8.0.27_linux.run  `
`./cuda_8.0.27_linux.run  `

PS：8.0.27可能已经过旧，请到官网下载最新版
需要注意该版本CUDA8中的NVIDIA驱动太旧，而且我们已经安装了，所以安装CUDA过程中唯有驱动不安装
除了第二项“”是否安装显卡驱动“选择no之外，其他全部按照默认设定
安装过程显示如下信息

```
Do you accept the previously read EULA?
accept/decline/quit: accept

Install NVIDIA Accelerated Graphics Driver for Linux-x86_64 361.62?
(y)es/(n)o/(q)uit: n

Install the CUDA 8.0 Toolkit?
(y)es/(n)o/(q)uit: y

Enter Toolkit Location
[ default is /usr/local/cuda-8.0 ]:

Do you want to install a symbolic link at /usr/local/cuda?
(y)es/(n)o/(q)uit: y

Install the CUDA 8.0 Samples?
(y)es/(n)o/(q)uit: y

Enter CUDA Samples Location
[ default is /home/zhou ]:

Installing the CUDA Toolkit in /usr/local/cuda-8.0 …
Missing recommended library: libGLU.so
Missing recommended library: libX11.so
Missing recommended library: libXi.so
Missing recommended library: libXmu.so

Installing the CUDA Samples in /root …
Copying samples to /root/NVIDIA_CUDA-8.0_Samples now…
Finished copying samples.
.
.
.
```

设置环境变量
（error while loading shared libraries: xxx.so.x" 错误的原因和解决办法）

`vim /etc/profile  `
加上两句

```
export PATH=/usr/local/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/lib64:$LD_LIBRARY_PATH
```

`vim /etc/ld.so.conf.d/cuda.conf`
中添加
`/usr/local/cuda/lib64`

执行`ldconfig  `

## make CUDA库
安装依赖：

```
apt-get install freeglut3-dev build-essential libx11-dev libxmu-dev libxi-dev  libglu1-mesa libglu1-mesa-dev libgl1-mesa-glx
cd /usr/local/cuda/samples
make all -j8
```

以上的make编译时为了测试cuda库和环境安装成功并编译玩一下。

`cd ./bin/x86_64/linux/release`
`./deviceQuery `    查询显卡信息

![](https://oda3wj69k.qnssl.com/Cache_3fb1040ea54e9bed..jpg)

## 安装CUDNN5.0

解压好CUDNN得到cuda目录

```
cd cuda
sudo cp lib64/lib* /usr/local/cuda/lib64/
sudo cp include/cudnn.h /usr/local/cuda/include/
cd /usr/local/cuda/lib64/
sudo chmod +r libcudnn.so.5.0.5
sudo ln -sf libcudnn.so.5.0.5 libcudnn.so.5
sudo ln -sf libcudnn.so.5 libcudnn.so
sudo ldconfig
```


## 安装OPENCV
推荐安装pyenv来管理python版本环境（自行查找）

提前安装libegl的库，免得安装到一并报错：
`apt install libegl1-mesa libegl1-mesa-drivers`

参考https://github.com/jayrambhia/Install-OpenCV一键安装opencv

## 编译安装Caffe

### 安装依赖：
```
apt-get install libprotobuf-dev libleveldb-dev libsnappy-dev libopencv-dev libhdf5-serial-dev protobuf-compiler libatlas-base-dev libgflags-dev libgoogle-glog-dev  liblmdb-dev  libboost-all-dev
```

### 如果不用mkl，而是用atlas，则安装:

```
apt-get install libatlas-dev libatlas-base-dev
```

### 所有python依赖:（按照不同情况自行查看关系安装）

```
apt-get install python-dev python-pip cython python-numpy python-scipy python-opencv
```

### 在github上clone Caffe： https://github.com/BVLC/caffe
进入其目录，并按照实际修改Makefile.config，主要是启用CUDNN，改用MKL（如果安装了），然后编译：

```
git clone https://github.com/BVLC/caffe
cd caffe
make all -j8
make test -j8
make runtest -j8
```

PS：j后面的8表示启用多少线程来编译，视性能而定

如果还需要使用pycaffe：需要对pycaffe进行编译：

`make pycaffe -j8`

而后进入python目录，用pip安装依赖：

```
apt-get install python-pip
cd python
pip install -r requirements.txt
```

顺手把graphviz也安装了：

```
apt-get install graphviz graphviz-dev
pip install pydot
pip install pygraphviz
```

最后添加pythonpath的环境变量：
`vim /etc/profile`
添加`export PYTHONPATH=/root/caffe/python:$PYTHONPATH  # path to pytho in caffe`
然后执行 `source /etc/profile`


若有错误之处请指出，更多地关注[煎鱼](http://www.jianyujianyu.com)。



