title: 用Go写一个简单Web应用
categories: Golang
tags: [go,web]
date: 2016-08-06 03:15:59
---


## 简介和要求

教程将涵盖以下知识：

- 创建一个带有load和save方法的数据结构体
- 使用net/http包来创建web应用
- 使用html/template包来处理HTML模板
- 使用regexp包来检测用户的输入
- 使用闭包

假设你已经有以下知识：

- 编程经验
- 明白基础的web知识（HTTP，HTML）
- 具有些UNIX、DOS的命令行知识

<!-- more -->

## 开始

首先，你需要有一个装了FreeBSD、Linux、MacOS甚至是Windows系统的机器来跑Go程序。然后，你需要有一个Go环境，即你需要安装Go（废话）。

为了这个教程，我们先在GOPATH里创建一个文件夹，并用cd命令进入里面：

```
$ mkdir gowiki
$ cd gowiki
```

而后创建一个名为wiki.go的文件，用你最中意的编辑器打开它，并在里面加上以下内容：

```
package main

import (
	"fmt"
	"io/ioutil"
)
```

以上我们从Go的标准库中导入了fmt和ioutil包。而之后我们会用import声明来引入更多的包，如果我们要实现更多额外的功能的话。

## 数据结构体

现在我们开始定义一个结构体。想象一下，一个wiki应该有什么？它应该有一堆互有关系（互含链接）的网页Page，而后每个网页Page都起码有一个标题Title和主体Body，主体就是内容。因此我们先定义一个网页Page的结构，它有一个标题域和主体域：

```
type Page struct {
    Title string
    Body  []byte
}
```

其中[]byte是“比特切片”的意思，不选用string而选用[]byte，是因为我们会在io库中用到[]byte类型，接下来你会看到的。

Page结构体描述了网页的数据存储在内存中的形式，然而持久化存储呢？我们可以为Page创建一个save方法来实现存储：

```
func (p *Page) save() error {
    filename := p.Title + ".txt"
    return ioutil.WriteFile(filename, p.Body, 0600)
}
```

这个方法的声明`func (p *Page) save() error{}`表明了这个方法名为save，属于p，即Page指针类型可调用的方法，而且它不需要传入任何参数，而后返回一个error类型的值。

这个方法会将网页的主体保存到一个txt文件中，而方便起见，我们选用这个网页的Title项作为这个txt文件的名字。而这个save方法返回一个error类型是因为error也是WriteFile的返回类型（WriteFile是一个用于将[]byte写入文件的标准库函数），当然这样返回error也是为了能让程序在写文件时发生错误后处理好。而大多数情况是一切安好，没有故障，这样Page.save()就会返回一个nil（nil是指针、接口或其他类型的”零值“）。

如果你足够细心的话，你会发现WriteFile的第三个参数很奇怪。这个一个八进制数字0600，表明了这个txt文件只对于当前用户，是以具有可读写权限的方式打开的（p.s. 不懂为啥是600的可以看一下Unix/Linux的权限的表达方式）。

有了存储save()方法，对应的也应该有读取的方法：

```
func loadPage(title string) *Page {
    filename := title + ".txt"
    body, _ := ioutil.ReadFile(filename)
    return &Page{Title: title, Body: body}
}
```

loadPage的思想很简单：读取与title有相应名字的txt文件，将文件的内容赋值给变量body，而后返回一个带有Title和Body的Page结构体实例的指针。

首先我们得知道函数是可以返回多个返回值的。而标准库函数io.ReadFile返回了[]byte和error两个类型的值。当然这个简单的loadPage，并没有对错误进行处理 —— 上述代码使用了空标识符，即下划线_，用于抛弃这个error返回值（本质上，这样就是将变量分配到空，就是抛弃）。

但是问题很严重 —— 如果有error了应该怎么办？举个例子，可能这个txt文件并不存在，总不能抛弃吧。因此我们不能坐视不理，我们应该修改一下这个方法：

```
func loadPage(title string) (*Page, error) {
    filename := title + ".txt"
    body, err := ioutil.ReadFile(filename)
    if err != nil {
        return nil, err
    }
    return &Page{Title: title, Body: body}, nil
}
```

现在这个方法的调用者就可以检测一下第二返回值是否为空，以此来检测是否成功读取到Page了。

而在这个moment，我们已经有一些简单的数据结构和读取页面的方法了。我们可以着手于写一个main来测试一下我们写的有没有错误：

```
func main() {
    p1 := &Page{Title: "TestPage", Body: []byte("This is a sample Page.")}
    p1.save()
    p2, _ := loadPage("TestPage")
    fmt.Println(string(p2.Body))
}
```

以上代码编译和执行完后，一个名为TestPage.txt、包含着p1内容的文件将会被创建出来。而后这个文件会被p2这个结构体读取，而后这个p2结构体的Body内容将会被输出到屏幕上。

好，现在我们可以编译和运行了：

```
$ go build wiki.go
$ ./wiki
This is a sample page.
```

（如果你是windows上跑的，运行的时候直接打"wiki"就行，不需要“./”了。）

## 介绍一下net/http包

以下是一个简单的web服务器程序例子：

```
package main

import (
    "fmt"
    "net/http"
)

func handler(w http.ResponseWriter, r *http.Request) {
    fmt.Fprintf(w, "Hi there, I love %s!", r.URL.Path[1:])
}

func main() {
    http.HandleFunc("/", handler)
    http.ListenAndServe(":8080", nil)
}
```

main函数一开始就调用了http.HandleFunc，这个函数就是告诉http包，将web服务器所有/下的请求交给handler处理。接着main函数又调用了http.ListenAndServe，目的就是指定8080端口（先不用管那个第二个参数nil），这个ListenAndServe会一直阻塞整个程序，直到程序被终止。

函数handler的类型是http.HandlerFunc，它需要两个参数，http.ResponseWriter和http.Request。http.ResponseWriter变量的作用就是回应HTTP请求，向它写入一些东西即向HTTP客户端发送一些东西。而http.Request是一个代表了HTTP客户请求的数据结构。handler中的r.URL.Path是请求URL的路径部分，紧跟着的[1:]是对路径的一个切片动作，即返回r.URL.Path的第一个字符到结尾的切片，在这里，实际意味着除去/符号，只要后面的。

如果你运行该程序，并访问以下地址：

```
http://localhost:8080/monkeys
```

这个程序就会在终端中输出：

```
Hi there, I love monkeys!
```

## 将wiki和net/http包合并使用

想要使用net/http包，我们必须先将它导入：

```
import (
	"fmt"
	"io/ioutil"
	"net/http"
)
```

而后我们创建一个handler，叫做viewHandler，它可允许用户访问wiki的页面，它会处理前缀是/view/的URL。

```
func viewHandler(w http.ResponseWriter, r *http.Request) {
    title := r.URL.Path[len("/view/"):]
    p, _ := loadPage(title)
    fmt.Fprintf(w, "<h1>%s</h1><div>%s</div>", p.Title, p.Body)
}
```

首先，函数先在请求URL的路径部分，即r.URL.Path中提取页面的title。路径被[len("/view/"):]重新切片了一下，为的就是除掉请求URL中/view/的部分，这是因为/view/并不是page的名称。而后函数读取这个txt文件，然后将内容格式转换为的string形式的简单的HTML，继而将这个string写到w，即http.ResponseWriter。

同样这里需要注意一下这个_，这里的_也是直接忽略了loadPage的error返回值，这样做仅是为了程序的简单易懂，而这样忽略通常是极其不好的习惯。我们迟点再对这里进行修改（其实，很多时候都是说迟点再改然后就忘了- -）。

要使用这个handler，我们需要重写一下我们的main函数中的http初始化部分：

```
func main() {
    http.HandleFunc("/view/", viewHandler)
    http.ListenAndServe(":8080", nil)
}
```

然后我们手动创建一下txt文件（比如说test.txt，用编辑器在里面写句Hello world），然后编译一下我们的代码并运行。

```
$ go build wiki.go
$ ./wiki
```

接着你就可以在浏览器访问http://localhost:8080/view/test看看是不是有一个Hello world，或者是你自己自定义的启动txt文件内容。

## wiki的编辑页面

不能编辑wiki页面的wiki不是一个好wiki。因此，我们需要额外创建两个handler，一个叫做editHandler，用来显示一个wiki的编辑页面，另一个handler叫saveHandler，用来通过提交的表单保存
数据。

首先，我们先将一下这些添加到main：

```
func main() {
    http.HandleFunc("/view/", viewHandler)
    http.HandleFunc("/edit/", editHandler)
    http.HandleFunc("/save/", saveHandler)
    http.ListenAndServe(":8080", nil)
}
```

而后以下的函数editHandler将会载入页面（或者如果这个页面不存在的话，创建一个新的页面结构），然后在浏览器显示这个编辑的表单：

```
func editHandler(w http.ResponseWriter, r *http.Request) {
    title := r.URL.Path[len("/edit/"):]
    p, err := loadPage(title)
    if err != nil {
        p = &Page{Title: title}
    }
    fmt.Fprintf(w, "<h1>Editing %s</h1>"+
        "<form action=\"/save/%s\" method=\"POST\">"+
        "<textarea name=\"body\">%s</textarea><br>"+
        "<input type=\"submit\" value=\"Save\">"+
        "</form>",
        p.Title, p.Title, p.Body)
}
```

这样的代码是没有问题的，它能正常运行，但是，这样的硬编码HTML实在是太难看了，我们需要一种“优雅”的输出HTML的方式。

## 使用html/template包优雅地输出HTML

html/template包属于Go标准库。使用这个包，我们就可以分离HTML到一个单独的HTML文件，这样我们在修改编辑页面的布局时，就不用再Go代码里面修改了。

首先，我们还是先在import列表中加入我们要导入的html/template，同时，这一次我们不再想要用fmt将内容输出到屏幕了，我们将fmt去掉：

```
import (
	"html/template"
	"io/ioutil"
	"net/http"
)
```

接下来，我们创建一个包含了HTML表单的模板 —— 新建一个名为edit.html的文件并添加以下内容：

```
<h1>Editing {{.Title}}</h1>

<form action="/save/{{.Title}}" method="POST">
<div><textarea name="body" rows="20" cols="80">{{printf "%s" .Body}}</textarea></div>
<div><input type="submit" value="Save"></div>
</form>
```

修改editHandler，将硬编码HTML替换为使用模板：

```
func editHandler(w http.ResponseWriter, r *http.Request) {
    title := r.URL.Path[len("/edit/"):]
    p, err := loadPage(title)
    if err != nil {
        p = &Page{Title: title}
    }
    t, _ := template.ParseFiles("edit.html")
    t.Execute(w, p)
}
```

template.ParseFiles函数会读取edit.html内容，并返回一个模板的指针*template.Template。而t.Execute函数则是将内容写入模板而后生成HTML到http.ResponseWriter。模板中.Title和.Body中使用的点就是指传入的对象的对应属性，在这里指p.Title和p.Body。

模板中的变量要使用双花括号套住。而模板中的指令`printf "%s" .Body`，则是一个以string形式而不是bytes串形式输出Body值的函数调用，这样就相当于fmt.Printf函数，只是一个是输出于浏览器页面上，另一个输出于终端上。

html/template包可以帮我们通过模板生成安全的、正确的HTML代码。比如说，它能自动帮你转换大于号（>），就是自动地帮你替换`&gt;`，这样就保证用户数据不会对HTML表单造成干扰。

既然我们已经在使用模板了，我们就继续用模板的这个套路来创建我们的view.html以及调用它的viewHandler。

```
<h1>{{.Title}}</h1>

<p>[<a href="/edit/{{.Title}}">edit</a>]</p>

<div>{{printf "%s" .Body}}</div>
```

修改viewHandler：

```
func viewHandler(w http.ResponseWriter, r *http.Request) {
    title := r.URL.Path[len("/view/"):]
    p, _ := loadPage(title)
    t, _ := template.ParseFiles("view.html")
    t.Execute(w, p)
}
```

好，该重点细节的时候来了。你看，我们两个handler都有相同的代码来渲染HTML，一个合格的程序员看到这种情况应该要将重复的部分模块化：

```
func renderTemplate(w http.ResponseWriter, tmpl string, p *Page) {
    t, _ := template.ParseFiles(tmpl + ".html")
    t.Execute(w, p)
}
```

然后两个handler就变成：

```
func viewHandler(w http.ResponseWriter, r *http.Request) {
    title := r.URL.Path[len("/view/"):]
    p, _ := loadPage(title)
    renderTemplate(w, "view", p)
}
func editHandler(w http.ResponseWriter, r *http.Request) {
    title := r.URL.Path[len("/edit/"):]
    p, err := loadPage(title)
    if err != nil {
        p = &Page{Title: title}
    }
    renderTemplate(w, "edit", p)
}
```

不要觉得代码反而变长了就不重要，甚至嘲笑，重要的是思想:)

## 处理好不存在的页面

如果你去访问/view/APageThatDoesntExist这样一个不存在的页面（假设他不存在），会发生什么？如果是上述代码的Web应用，你应该会看到一个包含着HTML的页面，这是因为我们在loadPage中忽略了文件不存在时的错误处理（这事终于被提上日程了），于是这样地读文件，它只读了个空。其实，如果请求的页面不存在，这样的请求就应该被重定向到编辑页面，这样用户就可以创建一个新的文件了。

```
func viewHandler(w http.ResponseWriter, r *http.Request) {
    title := r.URL.Path[len("/view/"):]
    p, err := loadPage(title)
    if err != nil {
        http.Redirect(w, r, "/edit/"+title, http.StatusFound)
        return
    }
    renderTemplate(w, "view", p)
}
```

http.Redirect函数参数包含了一个状态码http.StatusFound (302)，以及一个响应的目标地址。

## 保存页面

函数saveHandler将会处理好编辑页面中表单的子任务：

```
func saveHandler(w http.ResponseWriter, r *http.Request) {
    title := r.URL.Path[len("/save/"):]
    body := r.FormValue("body")
    p := &Page{Title: title, Body: []byte(body)}
    p.save()
    http.Redirect(w, r, "/view/"+title, http.StatusFound)
}
```

页面标题（由URL提供）以及Body都会被保存在新的Page实例中。然后save()函数的调用就是要将数据写入到一个文件中，然后客户端就被重定向到/view/中对应的页面。

其中函数FormValue()的返回值是string类型，我们需要将它转换为[]byte类型，这样才能用它来生成新的Page结构体实例。我们使用`[]byte(body) `来实现这个转换。

## 错误处理

我们的程序有几处地方忽略了不该忽略的错误，这是一个坏习惯，尤其是程序发生了你意想不到的错误的时候，你更会后悔莫及。一个较好的处理方案就是先程序自行处理好错误，然后将错误信息发送给用户。按照这样的方案，我们的应用必然会和我们预料的一样执行，并在有问题的时候通知用户。

首先，我们需要在我们刚才分离出来的renderTemplate里面添加处理信息的代码（模块化的好处开始凸显）：

```
func renderTemplate(w http.ResponseWriter, tmpl string, p *Page) {
    t, err := template.ParseFiles(tmpl + ".html")
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    err = t.Execute(w, p)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
    }
}
```

http.Error函数会给用户发送一个特定的状态码（这里是Internal Server Error）和错误信息。然后我们继续以同样的方法修改saveHandler：

```
func saveHandler(w http.ResponseWriter, r *http.Request) {
    title := r.URL.Path[len("/save/"):]
    body := r.FormValue("body")
    p := &Page{Title: title, Body: []byte(body)}
    err := p.save()
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    http.Redirect(w, r, "/view/"+title, http.StatusFound)
}
```

当p.save()执行时发生了错误，就会调用http.Error，用户就会得知此错误信息。

## 模板的缓存

当然这个简单的web应用还是不够高效，怎么个不够高效法呢？就是没有缓存，每次用户查看页面，Go程序都需要读取数据并重新渲染一下模板。也就是说，renderTemplate每次都调用ParseFiles。我们对其进行优化，比较好的方案是在程序初始化的时候调用ParseFiles一次，然后将所有模板都赋值到一个*Template里面，我们之后就用ExecuteTemplate来渲染特定的模板了。

首先我们先用ParseFiles函数初始化一个全局变量，名为templates：

```
var templates = template.Must(template.ParseFiles("edit.html", "view.html"))
```

template.Must是个封装好的函数，它会在Parse返回err不为nil时，调用panic，而其他情况下，它会照常返回Template指针。Must的引入允许我们不用显式地处理错误，而我们只关注这个业务功能而忽略它还会返回一个错误。而panic在这里也用得较为合适 —— 如果模板都不能被加载了，那么能做得好的事就只能是退出程序了。

ParseFiles函数的参数是任意数量的string，这些string对应着我们的模板文件。然后这些模板都会按照文件的命名加载到templates中。当然如果我们要添加更多的模板文件，我们只需要将它们的名字加到ParseFiles的参数里面。

然后我们正式地对renderTemplate进行修改，改成调用templates.ExecuteTemplate的形式：

```
func renderTemplate(w http.ResponseWriter, tmpl string, p *Page) {
    err := templates.ExecuteTemplate(w, tmpl+".html", p)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
    }
}
```

p.s.记得加上.html哦。

## 验证

其实如果你足够细心，你会发现一个安全隐患问题：用户可以在服务器应用下的任意路径做读取和修改。为了尽可能避免这个安全隐患，我们写一个函数，它可以用正则表达式来验证title的合法性。

首先我们先将regexp加入到import列表中，然后我们需要创建一个全局变量来存储我们需要用到的表达式：

```
var validPath = regexp.MustCompile("^/(edit|save|view)/([a-zA-Z0-9]+)$")
```

在这里，我们看到了熟悉的身影Must：regexp.MustCompile，它负责转换和遍历正则表达式，然后返回一个regexp.Regexp类型的变量。类似的，MustCompile和Compile这个妖艳贱货不一样，Must在处理失败的时候会返回一个panic。

然后，我们可以开始写一个函数，它专门用于验证validPath的正确性并从中提取文件的title：

```
func getTitle(w http.ResponseWriter, r *http.Request) (string, error) {
    m := validPath.FindStringSubmatch(r.URL.Path)
    if m == nil {
        http.NotFound(w, r)
        return "", errors.New("Invalid Page Title")
    }
    return m[2], nil // The title is the second subexpression.
}
```

如果路径合法，它会带着一个nil值返回（第二个返回值）；如果路径不合法，函数就会将“404 Not Found”写进HTTP连接，然后给handler返回一个error。当然，为了可以新建error，我们需要import一下errors包。

然后我们修改所有handler，让它们在里面调用getTitle来验证合法性：

```
func viewHandler(w http.ResponseWriter, r *http.Request) {
    title, err := getTitle(w, r)
    if err != nil {
        return
    }
    p, err := loadPage(title)
    if err != nil {
        http.Redirect(w, r, "/edit/"+title, http.StatusFound)
        return
    }
    renderTemplate(w, "view", p)
}

func editHandler(w http.ResponseWriter, r *http.Request) {
    title, err := getTitle(w, r)
    if err != nil {
        return
    }
    p, err := loadPage(title)
    if err != nil {
        p = &Page{Title: title}
    }
    renderTemplate(w, "edit", p)
}

func saveHandler(w http.ResponseWriter, r *http.Request) {
    title, err := getTitle(w, r)
    if err != nil {
        return
    }
    body := r.FormValue("body")
    p := &Page{Title: title, Body: []byte(body)}
    err = p.save()
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    http.Redirect(w, r, "/view/"+title, http.StatusFound)
}
```

## 闭包

心细的你又再次发现，为了捕捉和处理各种错误，我们使用了很多代码，而且还是很多重复的代码，那么我们能不能做点什么呢？也许抽象函数能帮得到我们。

首先，我们重写一下handler的函数定义（以同样的形式，整齐的参数）：

```
func viewHandler(w http.ResponseWriter, r *http.Request, title string)
func editHandler(w http.ResponseWriter, r *http.Request, title string)
func saveHandler(w http.ResponseWriter, r *http.Request, title string)
```

接下来我们定义一个包装函数，它需要的参数类型是*上面我们声明的函数类型*，即`func (http.ResponseWriter, *http.Request, string)`，然后返回一个http.HandlerFunc类型的函数，这个包装函数的大致框架如下：

```
func makeHandler(fn func (http.ResponseWriter, *http.Request, string)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		// Here we will extract the page title from the Request,
		// and call the provided handler 'fn'
	}
}
```

上述函数return了一个函数自己内部定义的函数，称为闭包。在这里，变量fn（即makeHandler唯一的参数）被闭包直接用了，而fn可以是我们的view、save或者edit的handler。

然后我们可以开始着手于闭包里面的实现，我们可以借用getTitle的代码：

```
func makeHandler(fn func(http.ResponseWriter, *http.Request, string)) http.HandlerFunc {
    return func(w http.ResponseWriter, r *http.Request) {
        m := validPath.FindStringSubmatch(r.URL.Path)
        if m == nil {
            http.NotFound(w, r)
            return
        }
        fn(w, r, m[2])
    }
}
```

makeHandler返回的闭包是带有http.ResponseWriter和http.Request参数的函数。而在这里，闭包在请求路径中提取了title，然后使用TitleValidator正则来检验合法性。如果不合法，它将会向ResponseWriter 用http.NotFound函数写入一个error；如果合法，函数将会用ResponseWriter、Request和title三个参数来调用fn。

然后我们就可以在main函数里面包装我们的handler了：

```
func main() {
    http.HandleFunc("/view/", makeHandler(viewHandler))
    http.HandleFunc("/edit/", makeHandler(editHandler))
    http.HandleFunc("/save/", makeHandler(saveHandler))

    http.ListenAndServe(":8080", nil)
}
```

然后我们去掉先前的getTitle，让handler变得苗条点：

```
func viewHandler(w http.ResponseWriter, r *http.Request, title string) {
    p, err := loadPage(title)
    if err != nil {
        http.Redirect(w, r, "/edit/"+title, http.StatusFound)
        return
    }
    renderTemplate(w, "view", p)
}

func editHandler(w http.ResponseWriter, r *http.Request, title string) {
    p, err := loadPage(title)
    if err != nil {
        p = &Page{Title: title}
    }
    renderTemplate(w, "edit", p)
}

func saveHandler(w http.ResponseWriter, r *http.Request, title string) {
    body := r.FormValue("body")
    p := &Page{Title: title, Body: []byte(body)}
    err := p.save()
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
        return
    }
    http.Redirect(w, r, "/view/"+title, http.StatusFound)
}
```

## 最终再试一下

重新编译运行试试？

```
$ go build wiki.go
$ ./wiki
```

试试运行访问http://localhost:8080/view/ANewPage，看看会怎么样？它应该会给出一个新的编辑页面，然后你可以输入一些内容，你可以保存，在保存后它会将你重定向到新的wiki页面~

### P.S.如果你很混乱，那么我附上最终的全部代码？

```
// Copyright 2010 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"html/template"
	"io/ioutil"
	"net/http"
	"regexp"
)

type Page struct {
	Title string
	Body  []byte
}

func (p *Page) save() error {
	filename := p.Title + ".txt"
	return ioutil.WriteFile(filename, p.Body, 0600)
}

func loadPage(title string) (*Page, error) {
	filename := title + ".txt"
	body, err := ioutil.ReadFile(filename)
	if err != nil {
		return nil, err
	}
	return &Page{Title: title, Body: body}, nil
}

func viewHandler(w http.ResponseWriter, r *http.Request, title string) {
	p, err := loadPage(title)
	if err != nil {
		http.Redirect(w, r, "/edit/"+title, http.StatusFound)
		return
	}
	renderTemplate(w, "view", p)
}

func editHandler(w http.ResponseWriter, r *http.Request, title string) {
	p, err := loadPage(title)
	if err != nil {
		p = &Page{Title: title}
	}
	renderTemplate(w, "edit", p)
}

func saveHandler(w http.ResponseWriter, r *http.Request, title string) {
	body := r.FormValue("body")
	p := &Page{Title: title, Body: []byte(body)}
	err := p.save()
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}
	http.Redirect(w, r, "/view/"+title, http.StatusFound)
}

var templates = template.Must(template.ParseFiles("edit.html", "view.html"))

func renderTemplate(w http.ResponseWriter, tmpl string, p *Page) {
	err := templates.ExecuteTemplate(w, tmpl+".html", p)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
	}
}

var validPath = regexp.MustCompile("^/(edit|save|view)/([a-zA-Z0-9]+)$")

func makeHandler(fn func(http.ResponseWriter, *http.Request, string)) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		m := validPath.FindStringSubmatch(r.URL.Path)
		if m == nil {
			http.NotFound(w, r)
			return
		}
		fn(w, r, m[2])
	}
}

func main() {
	http.HandleFunc("/view/", makeHandler(viewHandler))
	http.HandleFunc("/edit/", makeHandler(editHandler))
	http.HandleFunc("/save/", makeHandler(saveHandler))

	http.ListenAndServe(":8080", nil)
}
```


若有错误之处请指出，更多地关注[煎鱼](http://www.jianyujianyu.com)。

