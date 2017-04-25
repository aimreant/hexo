title: Python 2.x 的中文编码问题
categories: python
tags: [python,unicode]
date: 2017-03-06 02:21:00
---

Python 2.x的默认编码格式是ASCII，就是说，在没有指定Python源码编码格式的情况下，源码中的所有字符都会被默认为ASCII码。因此，在Python 2.x中经常会遇到UnicodeDecodeError或者UnicodeEncodeError的异常。

<!-- more -->


## 常见异常以及分析
### SyntaxError: Non-ASCII character

Python源码文件中有非ASCII字符，而且同时没有声明源码编码格式

### UnicodeDecodeError

```
#!/usr/bin/python
# -*- coding: utf-8 -*-
s = '中文'
s.decode('gb2312') 
# UnicodeDecodeError: 'gb2312' codec can't decode bytes in position 2-3: illegal multibyte sequence
print s
```
以上的s已经是声明了的utf8，但在转换为Unicode的时候传的不是utf8而是gb2312

```
#!/usr/bin/python
# -*- coding: utf-8 -*-
s = '中文'
s.encode('gb2312') 
# UnicodeDecodeError: 'ascii' codec can't decode byte 0xe4 in position 0: ordinal not in range(128)
print s
```
与前一种情况一样，都是当前字符编码和de/encode的参数编码冲突

### UnicodeEncodeError

如将Unicode编码的字符decode，或者将utf8编码的字符encode的时候

```
#!/usr/bin/python
# -*- coding: utf-8 -*-
s = u'中文'
s.decode('utf-8') 
# UnicodeEncodeError: 'ascii' codec can't encode characters in position 0-1: ordinal not in range(128)
print s
```

## 如何避免

1. 在文件头声明编码，即PEP0263
2. 用u'string'替代'string'
3. 使用sys.setdefaultencoding('utf-8')来reset编码
4. 原则：decode early, unicode everywhere, encode late
5. 升级Python 3


## 顺便一提Python 3的Unicode

1. 默认编码即为Unicode
2. 所有Python的内置模块都支持Unicode
3. 不再支持u'string'的格式


[原文链接][1]
若有错误之处请指出，更多地关注[煎鱼][2]。


  [1]: https://segmentfault.com/a/1190000002412924
  [2]: https://www.jianyujianyu.com
