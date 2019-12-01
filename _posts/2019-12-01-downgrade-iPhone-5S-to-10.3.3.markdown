---
title: "无SHSH将iPhone5S降级到10.3.3"
date: 2019-12-01T15:36:59+08:00
draft: false
tags: ["iPhone","jailbreak"]
layout: post
---

前几天琢磨着写一篇有关 iPhone 越狱的文章，奈何手里没有越狱机器，只有一台 iPhone 5S，但这台机器作为信息转发机早已被我升级到 iOS 13。无奈之下，只好亲自动手开始降级。

我从红雪时代开始就再也没有接触过 iPhone 降级这种事情了，所以遇到了不少坑，在这里我会将这些坑一一记录下来。

# 0x01 常见疑难解答

Q: 为什么可以降级？不是说 iPhone 一旦苹果服务器关闭某个版本的验证之后就不能刷机了吗？
A: 因为 checkm8 漏洞的出现，使得DFU模式可以传入自制 iBEC/iBSS，从而破坏整个引导链，最后进入刷机。

Q: 为什么不降级到更早的版本？比如iOS 7.1.1？
A: 苹果已经关闭那些版本的激活服务器，如果强行刷入，即使通过越狱删除系统文件进入界面，也会失去通信功能与iCloud相关功能。

同时，这个刷入 iOS 10.3.3 利用的似乎是OTA包，而不是普通的刷机包，所以可以实现无引导启动。如果刷入别的固件，可能需要每次手动进入DFU模式引导才能启动。这是一个猜测，暂时还没有验证。


# 0x02 步骤

目前市面上已经有不少工具支持降级，其中我使用的是[https://devluke.gitlab.io/stablea7/](StableA7)。

这个工具将安装依赖与刷机集成到一个文件中，只需通过一个命令即可以自动下载并安装所有依赖：

```bash
bash <(curl -s https://gitlab.com/snippets/1907816/raw)
```

在实际操作过程中，需要下载所对应设备的10.3.3系统固件，比如我的是`iPhone6,1`，那么我要下载的固件就是`iPhone_4.0_64bit_10.3.3_14G60_Restore.ipsw`。

要注意的一点是，这个工具只支持 mojave 和 catalina。

之后根据实际操作进入DFU模式，然后它会要求你选择降级方式，有两种方法可以选择：

- Normal/Auto
- /rsu

其中方法2需要futurerestore加载额外的dylib，这个方法成功率非常高，但我不知道为什么futurerestore非得读取根目录，由于这个原因，我们需要关闭macOS的rootless功能，并且给予root权限。

之后它会调用ipwndfu尝试进入pwned模式，这个步骤可能会循环很久，因为堆风水并不一定能保证一次成功。总而言之，进入之后，它就会开始发送iBEC/iBSS，如果成功载入上述引导，设备会显示绿色屏幕，然后一路回车直接刷机。（理想情况）

# 0x03 遇到的问题

## 一阶段没有显示绿色屏幕/iBEC卡在80%左右（如下所示）
```
==> Sending test file to device...
[==================================================] 100.0%
==> Sending patched iBSS/iBEC to device...
[=============================================     ] 81.5%
```

解决方法：换线！

没错，就这么简单粗暴。 我是新款MacBook Pro，用了一根usb-c的线，折腾了好久，绝望之下死马当活马医，找来一根usb-a的转换器，换了一根usb-a的线，结果就成功了。

## dyld: Library not loaded
```bash
umi@umi StableA7 % bin/futurerestore --exit-recovery
dyld: Library not loaded: /usr/local/opt/usbmuxd/lib/libusbmuxd.4.dylib
  Referenced from: /Users/umi/Desktop/1033-OTA-Downgrader/new/StableA7/bin/futurerestore
  Reason: image not found
```

解决方法：下载`libusbmuxd.4.dylib`。

这里，如果你安装了高版本libusbmuxd.6.dylib，千万不要自作聪明建立alias，这样futurerestore可以成功执行，但一旦刷机，就会报错。

## 卡在Checking filesystem (15)
```bash
Personalizing IMG4 component iBoot...
Personalizing IMG4 component RestoreSEP...
Personalizing IMG4 component SEP...
Sending NORData now...
Done sending NORData
About to send RootTicket...
Sending RootTicket now...
Done sending RootTicket
Waiting for NAND (28)
Checking filesystems (15)
```
解决方法：等

## 激活iCloud时提示KVS synchronizeWithCompletionHandler failed
解决方法：按下 Home 键，选没有Apple ID，进入桌面后注销重新登录。
