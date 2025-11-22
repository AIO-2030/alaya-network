# 部署合约到 Base 测试网（Base Sepolia Testnet）

本文档详细说明如何将智能合约部署到 Base Sepolia 测试网。

## 目录

- [前置准备](#前置准备)
- [环境配置](#环境配置)
- [部署步骤](#部署步骤)
- [验证合约](#验证合约)
- [部署后操作](#部署后操作)
- [故障排查](#故障排查)

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

##### 方法 1: 使用 Foundry Cast 创建新钱包（推荐用于测试）

使用 Foundry 的 `cast` 工具可以快速创建一个新钱包：

```bash
# 生成新的私钥和地址
cast wallet new
```

命令会输出：
- **Private Key**: 私钥（以 `0x` 开头）
- **Address**: 钱包地址

**示例输出**：
```
Successfully created new keypair.
Address: 0x1234567890123456789012345678901234567890
Private Key: 0xabcdef1234567890abcdef1234567890abcdef1234567890abcdef1234567890
```

⚠️ **重要**：请立即保存私钥和地址，私钥一旦丢失无法恢复！

##### 方法 2: 从 MetaMask 导出私钥

如果你已有 MetaMask 钱包，可以导出私钥：

1. 打开 MetaMask 浏览器扩展
2. 点击右上角账户图标
3. 选择"账户详情"
4. 点击"导出私钥"
5. 输入密码确认
6. 复制私钥（**注意安全，不要分享给任何人**）

⚠️ **安全警告**：
- 导出私钥会暴露你的钱包，请确保在安全的环境下操作
- 不要将私钥截图或发送给任何人
- 建议为部署专门创建一个新钱包，不要使用存有大量资金的主钱包

##### 方法 3: 使用其他钱包工具

你也可以使用其他工具创建钱包：

- **MyEtherWallet (MEW)**: [https://www.myetherwallet.com/](https://www.myetherwallet.com/)
- **MyCrypto**: [https://mycrypto.com/](https://mycrypto.com/)
- **命令行工具**: 使用 `openssl` 或其他加密工具生成

##### 方法 4: 使用 Python/Node.js 脚本生成

使用 Python 生成：

```python
from eth_account import Account
import secrets

# 生成随机私钥
priv = secrets.token_hex(32)
private_key = "0x" + priv
acc = Account.from_key(private_key)

print(f"Address: {acc.address}")
print(f"Private Key: {private_key}")
```

使用 Node.js 生成：

```javascript
const { ethers } = require("ethers");

// 生成随机钱包
const wallet = ethers.Wallet.createRandom();

console.log("Address:", wallet.address);
console.log("Private Key:", wallet.privateKey);
```

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

##### 安全提示

⚠️ **极其重要的安全注意事项**：

1. **私钥就是钱包**：拥有私钥就等于拥有钱包的完全控制权
2. **永远不要分享私钥**：不要通过任何方式（邮件、聊天、截图等）分享私钥
3. **不要提交到 Git**：确保 `.env` 文件在 `.gitignore` 中
4. **使用专用钱包**：为部署创建一个专门的钱包，不要使用主钱包
5. **测试网 vs 主网**：
   - 测试网私钥泄露风险较低（测试网代币无价值）
   - 主网私钥必须严格保密
6. **备份私钥**：安全地备份私钥（如加密存储、硬件钱包等）
7. **部署后考虑**：部署完成后，如果不再需要，可以考虑清空该钱包或转移资金

##### 下一步

获取私钥后：
1. 将私钥保存到 `.env` 文件的 `PRIVATE_KEY` 变量中
2. 确保钱包有足够的 Base Sepolia ETH（见下方"获取 Base Sepolia ETH"部分）
3. 继续后续的部署步骤

#### 2.2 Gas 费用说明

**是的，部署合约需要准备 gas 费用！**

每次部署交易都需要消耗 gas，包括：
- 部署 4 个合约（AIOERC20、FeeDistributor、Interaction、GovernanceBootstrapper）
- 合约验证（如果使用 `--verify` 参数）

**预估 Gas 费用**：
- 单个合约部署：约 1,000,000 - 3,000,000 gas
- 4 个合约总计：约 4,000,000 - 12,000,000 gas
- Base Sepolia 测试网 gas price 通常很低（约 0.1 - 1 gwei）
- **建议准备至少 0.01 - 0.05 Base Sepolia ETH**（测试网 ETH 免费，从水龙头获取即可）

#### 2.3 估算 Gas 费用（模拟部署）

在正式部署前，可以先模拟部署来估算 gas 费用：

```bash
# 模拟部署（不实际发送交易）
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $BASE_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY
```

输出会显示预估的 gas 使用量。然后可以计算费用：
```
总费用 = gas_used × gas_price
```

#### 2.4 检查钱包余额

部署前检查钱包余额是否足够：

```bash
# 检查余额（需要先设置钱包地址）
cast balance <YOUR_WALLET_ADDRESS> --rpc-url $BASE_SEPOLIA_RPC
```

#### 2.5 获取 Base Sepolia ETH（测试网）

测试网 ETH 是免费的，可以从以下水龙头获取：

- **Coinbase Base Sepolia Faucet**（推荐）: [https://www.coinbase.com/faucets/base-ethereum-goerli-faucet](https://www.coinbase.com/faucets/base-ethereum-goerli-faucet)
- **Base 官方水龙头**: [https://www.coinbase.com/faucets/base-ethereum-goerli-faucet](https://www.coinbase.com/faucets/base-ethereum-goerli-faucet)
- 其他 Base Sepolia 测试网水龙头

**注意**：
- 测试网 ETH 没有实际价值，仅用于测试
- 水龙头通常有每日限额
- 如果余额不足，可以多次从水龙头获取

### 3. 获取 Base Sepolia RPC 端点

你可以使用以下任一 RPC 端点：

- **Alchemy** (推荐): `https://base-sepolia.g.alchemy.com/v2/Br9B6PkCm4u7NhukuwdGihx6SZnhrLWI`
- **Coinbase Cloud**: `https://base-sepolia.gateway.tenderly.co`
- **Infura**: 在 [Infura](https://www.infura.io/) 创建项目后获取
- **公共 RPC**: `https://sepolia.base.org`

### 4. 获取 Basescan API Key

用于合约验证：

1. 访问 [BaseScan 官网](https://sepolia.basescan.org/)
2. 注册或登录账户
3. 进入账户设置/API 管理页面
4. 创建新的 API 密钥
5. 复制生成的 API 密钥并保存

## 环境配置

### 1. 创建 `.env` 文件

在项目根目录创建 `.env` 文件，配置以下环境变量：

```bash
# 部署钱包私钥（不要包含 0x 前缀，或包含都可以）
PRIVATE_KEY=your_private_key_here

# 项目钱包地址（接收所有费用的地址）
PROJECT_WALLET=0xYourProjectWalletAddress

# Safe 多签地址（所有合约的所有者，必须设置）
# ⚠️ 重要：部署前请确认此地址是正确的 Safe 多签地址
# 📖 如何获取 Safe 多签地址：详见 SAFE_MULTISIG_GUIDE.md
SAFE_MULTISIG=0xYourSafeMultisigAddress

# Base Sepolia RPC 端点（使用 Alchemy）
BASE_SEPOLIA_RPC=https://base-sepolia.g.alchemy.com/v2/Br9B6PkCm4u7NhukuwdGihx6SZnhrLWI

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
| `PRIVATE_KEY` | ✅ | 部署钱包的私钥 |
| `PROJECT_WALLET` | ✅ | 接收所有费用的钱包地址 |
| `SAFE_MULTISIG` | ✅ | Safe 多签地址，所有合约的所有者 |
| `BASE_SEPOLIA_RPC` | ✅ | Base Sepolia 测试网 RPC 端点 |
| `BASESCAN_API_KEY` | ✅ | Basescan API 密钥，用于合约验证 |
| `MAX_SUPPLY` | ❌ | AIOERC20 代币最大供应量（默认：10 亿） |
| `FEE_WEI` | ❌ | 初始手续费（默认：0.001 ETH） |

### 3. 安全提示

⚠️ **重要安全提示**：

- **永远不要**将包含真实私钥的 `.env` 文件提交到 Git 仓库
- 确保 `.env` 文件已添加到 `.gitignore`
- 部署钱包只保留少量测试 ETH，不要存放大量资金
- 确认 `SAFE_MULTISIG` 地址是正确的 Safe 多签地址

## 部署步骤

### 1. 编译合约

在部署前，先编译合约确保没有错误：

```bash
forge build
```

### 2. 模拟部署（可选，推荐先执行）

在正式部署前，建议先模拟部署以：
- 检查是否有错误
- 估算 gas 费用
- 验证配置是否正确

```bash
# 模拟部署（不实际发送交易，不消耗 gas）
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $BASE_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY
```

如果模拟成功，再执行实际部署。

### 3. 运行部署脚本

使用以下命令部署所有合约到 Base Sepolia 测试网：

```bash
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url $BASE_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast \
  --verify \
  --etherscan-api-key $BASESCAN_API_KEY
```

**注意**：此命令会实际发送交易并消耗 gas 费用，请确保钱包有足够的余额。

### 4. 部署命令说明

- `--rpc-url $BASE_SEPOLIA_RPC`: 指定 Base Sepolia 测试网 RPC 端点
- `--private-key $PRIVATE_KEY`: 部署钱包的私钥
- `--broadcast`: 实际发送交易到网络（不加此参数只会模拟）
- `--verify`: 自动在 Basescan 上验证合约源代码
- `--etherscan-api-key $BASESCAN_API_KEY`: Basescan API 密钥

### 5. 部署过程

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

### 6. 部署输出

部署成功后，脚本会输出 JSON 格式的合约地址：

```json
{
  "aioToken": "0x...",
  "feeDistributor": "0x...",
  "interaction": "0x...",
  "governanceBootstrapper": "0x...",
  "safeMultisig": "0x...",
  "network": "base-sepolia"
}
```

**请保存这些地址**，后续操作需要使用。

## 验证合约

### 1. 自动验证

如果部署时使用了 `--verify` 参数，合约应该已经自动在 Basescan 上验证。

### 2. 手动验证（如果需要）

如果自动验证失败，可以手动验证：

```bash
forge verify-contract <CONTRACT_ADDRESS> \
  <CONTRACT_NAME>:<CONTRACT_PATH> \
  --chain-id 84532 \
  --etherscan-api-key $BASESCAN_API_KEY \
  --constructor-args $(cast abi-encode "constructor(uint256,address)" <MAX_SUPPLY> <SAFE_MULTISIG>)
```

### 3. 在 Basescan 上查看

访问 [BaseScan Sepolia](https://sepolia.basescan.org/) 并搜索你的合约地址，确认：
- 合约代码已验证
- 合约所有者正确（应为 Safe 多签地址）
- 所有交易记录正常

## 部署后操作

### 1. 验证合约所有权

确认所有合约的所有者都是 Safe 多签地址：

```bash
# 检查 AIOERC20 所有者
cast call <AIO_TOKEN_ADDRESS> "owner()(address)" --rpc-url $BASE_SEPOLIA_RPC

# 检查 FeeDistributor 所有者
cast call <FEE_DISTRIBUTOR_ADDRESS> "owner()(address)" --rpc-url $BASE_SEPOLIA_RPC

# 检查 Interaction 所有者
cast call <INTERACTION_ADDRESS> "owner()(address)" --rpc-url $BASE_SEPOLIA_RPC
```

所有返回值应该都是你的 `SAFE_MULTISIG` 地址。

### 2. 配置 AIO Token 和奖励池

部署后，需要配置 Interaction 合约的 AIO token 和奖励池，以便用户完成交互后可以领取 AIO 奖励。

#### 2.1 准备 AIO Token 和奖励池

在配置之前，需要确保：

1. **AIO Token 已部署**：AIO token 合约已部署（部署脚本会自动部署）
2. **奖励池地址**：准备一个地址作为奖励池（可以是 Safe 多签地址或其他地址）
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

# 注意：mint 函数只能由 owner 调用
# 如果 owner 是 Safe 多签，必须通过 Safe 多签执行
```

**通过 Safe 多签执行**：
1. 在 Safe 多签界面创建交易
2. 调用 `AIOERC20.mint(ownerAddress, amount)`
3. 确认并执行交易

**或者使用 cast（仅当 owner 是单签地址时）**：

```bash
cast send $AIO_TOKEN_ADDRESS \
  "mint(address,uint256)" \
  $OWNER_ADDRESS $MINT_AMOUNT \
  --rpc-url $BASE_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY
```

**验证 Mint 结果**：

```bash
# 检查 owner 地址的余额
cast call $AIO_TOKEN_ADDRESS \
  "balanceOf(address)(uint256)" \
  $OWNER_ADDRESS \
  --rpc-url $BASE_SEPOLIA_RPC

# 检查已 mint 的总量
cast call $AIO_TOKEN_ADDRESS \
  "totalMinted()(uint256)" \
  --rpc-url $BASE_SEPOLIA_RPC
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
  --rpc-url $BASE_SEPOLIA_RPC

# 检查 owner 地址的余额（应该减少）
cast call $AIO_TOKEN_ADDRESS \
  "balanceOf(address)(uint256)" \
  $OWNER_ADDRESS \
  --rpc-url $BASE_SEPOLIA_RPC
```

**分批转账**：如果需要，可以分多次转账到奖励池，灵活控制奖励池的代币数量：

```bash
# 第一次转账：初始资金
# 通过 Safe 多签执行：AIOERC20.transfer(rewardPoolAddress, initialAmount)

# 后续根据需要补充奖励池
# 通过 Safe 多签执行：AIOERC20.transfer(rewardPoolAddress, additionalAmount)
```

**注意事项**：
- 奖励池地址需要有足够的代币余额，以支持用户领取奖励
- 可以根据实际使用情况，定期补充奖励池的代币
- 建议保留部分代币在 owner 地址，用于其他用途（如流动性、社区奖励等）

#### 2.2 设置 AIO Token 地址

```bash
# 设置环境变量
export INTERACTION_ADDRESS=<deployed_interaction_address>
export AIO_TOKEN_ADDRESS=<deployed_aio_token_address>

# 调用 setAIOToken（需要 owner 或 PARAM_SETTER_ROLE）
cast send $INTERACTION_ADDRESS \
  "setAIOToken(address)" \
  $AIO_TOKEN_ADDRESS \
  --rpc-url $BASE_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY
```

**如果使用 Safe 多签作为 owner**：
1. 在 Safe 多签界面创建交易
2. 调用 `Interaction.setAIOToken(aioTokenAddress)`
3. 确认并执行交易

#### 2.3 设置奖励池地址

```bash
# 设置环境变量
export INTERACTION_ADDRESS=<deployed_interaction_address>
export REWARD_POOL_ADDRESS=<reward_pool_address>

# 调用 setAIORewardPool（需要 owner 或 PARAM_SETTER_ROLE）
cast send $INTERACTION_ADDRESS \
  "setAIORewardPool(address)" \
  $REWARD_POOL_ADDRESS \
  --rpc-url $BASE_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY
```

**如果使用 Safe 多签作为 owner**：
1. 在 Safe 多签界面创建交易
2. 调用 `Interaction.setAIORewardPool(rewardPoolAddress)`
3. 确认并执行交易

#### 2.4 授权 Interaction 合约从奖励池转移 AIO Token

⚠️ **重要**：这是关键步骤！`claimAIO` 功能需要奖励池授权 Interaction 合约才能正常工作。

奖励池地址需要授权 Interaction 合约可以转移 AIO token。根据 `claimAIO` 函数的实现：
```solidity
aioToken.transferFrom(aioRewardPool, msg.sender, amount)
```
这意味着需要设置：`allowance[aioRewardPool][Interaction合约] >= amount`

##### 步骤 1：检查奖励池类型和余额

首先检查奖励池是 EOA（外部账户）还是智能合约：

```bash
# 检查奖励池地址是否有代码（合约）
cast code $REWARD_POOL_ADDRESS --rpc-url $BASE_SEPOLIA_RPC

# 检查奖励池的 ETH 余额（需要 ETH 支付 gas）
cast balance $REWARD_POOL_ADDRESS --rpc-url $BASE_SEPOLIA_RPC
```

**如果余额为 0**：
- 如果是 EOA：需要先充值 ETH 到奖励池地址（至少 0.01 ETH）
- 如果是 Safe 多签：Safe 会自动处理 gas，但需要确保 Safe 有 ETH 余额

##### 步骤 2：设置环境变量

```bash
# 设置环境变量
export AIO_TOKEN_ADDRESS=<deployed_aio_token_address>
export INTERACTION_ADDRESS=<deployed_interaction_address>
export REWARD_POOL_ADDRESS=<reward_pool_address>
```

##### 步骤 3：执行 Approve（根据奖励池类型选择方法）

**方法 A：如果奖励池是 EOA（外部账户）**

如果您有奖励池地址的私钥：

```bash
# ⚠️ 关键：交易必须发送到 AIO Token 合约地址，不是奖励池地址！
# ⚠️ 关键：使用奖励池地址的私钥签名

# 授权最大金额（推荐，避免频繁授权）
cast send $AIO_TOKEN_ADDRESS \
  "approve(address,uint256)(bool)" \
  $INTERACTION_ADDRESS \
  0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff \
  --rpc-url $BASE_SEPOLIA_RPC \
  --private-key $REWARD_POOL_PRIVATE_KEY

# 或授权固定金额（例如：10 亿 token，注意 AIO 使用 8 位小数）
cast send $AIO_TOKEN_ADDRESS \
  "approve(address,uint256)(bool)" \
  $INTERACTION_ADDRESS \
  1000000000000000000000000000 \
  --rpc-url $BASE_SEPOLIA_RPC \
  --private-key $REWARD_POOL_PRIVATE_KEY
```

**如果奖励池 ETH 余额不足**：
```bash
# 从其他账户向奖励池转账 ETH（至少 0.01 ETH）
cast send $REWARD_POOL_ADDRESS \
  --value $(cast --to-wei 0.01 ether) \
  --rpc-url $BASE_SEPOLIA_RPC \
  --private-key $OTHER_ACCOUNT_PRIVATE_KEY

# 或使用测试网水龙头
# 访问：https://www.coinbase.com/faucets/base-ethereum-goerli-faucet
# 输入奖励池地址领取测试 ETH
```

**方法 B：如果奖励池是 Safe 多签地址（推荐）**

通过 Safe 多签界面执行：

1. 访问 [Safe Web 界面](https://app.safe.global/)
2. 连接到您的 Safe 钱包（奖励池地址）
3. 点击 "New transaction" → "Contract interaction"
4. 设置以下参数：
   - **To**: `$AIO_TOKEN_ADDRESS` (AIO Token 合约地址) ⚠️ **不是奖励池地址！**
   - **Value**: `0`
   - **Method**: `approve`
   - **Parameters**:
     - `spender`: `$INTERACTION_ADDRESS` (Interaction 合约地址)
     - `amount`: `115792089237316195423570985008687907853269984665640564039457584007913129639935` (最大 uint256，或具体金额)
5. 确认并收集足够的签名
6. 执行交易

**方法 C：使用 Safe CLI**

```bash
# 生成交易数据
APPROVE_DATA=$(cast calldata 'approve(address,uint256)' \
  $INTERACTION_ADDRESS \
  0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)

# 通过 Safe 发送交易
safe-cli send \
  --safe $REWARD_POOL_ADDRESS \
  --to $AIO_TOKEN_ADDRESS \
  --data "$APPROVE_DATA" \
  --rpc-url $BASE_SEPOLIA_RPC
```

##### 步骤 4：验证 Approve 是否成功

执行 approve 后，**必须验证**是否设置成功：

```bash
# 检查 allowance
cast call $AIO_TOKEN_ADDRESS \
  "allowance(address,address)(uint256)" \
  $REWARD_POOL_ADDRESS \
  $INTERACTION_ADDRESS \
  --rpc-url $BASE_SEPOLIA_RPC
```

**预期结果**：
- 如果返回 `0`：approve 未成功，需要重新执行
- 如果返回非零值：approve 成功 ✅

**常见错误和解决方案**：

1. **错误：`gas required exceeds allowance (0)`**
   - **原因**：奖励池 ETH 余额为 0
   - **解决**：向奖励池地址充值 ETH（至少 0.01 ETH）

2. **错误：`execution reverted (unknown custom error)`**
   - **原因**：approve 交易发送到了错误的地址（发送到了奖励池而不是 AIO Token）
   - **解决**：确保 `To` 地址是 AIO Token 合约地址，不是奖励池地址

3. **错误：Allowance 仍为 0**
   - **原因**：approve 交易未成功执行
   - **解决**：
     - 检查交易是否已确认
     - 确认使用了正确的私钥（EOA）或通过 Safe 多签执行
     - 确认 spender 是 Interaction 合约地址

**建议**：
- 如果奖励池会持续补充，可以授权一个很大的额度（如 `type(uint256).max`），避免频繁授权
- 建议使用 Safe 多签作为奖励池，更安全且便于管理
- 执行 approve 后务必验证 allowance > 0

#### 2.5 为每个 Action 设置奖励数量

为每个 action 配置对应的 AIO 奖励数量：

```bash
# 设置环境变量
export INTERACTION_ADDRESS=<deployed_interaction_address>
export ACTION="send_pixelmug"  # action 字符串
export REWARD_AMOUNT=1000000000000000000  # 例如：1 AIO token (1e18 wei)

# 调用 setActionRewardByString（需要 owner 或 PARAM_SETTER_ROLE）
cast send $INTERACTION_ADDRESS \
  "setActionRewardByString(string,uint256)" \
  "$ACTION" $REWARD_AMOUNT \
  --rpc-url $BASE_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY
```

**示例：为多个 action 设置奖励**：

```bash
# 为 send_pixelmug action 设置 1 AIO 奖励
cast send $INTERACTION_ADDRESS \
  "setActionRewardByString(string,uint256)" \
  "send_pixelmug" 1000000000000000000 \
  --rpc-url $BASE_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY

# 为 aio_rpc_call action 设置 2 AIO 奖励
cast send $INTERACTION_ADDRESS \
  "setActionRewardByString(string,uint256)" \
  "aio_rpc_call" 2000000000000000000 \
  --rpc-url $BASE_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY

# 为 verify_proof action 设置 0.5 AIO 奖励
cast send $INTERACTION_ADDRESS \
  "setActionRewardByString(string,uint256)" \
  "verify_proof" 500000000000000000 \
  --rpc-url $BASE_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY
```

**如果使用 Safe 多签作为 owner**：
1. 在 Safe 多签界面创建交易
2. 调用 `Interaction.setActionRewardByString(action, rewardAmount)`
3. 确认并执行交易

#### 2.6 验证配置

配置完成后，验证设置是否正确：

```bash
# 检查配置
cast call $INTERACTION_ADDRESS \
  "getConfig()(uint256,address,bool,address,address)" \
  --rpc-url $BASE_SEPOLIA_RPC

# 检查特定 action 的奖励数量
cast call $INTERACTION_ADDRESS \
  "actionReward(bytes32)(uint256)" \
  $(cast keccak "send_pixelmug") \
  --rpc-url $BASE_SEPOLIA_RPC

# 检查奖励池的授权额度
cast call $AIO_TOKEN_ADDRESS \
  "allowance(address,address)(uint256)" \
  $REWARD_POOL_ADDRESS $INTERACTION_ADDRESS \
  --rpc-url $BASE_SEPOLIA_RPC
```

#### 2.7 配置检查清单

- [ ] AIO token 已 mint 到奖励池地址
- [ ] Interaction 合约已设置 AIO token 地址
- [ ] Interaction 合约已设置奖励池地址
- [ ] 奖励池已授权 Interaction 合约足够的额度
- [ ] 所有 action 的奖励数量已配置
- [ ] 配置已通过验证

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
  --rpc-url $BASE_SEPOLIA_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast
```

#### 启用治理模式后的变化分析

启用治理模式是一个**不可逆**的操作，会永久改变合约的权限结构。以下是详细的变化：

> **重要说明**：根据当前的部署脚本，合约在部署时就已经将 Safe 多签设置为 owner。因此启用治理模式时，所有权不会改变，主要变化是启用基于角色的访问控制（RBAC）系统。

##### 1. **权限结构变化**

**启用前：**
- 合约所有者（Owner）：Safe 多签地址（部署时已设置）
- 可以调用所有 `onlyOwner` 函数
- 可以设置所有参数（手续费、项目钱包、AIO Token 等）
- 使用简单的 owner 权限模型

**启用后：**
- 合约所有者：**仍然是 Safe 多签地址**（不变）
- 启用基于角色的访问控制（AccessControl）
- 参数设置权限从 `onlyOwner` 转移到 `PARAM_SETTER_ROLE`
- 引入角色管理系统，实现权限分离

##### 2. **角色分配**

启用治理模式后，会创建并分配两个角色：

| 角色 | 接收者 | 权限 | 说明 |
|------|--------|------|------|
| `DEFAULT_ADMIN_ROLE` | Safe 多签地址 | 最高管理权限，可以授予/撤销其他角色 | 与 owner 权限类似，但通过 AccessControl 管理 |
| `PARAM_SETTER_ROLE` | 参数设置者地址 | 可以设置合约参数（手续费、钱包地址、AIO Token 等） | 新引入的角色，专门用于参数设置 |

**关键变化：**
- Safe 多签**保持** `DEFAULT_ADMIN_ROLE`（在部署时构造函数中已授予，启用治理时保持不变）
- Safe 多签**保持** owner 身份（部署时已设置，启用治理时保持不变）
- 参数设置者**获得** `PARAM_SETTER_ROLE`，可以独立设置参数（这是主要的新变化）

##### 4. **受影响的函数**

以下函数在启用治理模式后，权限检查逻辑会改变：

**FeeDistributor 合约：**
- `setProjectWallet()` - 从检查 `owner` → 检查 `PARAM_SETTER_ROLE`
- `setFeeWei()` - 从检查 `owner` → 检查 `PARAM_SETTER_ROLE`

**Interaction 合约：**
- `setAIOToken()` - 从检查 `owner` → 检查 `PARAM_SETTER_ROLE`
- `setAIORewardPool()` - 从检查 `owner` → 检查 `PARAM_SETTER_ROLE`

**权限检查逻辑变化：**
```solidity
// 启用前：只有 owner（Safe 多签）可以调用
function setFeeWei(uint256 newFeeWei) external {
    require(msg.sender == owner(), "caller is not the owner");
    // ...
}

// 启用后：owner 或 PARAM_SETTER_ROLE 都可以调用
function setFeeWei(uint256 newFeeWei) external {
    if (governanceModeEnabled) {
        require(hasRole(PARAM_SETTER_ROLE, msg.sender), "caller does not have PARAM_SETTER_ROLE");
    } else {
        require(msg.sender == owner(), "caller is not the owner");
    }
    // ...
}
```

##### 4. **关键变化总结**

✅ **会发生的：**
- `governanceModeEnabled` 标志设置为 `true`（永久）
- Safe 多签**保持** `DEFAULT_ADMIN_ROLE` 和 owner 身份（部署时已拥有，启用治理时保持不变）
- 参数设置者**获得** `PARAM_SETTER_ROLE`（这是主要的新变化）
- 参数设置函数从检查 `owner` 改为检查 `PARAM_SETTER_ROLE`（启用治理后，即使 Safe 多签是 owner，也需要通过 `PARAM_SETTER_ROLE` 来设置参数）
- 启用基于角色的访问控制系统

❌ **不会发生的：**
- 所有权不会改变（已经是 Safe 多签）
- Safe 多签仍然可以调用 `onlyOwner` 函数（因为仍然是 owner）
- 无法撤销治理模式（一旦启用，永久生效）

⚠️ **重要限制：**
- `setTrustedBootstrapper()` 在治理模式启用后**无法再调用**
- 治理模式只能启用**一次**，无法重复启用
- **关键变化**：启用后，参数设置函数（`setFeeWei`, `setProjectWallet`, `setAIOToken`, `setAIORewardPool`）**不再检查 owner**，而是**只检查 `PARAM_SETTER_ROLE`**。这意味着：
  - 即使 Safe 多签是 owner，如果没有 `PARAM_SETTER_ROLE`，也无法设置参数
  - Safe 多签需要先给自己授予 `PARAM_SETTER_ROLE`，或者通过参数设置者来设置参数

##### 5. **启用后的操作流程**

启用治理模式后，管理操作分为两类：

1. **设置参数**：由 `PARAM_SETTER_ROLE` 持有者执行
   ```solidity
   // 需要 PARAM_SETTER_ROLE（启用治理后，不再检查 owner）
   feeDistributor.setFeeWei(newFee);
   interaction.setAIOToken(tokenAddress);
   interaction.setAIORewardPool(rewardPoolAddress);
   ```
   > **⚠️ 重要**：启用治理模式后，参数设置函数**只检查 `PARAM_SETTER_ROLE`，不再检查 owner**。这意味着：
   > - 即使 Safe 多签是 owner，如果没有 `PARAM_SETTER_ROLE`，也无法设置参数
   > - Safe 多签需要先给自己授予 `PARAM_SETTER_ROLE`，或者通过参数设置者来设置参数
   > - 建议在启用治理模式时，将 Safe 多签也设置为参数设置者，或者确保参数设置者地址可信

2. **角色管理**：由 Safe 多签（`DEFAULT_ADMIN_ROLE`）执行
   ```solidity
   // 需要 DEFAULT_ADMIN_ROLE
   interaction.grantRole(PARAM_SETTER_ROLE, newParamSetter);
   interaction.revokeRole(PARAM_SETTER_ROLE, oldParamSetter);
   ```

3. **所有权操作**：由 Safe 多签（owner）执行
   ```solidity
   // 需要 owner（Safe 多签）
   interaction.transferOwnership(newOwner);
   interaction.renounceOwnership();
   ```

**权限分离的优势：**
- 参数设置可以由专门的地址（`PARAM_SETTER_ROLE`）执行，无需 Safe 多签批准
- Safe 多签专注于角色管理和关键操作
- 降低操作成本（参数设置不需要多签确认）

##### 6. **实际变化总结（owner 已是 Safe 多签的情况）**

由于合约在部署时已经将 Safe 多签设置为 owner，启用治理模式的实际变化如下：

| 项目 | 启用前 | 启用后 | 变化 |
|------|--------|--------|------|
| **Owner** | Safe 多签 | Safe 多签 | ✅ 无变化 |
| **DEFAULT_ADMIN_ROLE** | Safe 多签（构造函数中已授予） | Safe 多签 | ✅ 无变化 |
| **PARAM_SETTER_ROLE** | 不存在 | 参数设置者地址 | ✅ 新增 |
| **参数设置权限** | 只有 owner（Safe 多签） | 只有 `PARAM_SETTER_ROLE` | ⚠️ **关键变化** |
| **governanceModeEnabled** | `false` | `true` | ✅ 永久启用 |

**核心变化：**
启用治理模式后，参数设置函数（`setFeeWei`, `setProjectWallet`, `setAIOToken`, `setAIORewardPool`）的权限检查从：
- **启用前**：`msg.sender == owner()`（只有 Safe 多签可以）
- **启用后**：`hasRole(PARAM_SETTER_ROLE, msg.sender)`（只有 `PARAM_SETTER_ROLE` 持有者可以）

**这意味着：**
- ✅ Safe 多签仍然是 owner 和 `DEFAULT_ADMIN_ROLE`，可以管理角色和所有权
- ⚠️ **但 Safe 多签无法再直接设置参数**（除非也拥有 `PARAM_SETTER_ROLE`）
- ✅ 参数设置可以由 `PARAM_SETTER_ROLE` 持有者独立执行，无需 Safe 多签批准
- ✅ Safe 多签可以通过 `grantRole`/`revokeRole` 管理参数设置者

##### 7. **安全考虑**

- ✅ **权限分离**：参数设置和角色管理分离，降低单点风险
- ✅ **灵活管理**：参数设置可以由专门地址执行，无需多签确认，降低操作成本
- ✅ **角色控制**：Safe 多签通过 `DEFAULT_ADMIN_ROLE` 可以灵活管理角色分配
- ⚠️ **不可逆性**：一旦启用，无法回退到简单的 owner 模式
- ⚠️ **前置条件**：启用前确保参数设置者地址可信（它将获得参数设置权限）
- ⚠️ **权限变化**：启用后，Safe 多签作为 owner 也无法直接设置参数，必须通过 `PARAM_SETTER_ROLE`
- 💡 **建议**：如果希望 Safe 多签也能设置参数，可以在启用治理后，给 Safe 多签也授予 `PARAM_SETTER_ROLE`

##### 8. **验证治理模式是否已启用**

```bash
# 检查 FeeDistributor 治理模式
cast call <FEE_DISTRIBUTOR_ADDRESS> "governanceModeEnabled()(bool)" --rpc-url $BASE_SEPOLIA_RPC

# 检查 Interaction 治理模式
cast call <INTERACTION_ADDRESS> "governanceModeEnabled()(bool)" --rpc-url $BASE_SEPOLIA_RPC

# 检查角色分配
cast call <INTERACTION_ADDRESS> "hasRole(bytes32,address)(bool)" \
  $(cast sig "DEFAULT_ADMIN_ROLE()") \
  <SAFE_MULTISIG_ADDRESS> \
  --rpc-url $BASE_SEPOLIA_RPC

# 检查参数设置者角色
cast call <INTERACTION_ADDRESS> "hasRole(bytes32,address)(bool)" \
  $(cast sig "PARAM_SETTER_ROLE()") \
  <PARAM_SETTER_ADDRESS> \
  --rpc-url $BASE_SEPOLIA_RPC
```

##### 9. **可选：给 Safe 多签也授予 PARAM_SETTER_ROLE**

如果希望 Safe 多签既能管理角色，也能设置参数，可以在启用治理模式后，给 Safe 多签也授予 `PARAM_SETTER_ROLE`：

```bash
# 通过 Safe 多签执行（需要多签批准）
cast send <INTERACTION_ADDRESS> \
  "grantRole(bytes32,address)" \
  $(cast sig "PARAM_SETTER_ROLE()") \
  <SAFE_MULTISIG_ADDRESS> \
  --rpc-url $BASE_SEPOLIA_RPC \
  --private-key $SAFE_MULTISIG_PRIVATE_KEY

# 同样给 FeeDistributor 也授予
cast send <FEE_DISTRIBUTOR_ADDRESS> \
  "grantRole(bytes32,address)" \
  $(cast sig "PARAM_SETTER_ROLE()") \
  <SAFE_MULTISIG_ADDRESS> \
  --rpc-url $BASE_SEPOLIA_RPC \
  --private-key $SAFE_MULTISIG_PRIVATE_KEY
```

这样配置后：
- ✅ Safe 多签拥有 `DEFAULT_ADMIN_ROLE`：可以管理角色
- ✅ Safe 多签拥有 `PARAM_SETTER_ROLE`：可以设置参数
- ✅ Safe 多签是 owner：可以执行所有权操作
- ✅ 参数设置者拥有 `PARAM_SETTER_ROLE`：也可以设置参数（无需多签批准）

或者使用 GovernanceBootstrapper（单笔交易）：

```bash
export TIMELOCK_ADDRESS=$SAFE_MULTISIG
export BOOTSTRAPPER_ADDRESS=<deployed_bootstrapper_address>

forge script script/Helpers.s.sol:HelperScripts \
  --sig "bootstrapGovernance()" \
  --rpc-url $BASE_SEPOLIA_RPC \
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

## 故障排查

### 问题 1: 部署失败 - Insufficient funds

**错误信息**: `insufficient funds for gas` 或 `execution reverted: insufficient funds`

**原因**:
- 钱包余额不足以支付 gas 费用
- 部署多个合约需要较多 gas，余额可能不够

**解决方案**:
1. **检查当前余额**:
   ```bash
   cast balance <YOUR_WALLET_ADDRESS> --rpc-url $BASE_SEPOLIA_RPC
   ```

2. **估算所需 gas**:
   ```bash
   # 先模拟部署查看 gas 使用量
   forge script script/Deploy.s.sol:DeployScript \
     --rpc-url $BASE_SEPOLIA_RPC \
     --private-key $PRIVATE_KEY
   ```

3. **获取更多测试 ETH**:
   - 从水龙头获取 Base Sepolia ETH（见上方"获取 Base Sepolia ETH"部分）
   - 建议至少准备 0.01 - 0.05 ETH

4. **如果余额仍然不足**:
   - 检查是否有未确认的交易占用余额
   - 等待之前的交易确认后再试
   - 考虑分批部署（修改部署脚本，分多次部署）

### 问题 2: 合约验证失败

**错误信息**: `Failed to verify contract`

**解决方案**:
- 检查 Basescan API Key 是否正确
- 确认合约编译设置与部署时一致
- 尝试手动验证（见上方手动验证部分）

### 问题 3: 环境变量未加载

**错误信息**: `Environment variable not found`

**解决方案**:
- 确认 `.env` 文件在项目根目录
- 使用 `source .env` 加载环境变量（或使用 `export` 命令）
- 或者直接在命令中指定：`--private-key $(grep PRIVATE_KEY .env | cut -d '=' -f2)`

### 问题 4: RPC 端点连接失败

**错误信息**: `Failed to connect to RPC`

**解决方案**:
- 检查 RPC URL 是否正确
- 尝试使用其他 RPC 端点
- 检查网络连接

### 问题 5: Safe 多签地址错误

**错误信息**: `SAFE_MULTISIG must be set`

**解决方案**:
- 确认 `.env` 文件中设置了 `SAFE_MULTISIG`
- 确认地址格式正确（0x 开头的 42 字符地址）
- 在 Base Sepolia 上确认该地址存在

## 网络信息

### Base Sepolia Testnet

- **Chain ID**: 84532
- **RPC URL**: `https://base-sepolia.g.alchemy.com/v2/Br9B6PkCm4u7NhukuwdGihx6SZnhrLWI` (Alchemy) 或 `https://sepolia.base.org` (公共 RPC)
- **区块浏览器**: [BaseScan Sepolia](https://sepolia.basescan.org/)
- **水龙头**: [Coinbase Base Sepolia Faucet](https://www.coinbase.com/faucets/base-ethereum-goerli-faucet)

## 相关资源

- [Foundry 文档](https://book.getfoundry.sh/)
- [Base 官方文档](https://docs.base.org/)
- [BaseScan 文档](https://docs.basescan.org/)
- [Safe 多签钱包](https://safe.global/)

## 注意事项

1. **测试网限制**: Base Sepolia 是测试网，代币和交易没有实际价值
2. **Gas 费用**: 虽然测试网 ETH 免费，但部署大型合约仍需要足够的 gas
3. **合约升级**: 部署后合约不可更改，请确保代码正确
4. **多签安全**: 所有合约所有者都是 Safe 多签，确保多签配置正确
5. **备份地址**: 部署后请备份所有合约地址，后续操作需要用到

---

如有问题，请参考项目主 README 或提交 Issue。

