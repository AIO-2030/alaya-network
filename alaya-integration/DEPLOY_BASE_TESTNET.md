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

- **Coinbase Cloud** (推荐): `https://base-sepolia.gateway.tenderly.co`
- **Alchemy**: 在 [Alchemy](https://www.alchemy.com/) 创建应用后获取
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
SAFE_MULTISIG=0xYourSafeMultisigAddress

# Base Sepolia RPC 端点
BASE_SEPOLIA_RPC=https://base-sepolia.gateway.tenderly.co

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

奖励池地址需要授权 Interaction 合约可以转移 AIO token：

```bash
# 设置环境变量
export AIO_TOKEN_ADDRESS=<deployed_aio_token_address>
export INTERACTION_ADDRESS=<deployed_interaction_address>
export REWARD_POOL_ADDRESS=<reward_pool_address>
export APPROVE_AMOUNT=1000000000000000000000000000  # 例如：10 亿 token，或使用 type(uint256).max 表示无限授权

# 从奖励池地址授权 Interaction 合约（需要奖励池地址的私钥或通过 Safe 多签）
cast send $AIO_TOKEN_ADDRESS \
  "approve(address,uint256)" \
  $INTERACTION_ADDRESS $APPROVE_AMOUNT \
  --rpc-url $BASE_SEPOLIA_RPC \
  --private-key $REWARD_POOL_PRIVATE_KEY  # 或通过 Safe 多签执行
```

**如果奖励池是 Safe 多签地址**：
1. 在 Safe 多签界面创建交易
2. 调用 `AIOERC20.approve(interactionAddress, amount)`
3. 确认并执行交易

**建议**：如果奖励池会持续补充，可以授权一个很大的额度（如 `type(uint256).max`），避免频繁授权。

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
- **RPC URL**: `https://sepolia.base.org` 或使用其他提供商
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

