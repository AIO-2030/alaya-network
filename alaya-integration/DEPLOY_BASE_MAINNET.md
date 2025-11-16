# 部署合约到 Base 主网（Base Mainnet）

⚠️ **重要警告**：本文档说明如何将智能合约部署到 **Base 主网**。主网部署涉及**真实资金**，请务必谨慎操作！

## 目录

- [前置准备](#前置准备)
- [环境配置](#环境配置)
- [部署步骤](#部署步骤)
- [验证合约](#验证合约)
- [部署后操作](#部署后操作)
- [故障排查](#故障排查)

## ⚠️ 主网部署前必读

在开始主网部署之前，请确保：

1. ✅ **已在测试网充分测试**：所有功能在 Base Sepolia 测试网上测试通过
2. ✅ **代码审计完成**：合约代码已通过安全审计（如适用）
3. ✅ **配置已确认**：所有环境变量和参数都已仔细检查
4. ✅ **Safe 多签地址正确**：确认 `SAFE_MULTISIG` 是正确的 Safe 多签地址
5. ✅ **有足够的 ETH**：部署钱包有足够的 Base ETH 支付 gas 费用
6. ✅ **私钥安全**：私钥已安全保存，不会泄露
7. ✅ **备份计划**：已准备好备份所有部署地址和配置

**主网部署不可逆**，一旦部署成功，合约将永久存在于主网上，请务必谨慎！

## 前置准备

### 1. 安装 Foundry

确保已安装 Foundry 工具链。如果未安装，请参考 [Foundry 官方文档](https://book.getfoundry.sh/getting-started/installation) 进行安装。

验证安装：
```bash
forge --version
cast --version
```

### 2. 准备部署钱包和 Gas 费用

#### 2.1 创建部署钱包和获取私钥

⚠️ **主网部署安全要求更高**：建议使用硬件钱包或多签钱包进行部署，避免使用单签钱包。

##### 方法 1: 使用硬件钱包（推荐用于主网）

对于主网部署，强烈建议使用硬件钱包（如 Ledger、Trezor）：

1. 连接硬件钱包到电脑
2. 使用支持硬件钱包的工具（如 MetaMask + 硬件钱包）
3. 导出或使用硬件钱包的地址进行部署

**注意**：硬件钱包不能直接导出私钥，需要使用支持硬件钱包的部署工具。

##### 方法 2: 使用 Foundry Cast 创建新钱包（仅用于测试，不推荐主网）

⚠️ **警告**：此方法仅适用于测试。主网部署应使用更安全的方法。

```bash
# 生成新的私钥和地址
cast wallet new
```

##### 方法 3: 从 MetaMask 导出私钥

⚠️ **安全警告**：
- 主网私钥泄露会导致**真实资金损失**
- 仅在绝对安全的环境下操作
- 建议为部署创建**专用钱包**，不要使用主钱包
- 部署完成后，考虑清空该钱包或转移资金

导出步骤：
1. 打开 MetaMask 浏览器扩展
2. 点击右上角账户图标
3. 选择"账户详情"
4. 点击"导出私钥"
5. 输入密码确认
6. 复制私钥（**绝对不要分享给任何人**）

##### 方法 4: 使用其他钱包工具

- **MyEtherWallet (MEW)**: [https://www.myetherwallet.com/](https://www.myetherwallet.com/)
- **MyCrypto**: [https://mycrypto.com/](https://mycrypto.com/)

##### 私钥格式说明

- 私钥是一个 64 字符的十六进制字符串（不包含 `0x` 前缀）
- 或者 66 字符（包含 `0x` 前缀）
- Foundry 支持两种格式，都可以使用

**示例**：
- ✅ `0x1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef`（66 字符，带 0x）
- ✅ `1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef`（64 字符，不带 0x）

##### 验证私钥和地址

获取私钥后，可以验证地址是否正确：

```bash
# 从私钥获取地址
cast wallet address --private-key <YOUR_PRIVATE_KEY>
```

##### 主网安全提示

⚠️ **极其重要的主网安全注意事项**：

1. **私钥就是钱包**：拥有私钥就等于拥有钱包的完全控制权
2. **永远不要分享私钥**：不要通过任何方式（邮件、聊天、截图、云存储等）分享私钥
3. **不要提交到 Git**：确保 `.env` 文件在 `.gitignore` 中，并且从未提交过
4. **使用专用钱包**：为部署创建一个专门的钱包，**不要使用存有大量资金的主钱包**
5. **最小权限原则**：部署钱包只保留部署所需的 ETH，不要存放其他资金
6. **硬件钱包优先**：如果可能，使用硬件钱包或多签钱包
7. **备份私钥**：安全地备份私钥（加密存储、离线存储、硬件钱包等）
8. **部署后处理**：部署完成后，考虑清空该钱包或转移剩余资金
9. **环境隔离**：在干净、安全的计算机上操作，避免使用公共网络
10. **双重检查**：部署前多次检查所有配置和地址

##### 下一步

获取私钥后：
1. 将私钥保存到 `.env` 文件的 `PRIVATE_KEY` 变量中
2. 确保钱包有足够的 Base ETH（见下方"Gas 费用说明"部分）
3. 继续后续的部署步骤

#### 2.2 Gas 费用说明

**是的，主网部署需要准备真实的 ETH 作为 gas 费用！**

每次部署交易都需要消耗 gas，包括：
- 部署 4 个合约（AIOERC20、FeeDistributor、Interaction、GovernanceBootstrapper）
- 合约验证（如果使用 `--verify` 参数）

**预估 Gas 费用**：
- 单个合约部署：约 1,000,000 - 3,000,000 gas
- 4 个合约总计：约 4,000,000 - 12,000,000 gas
- Base 主网 gas price 根据网络拥堵情况变化（通常 0.1 - 10 gwei）
- **建议准备至少 0.01 - 0.1 Base ETH**（实际费用取决于 gas price）

**Gas 费用计算示例**：
- 假设总 gas 使用量：8,000,000
- 假设 gas price：2 gwei
- 总费用 = 8,000,000 × 2 gwei = 0.016 ETH

**注意**：
- 主网 ETH 是**真实资金**，需要从交易所购买或从其他钱包转账
- Gas price 会根据网络拥堵情况波动
- 建议在网络不拥堵时部署以节省 gas 费用

#### 2.3 估算 Gas 费用（模拟部署）

在正式部署前，**强烈建议**先模拟部署来估算 gas 费用：

```bash
# 模拟部署（不实际发送交易，不消耗 gas）
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $BASE_RPC \
  --private-key $PRIVATE_KEY
```

输出会显示预估的 gas 使用量。然后可以计算费用：
```
总费用 = gas_used × gas_price
```

**获取当前 gas price**：
```bash
# 查看当前 gas price
cast gas-price --rpc-url $BASE_RPC
```

#### 2.4 检查钱包余额

部署前**必须**检查钱包余额是否足够：

```bash
# 检查余额（需要先设置钱包地址）
cast balance <YOUR_WALLET_ADDRESS> --rpc-url $BASE_RPC
```

确保余额足够支付：
- 部署 gas 费用
- 合约验证费用（如果启用）
- 一些额外缓冲（建议多准备 20-30%）

#### 2.5 获取 Base ETH（主网）

主网 ETH 需要从以下方式获取：

1. **从交易所购买**：
   - Coinbase、Binance、Kraken 等交易所
   - 购买 ETH 后，通过 Base 桥接或直接发送到 Base 网络

2. **从其他钱包转账**：
   - 从以太坊主网通过 [Base 官方桥](https://bridge.base.org/) 桥接到 Base
   - 或从其他 Base 钱包直接转账

3. **Base 官方桥接**：
   - 访问 [Base Bridge](https://bridge.base.org/)
   - 连接钱包
   - 从以太坊主网桥接 ETH 到 Base

**注意**：
- 主网 ETH 是**真实资金**，请谨慎操作
- 桥接可能需要一些时间（通常几分钟到几小时）
- 确保目标地址正确，转账不可逆

### 3. 获取 Base 主网 RPC 端点

你可以使用以下任一 RPC 端点：

- **Base 官方 RPC** (推荐): `https://mainnet.base.org`
- **Alchemy**: 在 [Alchemy](https://www.alchemy.com/) 创建应用后获取 Base Mainnet RPC
- **Infura**: 在 [Infura](https://www.infura.io/) 创建项目后获取 Base Mainnet RPC
- **QuickNode**: 在 [QuickNode](https://www.quicknode.com/) 创建端点
- **公共 RPC**: `https://mainnet.base.org`（可能有速率限制）

**建议**：使用付费 RPC 服务（如 Alchemy、Infura）以获得更好的稳定性和速率。

### 4. 获取 Basescan API Key

用于合约验证：

1. 访问 [BaseScan 官网](https://basescan.org/)
2. 注册或登录账户
3. 进入账户设置/API 管理页面
4. 创建新的 API 密钥
5. 复制生成的 API 密钥并保存

## 环境配置

### 1. 创建 `.env` 文件

在项目根目录创建 `.env` 文件，配置以下环境变量：

```bash
# 部署钱包私钥（不要包含 0x 前缀，或包含都可以）
# ⚠️ 主网私钥必须严格保密！
PRIVATE_KEY=your_private_key_here

# 项目钱包地址（接收所有费用的地址）
PROJECT_WALLET=0xYourProjectWalletAddress

# Safe 多签地址（所有合约的所有者，必须设置）
# ⚠️ 极其重要：部署前请多次确认此地址是正确的 Safe 多签地址
# ⚠️ 主网部署后无法更改，请务必确认！
SAFE_MULTISIG=0xYourSafeMultisigAddress

# Base 主网 RPC 端点
BASE_RPC=https://mainnet.base.org

# Basescan API Key（用于合约验证）
BASESCAN_API_KEY=your_basescan_api_key_here

# 可选：自定义最大供应量（默认：1,000,000,000 * 1e18）
# MAX_SUPPLY=1000000000000000000000000000

# 可选：自定义初始手续费（默认：0.001 ETH = 1e15 wei）
# FEE_WEI=1000000000000000
```

### 2. 环境变量说明

| 变量名 | 必填 | 说明 |
|--------|------|------|
| `PRIVATE_KEY` | ✅ | 部署钱包的私钥（主网必须严格保密） |
| `PROJECT_WALLET` | ✅ | 接收所有费用的钱包地址 |
| `SAFE_MULTISIG` | ✅ | Safe 多签地址，所有合约的所有者（主网部署前必须多次确认） |
| `BASE_RPC` | ✅ | Base 主网 RPC 端点 |
| `BASESCAN_API_KEY` | ✅ | Basescan API 密钥，用于合约验证 |
| `MAX_SUPPLY` | ❌ | AIOERC20 代币最大供应量（默认：10 亿） |
| `FEE_WEI` | ❌ | 初始手续费（默认：0.001 ETH） |

### 3. 主网部署安全检查清单

在部署前，请逐项检查：

- [ ] 已在测试网（Base Sepolia）成功部署并测试
- [ ] 所有合约代码已通过审查
- [ ] `SAFE_MULTISIG` 地址已多次确认正确
- [ ] `PROJECT_WALLET` 地址正确
- [ ] 部署钱包有足够的 Base ETH（建议多准备 20-30% 缓冲）
- [ ] 私钥安全保存，不会泄露
- [ ] `.env` 文件已添加到 `.gitignore`
- [ ] 所有环境变量都已正确设置
- [ ] 已备份所有配置和地址
- [ ] 在安全、干净的环境中操作
- [ ] 已准备好应对部署后的操作

### 4. 安全提示

⚠️ **主网部署安全提示**：

- **永远不要**将包含真实私钥的 `.env` 文件提交到 Git 仓库
- 确保 `.env` 文件已添加到 `.gitignore`，并且从未提交过
- 部署钱包只保留部署所需的 ETH，不要存放大量资金
- **多次确认** `SAFE_MULTISIG` 地址是正确的 Safe 多签地址
- 主网部署**不可逆**，一旦部署成功，合约将永久存在
- 建议在部署前进行最后的代码审查
- 考虑使用硬件钱包或多签钱包进行部署
- 在部署前，建议先在测试网完整测试一遍所有流程

## 部署步骤

### 1. 编译合约

在部署前，先编译合约确保没有错误：

```bash
forge build
```

**建议**：使用与测试网相同的编译设置，确保一致性。

### 2. 模拟部署（强烈推荐）

在正式部署前，**强烈建议**先模拟部署以：
- 检查是否有错误
- 估算 gas 费用
- 验证配置是否正确
- 确认所有地址和参数

```bash
# 模拟部署（不实际发送交易，不消耗 gas）
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $BASE_RPC \
  --private-key $PRIVATE_KEY
```

**重要**：
- 如果模拟部署失败，**不要**进行实际部署
- 仔细检查模拟部署的输出
- 确认所有地址和参数都正确

### 3. 最终确认

在实际部署前，请再次确认：

1. **检查当前 gas price**：
   ```bash
   cast gas-price --rpc-url $BASE_RPC
   ```

2. **检查钱包余额**：
   ```bash
   cast balance <YOUR_WALLET_ADDRESS> --rpc-url $BASE_RPC
   ```

3. **验证 Safe 多签地址**：
   - 在 BaseScan 上查看该地址
   - 确认这是正确的 Safe 多签地址
   - 确认该地址在 Base 主网上存在

4. **检查环境变量**：
   ```bash
   # 查看环境变量（不显示私钥）
   echo "PROJECT_WALLET: $PROJECT_WALLET"
   echo "SAFE_MULTISIG: $SAFE_MULTISIG"
   echo "BASE_RPC: $BASE_RPC"
   ```

### 4. 运行部署脚本

⚠️ **这是实际部署步骤，将消耗真实的 ETH！**

使用以下命令部署所有合约到 Base 主网：

```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $BASE_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY
```

**注意**：
- 此命令会实际发送交易并消耗**真实的 ETH**
- 部署过程可能需要几分钟
- 请耐心等待所有交易确认
- 不要中断部署过程

### 5. 部署命令说明

- `--rpc-url $BASE_RPC`: 指定 Base 主网 RPC 端点
- `--private-key $PRIVATE_KEY`: 部署钱包的私钥
- `--broadcast`: 实际发送交易到网络（不加此参数只会模拟）
- `--verify`: 自动在 Basescan 上验证合约源代码
- `--etherscan-api-key $BASESCAN_API_KEY`: Basescan API 密钥

### 6. 部署过程

部署脚本会按以下顺序部署合约：

1. **AIOERC20**: ERC20 代币合约
   - 所有者：Safe 多签地址
   - 最大供应量：从环境变量或默认值

2. **FeeDistributor**: 手续费分配合约
   - 所有者：Safe 多签地址
   - 项目钱包：`PROJECT_WALLET`
   - 初始手续费：从环境变量或默认值

3. **Interaction**: 交互合约
   - 所有者：Safe 多签地址
   - 关联的 FeeDistributor：步骤 2 部署的地址

4. **GovernanceBootstrapper**: 治理引导合约（无状态，无所有者）

**注意**：每个合约部署都会产生一笔交易，需要等待确认。

### 7. 部署输出

部署成功后，脚本会输出 JSON 格式的合约地址：

```json
{
  "aioToken": "0x...",
  "feeDistributor": "0x...",
  "interaction": "0x...",
  "governanceBootstrapper": "0x...",
  "safeMultisig": "0x...",
  "network": "base-mainnet"
}
```

**请立即保存这些地址**：
- 保存到安全的位置
- 备份多份
- 后续所有操作都需要这些地址

## 验证合约

### 1. 自动验证

如果部署时使用了 `--verify` 参数，合约应该已经自动在 Basescan 上验证。

### 2. 手动验证（如果需要）

如果自动验证失败，可以手动验证：

```bash
forge verify-contract <CONTRACT_ADDRESS> \
  <CONTRACT_NAME>:<CONTRACT_PATH> \
  --chain-id 8453 \
  --etherscan-api-key $BASESCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(uint256,address)" <MAX_SUPPLY> <SAFE_MULTISIG>)
```

### 3. 在 Basescan 上查看

访问 [BaseScan](https://basescan.org/) 并搜索你的合约地址，确认：
- 合约代码已验证
- 合约所有者正确（应为 Safe 多签地址）
- 所有交易记录正常
- 合约状态正确

## 部署后操作

### 1. 验证合约所有权

**立即验证**所有合约的所有者都是 Safe 多签地址：

```bash
# 检查 AIOERC20 所有者
cast call <AIO_TOKEN_ADDRESS> "owner()(address)" --rpc-url $BASE_RPC

# 检查 FeeDistributor 所有者
cast call <FEE_DISTRIBUTOR_ADDRESS> "owner()(address)" --rpc-url $BASE_RPC

# 检查 Interaction 所有者
cast call <INTERACTION_ADDRESS> "owner()(address)" --rpc-url $BASE_RPC
```

所有返回值应该都是你的 `SAFE_MULTISIG` 地址。

**如果所有者不正确**：
- ⚠️ 这是严重问题，需要立即处理
- 检查部署日志
- 联系技术支持

### 2. 配置 AIO Token 和奖励池

⚠️ **重要**：部署后必须配置 AIO token 和奖励池，否则用户无法领取 AIO 奖励。

#### 2.1 准备 AIO Token 和奖励池

在配置之前，需要确保：

1. **AIO Token 已部署**：AIO token 合约已部署（部署脚本会自动部署）
2. **奖励池地址**：准备一个地址作为奖励池（建议使用 Safe 多签地址或其他地址）
3. **Mint AIO Token**：AIO token 部署后不会自动 mint，需要手动 mint

**重要说明**：AIO token 部署后 `totalSupply` 为 0，需要调用 `mint()` 函数来 mint token。

**推荐流程**：先 Mint 到 Owner 地址，再根据需要转账部分到奖励池。这样可以灵活控制奖励池的代币数量，不是所有代币都需要进入奖励池。

##### 步骤 1：Mint AIO Token 到 Owner 地址

首先将所有代币 mint 到 owner 地址（通常是 Safe 多签地址）：

```bash
# 设置环境变量
export AIO_TOKEN_ADDRESS=<deployed_aio_token_address>
export OWNER_ADDRESS=<owner_address>  # 通常是 Safe 多签地址
export MINT_AMOUNT=1000000000000000000000000000  # 例如：10 亿 token (1e27 wei)

# ⚠️ 注意：mint 函数只能由 owner 调用
# 如果 owner 是 Safe 多签，必须通过 Safe 多签执行，不要使用私钥直接调用
```

**通过 Safe 多签执行 mint**：
1. 在 Safe 多签界面创建交易
2. 调用 `AIOERC20.mint(ownerAddress, amount)`
3. **仔细检查**：确认 owner 地址和数量正确
4. 确认并执行交易

**验证 Mint 结果**：

```bash
# 检查 owner 地址的余额
cast call $AIO_TOKEN_ADDRESS \
  "balanceOf(address)(uint256)" \
  $OWNER_ADDRESS \
  --rpc-url $BASE_RPC

# 检查已 mint 的总量
cast call $AIO_TOKEN_ADDRESS \
  "totalMinted()(uint256)" \
  --rpc-url $BASE_RPC
```

##### 步骤 2：转账部分代币到奖励池

根据需要，从 owner 地址转账部分代币到奖励池地址。这样可以灵活控制奖励池的代币数量：

```bash
# 设置环境变量
export AIO_TOKEN_ADDRESS=<deployed_aio_token_address>
export REWARD_POOL_ADDRESS=<reward_pool_address>
export OWNER_ADDRESS=<owner_address>  # 通常是 Safe 多签地址
export TRANSFER_AMOUNT=100000000000000000000000000  # 例如：1 亿 token (1e26 wei)，根据实际需求调整

# 通过 Safe 多签执行转账
# 在 Safe 多签界面创建交易，调用 AIOERC20.transfer(rewardPoolAddress, amount)
```

**通过 Safe 多签执行转账**：
1. 在 Safe 多签界面创建交易
2. 调用 `AIOERC20.transfer(rewardPoolAddress, amount)`
3. **仔细检查**：确认奖励池地址和转账数量正确
4. 确认并执行交易

**验证转账结果**：

```bash
# 检查奖励池地址的余额
cast call $AIO_TOKEN_ADDRESS \
  "balanceOf(address)(uint256)" \
  $REWARD_POOL_ADDRESS \
  --rpc-url $BASE_RPC

# 检查 owner 地址的余额（应该减少）
cast call $AIO_TOKEN_ADDRESS \
  "balanceOf(address)(uint256)" \
  $OWNER_ADDRESS \
  --rpc-url $BASE_RPC
```

**分批转账**：如果需要，可以分多次转账到奖励池，灵活控制奖励池的代币数量：

```bash
# 第一次转账：初始资金
# 通过 Safe 多签执行：AIOERC20.transfer(rewardPoolAddress, initialAmount)

# 后续根据需要补充奖励池
# 通过 Safe 多签执行：AIOERC20.transfer(rewardPoolAddress, additionalAmount)
```

⚠️ **主网安全提示**：
- 主网操作涉及真实资金，请务必谨慎
- 建议先在测试网完整测试所有流程
- 所有操作建议通过 Safe 多签执行，不要使用单签私钥
- **仔细检查**：每次转账前都要确认地址和数量正确
- 建议保留部分代币在 owner 地址，用于其他用途（如流动性、社区奖励等）
- 可以根据实际使用情况，定期补充奖励池的代币

#### 2.2 设置 AIO Token 地址

```bash
# 设置环境变量
export INTERACTION_ADDRESS=<deployed_interaction_address>
export AIO_TOKEN_ADDRESS=<deployed_aio_token_address>
```

**通过 Safe 多签执行**：
1. 在 Safe 多签界面创建交易
2. 调用 `Interaction.setAIOToken(aioTokenAddress)`
3. **仔细检查**：确认 AIO token 地址正确
4. 确认并执行交易

**或者使用 cast（仅当 owner 是单签地址时）**：

```bash
cast send $INTERACTION_ADDRESS \
  "setAIOToken(address)" \
  $AIO_TOKEN_ADDRESS \
  --rpc-url $BASE_RPC \
  --private-key $PRIVATE_KEY
```

#### 2.3 设置奖励池地址

```bash
# 设置环境变量
export INTERACTION_ADDRESS=<deployed_interaction_address>
export REWARD_POOL_ADDRESS=<reward_pool_address>
```

**通过 Safe 多签执行**：
1. 在 Safe 多签界面创建交易
2. 调用 `Interaction.setAIORewardPool(rewardPoolAddress)`
3. **仔细检查**：确认奖励池地址正确
4. 确认并执行交易

**或者使用 cast（仅当 owner 是单签地址时）**：

```bash
cast send $INTERACTION_ADDRESS \
  "setAIORewardPool(address)" \
  $REWARD_POOL_ADDRESS \
  --rpc-url $BASE_RPC \
  --private-key $PRIVATE_KEY
```

#### 2.4 授权 Interaction 合约从奖励池转移 AIO Token

奖励池地址需要授权 Interaction 合约可以转移 AIO token：

```bash
# 设置环境变量
export AIO_TOKEN_ADDRESS=<deployed_aio_token_address>
export INTERACTION_ADDRESS=<deployed_interaction_address>
export REWARD_POOL_ADDRESS=<reward_pool_address>
export APPROVE_AMOUNT=1000000000000000000000000000  # 例如：10 亿 token，或使用 type(uint256).max 表示无限授权
```

**通过 Safe 多签执行**（推荐）：
1. 在 Safe 多签界面创建交易（如果奖励池是 Safe 多签）
2. 调用 `AIOERC20.approve(interactionAddress, amount)`
3. **仔细检查**：确认 Interaction 地址和授权额度正确
4. 确认并执行交易

**建议**：
- 如果奖励池会持续补充，可以授权一个很大的额度（如 `type(uint256).max`），避免频繁授权
- 主网操作建议通过 Safe 多签执行，确保安全

#### 2.5 为每个 Action 设置奖励数量

为每个 action 配置对应的 AIO 奖励数量：

```bash
# 设置环境变量
export INTERACTION_ADDRESS=<deployed_interaction_address>
export ACTION="send_pixelmug"  # action 字符串
export REWARD_AMOUNT=1000000000000000000  # 例如：1 AIO token (1e18 wei)
```

**通过 Safe 多签执行**（推荐）：
1. 在 Safe 多签界面创建交易
2. 调用 `Interaction.setActionRewardByString(action, rewardAmount)`
3. **仔细检查**：确认 action 字符串和奖励数量正确
4. 确认并执行交易

**示例：为多个 action 设置奖励**：

```bash
# 为 send_pixelmug action 设置 1 AIO 奖励
# 通过 Safe 多签执行：Interaction.setActionRewardByString("send_pixelmug", 1000000000000000000)

# 为 aio_rpc_call action 设置 2 AIO 奖励
# 通过 Safe 多签执行：Interaction.setActionRewardByString("aio_rpc_call", 2000000000000000000)

# 为 verify_proof action 设置 0.5 AIO 奖励
# 通过 Safe 多签执行：Interaction.setActionRewardByString("verify_proof", 500000000000000000)
```

⚠️ **主网注意事项**：
- 奖励数量设置后会影响实际资金分配，请仔细确认
- 建议先在测试网测试奖励机制
- 所有操作建议通过 Safe 多签执行

#### 2.6 验证配置

配置完成后，**必须验证**设置是否正确：

```bash
# 检查配置
cast call $INTERACTION_ADDRESS \
  "getConfig()(uint256,address,bool,address,address)" \
  --rpc-url $BASE_RPC

# 检查特定 action 的奖励数量
cast call $INTERACTION_ADDRESS \
  "actionReward(bytes32)(uint256)" \
  $(cast keccak "send_pixelmug") \
  --rpc-url $BASE_RPC

# 检查奖励池的授权额度
cast call $AIO_TOKEN_ADDRESS \
  "allowance(address,address)(uint256)" \
  $REWARD_POOL_ADDRESS $INTERACTION_ADDRESS \
  --rpc-url $BASE_RPC
```

#### 2.7 配置检查清单

在继续之前，请确认：

- [ ] AIO token 已 mint 到奖励池地址
- [ ] Interaction 合约已设置 AIO token 地址
- [ ] Interaction 合约已设置奖励池地址
- [ ] 奖励池已授权 Interaction 合约足够的额度
- [ ] 所有 action 的奖励数量已配置
- [ ] 配置已通过验证
- [ ] 所有操作已通过 Safe 多签执行（如适用）

⚠️ **主网重要提示**：
- 配置错误可能导致用户无法领取奖励或资金损失
- 建议在测试网完整测试后再在主网配置
- 所有配置操作建议通过 Safe 多签执行

### 3. 启用治理模式（可选）

如果需要启用治理模式，可以使用 Helper 脚本：

```bash
# 设置环境变量
export TIMELOCK_ADDRESS=$SAFE_MULTISIG
export PARAM_SETTER_ADDRESS=<param_setter_address>
export FEE_DISTRIBUTOR_ADDRESS=<deployed_fee_distributor_address>
export INTERACTION_ADDRESS=<deployed_interaction_address>

# 启用治理
forge script script/Helpers.s.sol:HelperScripts \
  --sig "enableGovernance()" \
  --rpc-url $BASE_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast
```

或者使用 GovernanceBootstrapper（单笔交易）：

```bash
export TIMELOCK_ADDRESS=$SAFE_MULTISIG
export BOOTSTRAPPER_ADDRESS=<deployed_bootstrapper_address>

forge script script/Helpers.s.sol:HelperScripts \
  --sig "bootstrapGovernance()" \
  --rpc-url $BASE_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast
```

### 4. 测试合约功能

部署后，建议进行基本功能测试：

- 测试代币转账
- 测试手续费收取
- 测试交互功能
- 验证费用分配
- **测试 AIO 奖励领取**：
  1. 用户调用 `interact()` 完成交互
  2. 从事件中获取 `timestamp`
  3. 用户调用 `claimAIO(action, timestamp)` 领取奖励
  4. 验证 AIO token 已成功转移到用户地址

⚠️ **注意**：主网测试会消耗真实的 ETH，请谨慎操作。建议先在测试网完整测试所有功能。

### 5. 部署后安全检查

- [ ] 所有合约所有者都是 Safe 多签地址
- [ ] 所有合约地址已保存和备份
- [ ] 合约代码已验证
- [ ] AIO token 和奖励池配置完成
- [ ] 所有 action 奖励数量已配置
- [ ] 基本功能测试通过
- [ ] AIO 奖励领取功能测试通过
- [ ] 部署钱包剩余资金已处理（如需要）
- [ ] 所有配置和地址已备份

## 故障排查

### 问题 1: 部署失败 - Insufficient funds

**错误信息**: `insufficient funds for gas` 或 `execution reverted: insufficient funds`

**原因**:
- 钱包余额不足以支付 gas 费用
- 部署多个合约需要较多 gas，余额可能不够
- Gas price 上涨导致费用增加

**解决方案**:
1. **检查当前余额**:
   ```bash
   cast balance <YOUR_WALLET_ADDRESS> --rpc-url $BASE_RPC
   ```

2. **检查当前 gas price**:
   ```bash
   cast gas-price --rpc-url $BASE_RPC
   ```

3. **估算所需 gas**:
   ```bash
   # 先模拟部署查看 gas 使用量
   forge script script/Deploy.s.sol:DeployScript \
     --rpc-url $BASE_RPC \
     --private-key $PRIVATE_KEY
   ```

4. **获取更多 ETH**:
   - 从交易所购买或转账更多 Base ETH
   - 建议多准备 20-30% 的缓冲

5. **如果余额仍然不足**:
   - 检查是否有未确认的交易占用余额
   - 等待之前的交易确认后再试
   - 考虑在网络不拥堵时部署（gas price 较低）

### 问题 2: 合约验证失败

**错误信息**: `Failed to verify contract`

**解决方案**:
- 检查 Basescan API Key 是否正确
- 确认合约编译设置与部署时一致
- 检查网络连接
- 尝试手动验证（见上方手动验证部分）
- 等待一段时间后重试（有时 Basescan 需要时间同步）

### 问题 3: 环境变量未加载

**错误信息**: `Environment variable not found`

**解决方案**:
- 确认 `.env` 文件在项目根目录
- 使用 `source .env` 加载环境变量（或使用 `export` 命令）
- 或者直接在命令中指定：`--private-key $(grep PRIVATE_KEY .env | cut -d '=' -f2)`
- 检查环境变量名称是否正确（注意大小写）

### 问题 4: RPC 端点连接失败

**错误信息**: `Failed to connect to RPC`

**解决方案**:
- 检查 RPC URL 是否正确
- 尝试使用其他 RPC 端点
- 检查网络连接
- 如果使用免费 RPC，可能有速率限制，考虑使用付费 RPC 服务

### 问题 5: Safe 多签地址错误

**错误信息**: `SAFE_MULTISIG must be set` 或部署后发现所有者地址错误

**解决方案**:
- 确认 `.env` 文件中设置了 `SAFE_MULTISIG`
- 确认地址格式正确（0x 开头的 42 字符地址）
- 在 BaseScan 上确认该地址存在
- **如果已部署但地址错误**：这是严重问题，需要联系技术支持

### 问题 6: 交易被卡住或确认缓慢

**原因**:
- Gas price 设置过低
- 网络拥堵

**解决方案**:
- 检查交易状态：在 BaseScan 上查看交易哈希
- 如果交易 pending 时间过长，可能需要替换交易（使用更高的 gas price）
- 等待网络拥堵缓解
- 考虑在网络不拥堵时部署

## 网络信息

### Base Mainnet

- **Chain ID**: 8453
- **RPC URL**: `https://mainnet.base.org` 或使用其他提供商
- **区块浏览器**: [BaseScan](https://basescan.org/)
- **官方桥接**: [Base Bridge](https://bridge.base.org/)
- **官方文档**: [Base Docs](https://docs.base.org/)

## 相关资源

- [Foundry 文档](https://book.getfoundry.sh/)
- [Base 官方文档](https://docs.base.org/)
- [BaseScan 文档](https://docs.basescan.org/)
- [Safe 多签钱包](https://safe.global/)
- [Base Bridge](https://bridge.base.org/)

## 主网部署注意事项

1. **不可逆性**: 主网部署后合约不可更改，请确保代码正确
2. **真实资金**: 主网涉及真实 ETH，所有操作都会消耗真实资金
3. **Gas 费用**: 主网 gas 费用是真实的，建议在网络不拥堵时部署
4. **安全第一**: 主网部署必须遵循最高安全标准
5. **充分测试**: 部署前必须在测试网充分测试
6. **多签安全**: 所有合约所有者都是 Safe 多签，确保多签配置正确
7. **备份重要**: 部署后请备份所有合约地址和配置
8. **审计建议**: 主网部署前建议进行代码安全审计
9. **监控部署**: 部署后持续监控合约状态
10. **应急预案**: 准备好应对可能出现的问题

## 主网 vs 测试网对比

| 项目 | Base Sepolia 测试网 | Base 主网 |
|------|---------------------|-----------|
| Chain ID | 84532 | 8453 |
| ETH 价值 | 无价值（免费） | 真实价值 |
| Gas 费用 | 免费（水龙头） | 真实 ETH |
| 可逆性 | 可重置 | 不可逆 |
| 安全要求 | 较低 | 极高 |
| 测试要求 | 建议测试 | 必须测试 |
| 审计要求 | 可选 | 强烈建议 |

---

⚠️ **最后提醒**：主网部署涉及真实资金，请务必谨慎操作。如有疑问，建议先在测试网充分测试，或咨询技术支持。

如有问题，请参考项目主 README 或提交 Issue。

