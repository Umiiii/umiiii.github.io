---
title: 当我们谈论越狱时，我们在谈论什么
date: 2019-11-29 18:37:35
tags: ["Security","iOS","Jailbreak"]
layout: post
draft: true
---

# 前言

其实很早以前就一直想写一篇有关越狱的文章，但由于拖延症发作，外加知识储备不足，所以久未动手。

这几天一个学期结束，终于有些时间，再加上自己之前研究`checkm8`漏洞时，发现中文互联网上大多数越狱资料都不全。且不论一些垃圾信息被翻来覆去复制了千百遍，以讹传讹，一些真实有用的资料也早已过时，于是决定把这个坑填上。

但倒也不必过于对中文资料犬儒主义————毕竟，总会有人通过这些资料对越狱产生兴趣，从而真正自己去接触业界前沿。

写这篇文章，是对自己过去有关 iOS 越狱知识的一个检验，希望同时也能帮助到一些对 iOS 安全感兴趣，但却又无从下手的人。

本篇不会讨论过多的技术细节，可能之后会补充详细要素。

如果有错误，欢迎指出。

---

在真正谈论越狱之前，我们需要先熟悉一些基本概念。

# iPhone 的分区

如果大家对越狱有一些了解，可能知道 iPhone 有两个分区，一个是只读的系统分区(`/`)，另外一个则是数据分区(`/private/var`)。其中，系统分区储存着与系统运行相关的文件，在默认情况下，用户无权访问。数据分区则存放着用户的资料，比如照片、短信、软件等等。

但实际上，这两个分区是逻辑分区。iPhone的闪存中还存在别的物理分区，这部分物理分区并不是都可见的。以 iPhone 6S 为例，一共有七个分区，这些分区以[http://www.ssdfans.com/blog/2017/08/03/%E8%9B%8B%E8%9B%8B%E8%AF%BBnvme%E4%B9%8B%E5%85%AD/](命名空间(NameSpace))的形式存在于闪存中:[^3]

[^3]: http://ramtin-amin.fr/#nvmepcie

- NS1 - FSYS

- NS2 - (LLB +) iBoot

- NS3 - SCFG

- NS4 - WIFI

- NS5 - NVRM

- NS6 - KEYBAG

- NS7 - 空

---


FSYS 里面又有三个分区，分别是系统分区，数据分区和基带分区。（这就是为什么你可以只刷基带，而不刷系统的原因。早在 iPhone 3GS 时代，由于 iPad 06.15.00 基带存在漏洞，可以通过先刷入 iPad 06.15.00 基带来解锁 iPhone。）

而 iBoot 与 LLB 则会分别被映射到 `/dev/disk1` 与 `/dev/disk2` 中。（我没有 A10 越狱设备）

在 iPhoneOS(iOS 1.0) ~ iOS 4 时代，长这样:
```
/dev/disk0
  /dev/disk0s1 System partition
  /dev/disk0s2 Data partition
```

从 iOS 5.0 开始，分区表表由 LwVM(Lightweight Volume Manager)管理。LwVM 的工作原理与 Linux 的 LVM 有些类似。每次启动时，LwVM 会读取储存在`/dev/disk0`中的分区表，然后根据这个分区表在`/dev/disk0s1`虚拟一个新的卷，之后再将逻辑分区挂载在卷下面。同时，LwVM会加载一个kext驱动挂载在系统，每次系统要对分区表更改的时候，LwVM会先检测它的有效性，如果通过了，才能写回`/dev/disk0`保存。
这样做的目的除了让读写分区表更安全以外，还让 OTA 更新变成可能。

在 iOS 5.0 之前，所有的升级操作都必须通过电脑完成。之后的系统里，iPhone 就可以通过设置-软件更新来直接更新操作系统。在 OTA 过程中，系统首先下载 OTA 更新包，然后将其挂载到名为`Update`的分区中，然后在重启后命令系统进入升级模式。

新的卷目录结构如下所示:
```
/dev/disk0          Root NAND volume
  /dev/disk0s1      LwVM master volume
    /dev/disk0s1s1  System partition   (->/)
    /dev/disk0s1s2  Data partition     (->/private/var)
    /dev/disk0s1s3  Baseband partition (->/private/var/wireless/baseband_data) #有的时候不会挂载
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
 
需要注意的是，如果 BootROM 是在搜寻或进入 LLB 时失败，则会进入 DFU 模式。如果 LLB/iBoot 引导下一阶段失败，进入 Recovery 模式。（对于 BootROM 进入 iBoot 失败的情况下是否会进入DFU模式，暂时没有找到相关资料。从目前测试情况来看，仍然是进入 Recovery 模式）

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

如果`boot-command`被设置成`upgrade`（一般都是OTA更新时），那么 iBoot 则会从 LwVM 分区里面找名为 `Update` 的分区，然后把引导权交给里面的`/iBEC`。

需要注意的是，与LLB不同，如果 iBoot 因为损坏或签名无效而无法读取的话，启动过程会停止，但屏幕将会显示连接到iTunes，这就是所谓的 Recovery 模式。

## DFU 模式

DFU 模式中，设备默认不从自己的引导中启动，相反，它会从 USB 宿主机中接收一个引导镜像，由这个镜像来完成后续的引导操作。

在之前的版本里，DFU 首先需要接收一个 iBSS 镜像, iBSS 随后接收 iBEC 镜像，由 iBEC 完成后续的刷机操作。但随着 LLB 的消失，iBSS/iBEC 也消失了。在 A10+ 设备中，这个镜像就是一个完整版的 iBoot，与同版本固件中的 iBoot 没有任何差别。

当然，这个阶段，也是需要验证签名的。

# 越狱

有了前面的铺垫，我们就可以来讲讲本文的重点了：越狱究竟做了什么？

一般来说，越狱会做到以下三点：
- 绕过`Apple Mobile File Integrity`允许未签名代码执行
- 给内核打补丁，提权，解除沙盒限制
- 重新挂载 fsroot 为 rw

之后，越狱工具一般还会帮你安装 Cydia 包管理器，以及 Mobile Substrate 包。通过 Cydia，你才能真正方便地安装各类实用工具。需要注意的是，安装 Cydia 是越狱的充分必要条件，这就是说，越狱不一定要安装 Cydia，也可以安装别的包管理软件，甚至不安装 Cydia 也不代表没有越狱。在 Cydia 年老失修，而且每个版本需要改的代码越来越多的情况下，以后可能会有新的包管理软件取代这个小灰盒子也说不定。

要越狱，我们首先需要找到漏洞来提升权限。

根据漏洞所在地的不同，分为三个等级：
- BootROM 漏洞
    这个等级的漏洞基本上是最罕见的。如上所述，如果 iPhone 出现了 BootROM 漏洞，Apple 没有任何办法修复。并且 BootROM 漏洞一般都可以让你任意修改引导链上的所有环节，所以只要有人愿意开发工具，即使 iOS 升级到 iOS 100（如果设备支持的话），也依然能成功越狱。目前一共有三个这样已公开并实装的漏洞，分别对应 alloc8 (iPhone 3GS 41周前生产)，Limera1n(iPhone4），以及最新的checkm8(iPhone 4S - iPhone X)。
- iBoot 漏洞
    这个等级的漏洞可以通过 iOS 更新直接修复，但如果有了这类型的漏洞，能使越狱持久化，这意味着你即使重启手机，越狱也不会消失。
- Userland 漏洞
    iOS 系统运行时的漏洞。这种类型的漏洞一般都要求先把漏洞利用工具安装在手机上运行，之后再通过手机进行下一步越狱操作。

越狱的历史，借用希腊神话来打比方的话，大致可以分为三个时代：

## 黄金时代 (<= iOS 4)
由于 Limera1n 漏洞的存在，当时最热门的设备 iPhone 4 几乎每次更新过后不出数十天，redsn0w 就会更新并支持最新版固件的不完美越狱。如前文所说，BootROM 漏洞没有任何办法修复。更重要的是，当时 iPhone 缺少一系列保护措施，甚至连 ASLR 也是在 4.3 才引入的。然而，处于性能方面的考量，使用 BootROM 漏洞加载后会直接改写内核，这就导致了重启后 iPhone 启动链被破坏而进入恢复模式，需要连接电脑才能重新开机，这种越狱被称为引导越狱(tethered jailbreak)，在当时也被大家叫做非完美越狱。

## 白银时代 (iOS 5 - iOS 9)
在 iOS 5 之后，苹果发布的 iPhone 4S 封堵了 Limera1n 漏洞（当然， iPhone 4还是能越狱），并且 iOS 5 新增了很多新的系统机制，导致难度增加。


## 黑铁时代

根据使用漏洞的不同及工具完成程度，越狱会被划分为四种越狱。

## 完美越狱 (untethered jailbreak)
随便重启，越狱状态依然保留。
## 半完美越狱 (semi-untethered jailbreak)
重启之后，越狱消失，但通过桌面上的越狱工具可以重新越狱。
## 引导越狱 (tethered jailbreak)
越狱一般通过连接电脑完成。在越狱完成之后，如果重启手机，则需要连接电脑引导才能开机。
## 半完美引导越狱 (semi-tethered jailbreak)
与引导越狱相同，都需要通过连接电脑来完成越狱。但重启之后，手机会重新进入未越狱状态。

这里着重说明一下引导越狱。

很早以前的引导越狱中，每次苹果一更新 A4 设备的固件（甚至是 beta 固件），redsn0w 总能过几天发布越狱工具。然而，如上文所说的，这些工具越狱后的 iPhone，每次开机都需要引导。原因就是他们只用了 BootROM 层面上的漏洞，让他们能通过 DFU 上传未签名的引导程序。他们在引导成功后直接对root分区进行修改，给系统内核打补丁，破坏了启动链，导致后续的 iBoot 会校验失败而进入引导模式。

然而，这次的 checkra1n 虽然也是引导越狱，但重启后能够正常引导，猜测是每次引导的时候给内核动态打补丁了。



https://www.youtube.com/watch?v=t01tbbjJHbs