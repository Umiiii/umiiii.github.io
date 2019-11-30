---
title: macOS 10.15 Catalina 中 使用 Apple Watch 进行 sudo 鉴权
date: 2019-10-01 14:41:50
tags: ["macOS","Apple Watch"]
layout: post
thumbnail: https://umiblog.oss-cn-shenzhen.aliyuncs.com/macOS/title1.png
---
# 简介

最近更新了 macOS 10.15，sidecar（官方中文叫随航）确实好用，不过我在闲逛官网的时候发现了另外一个功能，如题图所示。
实际测试了一下，效果确实好使。

问题有二：
- 可以让 sudo 也支持这个功能吗？
- Apple Watch 时不时无法连接，需要重启才能连回，有办法检测 Apple Watch 的连接状态吗？


<!-- more -->

# 初探

翻看了一些资料，找到了之前使用 Touch ID 鉴权 sudo 的方法：
在 `/etc/pam.d/sudo` 中加入 `auth       sufficient     pam_tid.so`。
那么这一招对 Apple Watch 是否管用？

一开始，我的想法是，会不会有类似 pam_watch.so 的 pam 文件？

macOS 的默认 pam 文件夹在 /usr/lib/pam，看了看，里面并没有新增什么东西。

我们首先按照老方法直接加入，经过测试之后发现，当拉起 Touch ID 验证窗时，手表也会收到鉴权提示，证明此方法有效。

那么就这么解决了吗？并没有。

当电脑合盖连显示器之后，这个鉴权就失效了，回退到原本的密码输入中，想解决这个问题，还需要进一步探究原理。


# macOS 的鉴权机制
macOS 有两套鉴权机制，一套是 pam.d ，另一套则是 LocalAuthentication.framework。
![](https://docs-assets.developer.apple.com/published/08a1846d5e/b32218fc-f538-412c-80d7-183c920d9429.png)

查看源码后我们得知，`pam_tid`是对后者的一个封装。
https://opensource.apple.com/source/pam_modules/pam_modules-173.50.1/modules/pam_tid/pam_tid.c.auto.html

也就是 sudo -> pam_tid.so -> LocalAuthentication.framework -> 指纹或手表验证，这样一条调用链

观察到这一段：

```c
    /* evaluate policy */
    if (!LAEvaluatePolicy(context, kLAPolicyDeviceOwnerAuthenticationWithBiometrics, options, &error)) {
        // error is intended as failure means Touch ID is not usable which is in fact not an error but the state we need to handle
        if (CFErrorGetCode(error) != kLAErrorNotInteractive) {
            os_log_debug(PAM_LOG, "policy evaluation failed: %ld", CFErrorGetCode(error));
            retval = PAM_AUTH_ERR;
            goto cleanup;
        }
    }
```

该段代码执行 LAEvaluatePolicy 调起生物识别。
找一下 macOS 10.15 的 SDK 头文件:

``` Objective-C
// LocalAuthentication.framework/Versions/A/Headers/LAPublicDefines.h
#define kLAPolicyDeviceOwnerAuthenticationWithBiometrics        1
#define kLAPolicyDeviceOwnerAuthentication                      2
#define kLAPolicyDeviceOwnerAuthenticationWithWatch             3
#define kLAPolicyDeviceOwnerAuthenticationWithBiometricsOrWatch 4
```

果不其然，相比 10.14 新增了 `Watch` 和 `BiometricsOrWatch`。

那是什么原因导致我们合盖就无法鉴权的呢？

## 猜测一：Apple Watch 的鉴权和 Touch ID 是同时进行的(and)，当 Touch ID 无法执行时（即合上电脑），Apple Watch 也会返回无法执行。

做个实验：

``` Objective-C
BOOL can = [context canEvaluatePolicy:kLAPolicyDeviceOwnerAuthenticationWithWatch error:&error];
LABiometryType bioType = context.biometryType;
NSLog(@"%hhd",can);
```

| 枚举                                                    | 状态 | 返回值 |
| ------------------------------------------------------- | ---- | ------ |
| kLAPolicyDeviceOwnerAuthenticationWithWatch             | 开盖 | 1      |
| kLAPolicyDeviceOwnerAuthenticationWithBiometricsOrWatch | 开盖 | 1      |
| kLAPolicyDeviceOwnerAuthenticationWithWatch             | 合盖 | 1      |
| kLAPolicyDeviceOwnerAuthenticationWithBiometricsOrWatch | 合盖 | 1      |


证明我们猜测是错误的，而且，用 IDA 打开新版的 pam_tid.so 发现，调用的参数竟然不是 `BiometricsOrWatch` , 而仍是之前的 `Biometric`。
```c
if ( (unsigned __int8)LAEvaluatePolicy(v33, 1LL, v31, &v65) || CFErrorGetCode(v65) == -1004 )
                                            ~~~
```
这是怎么一回事？按照苹果的说法，只有 `BiometricsOrWatch` 才能实现若指纹识别无法使用的情况下使用Watch。

## 猜测二：`kLAPolicyDeviceOwnerAuthenticationWithBiometrics` 的真实表现型为 "BiometricAndWatch"，即猜测一，但 Apple Watch 无法检测的话不影响 Touch ID。

打开 IDA，找到 pam_tid.so，跳转到地址 1FBB，此处语句为 `mov esi,1`，也就是`kLAPolicyDeviceOwnerAuthenticationWithBiometrics`的枚举值。

选择 Edit - Patch Program - Patch Word，将 `0x1BE` 改为 `0x4BE`（即`kLAPolicyDeviceOwnerAuthenticationWithBiometricsOrWatch`的枚举值）
![](patch.png)

然后选择 Apply patches to input file,得到新的 pam_tid.so。

由于pam文件经过签名，我们如果直接使用这个文件，会被 Kill 掉，使用以下语句进行签名：

```
sudo codesign -f -s pam_tid.so
```
其中， `-f` 代表替换原签名，`-s`代表使用 Ad-Hoc 签名。

由于 macOS 的 rootless 机制，我们无法修改 `/usr/lib/pam`。所以签名完成后，你需要找一个文件夹放置，然后重新将 /etc/pam.d/sudo 里面的so文件指向新的so文件。

测试后发现，无论是 Touch ID， 还是 Apple Watch，均能完成鉴权，且在屏幕合盖后，Apple Watch 也能进行独立鉴权。
![](success.png)

不过，有一个缺点，Apple Watch 总是断连，这个问题不知道如何解决。

# 检测 Apple Watch 与 macOS 的连接状态
``` c
LAContext* context = [[LAContext alloc]init];
NSLog(@"%hhd",[context canEvaluatePolicy:kLAPolicyDeviceOwnerAuthenticationWithWatch error:&error]);
```
当 Apple Watch 与 macOS 连接正常时，该值返回 1。问题在于，第一次要求鉴权时，Apple Watch 总是不可用（即返回0），需要等待较久时间才能自动连回电脑。

而 macOS 自带的使用 Apple Watch 解锁基本上每次都能成功，准确地说：
- 运行上述代码，显示 0。
- 锁定 macOS。
- 唤醒 macOS，手表自动解锁。
- 再次运行上述代码，显示 1。

暂时不知道如何实现的，留作以后探究吧。

# 结论

由于未知的原因，系统自带的 pam_tid.so 仍然没有更新，而 `LAContext` 的 `canEvaluatePolicy` 方法将 `kLAPolicyDeviceOwnerAuthenticationWithBiometrics` 的默认表现型改为当 Touch ID 无法执行时（即合上电脑），Apple Watch 也会返回无法执行。

以上结论基于实验与猜测，附上 [pam_tid.so](pam_tid_edit.so) 的修改版。
