---
title: OKEX 藏宝图 第一关 WriteUp
date: 2019/08/07 15:30:00
tags: ["ctf","OKEx","blockchain"]
layout: post
---



OKEx 在 2019 年 7 月 30 日的时候上线了一个" LTC 藏宝图"的活动，这个藏宝图活动与去年 10 月 310 个 BTC 的活动一样，均为 ctf 的 misc 形式，只不过相比 ctf 比赛的 flag，这个活动将 flag 换成了私钥。玩家需要通过各种手段破解藏在图片中的信息，从而获取正确的私钥来取得奖励，现在活动已经完结，作为一个复盘而言，写一下总归是有价值的。这个游戏做的不错，融合了不少比特币相关的知识。

此为第一关 writeup。



# 规则介绍

["关于OKEx上线-LTC藏宝图-活动的公告"](https://support.okex.com/hc/zh-cn/articles/360031392471-%E5%85%B3%E4%BA%8EOKEx%E4%B8%8A%E7%BA%BF-LTC%E8%97%8F%E5%AE%9D%E5%9B%BE-%E6%B4%BB%E5%8A%A8%E7%9A%84%E5%85%AC%E5%91%8A)


1. 藏宝图中总共藏有142.579436个LTC；
2. 藏宝图中隐藏着3道关卡，需要依次破关；
3. 关卡的答案对应钱包的密钥，参与者在破关成功后可以将奖励直接转走；
4. 藏宝图关卡及奖励分布如下

| **关数** | **奖励**                                                     |
| -------- | ------------------------------------------------------------ |
| 第一关   | 共12.579436 LTC（分布在12个地址内，即最多可有12个用户获得第一关奖励） |
| 第二关   | 共30LTC（存放在一个地址内）                                  |
| 第三关   | 共100LTC（存放在一个地址内）                                 |

老实说，一开始有点想吐槽最后的“因账户地址包含藏宝图的线索，为保证活动的公平公正，奖励地址会在活动结束后公布“，因为我觉得区块链上的信息应该谁都能获取，对这些信息隐藏没有意义。但实际上我错了，第三关居然用到了这些信息，而隐藏地址显然会增加破解的难度，想要通过区块链上的数据获取目标地址无异于大海捞针。





# 第一关

图片留意到一段莫斯电码

.../-/./--./.-/-./---/--./.-./.-/.--./..../-.--

解得

steganography

很明显了，上[Stegsolve](http://www.caesum.com/handbook/Stegsolve.jar)。（实际上我一开始根本没看到莫斯电码，直接就上了）

![stage1-1](https://umiblog.oss-cn-shenzhen.aliyuncs.com/okex-ltc/stage1-1.gif)

![](https://umiblog.oss-cn-shenzhen.aliyuncs.com/okex-ltc/solved.png)

然后拿到了第一张图片，之后所有的解谜都从这里开始。

首先，我们看到在(400,400)处有一个很小的点，这个代表圆心，周围的点和空白分别代表 0 和 1。

顺时针将这个圆圈上的点都转换为 0 和 1。

代码如下:

```python
import matplotlib.image as mpimg
import binascii
import math
I = mpimg.imread('./solved.png')

s = ""

# r = 400
# (x-450) ^2 + (y-450)^2 = 160000

r = 400
for i in range(360):
    x = r * math.sin(math.radians(i)) + 450
    y = r * math.cos(math.radians(i)) + 450
    x = int(round(x))
    y = int(round(y))
    if I[x,y][2] != 1:
        s+='1'
    else:
        s+='0'
print(s)
print(binascii.unhexlify('%x' % (int(s,2))))
```

执行结果如下：

```bash
010010000100100100100000010011000101010001000011001000000100100001010101010011100101010001000101010100100010000001010111010001010100110001000011010011110100110101000101001000000011001000100000010011110100101100100000010011000101010001000011001000000100011101000001010011010100010100100000010011110010000001001011001000000100010100100000010110000000000000000000
HI LTC HUNTER WELCOME 2 OK LTC GAME O K E X
```

圆圈这个地方实际上第二天就有人解出来了，然后被直接发在了微博底下。大家都不知道怎么把这些单词与助记词联系起来，我甚至还觉得这个可能只是一个热身，然后对着右下角的点阵图案死磕。

官方在此期间发出的提示有很多：

| 提示                                | 来源                                         | 公布时间   |
| ----------------------------------- | -------------------------------------------- | ---------- |
| b c d e f g h i j k l a             | @OKEx                                        | 7-30 14:44 |
| l k j i h g f e d c b a             | @[莱特币中国社区](https://weibo.com/LTChome) | 7-31 00:31 |
| a c e g i k b d f h j l             | @OKEx                                        | 7-31 12:56 |
| ab bc cd de ef fg gh hi ij jk ka lb | @OKEx                                        | 7-31 16:02 |
| j k l a b c d e f g h i             | @[莱特币中国社区](https://weibo.com/LTChome) | 7-31 12:03 |
| g h i j k l a b c d e f             | @OKEx                                        | 7-31 17:06 |
| b d f h j l a c e g i k             | @OKEx                                        | 8-01 16:16 |

@[OKEx](https://weibo.com/bafanghuzhu) 和 @[莱特币中国社区](https://weibo.com/LTChome) 这两个账号要求参加者在对应微博下转发、评论或点赞，达到一定次数时解锁线索。但目前来看，整个区块链生态在微博上应该没有这么高的活跃度，于是不知道哪个大哥去淘宝买了一堆转发，评论和点赞，随着僵尸号把量刷上去之后，这些线索就一个一个地冒出来了。在第七个线索公布时，所有的 LTC 都被拿走，于是线索就没有继续公布。

那么，如何通过这些线索和上面的单词来取得 LTC 呢？

这就涉及到了 BIP-32 了。

#### BIP-32

首先，BTC 的每个地址都由一个或者多个私钥来控制。但是，若一个人持有多个地址，那么管理对应的私钥则会是一件非常麻烦的事情。 BIP-32 提出了一种名叫 Hierarchical Deterministic Wallets （HD 钱包）的理念，允许一个种子来管理多个私钥。其中，主私钥能够推导出子私钥，反之则不行。



其中， Master key 的生成方法如下: （参考资料:https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki
![0*pJlDPg23_yNzMRPa](https://learnblockchain.cn/images/3ec7468aa49d907b0ec66b5d8b41a0a1.png)


我们可以发现，虽然正常HD钱包的生成路径中，根种子是固定位数的，但 HMAC-SHA512 是一个哈希函数，这就意味着，我们的输入长度可以不是 128, 256 或 512。

回过头来观察一下，我们取得了如下字符串:

```
HI LTC HUNTER WELCOME 2 OK LTC GAME O K E X
```
刚好十二个，而上面的提示也是十二个字母（或字母对）排列组合。
结合一下上面的提示，怎么样？
令 a = "HI" , 以此类推。
```python
from pycoin.symbols.ltc import network
s = "HI LTC HUNTER WELCOME 2 OK LTC GAME O K E X".split(" ")
order = "b c d e f g h i j k l a".split(" ")
final = []
for o in order:
    final.append(s[ord(o)-ord("a")])
final = ' '.join(final)
key = network.keys.bip32_seed(final)
print(key.address())
```
输出
```
LgzYLJQxoo6Tzciahyeru3hEx6RsS2bNSf
```
到区块链浏览器看一下，有余额，说明第一关宣告结束。其他十一个以此类推。

seed[0] 从第二个开始:

"LTC HUNTER WELCOME 2 OK LTC GAME O K E X HI":

地址: "LgzYLJQxoo6Tzciahyeru3hEx6RsS2bNSf"

 

seed[1] 逆序:

"X E K O GAME LTC OK 2 WELCOME HUNTER LTC HI":

地址: "LU5bQkFBcDMS2At6YG1xe44nWtC8VtP6Ms"

 
seed[2] 跳序 :

"HI HUNTER 2 LTC O E LTC WELCOME OK GAME K X":

"Lh17sPSpzNticZTqPgyywEheV8zVs5EMje"

 
seed[3] 相邻单词连接 :

"HILTC LTCHUNTER HUNTERWELCOME WELCOME2 2OK OKLTC LTCGAME GAMEO OK KE EHI XLTC":

"LZD7bL865BGEdtNfsjh32pPtwZZexhcnRc"

 

seed[4] 从中间开始:

"LTC GAME O K E X HI LTC HUNTER WELCOME 2 OK":

"LMRQquyyxV3x3oKUNi1XVW2soN3hshurkj"

 

seed[5] 跳序 * 2 :

"LTC WELCOME OK GAME K X HI HUNTER 2 LTC O E":

"LXDaymVT3MYxFzxxr8z1yRu786dD8u74B8"

 

seed[6] 逆序相邻单词连接 :

"XE EK KO OGAME GAMELTC LTCOK OK2 2WELCOME WELCOMEHUNTER HUNTERLTC LTCHI HIX":

"LXXASRZp1nojbTGyq1dZrwTRvZyj6QwaMA"

 

seed[7] 用字符串比较的方式排序单词:

"2 E GAME HI HUNTER K LTC LTC O OK WELCOME X":

"LP8kLTRCUDCeKLjDt7hHBrLpozo6GUUoM2"

 

seed[8] 反向排序:

"X WELCOME OK O LTC LTC K HUNTER HI GAME E 2":

"LYMR6SmtqfPgj9gBBJz2rzu8UjujTQroMY"

 

seed[9] 从第3个单词开始 :

"WELCOME 2 OK LTC GAME O K E X HI LTC HUNTER":

"Ldxzgxbsfob3eaouwL1RAVGDtfBvPjr9Zh"

 

seed[10] 从第7个单词开始 :

"GAME O K E X HI LTC HUNTER WELCOME 2 OK LTC":

"LfGrSFv1Cg2i93b2KburFicpnuRGMBHtm2"

 

seed[11] 从第9个单词开始 :

"K E X HI LTC HUNTER WELCOME 2 OK LTC GAME O":

"Lbzma9yHoKnvUUPzCSCvXtaz9P9pfMdU7p"

第一关圆满结束，撒花。
