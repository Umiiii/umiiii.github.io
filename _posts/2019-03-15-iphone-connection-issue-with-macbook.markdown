---
title: Macbook Pro 与 iPhone 连接抽风的解决方案
date: 2019/03/15 13:25:16
tags: ["Apple", "Macbook Pro","iPhone"]
layout: post
lang: cn
---

机器为 2015 Macbook Pro LT2 港版。 

经常进行 iOS 开发，在使用机器左右的 USB 接口连接 iPhone 时，有的时候发现连接不正常，具体表现为：
- Macbook 能够识别 iPhone 插入并试图进行握手，此后立即断开，然后反复尝试重新连接，中间可能还会伴有提示升级 iPhone 连接固件并失败的现象。
- iPhone 进入充电状态，而后在数秒内自行断开。
- iTunes 自行打开，iPhone 图标出现后消失。


一开始猜测是电流的问题，于是换了一个 USB hub ，把 iPhone 接在上面之后解决。
然后猜测是不是跟线也有关系，于是换了一条原装线，比起之前的品胜线，更大概率能够握手成功，但在调试时断开。


# 解决方案
打开活动监视器，找到`usbd`进程，强制停止，之后问题解决。

