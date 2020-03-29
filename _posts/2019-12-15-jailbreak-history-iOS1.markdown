---
title: "iOS 越狱史及技术简析 - iPhone OS (iOS 1)"
date: 2019-12-13T13:27:59+08:00
draft: false
tags: ["iPhone","jailbreak"]
layout: post
---

本文是对自己这么多年以来对 iPhone 越狱学习的一个总结。

总是谈越狱越狱，结果自己连基本核心都没有搞太懂，于是就想从技术角度回顾一下越狱这么多年都做了些什么，也希望能帮到有相同兴趣的人。


# iPhone OS (iOS 1.0) - 2007 年 10 月 
当时，iOS 还被叫做 iPhone OS ，预装在 iPhone 第一代里面。没有 App Store，只有一些基础应用，当然，也没有办法安装新的应用。

苹果一开始的想法是用户只需要使用 Safari 访问 HTML5 应用就够了，所以他们并没有提供 iPhone SDK。这个阶段越狱团队的工作一方面是逆向 iPhone 自带的应用程序，搞清楚 iPhone 原生应用程序是如何工作的，然后提供一套工具链用于开发自制的第三方应用[^1]（事实证明，后来苹果发布的 SDK 就是这套东西），一方面是取得系统 root 权限，然后安装自制铃声和应用程序。

> 一个远古[第三方自制程序](https://github.com/planetbeing/iphonecommunity/blob/44ab6523fe8acb5b176b15960078c69f2ed2a43b/Upgrade.app-113/sources/UpgradeApplication.m)是这样写的


```objc
#import <CoreFoundation/CoreFoundation.h>
#import <Foundation/Foundation.h>
#import <UIKit/UITableColumn.h>
#import <UIKit/UISwitchControl.h>
#import <UIKit/UIAlertSheet.h>
...
void progressCallback(unsigned int progress, unsigned int total, char* formatString, void* application) {
    UpgradeApplication* myApp = (UpgradeApplication*) application;
    [myApp doProgress:progress withTotal: total withFormat: formatString];
}
...
@implementation UpgradeApplication

- (void) applicationDidFinishLaunching: (id) unused
{
    UIWindow *window;
    UIView *mainView;
    struct CGRect rect;
    ...
}
```

[^1]: iPhone Open Application Development, 2nd Edition by Jonathan Zdziarski

这个时候的 iPhone 的安全机制如下:
- 安全引导链（每个引导环节，都会由上一个引导环节检查签名，但bootrom此时不会检查LLB的签名[^2]）
- `fsboot` 默认只读
- AFC 默认只能访问并读写 `/Media`（即`/var/root/Media`)[^2]
- lockdownd 激活锁，防止第三方运营商 SIM 卡使用 iPhone

[^2]: https://mrtopf.de/conferences-and-meetings/25c3-hacking-the-iphone/
所有应用程序都放在`/Application`下，并默认以`root`权限执行，没有代码签名，甚至刷机不会校验 SHSH（iPhone 一代），这意味着你可以随便降级，所以在这个阶段，越狱实际上是非常简单的。


## iBoot cp-command 

iOS 版本: iOS 1.0 - iOS 1.0.2 

利用软件: iBrickr (Windows) / AppTapp Installer (Mac OS X)

严格意义上来说，这并不算一个漏洞，而更像是一个 feature。起因是 Apple 并没有删除恢复模式中的很多命令，比如`cp`。

流程大致如下：
- 让设备进入恢复模式，从固件中找出 Restore Ramdisk 和 kernelcache，然后上传到设备上。
- 创建两个文件 `/var/root/Media/fstab` 和 `/var/root/Media/Services.plist`，后者会创建一个新的服务`com.apple.afc2`，允许通过AFC访问所有文件目录。
- 将 `/dev/disk0s1` 挂载到 `/mnt1`，用户数据`/dev/disk0s2`挂载到`/mnt2`，然后把我们上一步创建的两个文件用`cp`分别替换掉`/mnt1/etc/fstab`和`/mnt1/System/Library/Lockdown/Services.plist`
- iBrickr 还会安装 PXLDaemon 守护进程，这个守护进程可以与电脑端 iBrickr 通信，安装第三方软件包，替换铃声等等。而 AppTapp Install 则会安装 `Installer.app`，其功能与前者大致相同。
- 重启完成越狱。


[^2]: 这里的`/Media`指的是`/root/Media`而并非我们熟知的`/var/mobile/Media`，因为`mobile`用户在iOS 1.0-1.1.2中暂时还不存在，下同。


修复：
- 在 iOS 1.0.2 后更新 iBoot，删除了`cp`以及其他一些命令。

## libtiff-exploit (CVE-2006-3459)

iOS 版本: iOS 1.0 - iOS 1.1.1

利用软件: AppSnapp / JailbreakMe  1.0

核心原理是经典的 buffer overflow --- `libtiff` 在处理 tiff 文件的时候会发生 buffer overflow，允许任意代码执行，只需要让用户访问一个含有tiff图片的网站就可以完成越狱。

碰巧的是，当年 PSP 也饱受 tiff 漏洞的[摧残](https://www.youtube.com/watch?v=WRWJtI-HzpY)，这个漏洞应该是从 PSP 的破解中收到了启发。

shellcode 做了一些微小的工作:
- 将`/var/root/Media`重命名为`/var/root/oldMedia`
- 创建符号链接`/var/root/Media/ -> /`
- 重新挂载`/dev/disk0s1`为读写

```c
    stack.Add(Node(0, Node::PTR));           // r0 = "/var/root/Media"
    stack.Add(Node(1, Node::PTR));           // r1 = "/var/root/Oldmedia"
    stack.Add(Node(20, Node::BYTES));        // r2,r3,r5,r6,r12
    stack.Add(Node(12, Node::STACK));        // sp    -> offset 12
    stack.Add(ldmia_sp_r4);                  // lr = load r4,r7,pc from sp
    stack.Add(rename);                       // pc = rename(r0, r1)

    ...

    stack.Add(Node(2, Node::PTR));           // r0 = "/"
    stack.Add(Node(0, Node::PTR));           // r1 = "/var/root/Media"
    stack.Add(Node(20, Node::BYTES));        // r2,r3,r5,r6,r12
    stack.Add(Node(12, Node::STACK));        // sp -> offset 12
    stack.Add(ldmia_sp_r0);                  // lr = load from r0..pc from sp
    stack.Add(symlink);                      // pc = symlink(r0, r1)

    stack.Add(Node(3, Node::PTR));           // r0 = "hfs"
    stack.Add(Node(2, Node::PTR));           // r1 = "/"
    stack.Add(Node(0x00050000, Node::VAL));  // r2 = MNT_RELOAD | MNT_UPDATE
    stack.Add(Node(8, Node::STACK));         // r3 = **data
    stack.Add(mount);                        // pc = mount(r0, r1, r2, r3)
    stack.Add(Node(4, Node::PTR));           // data = "/dev/disk0s1"
```

完整代码可以在[这里](https://github.com/OpenJailbreak/JailbreakMe-1.0/blob/master/tiff_exploit.cpp)看到。

修复：
- 更新 `libtiff` 库。

## mknod-vulnerability 

iOS 版本: iOS 1.1.2

利用软件： OktoPrep + [touchFree](https://github.com/planetbeing/touchfree)

iOS 1.1.2 版本之后，Apple 修复了 `libtiff` 和 `iBoot cp-command` 的漏洞，然而，因为前文所提到的，iPhone 第一代可以随便刷机，所以新版的方法也很简单粗暴：先在 iOS 1.1.1 动手脚，然后升级到 iOS 1.1.2 继续搞事情。

具体来说：
- 在 iPhone 升级之前，OktoPrep 使用`mknod /var/root/Media/disk c 14 1`直接在用户盘符创建一个字符设备，这句命令的意思是，为主设备号是14，次设备号是1的设备创建一个在`/var/root/Media/disk`的字符设备，这等同于`/dev/rdisk0s1`。（可以使用`ls -lR /dev`查看主次设备号）
- 升级系统到 iOS 1.1.2，由于升级系统只更改fsroot，而我们创建的文件在用户数据分区中，所以不受影响。
- touchFree 检查 `/var/root/Media/disk` 是否存在，然后创建`/var/root/Media/touchFree`文件夹，复制必要文件到此文件夹中。
- 将`/var/root/Media/disk`dump为`rdisk0s1.dmg`，挂载这个dmg文件，修改`/etc/fstab`
- 往[`com.apple.syslogd.plist`](https://github.com/planetbeing/touchfree/blob/f01e306513fd01c678d6e639ac53692daf6b4383/java/resources/required/com.apple.syslogd.new.plist)里面添加`DYLD_INSERT_LIBRARIES:/var/root/Media/touchFree/planetbeing.dylib`环境变量键值对（熟悉逆向的朋友们可能已经猜到了，没错，syslogd在下一次执行的时候会首先被注入这个动态库。）
- 动态库会将touchFree文件夹里的东西复制到`/bin`，创建 AFC2 服务，运行`/var/root/Media/touchFree/run.sh`脚本，然后把自己的注入环境变量删掉。
- 脚本会继续复制`Installer.app`和ssh服务，然后给Springboard和lockdown打补丁。

其中，Springboard 补丁是因为当时 Springboard 显示的程序是写死在`allowedDisplayIcons`里的，所以需要给`[SBIconModel addItemsToIconList: fromPath: withTags:]`和` [SBIconController relayoutIcons]`里面打补丁，让`Installer.app`能显示在主屏幕，而lockdown的补丁主要是绕过iPhone激活锁。

修复:
`/dev/rdisk0s1`被加上了`nodev`，所以不能再用`mknod`创建它的设备文件了。

## Ramdisk Hack

iOS 版本: iOS 1.1.3 - 1.1.5

利用软件: [ZiPhone](https://github.com/Zibri/ZiPhone/) & iLiberty

从 iOS 1.1 开始，iPhone 新增了以下安全机制:
- 新增`mobile`用户，大部分进程都开始以`mobile`权限运行。（iOS 1.1.3）
- 所有固件都被[Key 0x837](https://www.theiphonewiki.com/wiki/AES_Keys#Key_0x837)加密了

这意味着即使应用出现了 libtiff 的 userland 漏洞，也不再能一招吃遍天了。

这次出现的漏洞还是在恢复模式中。之前 Apple 把 `cp` 之类的调试命令删掉了，但是，他们还留了一个`boot-args`环境变量。我们知道，恢复模式需要挂载一个 Ramdisk，这个 Ramdisk 在一般情况下是需要验证签名的。但如果 Ramdisk 的内存地址超过了`0x09C00000`，则无论什么情况下都会启动。

这回我们轻车熟路了，以[ZiPhone](https://github.com/Zibri/ZiPhone/blob/d7dca81b2707fe962f116b23bface18de88f4351/ziphone.cpp)为例：
- AFC 复制必要文件到`/var/mobile/Media`
- 重启进入恢复模式，设置引导环境变量`setenv boot-args rd=md0 -s -x pmd0=0x09CC2000.0x0133D000`（以单用户模式、安全模式启动）
- 发送`bootx`，让 iPhone 从 Ramdisk 启动
- Ramdisk 首先挂载`/dev/disk0s1`，`/dev/disk0s2`，然后复制一些必要的文件，同时修改`/etc/fstab`，开机启动`prof.sh`
```bash
if [ "`/usr/bin/nvram jailbreak 2>/dev/null|/bin/cut -f 2`" == "1" ] ; then
/bin/echo "Starting jailbreak..."
/bin/cp /bin/sh /mnt1/bin/sh
/bin/cp /bin/sync /mnt1/bin/sync
/bin/cp /bin/rm /mnt1/bin/rm
/bin/cp /zib/prof.sh /mnt1/private/etc/profile
/bin/cp /zib/fstab /mnt1/private/etc/fstab
…
fi
```
- 重启，`prof.sh`会完成之后的一系列操作，比如给Springboard打补丁什么的。

修复:
`boot-args`从iOS 2.0开始，在生产环境中不生效。（这一点可以从 iBoot 泄露的源码中看出）
```c
// iBoot/apps/iBoot/main.c
bool
env_blacklist_nvram(const char *name)
{
    static const char * const whitelist[] = {
        ...
#if DEVELOPMENT_BUILD || DEBUG_BUILD
        "boot-args", // factory needs to set boot-args
#endif
        ...
        NULL
    }
    ...
}
```

# 总结

本文回顾了 iPhone OS 中大部分已经公开并使用的越狱工具与他们的利用方法，以及苹果的修补方法。

虽然 iPhone OS 离我们已经有一轮年头了，但从上面的做的事情中，我们可以看出，实际上，越狱所做的东西还是没有变化太多。

就以本文所有越狱工具为例，基本上就做这么几件事:

- 修改 `/etc/fstab`，挂载系统盘为`rw`
- 安装一个软件包管理器(`Installer.app`)，然后安装第三方软件
- 给系统打补丁（解锁，换壁纸，铃声）

为了做这些事情，我们需要:
- 修改系统文件
- 破坏 iOS 引导链

在之后长达 12 年中，围绕着这两件事情，苹果跟安全研究员们展开了斗智斗勇。


# 参考资料

[1] https://www.peerlyst.com/posts/ios-jailbreaks-history-part-1-ivan-ponurovskiy?trk=profile_page_overview_panel_posts

[2] https://www.theiphonewiki.com/

[3] http://blog.iphone-dev.org/