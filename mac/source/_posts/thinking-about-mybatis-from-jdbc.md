title: 从JDBC的不足思考Mybatis的构建
categories: Java
tags: [jdbc,mybatis]
date: 2017-03-03 08:13:37
---


## 用JDBC实现对数据上的操作

```Java
public static List<Map<String,Object>> queryForList(){  
        Connection connection = null;  
        ResultSet rs = null;  
        PreparedStatement stmt = null;  
        List<Map<String,Object>> resultList = new ArrayList<Map<String,Object>>();  
          
        try {  
            // 1.加载JDBC驱动  
            Class.forName("oracle.jdbc.driver.OracleDriver").newInstance();  
            String url = "jdbc:oracle:thin:@localhost:1521:ORACLEDB";  
              
            String user = "trainer";   
            String password = "trainer";   
              
            // 2.获取数据库连接，这里需要填写数据库的信息，包括账号密码
            connection = DriverManager.getConnection(url,user,password);   
              
            // 创建查询语句
            String sql = "select * from userinfo where user_id = ? ";  
            // 3.创建Statement对象（每一个Statement为一次数据库执行请求
            stmt = connection.prepareStatement(sql);  
              
            // 4.设置传入参数  
            stmt.setString(1, "zhangsan");  
              
            // 5.执行SQL语句  
            rs = stmt.executeQuery();  
              
            // 6.处理查询结果（将查询结果转换成List<Map>格式）  
            ResultSetMetaData rsmd = rs.getMetaData();  
            int num = rsmd.getColumnCount();  
              
            while(rs.next()){  
                Map map = new HashMap();  
                for(int i = 0;i < num;i++){  
                    String columnName = rsmd.getColumnName(i+1);  
                    map.put(columnName,rs.getString(columnName));  
                }  
                resultList.add(map);  
            }  
              
        } catch (Exception e) {  
            e.printStackTrace();  
        } finally { 
        		 // 7. 释放所有资源
            try {  
                   //关闭结果集  
                if (rs != null) {  
                    rs.close();  
                    rs = null;  
                }  
                   //关闭执行  
                if (stmt != null) {  
                    stmt.close();  
                    stmt = null;  
                }  
                if (connection != null) {  
                    connection.close();  
                    connection = null;  
                }  
            } catch (SQLException e) {  
                e.printStackTrace();  
            }  
        }  
          
        return resultList;  
    }  
```

<!-- more -->

## 从JDBC中思考Mybatis的构建
MyBatis是将sql语句中的输入参数和输出参数映射为java对象，放弃了对数据表的完整性控制，但是获得了更灵活和响应性能更快的优势。
代码注释中标出的7步，在开发中显得略微复杂繁琐，因此在此思考Mybatis是如何改进JDBC的缺点的。

### 连接获取和释放
如果每次请求数据库都获取连接然后释放，则过于浪费性能；如果都放在一个try里面，则增加代码复杂度以至于难以阅读。可以是用连接池以重复使用连接，但是连接池的多样化问题略为严重。

**解决：**通过一个中间层DataSource进行解耦，统一从DataSource获取连接，DataSource可通过配置选择不同的连接池（DBCP、JNDI）。

### SQL统一存取
以上例子中的查询语句依然使用SQL字符串，并且还略为发散，根据大佬的话，有三处不足：

- 可读性很差，不利于维护以及做性能调优
- 改动Java代码需要重新编译、打包部署
- 不利于取出SQL在数据库客户端执行

**解决：**将SQL语句统一集中放到配置文件或者数据库里面（以key-value的格式存放），但涉及读取SQL语句的加载问题。

### 传入参数映射和动态SQL
通过在SQL语句中设置占位符来传参，就要求参数与占位符一一匹配，当传参不确定时，还是得自己拼接于是还是只能在代码中写SQL，因此需要方法根据不同的传参动态生成。

**解决：**类似if-else清晰的结构，使用key-value的Map，在解析的时候根据变量名的具体值来判断，同时使用一种有别于SQL的语法来嵌入变量（如`#变量名#`），如此便可生成符合上下文的SQL语句。

同时，要区分开占位符变量和非占位变量，可以使用`#变量名#`表示占位符变量，使用`$变量名$`表示非占位符变量。

### 结果映射和结果缓存
执行SQL语句、获取执行结果、对执行结果进行转换处理、释放相关资源的步骤必须是有序的，否则会出错。（如，获取结果不能在释放之后）因此可以封装起来，但主要的是处理结果，如果能把常用的结果处理方法都到位，就可将整个过程封装起来。

**解决：**由于返回和处理结果的多样性，必须要设置两个参数：返回对象的类型，返回数据与处理结构的映射。同时，采用KV缓存提供SQL的性能，而为了保证key的唯一，key采用SQL语句和参数。

### 重复SQL语句问题
个别语句只是条件不同，主体大致，而表结构的改动促使代码多处修改导致不利于维护。

**解决：**将重复的代码抽离出来成为独立的一个类，然后在各个需要使用的地方进行引用，即模块化。

## 总结
Hibernate属于全自动，Mybatis属于半自动，JDBC属于手动
从开发效率上讲Hibernate较高，Mybatis居中，JDBC较低
从执行效率上讲Hibernate较低，Mybatis居中，JDBC较高

## 其他问题：ibatis与Mybatis的区别
ibatis是Mybatis的前身

- Mybatis实现了接口绑定，使用更加方便
- 对象关系映射的改进，效率更高
- MyBatis采用功能强大的基于OGNL的表达式来消除其他元素


<br/><br/>
若有错误之处请指出，更多地关注[煎鱼](https://www.jianyujianyu.com)。






