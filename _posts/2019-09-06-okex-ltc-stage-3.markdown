---
title: OKEX 藏宝图 第三关 WriteUp
date: 2019-09-06 21:24:53
tags: ["ctf","OKEx","blockchain"]
layout: post
---

OKEx 在 2019 年 7 月 30 日的时候上线了一个" LTC 藏宝图"的活动，这个藏宝图活动与去年 10 月 310 个 BTC 的活动一样，均为 ctf 的 misc 形式，只不过相比 ctf 比赛的 flag，这个活动将 flag 换成了私钥。玩家需要通过各种手段破解藏在图片中的信息，从而获取正确的私钥来取得奖励，现在活动已经完结，作为一个复盘而言，写一下总归是有价值的。这个游戏做的不错，融合了不少比特币相关的知识。

此为第三关 writeup。

<!-- more -->

从第二关中我们获得了第二关的奖励地址 LTSYo5LL7oKopwt62Su2wUqUNcykacj4Fw 。

区块链浏览器查一查，发现 LTSYo5LL7oKopwt62Su2wUqUNcykacj4Fw 为 vout0， 而 vout1 为 LXd4oah1kaCY1GKzoQVEGxCNrzNVRarcqV。

LXd4oah1kaCY1GKzoQVEGxCNrzNVRarcqV 里面有 100 个 LTC，看来这就是我们的目标了。

![explorer](http://umi.cat/pic/okex/stage3-1.png)

嗯？中间还有一笔交易。 刚刚的 vout1 被分成七份发送给了七个地址。

有了上次的经验，我们先把金额转换成字符串看看。

```python
import binascii
v = ["0.06250329","0.03175719","0.07759199","0.06697077","0.07234655","0.06832236","0.06709087"]
h = "".join(hex(int(i[2:]))[2:] for i in v)
print(binascii.unhexlify(h))
```

输出结果为
```
5f5f5930752776655f6630756e645f68406c665f5f
__Y0u've_f0und_h@lf__
```

找到一半了，那剩下一半呢？

这里我们有第二个知识点：

根据 [BIP-13](https://github.com/bitcoin/bips/blob/master/bip-0013.mediawiki)，比特币地址是这样构成的:
```
base58-encode: [one-byte version][20-byte hash][4-byte checksum]
```
而莱特币作为比特币的分叉币，自然也继承了 BIP-13。 其中 version 字段，莱特币为 0x30。

那我们来看看对应的比特币地址，如何呢？

utils 文件取自 pycoin
```python
import utils

bytes = utils.b58decode("LXd4oah1kaCY1GKzoQVEGxCNrzNVRarcqV",25)

version, keyhash, chksum = bytes[0], bytes[1:21], bytes[21:25]
print(version.encode("hex"),keyhash.encode("hex"),chksum.encode("hex"))
print(utils.hash2addr(keyhash))

```

输出
```
('30', '8800895af18dac1775984e46790118bb8a9c48e4', '8e34a920')
1DQ7YNPBfuxUkTdqdGVvzw8cen1DJLKyXr
```

然后去比特币对应的地址看看，果然又是7个vout，先将这七个转为hex之后，再与之前的字符串异或。

```python
v1 = ["0.06250329","0.03175719","0.07759199","0.06697077","0.07234655","0.06832236","0.06709087"]
v2 = ["0.05971248","0.06165134","0.06444911","0.03756588","0.01704236","0.03614729","0.01338584"]
h = "".join(hex(int(i[2:]))[2:] for i in v1)
h2 = "".join(hex(int(i[2:]))[2:] for i in v2)
h = binascii.unhexlify(h)
h2 = binascii.unhexlify(h2)
info = ""
for i in range(len(h)):
    c = ord(h[i]) ^ ord(h2[i])
    info +=chr(c)
    
print(info)
print("hex: "+info.encode("hex"))
```
结果是这个字符串（注意中间有不可见字符）
```
Bing�20_bYtes_her3�
hex: 0442696e67a91432305f62597465735f6865723387
```

这个 hex 可以转换为对应的 bitcoin opcode :

| Hex                                       | opcode                    |
| ----------------------------------------- | ------------------------- |
| 04                                        | PUSH 4 bytes              |
| 42 69 6e 67                               | [4bytes]"Bing"            |
| a9                                        | OP_HASH160                |
| 14                                        | PUSH 20 bytes             |
| 32 30 5f 62 59 74 65 73 5f 68 65 72 33 87 | [20bytes]"20_bYtes_her3." |


20 bytes！ 听起来有点耳熟？




看看 (BIP-16)[https://github.com/bitcoin/bips/blob/master/bip-0016.mediawiki] 定义的 P2SH 怎么说吧。
> scriptSig: [signature] {serialized script}
> scriptPubKey: OP_HASH160 [20-byte-hash-value] OP_EQUAL

😯，20 byte 的 hash！ 不过，是hash什么呢？

要理解上面的内容，我们就要从最传统的比特币转账交易 P2PKH 开始说起。

P2PKH中，上面那两个东西长这样：
> scriptSig:   [signature] [pubkeyHash]
> scriptPubkey: OP_DUP OP_HASH160 [pubkeyHash] OP_EQUALVERIFY OP_CHECKSIG

其中， scriptPubkey 是一把锁，scriptSig 是钥匙。

scriptPubkey 代表之前一个交易的发起者，将一部分他的 utxo，通过这个加锁脚本锁了起来。只有 PubkeyHash 的私钥持有者，通过验证签名才能解锁。比特币系统在转账时，会将 scriptSig 和 scriptPubkey 拼接起来，如果完全执行成功，说明解锁成功。

拼接起来长这样:
[signature] [pubkeyHash] OP_DUP OP_HASH160 [pubkeyHash] OP_EQUALVERIFY OP_CHECKSIG

举个例子吧，假设 A 转账给你一笔比特币，那么，他需要在输出的 utxo 中，把你的公钥写在 scriptPubkey 上，然后广播出去。这样，所有比特币节点都知道有这么一笔 utxo ，所属权已经转给了 Pubkey 私钥的持有者，如果你有私钥，那么这笔 utxo 你就可以轻松解锁花掉。

不过， P2PKH 有很多局限性，比如他只能将 utxo 移交给一个 Pubkey。为了应对这种问题，P2SH 出现了。我们经常说的多重签名，实际上指的就是他，不过，P2SH 可以做的可不止多重签名。

话不多说，我们先把这两拼起来，看看跟 P2PKH 有什么不同:

[signature] {serialized script} OP_HASH160 [20-byte-hash] OP_EQUALVERIFY

跟上面opcode对一对，感觉 hex 就是这一段 `{serialized script} OP_HASH160 [20-byte-hash]`，其中构造的script就是42 69 6e 67。

未完待续。