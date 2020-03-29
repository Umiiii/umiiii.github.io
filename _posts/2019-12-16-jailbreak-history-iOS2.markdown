---
title: "iOS 越狱史及技术简析 - iOS 2"
date: 2019-12-16T04:15:59+08:00
draft: false
tags: ["iPhone","jailbreak"]
layout: post
---

# 回顾

在上一篇文章中，我们已经提到了苹果对 iOS 1 的安全保护正在一步一步进化中。截止 iOS 1.1.5，从上至下层级排列，iOS 的安全措施如下

| 名称            | 出现版本  | 说明                                                         |
| --------------- | --------- | ------------------------------------------------------------ |
| Secure Boot     | iOS 1.0   | 启动链的每个环节都会负责验证下一阶段的签名                   |
| fsroot 只读     | iOS 1.0   | 系统盘 /dev/disk0s1 默认是只读的                             |
| AFC Restriction | iOS 1.0   | iPhone 通过 AFC 服务与电脑进行数据交换，这个服务默认只允许宿主机访问`/Media`目录 |
| 固件加密        | iOS 1.1   | `IMG2`格式的系统固件通过`Key 0x837`被加密                    |
| mobile 用户     | iOS 1.1.3 | 在此之前，所用应用程序均使用`root`权限运行                   |

[^1]: https://www.theiphonewiki.com/wiki/25C3_presentation_%22Hacking_the_iPhone%22

随后，2008 年 7 月 1 日， 苹果推出了 iOS 2 更新，同时推出了 iPhone 3G，更重要的是，App Store 开始内置在 iPhone 内，这意味着用户可以自己下载并安装应用程序了。相对应的，iOS 新增了以下安全机制:

