---
title: ​Implement a strace equivalent using DynamoRio Framework
date: 2019-10-14 19:41:12
tags: ["strace","Dynamorio"]
layout: post
---

cs5231的大作业，要求写一个 DynamoRio Client 实现strace的无参数版本，
其输出必须与strace一模一样，在实现过程中遇到了不少坑，在这里记录一下。

# 简介

## strace && ptrace
`strace` 是一个追踪程序系统调用的系统实用工具。

以执行`strace date`为例，其输出大致如下:
```
execve("/bin/date", ["date"], 0x7ffe396958a0 /* 57 vars */) = 0
brk(NULL)                               = 0x5599fa9db000
access("/etc/ld.so.nohwcap", F_OK)      = -1 ENOENT (No such file or directory)
access("/etc/ld.so.preload", R_OK)      = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/etc/ld.so.cache", O_RDONLY|O_CLOEXEC) = 3
fstat(3, {st_mode=S_IFREG|0644, st_size=86799, ...}) = 0
mmap(NULL, 86799, PROT_READ, MAP_PRIVATE, 3, 0) = 0x7f3e75b65000
close(3)                                = 0
access("/etc/ld.so.nohwcap", F_OK)      = -1 ENOENT (No such file or directory)
openat(AT_FDCWD, "/lib/x86_64-linux-gnu/libc.so.6", O_RDONLY|O_CLOEXEC) = 3
...
```

`strace`工具的核心是系统的`ptrace`。

`ptrace`也是一个系统调用，只需调用它，即可观察一个程序的系统调用。

详细的说，`strace`首先fork()一个子进程，然后给子进程设置一个标志`PTRACE_TRACEME`后使用`execve`执行目标进程。

之后父进程将会等待，子进程的每一个系统调用都会先返回该系统调用号和寄存器状态给父进程，父进程接着解析并打印相关信息。

## DynamoRio

DynamoRio是一个动态二进制分析框架，它可以在程序执行的时候插入额外的分析代码，同时不影响程序正常运行效率。

具体原理是：DynamoRio将程序的执行流由原来的结构转移到代码缓存中，在这个缓存里，代码可以被任意修改，之后再进行模拟执行。

### DynamoRio Client

![DynamoRio Client](http://dynamorio.org/docs/client.png)

Client 与 DynamoRio 的关系如上图所示。

一个 Client 的运行方式为:

```bash
drrun -c libstrace.so -- ls
```

# 开工
## TL;DR
- 每个syscall中如果该参数是结构体，那么结构体的指针存在arg->value64中，仅能在event_post_syscall才能拿到

了解了以上信息之后，就可以大概知道我们要干什么了。
- 获取每个`syscall`及其相关信息
- 解析相关信息



## 实现
DynamoRio 中有一个框架叫做 Dr.Memory，其中的 Dr.Syscall 就是我们所需要的。

首先我们需要声明一个 Client 的 main 函数，注册回调函数。

```c
DR_EXPORT void dr_client_main(client_id_t id, int argc, const char *argv[])
{
    freopen("/dev/null", "w", stdout);
    // 关闭stdout
    drsys_options_t ops = {sizeof(ops),0};

    drmgr_init();
    dr_register_filter_syscall_event(event_filter_syscall);
    drmgr_register_pre_syscall_event(event_pre_syscall);
    drmgr_register_post_syscall_event(event_post_syscall);
    if (drsys_init(id, &ops) != DRMF_SUCCESS)
        DR_ASSERT(false);
    dr_register_exit_event(event_exit);

}
```
### 参数处理
之后每次目标程序呼叫系统调用时，DynamoRio都会截取并返回给我们的回调函数处理。

```c
static bool event_pre_syscall(void *drcontext, int sysnum)
{

    drsys_syscall_t *syscall;
    const char *name = "<unknown>";
    if (drsys_cur_syscall(drcontext, &syscall) == DRMF_SUCCESS){
        drsys_syscall_name(syscall, &name);
    }
    
    char* buf = malloc(sizeof(char)*OUTBUF_SIZE);

    drsys_iterate_args(drcontext, drsys_iter_arg_cb, buf);
    char *final = malloc(sizeof(OUTBUF_SIZE));

    sprintf(final,"%s(%s)",name,buf);
    dr_fprintf(STDERR, "%-39s",final);

    return true; /* execute normally */
}

```
由于需要跟strace的输出保持一致，在这里使用了一个buf来保存最后输出。使用`drsys_iterate_args`遍历参数，对于每个参数都会调用我们的自定义函数`drsys_iterate_arg_cb`。
```c
static bool drsys_iter_arg_cb(drsys_arg_t *arg, void *user_data){
    if (arg->ordinal == -1)
        return false;
    //...
}
```
对于每个参数，其类型存在`arg->type`中，实测不支持太多Linux类型，所以只能按syscall的大分类一个一个处理过去。

第一个坑是struct。
以`fstat`为例：，他的第二个参数是一个`struct stat`。
如果按照一般类型处理的话，`arg->value`里面存的应该就是内容，
然而如果是struct的话，里面似乎是全是垃圾。

那么来看看另外一个回调函数`drsys_iter_memarg_cb`，又如何呢？
```c
static bool drsys_iter_memarg_cb(drsys_arg_t *arg, void *user_data){
    char* buf = (char*)user_data;
    sprintf(buf,"[%s]",arg->value);

}
```
测试了一下，里面是NULL，陷入了僵局。

没办法，看看`drstrace`它怎么实现的打印struct:
```c

static bool
drstrace_print_info_class_struct(buf_info_t *buf, drsys_arg_t *arg)
{
    char buf_tmp[TYPE_OUTPUT_SIZE];
    drsym_type_t *type;
    drsym_type_t *expand_type;
    drsym_error_t r;

    r = drsym_get_type_by_name(options.sympath, arg->enum_name,
                               buf_tmp, BUFFER_SIZE_BYTES(buf_tmp),
                               &type);
    if (r != DRSYM_SUCCESS) {
        NOTIFY("Value to symbol %s lookup failed", arg->enum_name);
        return false;
    }

    r = drsym_expand_type(options.sympath, type->id, UINT_MAX,
                          buf_tmp, BUFFER_SIZE_BYTES(buf_tmp),
                          &expand_type);
    if (r != DRSYM_SUCCESS) {
        NOTIFY("%s structure expanding failed", arg->enum_name);
        return false;
    }
    if (!type_has_unknown_components(expand_type)) {
        NOTIFY("%s structure has unknown types", arg->enum_name);
        return false;
    }

    if (arg->valid && !arg->pre) {
        if (arg->value64 == 0) {
            OUTPUT(buf, "NULL");
            /* We return true since we already printed for this value */
            return true;
        }
        /* We're expecting an address here. So we truncate int64 to void*. */
        print_structure(buf, expand_type, arg, (void *)arg->value64);
    } else {
        return false;
    }

    return true;
}
```

```c
static void
print_structure(buf_info_t *buf, drsym_type_t *type, drsys_arg_t *arg, void *addr)
{
    ...
    if (type->kind == DRSYM_TYPE_VOID) {
            OUTPUT(buf, "void=");
            safe_read_field(buf, addr, type->size, true);
            return;
    } else if (type->kind == DRSYM_TYPE_PTR) {
    ...
```

得，看样子struct的指针存在arg->value64里面，不是我想象的垃圾。

那打印arg->value64地址所在的内存出来看看吧：
```c
fstat,[ordinal1][0x00007f5080f4b7d0]:
-----------------begin-------------------
05 00 00 00 00 00 00 00 91 1a d4 80 50 7f 00 00 
01 00 00 00 05 00 00 00 02 00 00 00 00 00 00 00 
01 00 00 00 90 00 00 00 02 00 00 00 00 00 00 00 
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 
------------------end-------------------
[0x00007f50f09c4ad0]:
-----------------begin-------------------
d0 b7 f4 80 50 7f 00 00 05 00 00 00 00 00 00 00 
80 80 99 f0 50 7f 00 00 01 58 a1 f0 50 7f 00 00 
10 a0 9c f0 50 7f 00 00 01 00 00 00 02 00 00 00 
10 00 00 00 00 00 00 00 08 0e d4 80 50 7f 00 00 
00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 
07 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 
f0 5f a4 59 fd 7f 00 00 08 00 00 00 00 00 00 00 
f0 5f a4 59 fd 7f 00 00 00 00 00 00 00 00 00 00 
05 00 00 00 00 00 00 00 02 00 00 00 00 00 00 00 
------------------end-------------------

```
观察到有个很像地址的东西，接着探究，结果发现似乎并不是……

是不是有什么地方看漏了？

回头再看drstrace的源码，突然发现，他在pre_syscall和post_syscall都遍历了一遍参数，而且判断了只有在postcall的时候才去打印结构体。

照葫芦画瓢试试看：
```c
static bool drsys_iter_arg_cb(drsys_arg_t *arg, void *user_data)
{
    if (!arg->pre){
        struct stat* st = (void*)arg->value64;    
        dr_fprintf(STDERR,"st_size=%d",st->st_size);
    }
}
```
结果正常了。

这个故事告诉我们，要好好看文档。

第二个坑是`write`

这是自己程序运行`cal`时的输出
```bash
   November 2019write(1, "   November 2019"..., 16)     = 16
      
write(1, "      \nmber 2019"..., 7)     = 7
Su Mo Tu We Th Fwrite(1, "Su Mo Tu We Th F"..., 16)     = 16
r Sa  
write(1, "r Sa  \nu We Th F"..., 7)     = 7
                write(1, "                "..., 16)     = 16
1  2  
write(1, "1  2  \n         "..., 7)     = 7
 3  4  5  6  7  write(1, " 3  4  5  6  7  "..., 16)     = 16
8  9  
write(1, "8  9  \n5  6  7  "..., 7)     = 7
10 11 12 13 14 1write(1, "10 11 12 13 14 1"..., 16)     = 16
5 16  
write(1, "5 16  \n2 13 14 1"..., 7)     = 7
17 18 19 20 21 2write(1, "17 18 19 20 21 2"..., 16)     = 16
2 23  
write(1, "2 _\"..., 11)                 = 11
24 25 26 27 28 2write(1, "24 25 26 27 28 2"..., 16)     = 16
9 30  
write(1, "9 30  \n6 27 28 2"..., 7)     = 7
                write(1, "                "..., 16)     = 16
      
write(1, "      \n         "..., 7)     = 7
exit_group(0)                           = ?
```

而strace标准输出则是
```bash
write(1, "   November 2019", 16   November 2019)        = 16
write(1, "      \n", 7      
)                 = 7
write(1, "Su Mo Tu We Th F", 16Su Mo Tu We Th F)        = 16
write(1, "r Sa  \n", 7r Sa  
)                 = 7
write(1, "                ", 16                )        = 16
write(1, "1  2  \n", 71  2  
)                 = 7
write(1, " 3  4  5  6  7  ", 16 3  4  5  6  7  )        = 16
write(1, "8  9  \n", 78  9  
)                 = 7
write(1, "10 11 12 13 14 1", 1610 11 12 13 14 1)        = 16
write(1, "5 16  \n", 75 16  
)                 = 7
write(1, "17 18 19 20 21 2", 1617 18 19 20 21 2)        = 16
write(1, "2 \33[7m23\33[27m  \n", 162 23  
)   = 16
write(1, "24 25 26 27 28 2", 1624 25 26 27 28 2)        = 16
write(1, "9 30  \n", 79 30  
)                 = 7
write(1, "                ", 16                )        = 16
write(1, "      \n", 7      
)                 = 7
exit_group(0)                           = ?
```
可以看到，流的顺序完全不一样。

这部分应该再看看strace的实现的，然而来不及了，先把作业交上去，以后再说吧。

# 代码
[Github](https://github.com/Umiiii/strace)