# 代币 Mint 使用指南

## 概述

AIOERC20 代币合约支持多次 mint，只要总 mint 数量不超过 `MAX_SUPPLY`。

### 代币规格
- **总供应量**: 21 亿代币 (2,100,000,000 * 1e8)
- **初始 Mint**: 2.1 亿代币 (210,000,000 * 1e8)
- **小数位数**: 8 位
- **权限**: 只有 owner (Safe multisig) 可以 mint

## Mint 权限

### 谁可以 mint？
- **只有合约 owner** 可以调用 `mint()` 函数
- 在生产环境中，owner 是 Safe multisig 钱包
- 在本地测试中，owner 是部署者地址

### 如何检查 owner？
```bash
cast call <TOKEN_ADDRESS> "owner()(address)" --rpc-url <RPC_URL>
```

## 使用 Mint 脚本

### 方法 1: 直接调用 mint 函数

```bash
forge script script/Mint.s.sol:MintScript \
  --sig "mint(address,address,uint256)" \
  <TOKEN_ADDRESS> \
  <RECIPIENT_ADDRESS> \
  <AMOUNT> \
  --rpc-url <RPC_URL> \
  --broadcast \
  --private-key <OWNER_PRIVATE_KEY>
```

**参数说明**:
- `TOKEN_ADDRESS`: AIOERC20 代币合约地址
- `RECIPIENT_ADDRESS`: 接收代币的地址
- `AMOUNT`: 要 mint 的代币数量（**不带小数位**，脚本会自动乘以 1e8）

**示例** (mint 1000 万代币):
```bash
forge script script/Mint.s.sol:MintScript \
  --sig "mint(address,address,uint256)" \
  0x5FC8d32690cc91D4c39d9d3abcBD16989F875707 \
  0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  10000000 \
  --rpc-url http://127.0.0.1:8545 \
  --broadcast \
  --private-key $PRIVATE_KEY
```

### 方法 2: 使用环境变量

```bash
TOKEN_ADDRESS=0x... \
RECIPIENT_ADDRESS=0x... \
MINT_AMOUNT=10000000 \
forge script script/Mint.s.sol:MintScript \
  --sig "mintFromEnv()" \
  --rpc-url <RPC_URL> \
  --broadcast \
  --private-key <OWNER_PRIVATE_KEY>
```

### 方法 3: 检查代币信息（不执行 mint）

```bash
forge script script/Mint.s.sol:MintScript \
  --sig "checkTokenInfo(address)" \
  <TOKEN_ADDRESS> \
  --rpc-url <RPC_URL>
```

## 检查代币状态

### 使用 cast 命令

```bash
# 检查 decimals
cast call <TOKEN_ADDRESS> "decimals()(uint8)" --rpc-url <RPC_URL>

# 检查最大供应量
cast call <TOKEN_ADDRESS> "MAX_SUPPLY()(uint256)" --rpc-url <RPC_URL>

# 检查已 mint 总量
cast call <TOKEN_ADDRESS> "totalMinted()(uint256)" --rpc-url <RPC_URL>

# 检查剩余可 mint 数量
cast call <TOKEN_ADDRESS> "totalSupply()(uint256)" --rpc-url <RPC_URL>

# 检查账户余额
cast call <TOKEN_ADDRESS> "balanceOf(address)(uint256)" <ADDRESS> --rpc-url <RPC_URL>
```

### 使用 Mint 脚本

```bash
forge script script/Mint.s.sol:MintScript \
  --sig "checkTokenInfo(address)" \
  <TOKEN_ADDRESS> \
  --rpc-url <RPC_URL>
```

## 重要注意事项

1. **权限要求**: 只有 owner 可以 mint，确保使用 owner 的私钥签名交易
2. **数量限制**: 每次 mint 后，`totalMinted` 不能超过 `MAX_SUPPLY`
3. **小数位**: 代币使用 8 位小数，但在脚本中输入数量时不需要包含小数位
4. **Safe Multisig**: 在生产环境中，需要通过 Safe multisig 钱包执行 mint 操作

## 多次 Mint 支持

代币合约完全支持多次 mint，只要满足以下条件：
- 每次 mint 后，`totalMinted + amount <= MAX_SUPPLY`
- 调用者必须是合约 owner
- `amount > 0` 且 `to != address(0)`

## 示例场景

### 场景 1: 初始部署后 mint 2.1 亿代币
初始部署时已经自动 mint 了 2.1 亿代币到 project wallet。

### 场景 2: 后续 mint 1000 万代币
```bash
forge script script/Mint.s.sol:MintScript \
  --sig "mint(address,address,uint256)" \
  <TOKEN_ADDRESS> \
  <RECIPIENT_ADDRESS> \
  10000000 \
  --rpc-url <RPC_URL> \
  --broadcast \
  --private-key <OWNER_PRIVATE_KEY>
```

### 场景 3: 分批 mint 到不同地址
可以多次调用 mint 脚本，每次指定不同的接收地址和数量。

## 故障排除

### 错误: "AIOERC20: mint would exceed MAX_SUPPLY"
- **原因**: 尝试 mint 的数量超过了剩余可 mint 数量
- **解决**: 检查 `MAX_SUPPLY - totalMinted` 的值，确保 mint 数量不超过这个值

### 错误: "Ownable: caller is not the owner"
- **原因**: 调用者不是合约 owner
- **解决**: 确保使用 owner 的私钥签名交易，或通过 Safe multisig 执行

### 错误: "AIOERC20: amount cannot be zero"
- **原因**: mint 数量为 0
- **解决**: 确保传入的 amount 大于 0

