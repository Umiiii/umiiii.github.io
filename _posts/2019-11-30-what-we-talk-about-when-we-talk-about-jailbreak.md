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

写这篇文章，是对自己过去有关 iOS 越狱知识的一个检验，希望同时也能帮助到一些对iOS安全感兴趣，但却又无从下手的人。

本篇不会设计过多的技术细节，可能之后会补充详细要素。

在真正谈论越狱之前，我们需要先熟悉一些基本概念。

# iOS 启动链

一般来说，我们把打开一台*处于关闭状态*设备电源的动作叫做冷启动(cold boot)。

以此类推，iPhone（或iPad/iPod Touch/Apple TV，下同）的冷启动，指的是在 iPhone 关机下按住电源键进行开机操作。

按住电源键后，SoC（什么是SoC？举个例子：A13 Bionic）会被加电，之后，它会运行一段代码来进行后续的引导操作。这段代码被放在 BootROM（苹果也叫它SecureROM） 中 ，在每次冷启动中都会被第一个执行。

与很多人对 ROM 的理解所不同的是，BootROM 是一块 Mask ROM，其制作原理决定了从芯片出场的那一刻开始，里面的内容就无法更改。

除了含有上述所说的引导代码，BootROM 还包含了苹果公司自己家里的根证书公钥。[^1]（下文提及的BootROM，均指其内部储存的引导程序）

由于 ROM 空间比较小，不可能装下一个完整的引导程序，所以这段代码所做的事情，是寻找下一个引导程序，并且在保证下一个引导程序都是合法的情况下将控制权转交给它。在这里，BootROM 通过使用内置的公钥来验证下一段程序的签名，借此判断合法性。

一般情况下，BootROM 会进入正常引导模式。通过特殊按键组合，会进入DFU引导模式。

[^1]: https://www.apple.com.cn/cn/iphone/business/docs/iOS_Security_Guide.pdf, p5

## 正常引导

在 SoC 是 A9 及之前的设备中，引导的每个阶段如下图所示：
```
+-------+   +---+   +-----+   +---+  +---+
|BootROM|-->|LLB|-->|iBoot|-->|XNU|->|iOS|
+-------+   +---+   +-----+   +---+  +---+
```
在之后的设备里，这个阶段被并入iBoot中，所以在 A10 及之后的设备里，引导的每个阶段是这样的：
```
+-------+     +-----+   +---+  +---+
|BootROM|---->|iBoot|-->|XNU|->|iOS|
+-------+     +-----+   +---+  +---+
```
虽然已经并入了iBoot，但你仍然会在ipsw固件文件中发现它的身影(Firmware/all_flash)。

下面对每个阶段进行简短的阐述。

### BootROM
由于体积很小

在验证完下一个阶段程序的签名真实有效之后，BootROM 会显示出苹果的 Logo，初始化SRAM、GPIO，然后把控制权交给它。

### LLB (Low-level bootloader)
一个适配层，负责验证并引导下一个引导阶段iBoot，里面有32位的驱动和Flash Translation Layer的实现[^2]。
FTL是一个用来读写闪存的解决方案，在这里我们不深究。
这个阶段也被称为 iBoot first-stage loader。
如果BootROM无法读取 LLB ，或签名无效，则设备将会进入DFU模式待命。

[^2]: http://esec-lab.sogeti.com/posts/2012/06/28/low-level-ios-forensics.html

### iBoot 
在这个阶段，设备初始化才算大致进入正轨。
iBoot 会验证内核的签名是否有效，然后做一些准备（比如映射设备树），最后和一些参数一并传给XNU内核进行启动。
需要注意的是，与LLB不同，如果iBoot因为损坏或签名无效而无法读取的话，启动过程会停止，但屏幕将会显示连接到iTunes，这就是所谓的恢复模式。

https://www.peerlyst.com/posts/ios-jailbreaks-history-part-1-ivan-ponurovskiy?trk=profile_page_overview_panel_posts
