---
title: "USDC CCTP Bridge Investigation"
date: 2024-10-01
tags: ["CryptoCurrency", "USDC", "CCTP", "Bridge", "Solana", "Ethereum", "Arbitrum", "Optimism", "Avalanche"]
layout: post
---

# 背景

![CCTP架构图](https://files.readme.io/316de4a-CCTP_architecture_domains2x.png)

跨链转账协议（Cross-Chain Transfer Protocol，简称CCTP）是Circle公司开发的一种无需许可的链上工具。
按照官方说法：
> CCTP 旨在通过原生燃烧和铸造机制，实现USDC在不同区块链网络间的安全转移。CCTP的设计目标是提高资本效率，并在跨链使用USDC时最小化信任要求。

CCTP 不需要KYC，不需要许可，也没有额外的资金损耗。


CCTP的工作原理可以简化为三个步骤：
1. 在源链上燃烧USDC
2. 从Circle获取签名证明
3. 在目标链上铸造USDC

目前，CCTP支持8个区块链网络，包括Arbitrum、Avalanche、Base、Ethereum、Noble、OP Mainnet、Polygon PoS和Solana，形成了56条独特的跨链转账路径。

## 支持的网络

| 主网 | 测试网 |
|------|--------|
| Arbitrum | Arbitrum Sepolia |
| Avalanche | Avalanche Fuji |
| Base | Base Sepolia |
| Ethereum | Ethereum Sepolia |
| Noble | Noble Testnet |
| OP Mainnet | OP Sepolia |
| Polygon PoS | Polygon PoS Amoy |
| Solana | Solana Devnet |
| Sui (即将推出) | Sui Testnet |

## 所需确认数

官网提供了一组[数据](https://developers.circle.com/stablecoins/docs/required-block-confirmations)，用于描述不同链上转账所需的确认数和平均时间。
### Mainnet

| Source Chain | Number of Blocks | Average Time |
|--------------|------------------|--------------|
| Ethereum     | ~65*             | ~13 minutes  |
| Avalanche    | 1                | ~20 seconds  |
| OP Mainnet   | ~65 ETH blocks*  | ~13 minutes  |
| Arbitrum     | ~65 ETH blocks*  | ~13 minutes  |
| Noble        | 1                | ~20 seconds  |
| Base         | ~65 ETH blocks*  | ~13 minutes  |
| Polygon PoS  | ~200*            | ~8 minutes   |
| Solana       | 32               | ~25 seconds  |

### Testnet

| Source Chain      | Number of Blocks | Average Time |
|-------------------|------------------|--------------|
| Ethereum Sepolia  | 5                | ~1 minute    |
| Avalanche Fuji    | 1                | ~20 seconds  |
| OP Sepolia        | 5                | ~20 seconds  |
| Arbitrum Sepolia  | 5                | ~20 seconds  |
| Noble Testnet     | 1                | ~20 seconds  |
| Base Sepolia      | 5                | ~20 seconds  |
| Polygon PoS Amoy  | 1                | ~20 seconds  |
| Solana Devnet     | 32               | ~25 seconds  |


# 目标
由于业务需要，想了解从某条链上跨到另一条链时，实际到账的时间。由于上述步骤中的 Step 2 生成签名依赖 Circle 官方API，这个API我们无法感知具体情况，故需要通过其他方式来获取实际到账时间。
此外，我们还想了解跨链的实际成本如何。

这里我写了一个[脚本](https://github.com/Umiiii/CCTP-Analytics)，用于获取跨链转账的实际到账时间。

当前做了以下几个方向的调研：

1. SOL -> EVM 
2. EVM -> SOL

方案是先从源链中获取指定燃烧事件，然后从目标链中获取指定铸造事件，通过时间差来计算实际到账时间。

## SOL -> EVM

SOL 中 CCTP Program ID 为 CCTPiPYPc6AsJuwueEnWgSgucamXDZwBd53dQ11YiKX3， 其对应燃烧事件为 depositForBurn，事件结构如下：

```
type DepositForBurnArgs = {
    params: {
        amount: BN;
        destinationDomain: BN;
        mintRecipient: PublicKey;
    }
}
```

这里，我们采用debridge-finance的第三方工具解析链上数据。
```typescript
import { SolanaParser } from "@debridge-finance/solana-transaction-parser";
const CCTP_PROGRAM_ID = "CCTPiPYPc6AsJuwueEnWgSgucamXDZwBd53dQ11YiKX3";
const rpcConnection = new Connection(process.env.SOLANA_RPC_URL || "");
const txParser = new SolanaParser([{ idl: CCTPIdl as unknown as Idl, programId: new PublicKey(CCTP_PROGRAM_ID) }]);
  const parsed = await txParser.parseTransaction(
    rpcConnection,
    txSignature
  );
    if (parsed && parsed.length > 0) {
        if (parsed[0].name == 'depositForBurn' && parsed[0].args ) {
            let args = parsed[0].args as DepositForBurnArgs;
            // do something
        }
    }
```

需要注意的是，TxFee并不包含在DepositForBurnArgs中，需要单独获取。

主函数遍历：

```typescript
async function getAllTransactions() {
    const txs = await rpcConnection.getSignaturesForAddress(new PublicKey(CCTP_PROGRAM_ID), {limit: 1000});
    //console.log("Length: ", txs.length);
    for (const tx of txs) {
  
        parseTx(tx.signature).catch((error) => {
            console.error(`Error parsing transaction ${tx.signature}:`, error);
        });
        
        // wait 1 second
        await new Promise(resolve => setTimeout(resolve, 1000));
    }
}
```

对于EVM，我们将mintReceipt 转换为对应的EVM地址即可
```typescript
function publicKeyToEthereumAddress(publicKey: PublicKey) {
    let hash = (publicKey as any)._bn as BN;
    return "0x"+hash.toString(16);
}
```

## EVM -> SOL

对于 EVM，官方给出了另外一组合约对应的表格：

| Chain       | Domain | Address                                    |
|-------------|--------|-------------------------------------------|
| Ethereum    | 0      | 0xbd3fa81b58ba92a82136038b25adec7066af3155 |
| Avalanche   | 1      | 0x6b25532e1060ce10cc3b0a99e5683b91bfde6982 |
| OP Mainnet  | 2      | 0x2B4069517957735bE00ceE0fadAE88a26365528f |
| Arbitrum    | 3      | 0x19330d10D9Cc8751218eaf51E8885D058642E08A |
| Base        | 6      | 0x1682Ae6375C4E4A97e4B583BC394c861A46D8962 |
| Polygon PoS | 7      | 0x9daF8c91AEFAE50b9c0E69629D3F6Ca40cA3B3FE |

这里我们采取相同的手段即可，与 Solana 不同的是，EVM需要依靠 Filter Event的方式获取。
```typescript
let transferFilterTopic = "0xddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef";
let ethereumStandardAddress =  web3.utils.toChecksumAddress(web3.utils.padLeft(targetAddress, 40, '0').toLowerCase());
let padding = web3.utils.padLeft(ethereumStandardAddress, 64, '0').toLowerCase();
const filter = {
            fromBlock: fromBlock,
            toBlock: toBlock,
            topics: [transferFilterTopic, "0x0000000000000000000000000000000000000000000000000000000000000000",padding],
        };
 ```

这里，我们还有另外一个需要注意的点，L2有些链的Gas Fee需要把 L1 跟 L2加起来，才是最终消耗的Gas Fee。

```typescript
async function getL2Fee(chainId: number,txId: string) {
    let method = "eth_getTransactionReceipt";
    let params = [txId];
    let rpcInstanceCfg = getConfig(chainId);
    if (!rpcInstanceCfg) {
        console.error("Invalid chain ID");
        return;
    }
    let url = rpcInstanceCfg.rpcAddress;
    let axiosInstance = axios.create({
        baseURL: url,
        timeout: 10000,
        headers: {
            'Content-Type': 'application/json'
        }
    });
    let data = {
        jsonrpc: "2.0",
        method: method,
        params: params,
        id: 1
    }
    let response = await axiosInstance.post(url, data);
    let l1Fee = response.data.result.l1Fee;
    let l2GasUsed = response.data.result.gasUsed;
    let l2GasPrice = response.data.result.effectiveGasPrice;
    let l2Fee = l2GasUsed * l2GasPrice;
    l1Fee = parseInt(l1Fee);
    if (isNaN(l1Fee)) {
        l1Fee = 0;
    }
    let totalFee = l1Fee + l2Fee;
    totalFee = totalFee / 1e18;
    //console.log(`L1 Fee: ${l1Fee}, L2 Fee: ${l2Fee}, Total Fee: ${totalFee}`);
    return totalFee;
}
```

## 总结

通过上述方法，我们可以获取到跨链转账的实际到账时间。

直接给结论。

从 SOL 跨链到 EVM 各链的平均时间/成本如下：

| 目标链    | 平均目标链mint成本(USD) | 平均目标链Mint时间 | 
|-----------|-------------------------|---------------------|
| Arbitrum  | 0.014992835             | 406.6               | 
| Avalanche | 0.119040534             | 117.5               | 
| Base      | 0.003440751             | 131.4814815         |
| Ethereum  | 9.390838272             | 161.4347826         | 
| Optimism  | 0.012127123             | 138.1               | 
| Polygon   | 0.002715731             | 101.05              | 

以上成本还需加上 Solana 销毁 Tx 的 Gas Fee， 约为0.00295 SOL = 0.45 USD

从 EVM 跨链到 SOL 各链的平均时间/成本如下：

| 目标链    | 平均目标链mint成本(transfer) | 平均目标链Mint时间 | 官方标称时间          |
|-----------|------------------------------|---------------------|-----------------------|
| Arbitrum  | 0.009897                     | 2204.197279         | ~13 minutes = 780s    |
| Avalanche | 0.113491                     | 66.9245283          | ~20 seconds           |
| Base      | 0.006112                     | 1797.410072         | ~13 minutes = 780s    |
| Ethereum  | 3.431554                     | 1745.436975         | ~13 minutes = 780s    |
| Optimism  | 0.002721                     | 5731.428571         | ~13 minutes = 780s    |
| Polygon   | 0.007612                     | 602.18273           | ~8 minutes = 480s     |

以上成本还需加上Solana Mint Tx 的 Gas Fee， 约为0.0000675 SOL = $0.00995 USD。
