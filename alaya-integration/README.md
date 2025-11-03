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

### Anvil

```shell
$ anvil
```

### Deploy

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
export TIMELOCK_ADDRESS=<timelock_or_safe_address>
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
export BOOTSTRAPPER_ADDRESS=<deployed_bootstrapper_address>

forge script script/Helpers.s.sol:HelperScripts \
  --sig "bootstrapGovernance()" \
  --rpc-url $BASE_RPC \
  --private-key $PRIVATE_KEY \
  --broadcast
```

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
