---
title: 当我们谈论越狱时，我们在谈论什么
date: 2019-11-29 18:37:35
tags: ["Security","iOS","Jailbreak"]
layout: post
---

# 前言

其实很早以前就一直想写一篇有关越狱的文章，但由于拖延症发作，外加知识储备不足，所以久未动手。

这几天一个学期结束，终于有些时间，于是决定把这个坑填上。

中文互联网上大多数资料都不全，且不论一些垃圾信息被翻来覆去复制了千百遍，以讹传讹，一些真实有用的资料也早已过时。

但倒也不必过于对中文资料犬儒主义————毕竟，总会有人通过这些资料对越狱产生兴趣，从而真正自己去接触业界前沿。

写这篇文章，是对自己过去有关 iOS 越狱知识的一个检验，希望同时也能帮助到一些对 iOS 安全感兴趣，但却又无从下手的人。

本篇不会讨论过多的技术细节，可能之后会补充详细要素。

---
在真正谈论越狱之前，我们需要先熟悉一些基本概念。

# iPhone 的分区

如果大家对越狱有一些了解，可能知道 iPhone 有两个分区，一个是只读的系统分区(fsroot)，另外一个则是数据分区(`/private/var`)。

但实际上，iPhone的闪存中还存在别的分区，这部分分区是*不可见*的。以 iPhone 6S 为例，一共有七个分区:[^3]

[^3]: http://ramtin-amin.fr/#nvmepcie

- NS1 - FSYS

- NS2 - (LLB +) iBoot

- NS3 - SCFG

- NS4 - WIFI

- NS5 - NVRM

- NS6 - KEYBAG

- NS7 - 空

---

NS1 会默认被挂载为`/dev/disk0`。

里面有三个分区，分别是系统分区，数据分区和基带分区，但只有前两者会显示出来。（这就是为什么早在 iPhone 3GS 时代，你可以只刷06.15.00基带来解锁有锁iPhone，而不重置系统的原因。）

在 iPhoneOS ~ iOS 4 时代，长这样:
```
/dev/disk0
  /dev/disk0s1 System partition
  /dev/disk0s2s1 Data partition
```


从 iOS 5.0 开始，这个分区的分区表表由LwVM(Lightweight Volume Manager)管理。每次启动时，LwVM会读取储存的分区表，然后根据这个分区表在`/dev/disk0s1`下面虚拟一个新的卷。同时，LwVM会加载一个kext驱动挂载在系统，每次系统要对分区表更改的时候，LwVM会先检测它的有效性，如果通过了，才能写回`/dev/disk0`保存。
这样做的目的除了让读写分区表更安全以外，一个更重要的原因大概是让 OTA 更新变成可能。

新的卷目录结构如下所示:
```
/dev/disk0          Root NAND volume
  /dev/disk0s1      LwVM master volume
    /dev/disk0s1s1  System partition
    /dev/disk0s1s2  Data partition
```

# iOS 启动链

一般来说，我们把打开一台*处于关闭状态*设备电源的动作叫做冷启动(cold boot)。

依此类推，iPhone（或iPad/iPod Touch/Apple TV，下同）的冷启动，指的是在 iPhone 关机下按住电源键进行开机操作。

按住电源键后，SoC（什么是SoC？举个例子：A13 Bionic）会被加电，之后，它会运行一段代码来进行后续的引导操作。这段代码被放在 BootROM（苹果也叫它SecureROM） 中 。每次冷启动，他都会被第一个执行。

除了含有上述所说的引导代码，BootROM 还包含了苹果公司自己的根证书公钥。[^1]

与很多人对 ROM 的理解所不同的是，BootROM 是一块 Mask ROM，其制作原理决定了从芯片出场的那一刻开始，里面的内容就无法更改。

由于 ROM 空间比较小，不可能装下一个完整的引导程序，所以这段代码所做的事情，是寻找下一个引导程序，并且在保证下一个引导程序都是合法的情况下将控制权转交给它。在这里，BootROM 使用内置的公钥来验证下一段程序的签名，借此判断合法性。在验证完下一个阶段程序的签名真实有效之后，BootROM 会显示出苹果的 Logo，初始化SRAM、GPIO、时钟以及一些必要的环境，然后把控制权交给它。

BootROM有两条引导路径：一般情况下，BootROM 会进入正常引导模式；如果 BootROM 监听到特殊按键组合，则会让设备进入 DFU 引导模式。

一个典型的启动链如下图所示：[^2]

![iOS Boot process](/assets/iOS/iOS-Boot-process.png)

LLB 环节在 SoC 为 A10 及之后的设备中不存在，在这些设备上，BootROM 会直接跳到 iBoot 环节。
 
需要注意的是，如果 BootROM 是在搜寻或进入 LLB 时失败，则会进入 DFU 模式。如果 LLB/iBoot 引导下一阶段失败，进入 Recovery 模式。（对于 BootROM 进入 iBoot 失败的情况下是否会进入DFU模式，暂时没有找到相关资料。）

下面以引导路径为分组，简短地介绍一下每个引导环节。

[^1]: https://www.apple.com.cn/cn/iphone/business/docs/iOS_Security_Guide.pdf, p5
[^2]: Mac OS X and iOS : Internals To the Apple's Core Volume I, page 210

## 正常引导

这部分所有的内容都存放在设备的闪存中，属于可读写的部分，这就意味着，即使这部分引导环节出现了漏洞，苹果也可以通过软件更新修复他们。

### LLB (Low-level bootloader)

一个适配层，负责验证并引导下一个引导阶段iBoot。

这个阶段也被称为 iBootStage1。

如果 BootROM 无法读取 LLB ，或签名无效，则设备将会进入DFU模式待命。

### iBoot (iBootStage2)

在 A10 及后续设备中，LLB 环节被并入 iBoot 环节，虽然 ipsw 中仍然存在 LLB 与 iBoot ，但解密后他们的内容是一样的。

iBoot 会验证内核的签名是否有效，然后做一些准备（比如映射设备树），最后会根据在 NVRAM 中的变量来决定之后的操作。

在默认情况下，执行的是`fsboot`。 iBoot 随后会从`boot-path`(默认值为`/System/Library/Caches/com.apple.kernelcaches/kernelcache`)的内核进行启动。

如果`boot-command`被设置成`upgrade`（一般都是OTA更新时），那么 iBoot 则会从 LwVM 分区里面找名为 `Update` 的分区，然后使用里面的`iBEC`进行引导。

需要注意的是，与LLB不同，如果 iBoot 因为损坏或签名无效而无法读取的话，启动过程会停止，但屏幕将会显示连接到iTunes，这就是所谓的 Recovery 模式。

## DFU 模式

DFU 模式中，设备默认不从自己的引导中启动，相反，它会从 USB 宿主机中接收一个引导镜像，由这个镜像来完成后续的引导操作。

在之前的版本里，DFU 首先需要接受 iBSS, iBSS 随后接受 iBEC，iBEC 完成后续的刷机操作。但随着 LLB 的消失，iBSS/iBEC 也消失了。在 A10+ 设备中，这个镜像就是一个完整版的 iBoot，与同版本固件中的 iBoot 没有任何差别。

当然，这个阶段，也是需要验证签名的。签名不对劲？不好意思，拒绝启动。

# 越狱

有了前面的铺垫，我们就可以来讲讲本文的重点了：到底要做什么，才能越狱？

要回答这个问题，我们要知道越狱本质核心----获取系统的最高权限。苹果从一开机开始，就给你布下了天罗地网，如前文所见，我们讨论了整个引导链，一般情况下，每个环节不出问题，你是没法逃出去的。

但代码是人写的，所以难免会有疏漏。每个版本的越狱，大致就是从整个引导链中找出破绽，然后通过一系列操作将自己的权限提升。你可能会问，权限提升，不就是通过一个漏洞把自己切换成root吗？然后`/etc/fstab`一挂载rw`fsroot`，cydia一装，还不是美滋滋？