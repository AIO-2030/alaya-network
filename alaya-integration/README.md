## Foundry

**Foundry is a blazing fast, portable and modular toolkit for Ethereum application development written in Rust.**

Foundry consists of:

- **Forge**: Ethereum testing framework (like Truffle, Hardhat and DappTools).
- **Cast**: Swiss army knife for interacting with EVM smart contracts, sending transactions and getting chain data.
- **Anvil**: Local Ethereum node, akin to Ganache, Hardhat Network.
- **Chisel**: Fast, utilitarian, and verbose solidity REPL.

## Documentation

https://book.getfoundry.sh/

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### 本地测试网络 (Anvil)

#### 启动本地测试网络

**方法 1: 使用启动脚本（推荐）**

```shell
./scripts/start-local-network.sh
```

**方法 2: 直接使用 Anvil 命令**

```shell
anvil
```

**方法 3: 自定义配置启动**

```shell
anvil \
  --host 0.0.0.0 \
  --port 8545 \
  --accounts 10 \
  --balance 10000 \
  --gas-limit 30000000
```

启动后，Anvil 会显示：
- RPC URL: `http://127.0.0.1:8545`
- Chain ID: `31337`
- 10 个预充值账户（每个账户 10000 ETH）及其私钥

#### 部署到本地测试网络

**⚠️ 重要**: 部署时必须指定 `--private-key` 和 `--sender` 参数，否则会报错。

**方法 1: 使用部署脚本（最简单，推荐）**

```shell
./scripts/deploy-local.sh
```

**方法 2: 手动部署命令**

```shell
# 使用 Anvil 默认的第一个账户
# 地址: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
# 私钥: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
forge script script/Deploy.s.sol:DeployScript \
  --sig "deployLocal()" \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --broadcast
```

或者使用 Anvil 启动时显示的其他账户：

```shell
# 使用 Anvil 启动时显示的账户地址和私钥
forge script script/Deploy.s.sol:DeployScript \
  --sig "deployLocal()" \
  --rpc-url http://127.0.0.1:8545 \
  --private-key <ANVIL_PRIVATE_KEY> \
  --sender <ANVIL_ADDRESS> \
  --broadcast
```

**注意**: `deployLocal()` 函数会：
- 自动部署 MockERC20 作为 USDT token
- 使用 deployer 地址作为所有合约的 owner 和 projectWallet
- 使用较小的测试值（100万代币，0.0001 ETH 手续费）
- 无需设置任何环境变量

部署完成后，脚本会输出所有合约地址的 JSON 格式，包括：
- `mockUsdt`: Mock USDT token 地址
- `aioToken`: AIOERC20 token 地址
- `feeDistributor`: FeeDistributor 合约地址
- `interaction`: Interaction 合约地址
- `governanceBootstrapper`: GovernanceBootstrapper 合约地址
- `owner`: 合约所有者地址（deployer）

### Deploy

#### 本地测试网络

**方法 1: 使用部署脚本（推荐）**

```shell
# 1. 启动本地测试网络（在另一个终端）
./scripts/start-local-network.sh

# 2. 部署合约（在新终端）
./scripts/deploy-local.sh
```

**方法 2: 手动部署**

```shell
# 1. 启动本地测试网络（在另一个终端）
./scripts/start-local-network.sh

# 2. 部署合约（在新终端）
# ⚠️ 必须同时指定 --private-key 和 --sender 参数
forge script script/Deploy.s.sol:DeployScript \
  --sig "deployLocal()" \
  --rpc-url http://127.0.0.1:8545 \
  --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --broadcast
```

**Anvil 默认账户信息**: 
- 第一个账户地址: `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266`
- 第一个账户私钥: `0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80`
- 每个账户预充值: 10000 ETH
- 你也可以使用 Anvil 启动时显示的其他账户地址和私钥

#### Base Sepolia Testnet

```shell
forge script script/Deploy.s.sol --rpc-url $BASE_SEPOLIA_RPC --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $BASESCAN_API_KEY
```

#### Base Mainnet

```shell
forge script script/Deploy.s.sol --rpc-url $BASE_RPC --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $BASESCAN_API_KEY
```

#### Environment Variables

Create a `.env` file based on `.env.example`:

- `PRIVATE_KEY`: Your deployment wallet private key
- `PROJECT_WALLET`: Address that will receive all fees
- `SAFE_MULTISIG`: **REQUIRED** - Address of Safe multisig that will own ALL contracts (AIOERC20, FeeDistributor, Interaction). 
  - ⚠️ **IMPORTANT**: Before mainnet deployment, verify this address is the correct Safe multisig address
  - All contracts are deployed with Safe multisig as owner in constructor - no transferOwnership needed
- `USDT_TOKEN`: USDT token address on Base
- `BASE_SEPOLIA_RPC`: Base Sepolia RPC endpoint
- `BASE_RPC`: Base Mainnet RPC endpoint
- `BASESCAN_API_KEY`: API key for Basescan verification
  - 获取方式：
    1. 访问 [BaseScan 官网](https://basescan.org/)
    2. 注册或登录账户
    3. 进入账户设置/API 管理页面
    4. 创建新的 API 密钥
    5. 复制生成的 API 密钥并保存到 `.env` 文件中

#### Post-Deployment: Enable Governance

After deployment, enable governance mode using the helper script:

```shell
# Set required environment variables
# TIMELOCK_ADDRESS: Use the same Safe multisig address (or any governance address)
export TIMELOCK_ADDRESS=$SAFE_MULTISIG  # 直接使用 Safe 多签地址
export PARAM_SETTER_ADDRESS=<param_setter_address>
export FEE_DISTRIBUTOR_ADDRESS=<deployed_fee_distributor_address>
export INTERACTION_ADDRESS=<deployed_interaction_address>

# Enable governance for both contracts
forge script script/Helpers.s.sol:HelperScripts \
  --sig "enableGovernance()" \
  --rpc-url $BASE_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast
```

Or use the GovernanceBootstrapper for a single transaction:

```shell
export TIMELOCK_ADDRESS=$SAFE_MULTISIG  # 直接使用 Safe 多签地址
export BOOTSTRAPPER_ADDRESS=<deployed_bootstrapper_address>

forge script script/Helpers.s.sol:HelperScripts \
  --sig "bootstrapGovernance()" \
  --rpc-url $BASE_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast
```

**Note**: The `TIMELOCK_ADDRESS` can be any governance address (Safe multisig, TimelockController, etc.). For simplicity, you can use the same `SAFE_MULTISIG` address that owns the contracts.

### Cast

```shell
$ cast <subcommand>
```

## Dune Analytics Integration

项目包含详细的 Dune Analytics 集成指南，帮助您查询和分析链上交互数据。

详见: [DUNE.md](./DUNE.md)

关键特性:
- `InteractionRecorded` 事件包含 indexed `actionHash` 字段，便于高效过滤
- 提供完整的 Dune SQL 查询示例
- 包含常用查询模式和可视化建议

## Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
