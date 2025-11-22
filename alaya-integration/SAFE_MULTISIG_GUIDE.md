# Safe 多签钱包创建指南

本文档详细说明如何创建 Safe 多签钱包并获取 `SAFE_MULTISIG` 地址。

## 什么是 Safe 多签钱包？

Safe（原 Gnosis Safe）是一个智能合约钱包，需要多个签名者（所有者）的确认才能执行交易。这提供了更高的安全性，因为：

- **多重签名保护**：需要多个签名者确认才能执行交易
- **权限管理**：可以设置不同的权限和角色
- **可恢复性**：如果某个签名者丢失私钥，其他签名者可以恢复访问
- **审计透明**：所有交易都在链上可查

## 创建 Safe 多签钱包

### 步骤 1: 访问 Safe 平台

1. 访问 [Safe 官网](https://safe.global/)
2. 点击右上角的 **"Launch App"** 或 **"Get Started"**
3. 选择 **Base** 网络（测试网选择 Base Sepolia，主网选择 Base）

### 步骤 2: 连接钱包

1. 点击 **"Connect Wallet"**
2. 选择你的钱包（MetaMask、WalletConnect 等）
3. 确认连接

### 步骤 3: 创建新的 Safe

1. 在 Safe 界面，点击 **"Create new Safe"** 或 **"Create Safe"**
2. 如果是首次使用，可能需要先创建一个 Safe 账户

### 步骤 4: 配置签名者（Owners）

1. **添加签名者地址**：
   - 输入第一个签名者的钱包地址
   - 点击 **"Add owner"** 添加更多签名者
   - 建议至少添加 2-3 个签名者（可以根据需要添加更多）

2. **设置确认阈值**：
   - 选择需要多少个签名者确认才能执行交易
   - 例如：如果有 3 个签名者，可以设置为需要 2 个确认（2/3）
   - 建议：至少需要 2 个确认，即使只有 2 个签名者

**示例配置**：
- 签名者数量：3
- 确认阈值：2（即需要 2/3 的签名者确认）

### 步骤 5: 审查并创建

1. 仔细检查所有配置：
   - 签名者地址是否正确
   - 确认阈值是否合理
   - 网络是否正确（Base Sepolia 或 Base Mainnet）

2. 点击 **"Create"** 或 **"Deploy Safe"**

3. 确认交易（需要支付 gas 费用）

### 步骤 6: 获取 Safe 地址

1. 创建成功后，Safe 会显示你的 Safe 钱包地址
2. **复制这个地址**，这就是你的 `SAFE_MULTISIG` 地址
3. 地址格式：`0x` 开头的 42 字符地址，例如：`0x1234567890123456789012345678901234567890`

### 步骤 7: 验证 Safe 地址

在部署合约前，**强烈建议**验证 Safe 地址：

1. **在区块浏览器上查看**：
   - 测试网：访问 [BaseScan Sepolia](https://sepolia.basescan.org/) 并搜索你的 Safe 地址
   - 主网：访问 [BaseScan](https://basescan.org/) 并搜索你的 Safe 地址

2. **确认信息**：
   - 地址存在且有交易记录
   - 签名者配置正确
   - 网络正确

3. **在 Safe 界面验证**：
   - 在 Safe 界面查看钱包详情
   - 确认签名者列表和确认阈值

## 不同网络的 Safe 地址

⚠️ **重要**：不同网络的 Safe 地址是**不同的**！

- **Base Sepolia 测试网**：需要创建 Base Sepolia 网络上的 Safe
- **Base 主网**：需要创建 Base 主网上的 Safe

如果你需要在两个网络都部署，需要：
1. 在 Base Sepolia 上创建一个 Safe，获取测试网地址
2. 在 Base 主网上创建另一个 Safe，获取主网地址

## 配置到 .env 文件

获取 Safe 地址后，将其添加到 `.env` 文件：

```bash
# Safe 多签地址（所有合约的所有者，必须设置）
# ⚠️ 重要：部署前请确认此地址是正确的 Safe 多签地址
SAFE_MULTISIG=0xYourSafeMultisigAddress
```

**示例**：
```bash
# Base Sepolia 测试网
SAFE_MULTISIG=0x1234567890123456789012345678901234567890

# Base 主网（如果不同）
SAFE_MULTISIG=0xabcdefabcdefabcdefabcdefabcdefabcdefabcd
```

## 使用 Safe 多签钱包

### 执行交易

部署后，如果需要通过 Safe 多签执行合约操作（如 mint token、设置参数等）：

1. **在 Safe 界面创建交易**：
   - 登录 Safe 界面
   - 选择你的 Safe 钱包
   - 点击 **"New Transaction"** 或 **"Send"**

2. **输入交易详情**：
   - 目标合约地址
   - 函数调用数据（可以使用 [MyEtherWallet](https://www.myetherwallet.com/interface/interact) 或类似工具生成）
   - 金额（如果需要）

3. **确认交易**：
   - 第一个签名者确认
   - 等待其他签名者确认（达到确认阈值）
   - 交易自动执行

### 查看交易历史

- 在 Safe 界面可以查看所有交易历史
- 在区块浏览器上也可以查看 Safe 地址的所有交易

## 安全建议

1. **签名者选择**：
   - 选择可信的签名者
   - 建议至少 3 个签名者，确认阈值为 2
   - 不要将所有签名者都放在同一设备上

2. **私钥安全**：
   - 每个签名者必须安全保管自己的私钥
   - 建议使用硬件钱包作为签名者

3. **确认阈值**：
   - 不要设置为 1/1（单签，失去多签意义）
   - 建议至少 2/3 或 2/2
   - 对于重要操作，可以设置更高的阈值

4. **网络验证**：
   - 部署前多次确认 Safe 地址
   - 确认网络正确（测试网 vs 主网）
   - 在区块浏览器上验证地址

5. **备份**：
   - 保存 Safe 地址
   - 记录签名者列表和确认阈值
   - 保存 Safe 恢复信息（如果需要）

## 常见问题

### Q: 可以在不同网络使用同一个 Safe 地址吗？

A: 不可以。每个网络上的 Safe 地址是独立的。如果你在 Base Sepolia 上创建了 Safe，地址是 `0xABC...`，在 Base 主网上创建的 Safe 地址会是不同的地址。

### Q: 如何确认我的 Safe 地址是正确的？

A: 
1. 在 Safe 界面查看钱包地址
2. 在区块浏览器上搜索该地址，确认是 Safe 合约
3. 验证签名者配置是否正确

### Q: 创建 Safe 需要多少 gas 费用？

A: 创建 Safe 需要支付一次性的 gas 费用，通常在 0.001 - 0.01 ETH 之间，取决于网络拥堵情况。

### Q: 可以修改签名者或确认阈值吗？

A: 可以。在 Safe 界面可以添加/删除签名者，或修改确认阈值。这些操作需要现有签名者确认。

### Q: 如果丢失了签名者的私钥怎么办？

A: 如果其他签名者仍然可以访问，可以通过 Safe 界面移除丢失的签名者并添加新的签名者。如果所有签名者都丢失了私钥，则无法恢复。

## 相关资源

- [Safe 官网](https://safe.global/)
- [Safe 文档](https://docs.safe.global/)
- [Base 网络信息](https://docs.base.org/)
- [BaseScan 区块浏览器](https://basescan.org/)
- [BaseScan Sepolia](https://sepolia.basescan.org/)

## 下一步

获取 Safe 地址后：

1. ✅ 将地址添加到 `.env` 文件
2. ✅ 在区块浏览器上验证地址
3. ✅ 确认网络正确（测试网或主网）
4. ✅ 继续部署流程（见 `DEPLOY_BASE_TESTNET.md` 或 `DEPLOY_BASE_MAINNET.md`）

---

如有问题，请参考 [Safe 官方文档](https://docs.safe.global/) 或提交 Issue。

