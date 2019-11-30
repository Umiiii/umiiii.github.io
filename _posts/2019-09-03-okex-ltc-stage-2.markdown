---
title: OKEX 藏宝图 第二关 WriteUp
date: 2019-09-03 12:55:08
tags: ["ctf","OKEx","blockchain"]
layout: post
---

OKEx 在 2019 年 7 月 30 日的时候上线了一个" LTC 藏宝图"的活动，这个藏宝图活动与去年 10 月 310 个 BTC 的活动一样，均为 ctf 的 misc 形式，只不过相比 ctf 比赛的 flag，这个活动将 flag 换成了私钥。玩家需要通过各种手段破解藏在图片中的信息，从而获取正确的私钥来取得奖励，现在活动已经完结，作为一个复盘而言，写一下总归是有价值的。这个游戏做的不错，融合了不少比特币相关的知识。

此为第二关 writeup。

<!-- more -->

在第一关的最后，我们获得了十二个地址，从这十二个地址转账中我们发现，每一个地址中都有一个交易。这个交易一共有三个 vout 。其中 vout0 为地址的 utxo，vout1为一串可疑的01字符串，vout2为找零。

那么一个很自然的想法就是先把这些字符串整理出来：

| Address                            | LTC        | Hash                                                         |
| ---------------------------------- | ---------- | ------------------------------------------------------------ |
| LgzYLJQxoo6Tzciahyeru3hEx6RsS2bNSf | 0.01001010 | e92c06e376876e9218ab9126fcc49f04afaf8e8d87372bf6b03becab01d0a021 |
| LU5bQkFBcDMS2At6YG1xe44nWtC8VtP6Ms | 0.01010001 | 624ad997f6bed92c446fe4c6419ce392730f330a409b93394c74468da500c53d |
| Lh17sPSpzNticZTqPgyywEheV8zVs5EMje | 0.01000101 | 00958d203d2040f66ea8d6b2ee209ee787b7329d459d3948fa157324c498d062 |
| LZD7bL865BGEdtNfsjh32pPtwZZexhcnRc | 0.01001011 | d223e8271bfb324ae7421ff2ff3561011cfc423a69229733ae65b7f701c24bfc |
| LMRQquyyxV3x3oKUNi1XVW2soN3hshurkj | 0.01001010 | 15ff37f72dfccb7f15c3f917bf556db810df8da316fc5ceacdb3a06bfff6b925 |
| LXDaymVT3MYxFzxxr8z1yRu786dD8u74B8 | 0.01010001 | c86533737c84426d69c690148a1f6a1ebb6cb8dce8af5fabaa62af5139531b21 |
| LXXASRZp1nojbTGyq1dZrwTRvZyj6QwaMA | 0.01000101 | acb7447fec1edb10a84f23eaa6de0f098b75d5a87a8d5db87ebc7ebc27969540 |
| LP8kLTRCUDCeKLjDt7hHBrLpozo6GUUoM2 | 0.01001011 | ee61083111270e87291f3a2a362f2699314cfad9421f9ecb5b9845a7c220c28a |
| LYMR6SmtqfPgj9gBBJz2rzu8UjujTQroMY | 0.01001010 | b3c91056ae64eb359efb380db3855c791ef37700b9030c59163008150595a3b1 |
| Ldxzgxbsfob3eaouwL1RAVGDtfBvPjr9Zh | 0.01010001 | 34112eb9ad6e86c016453e6505b9618e3858512260fa5750aa60c6d147ec2adf |
| LfGrSFv1Cg2i93b2KburFicpnuRGMBHtm2 | 0.01000101 | fd6e0b4e962f6bbbc90dddf958296564a9c883b8af2a423e81fbc0ace0fd7e7c |
| Lbzma9yHoKnvUUPzCSCvXtaz9P9pfMdU7p | 0.01001011 | 975a1397b5d04119c57524ce69a2f98cc5c3b8b7f1c488ee90ce8f6a47a69f11 |

[0.0100101, 0.01010001, 0.01000101, 0.01001011, 0.0100101, 0.01010001, 0.01000101, 0.01001011, 0.0100101, 0.01010001, 0.01000101, 0.01001011]

转为ascii码为'JQEKJQEKJQEK'

然后我就卡住了。

参考这个地址，写出了剩余的解题过程

https://www.chainnode.com/post/360569-24

首先，我们把每个01字符串看成一个截取规则。
例如，0b3e61cc在01001010截取规则下的结果为b6c。
```
0b3e61cc
01001010
 b  6 c  
```

然后我们以12个vout1地址为输入，vout1金额为截取规则，输出12个短字符串k。

| Address                            | Vout1      |
| ---------------------------------- | ---------- |
| MKE34mPVVaMUbV66vybUY8eKgBy2JbGfFb | 0.01001010 |
| MLZDb5gfcnHvuBEHtwquQnVaKw5n1e8qHt | 0.01010001 |
| MV3Do2q6NzsteiB5245usYtywF2onkURTw | 0.01000101 |
| MFUkMzXQK4hNTv69334W5oik6jX1Q1VFQD | 0.01001011 |
| MUmGxvkvJ2b3vTpNFQsLSgqnSPv3Eci5eb | 0.01001010 |
| MQQEMy8tyfZBAz76MqDXZ2RbRpT8cdRuP4 | 0.01010001 |
| MMZXU9Xwad5TPQhppe2jBwrhDs2kkzC4Bq | 0.01000101 |
| MB9TKjwtASBsDAr59tLEVXdS7XQJELZFuV | 0.01001011 |
| MPMQvnRaiAwHxQLXWNmUpzfqM8TwThZ751 | 0.01001010 |
| MTwGBRdXL7L1MLTKoY3gcSKCcheKJekdk7 | 0.01010001 |
| MVtDH3MKoCRke6NwBaZwj7hW63e4GSjyoM | 0.01000101 |
| MTCTCKDHGMBwA6uqbCGZpLtaAyKNE1RUyR | 0.01001011 |

```python
addr = ["MKE34mPVVaMUbV66vybUY8eKgBy2JbGfFb",
        "MLZDb5gfcnHvuBEHtwquQnVaKw5n1e8qHt",
        "MV3Do2q6NzsteiB5245usYtywF2onkURTw",
        "MFUkMzXQK4hNTv69334W5oik6jX1Q1VFQD",
        "MUmGxvkvJ2b3vTpNFQsLSgqnSPv3Eci5eb",
        "MQQEMy8tyfZBAz76MqDXZ2RbRpT8cdRuP4",
        "MMZXU9Xwad5TPQhppe2jBwrhDs2kkzC4Bq",
        "MB9TKjwtASBsDAr59tLEVXdS7XQJELZFuV",
        "MPMQvnRaiAwHxQLXWNmUpzfqM8TwThZ751",
        "MTwGBRdXL7L1MLTKoY3gcSKCcheKJekdk7",
        "MVtDH3MKoCRke6NwBaZwj7hW63e4GSjyoM",
        "MTCTCKDHGMBwA6uqbCGZpLtaAyKNE1RUyR"]
vout = ["0.01001010",
        "0.01010001",
        "0.01000101",
        "0.01001011",
        "0.01001010",
        "0.01010001",
        "0.01000101",
        "0.01001011",
        "0.01001010",
        "0.01010001",
        "0.01000101",
        "0.01001011"]
def f(addr,vout):
    result = ""
    vout = vout.replace("0.","")
    for i in range(len(vout)):
        if vout[i] == '1':
            result += addr[i]
    return result

k = []
for kv in zip(addr,vout):
    k.append(f(kv[0],kv[1]))
    
print(k)
```


最后，以JQEK为密钥，使用维吉尼亚密码加密，得到最终答案。

至于为什么是维吉尼亚密码，需要用到一点密码学的小知识。

观察得到JQEK重复了三次，而维吉尼亚密码中，若密钥不足明文长度的，则重复此密钥直到补足长度为止，所以猜想需要使用维吉尼亚密码。

```python

def encrypt(plaintext, key):
    key_length = len(key)
    key_as_int = [ord(i) for i in key]
    plaintext_int = [ord(i) for i in plaintext]
    plaintext = filter(str.isalpha,plaintext).upper()
    ciphertext = ''
    for i in range(len(plaintext_int)):
        value = (plaintext_int[i] + key_as_int[i % key_length]) % 26
        ciphertext += chr(value + 65)
    return ciphertext
f = []
for _ in k:
    f.append(encrypt(_,"JQEK"))
print(f)
final = ''.join(f)
print(final)
key = network.keys.bip32_seed(final)
print(key.address())
```

输出:

```python
['TF', 'UTJ', 'E', 'OCBA', 'DNO', 'ZUX', 'VM', 'KAAD', 'YLV', 'CWB', 'EA', 'CSHR']
TFUTJEOCBADNOZUXVMKAADYLVCWBEACSHR
LTSYo5LL7oKopwt62Su2wUqUNcykacj4Fw
```
看到LTSYo5LL7oKopwt62Su2wUqUNcykacj4Fw有30个LTC，本关结束。

从key里扒拉出私钥吧。

这里有几个自己踩过的坑:

- 使用vout0地址而不是vout1地址作为筛选输入
- 使用M开头的找零地址而不是3开头的地址作为输入
    - 为了防止与比特币的Segwit地址混淆，莱特币启用了M地址，3地址与M地址是等效的。(例：3D1tksyXYTW3nypCq6c8iVPvMVNaJ6CYdd与MKE34mPVVaMUbV66vybUY8eKgBy2JbGfFb)
    - 之前有很长一段时间不能理解为什么攻略作者能顺利筛选出来k，而自己死活筛选不出来，后来发现自己使用的区块链浏览器不支持M地址，白忙活了好久。
- 维吉尼亚密码不转换数字，因此过滤掉数字`filter(str.isalpha,plaintext)`
- 字符串要全大写 `.upper()`
- 与第一关不同，每个字符串间不留空格