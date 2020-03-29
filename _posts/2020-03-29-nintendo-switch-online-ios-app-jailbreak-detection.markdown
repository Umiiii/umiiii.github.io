---
title: "iOS Nintendo Switch Online app 闪退的解决方法"
date: 2020-03-29T17:49:59+08:00
draft: false
tags: ["iPhone","jailbreak","nintendo"]
layout: post
---

任天堂的 iOS 手机 app Nintendo Switch Online 具有与 switch 联动的功能，但鉴于任天堂一贯对黑客精神的严防，这个 app 在 iOS 上实行了非常严格的越狱检测，甚至连你重启恢复未越狱状态也不行，各种反越狱检测插件自然也不行。

研究了一会，发现唯一的办法就是安装 SnapBack 插件，恢复被越狱修改的 rootfs 分区。
具体操作很简单，先安装 SnapBack 插件，然后点击右上角的 + 号创建一个 APFS 快照，然后回退到原始orig-fs中，此时 SnapBack 会进行一段进度条，进度条结束后会黑屏，退出 SnapBack 你会发现所有越狱 app 的名字都消失了，此时直接打开 app 即可。
