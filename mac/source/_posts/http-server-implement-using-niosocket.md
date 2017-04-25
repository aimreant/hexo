title: 使用NioSocket手动实现HTTP服务器
categories: Java
tags: [java,niosocket]
date: 2017-01-14 19:37:00
---

## NioSocket简单复习

### 重要概念
NioSocket里面的三个重要概念：Buffer、Channel、Selector

- Buffer为要传输的数据
- Channel为传输数据的通道
- Selector为通道的分配调度者

<!-- more -->

### 使用步骤
使用NioSocket实现通信大概如以下步骤：

1. ServerSocketChannel可以通过configureBlocking方法来设置是否采用阻塞模式，设置为false后就可以调用register注册Selector，阻塞模式下不可以用Selector。
2. 注册后，Selector就可以通过select()来等待请求，通过参数设置等待时长，若传入参数0或者不传入参数，将会采用阻塞模式直到有请求出现。
3. 接收到请求后Selector调用selectedKeys方法，返回SelectedKey集合。
4. SelectedKey保存了处理当前请求的Channel和Selector，并提供了不同的操作类型。四种操作属性：SelectedKey.OP_ACCEPT、SelectedKey.OP_CONNECT、SelectedKey.OP_READ、SelectedKey.OP_WRITE。
5. 通过SelectedKey的isAcceptable、isConnectable、isReadable和isWritable来判断操作类型，并处理相应操作。
6. 在相应的Handler中提取SelectedKey中的Channel和Buffer信息并执行相应操作。

## 实现HTTP
### 创建HttpServer类作为程序的主要入口

```java
public class HttpServer {
    public static void main(String[] args) throws Exception{
        ServerSocketChannel serverSocketChannel = ServerSocketChannel.open();
        serverSocketChannel.socket().bind(new InetSocketAddress((8080)));
        serverSocketChannel.configureBlocking(false);

        Selector selector = Selector.open();

        // It must be ACCEPT, or it will throw exception
        serverSocketChannel.register(selector, SelectionKey.OP_ACCEPT);

        while(true){
            if (selector.select(3000) == 0){
                continue;
            }

            Iterator<SelectionKey> keyIter = selector.selectedKeys().iterator();

            while (keyIter.hasNext()){
                SelectionKey key = keyIter.next();
                new Thread(new HttpHandler(key)).run();
                keyIter.remove();
            }
        }
    }
}
```

以上代码的逻辑大致遵循着NioSocket的大概用法，其中serverSocketChannel使用register方法注册到selector仅是OP_ACCEPT，使用其他操作就会操作。但是并不是说不能进行其他操作，而是其他操作稍后实现。

在serverSocketChannel.configureBlocking(false)后，非阻塞模式启动。Server接收到请求后就会将记录了请求信息的key交给HttpHandler做详细处理，处理完就把key从迭代器里面remove掉。可以看到出来，HttpServer对请求里面的信息一概不知，这样才能成为一个出色的管理层，它管理着HttpHandler来处理请求。

既然选用了NioSocket这样的New IO，HttpHandler必然是多线程的实现（否则还有什么意义）。

### 创建HttpHandler来处理请求

对于来自HttpServer的不加工信息，HttpHandler必须要做全套，因此需要HttpHandler自己考虑好有没有中文乱码、Buffer大小是多少等等。HttpHandler大概框架如下即可：

```java
class HttpHandler implements Runnable{
    private int bufferSize = 1024;
    private String localCharset = "UTF-8";
    private SelectionKey key;

    public HttpHandler(SelectionKey key){
        this.key = key;
    }

    public void handleAccept() throws IOException{}

    public void handleRead() throws IOException{}

    @Override
    public void run() {
        try {
            if(key.isAcceptable()){
                handleAccept();
            }
            if(key.isReadable()){
                handleRead();
            }
        }catch (IOException ex){
            ex.printStackTrace();
        }
    }
}
```

如上框架简单明了，重载run实现多线程，handleAccept和handleRead用于详细地处理相关操作，bufferSize规定Buffer大小，localCharset的设定提前防止中文乱码。

需要注意的是HttpServer里面，我们只注册了OP_ACCEPT这个操作，那么在HttpHandler里面只有isAcceptable()判定为真，那么handleRead()怎么办呢？我们会在handleAccept()注册好的：

```java
	public void handleAccept() throws IOException{
        SocketChannel clientChannel =
        		((ServerSocketChannel)key.channel()).accept();
        clientChannel.configureBlocking(false);
        clientChannel.register(
        		key.selector(), SelectionKey.OP_READ, ByteBuffer.allocate(bufferSize)
        	);
    }
```

在handleAccept里面，我们先取得key里面的请求信息，如对应客户端的SocketChannel （SocketChannel需要ServerSocketChannel接受了后才有），接着就可以为SocketChannel注册OP_READ操作了，带上指定大小的Buffer。注册后，key可是isReadable()了，接下来则是在handleRead中对key进行解剖处理：（代码有点长，但大多是控制台输出和对字符串的拼接操作，看官可放心食用。）

```java
	public void handleRead() throws IOException{
        SocketChannel sc = (SocketChannel)key.channel();
        ByteBuffer buffer = (ByteBuffer)key.attachment();
        buffer.clear();

        if (sc.read(buffer) == -1){
            sc.close();
        }else {
            buffer.flip();
            String receiveString = Charset.forName(localCharset).newDecoder().decode(buffer).toString();

            String[] requestMessage = receiveString.split("\r\n");
            for (String s: requestMessage){
                System.out.println(s);
                if (s.isEmpty()){
                    break;
                }
            }

            String[] firstLine = requestMessage[0].split(" ");
            System.out.println();
            System.out.println("Method:\t"+ firstLine[0]);
            System.out.println("url:\t"+firstLine[1]);
            System.out.println("HTTP Version:\t" + firstLine[2]);
            System.out.println();

            StringBuilder sendString = new StringBuilder();
            sendString.append("HTTP/1.1 200 OK\r\n");
            sendString.append("Content-Type:text/html;Charset="+localCharset+"\r\n");
            sendString.append("\r\n");
            sendString.append("<html><head><title>SHOW</title></head></body>");
            sendString.append("Received:<br/>");

            for (String s : requestMessage){
                sendString.append(s + "<br/>");
            }
            sendString.append("</body></html>");
            buffer = ByteBuffer.wrap(sendString.toString().getBytes(localCharset));
            sc.write(buffer);
            sc.close();
        }
    }
```

handleRead开头先获取到对应的SocketChannel和ByteBuffer，就这两个最为关键，SocketChannel负责与客户端的链接和传输数据，而ByteBuffer充当数据运输的载体。

而后则是简单的判断连接状态，若是连接，将相关信息输出到控制台，并拼接出HTTP头的字符串发送至客户端。

效果如图：
![](http://source.jianyujianyu.com/2017-01-15-14844539625326.jpg)
![](http://source.jianyujianyu.com/2017-01-15-14844539849717.jpg)


若有错误之处请指出，更多地关注[煎鱼](https://www.jianyujianyu.com)。


