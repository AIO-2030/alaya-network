# Dune Analytics Integration Guide

本指南帮助您在 Dune Analytics 上查询和分析 AIO2030 Base Proof 系统的交互数据。

## 合约信息

### Interaction Contract

- **事件名称**: `InteractionRecorded`
- **合约地址**: 部署后从 `script/Deploy.s.sol` 输出获取
- **网络**: Base Mainnet / Base Sepolia Testnet

## 事件定义

### InteractionRecorded

```solidity
event InteractionRecorded(
    address indexed user,           // 执行交互的用户地址（索引）
    bytes32 indexed actionHash,      // Action 的哈希值（索引，用于过滤）
    string action,                   // Action 字符串标识符（如 "send_pixelmug"）
    bytes meta,                      // 元数据 JSON 字节
    uint256 timestamp                // 区块时间戳
);
```

**重要说明**:
- `actionHash = keccak256(bytes(action))` - 用于高效过滤特定 action
- 两个 indexed 字段 (`user`, `actionHash`) 可用于快速查询
- `action` 字段保留原始字符串，便于人类阅读
- `meta` 字段包含 JSON 编码的详细信息

## Dune 建表示例

### 方法 1: 使用 Dune Spell（推荐）

在 Dune 中创建新查询，使用以下 SQL：

```sql
-- 创建 InteractionRecorded 事件表
CREATE TABLE IF NOT EXISTS dune_user_generated.interaction_recorded (
    evt_tx_hash bytea,
    evt_index integer,
    evt_block_time timestamp,
    evt_block_number bigint,
    "user" bytea,
    actionHash bytea,
    action text,
    meta bytea,
    timestamp numeric
);

-- 索引以提高查询性能
CREATE INDEX IF NOT EXISTS idx_interaction_user ON dune_user_generated.interaction_recorded("user");
CREATE INDEX IF NOT EXISTS idx_interaction_actionHash ON dune_user_generated.interaction_recorded(actionHash);
CREATE INDEX IF NOT EXISTS idx_interaction_timestamp ON dune_user_generated.interaction_recorded(timestamp);
```

### 方法 2: 直接查询（使用 Dune 的内置解码）

Dune 会自动解码已索引的合约事件。您可以直接查询：

```sql
-- 替换 YOUR_INTERACTION_CONTRACT_ADDRESS 为实际部署地址
SELECT 
    evt_tx_hash,
    evt_block_time,
    "user" as user_address,
    actionHash,
    action,
    timestamp
FROM ethereum.logs_decoded
WHERE contract_address = 'YOUR_INTERACTION_CONTRACT_ADDRESS'
  AND event_name = 'InteractionRecorded'
ORDER BY evt_block_time DESC;
```

### 方法 3: 使用 Dune App（最简单）

1. 在 Dune 上创建新查询
2. 在编辑器中选择 "Decode Contract Data"
3. 输入合约地址
4. 选择 `InteractionRecorded` 事件
5. Dune 会自动创建表结构

## 常见查询示例

### 1. 查询所有交互记录

```sql
SELECT 
    evt_block_time as block_time,
    evt_tx_hash as tx_hash,
    "user" as user_address,
    actionHash,
    action,
    timestamp
FROM ethereum.logs_decoded
WHERE contract_address = 'YOUR_INTERACTION_CONTRACT_ADDRESS'
  AND event_name = 'InteractionRecorded'
ORDER BY evt_block_time DESC;
```

### 2. 按特定 action 过滤（使用 actionHash）

```sql
-- 查询 "send_pixelmug" 的所有交互
-- actionHash = keccak256(bytes("send_pixelmug"))
SELECT 
    evt_block_time,
    "user" as user_address,
    action,
    timestamp
FROM ethereum.logs_decoded
WHERE contract_address = 'YOUR_INTERACTION_CONTRACT_ADDRESS'
  AND event_name = 'InteractionRecorded'
  AND actionHash = '0x...' -- 替换为实际 hash
ORDER BY evt_block_time DESC;
```

### 3. 按用户地址过滤

```sql
-- 查询特定用户的所有交互
SELECT 
    evt_block_time,
    actionHash,
    action,
    timestamp
FROM ethereum.logs_decoded
WHERE contract_address = 'YOUR_INTERACTION_CONTRACT_ADDRESS'
  AND event_name = 'InteractionRecorded'
  AND "user" = '0x...' -- 替换为实际用户地址
ORDER BY evt_block_time DESC;
```

### 4. 按时间范围过滤

```sql
-- 查询最近 24 小时的交互
SELECT 
    evt_block_time,
    "user" as user_address,
    action,
    COUNT(*) as interaction_count
FROM ethereum.logs_decoded
WHERE contract_address = 'YOUR_INTERACTION_CONTRACT_ADDRESS'
  AND event_name = 'InteractionRecorded'
  AND evt_block_time >= NOW() - INTERVAL '24 hours'
GROUP BY evt_block_time, "user", action
ORDER BY evt_block_time DESC;
```

### 5. 统计每个 action 的使用次数

```sql
-- 统计各 action 的使用频率
SELECT 
    action,
    COUNT(*) as count,
    COUNT(DISTINCT "user") as unique_users
FROM ethereum.logs_decoded
WHERE contract_address = 'YOUR_INTERACTION_CONTRACT_ADDRESS'
  AND event_name = 'InteractionRecorded'
GROUP BY action
ORDER BY count DESC;
```

### 6. 查询活跃用户（Top 10）

```sql
-- 查询交互次数最多的用户
SELECT 
    "user" as user_address,
    COUNT(*) as interaction_count,
    COUNT(DISTINCT action) as unique_actions,
    MIN(evt_block_time) as first_interaction,
    MAX(evt_block_time) as last_interaction
FROM ethereum.logs_decoded
WHERE contract_address = 'YOUR_INTERACTION_CONTRACT_ADDRESS'
  AND event_name = 'InteractionRecorded'
GROUP BY "user"
ORDER BY interaction_count DESC
LIMIT 10;
```

### 7. 每日交互统计

```sql
-- 按日期统计交互数量
SELECT 
    DATE(evt_block_time) as date,
    COUNT(*) as total_interactions,
    COUNT(DISTINCT "user") as unique_users,
    COUNT(DISTINCT action) as unique_actions
FROM ethereum.logs_decoded
WHERE contract_address = 'YOUR_INTERACTION_CONTRACT_ADDRESS'
  AND event_name = 'InteractionRecorded'
GROUP BY DATE(evt_block_time)
ORDER BY date DESC;
```

## 计算 actionHash

如果需要手动计算 `actionHash`，可以使用以下方法：

### JavaScript/TypeScript

```javascript
import { keccak256, toUtf8Bytes } from 'ethers';

const action = "send_pixelmug";
const actionHash = keccak256(toUtf8Bytes(action));
console.log(actionHash); // 0x...
```

### Python

```python
from eth_utils import keccak, to_bytes, text_if_str

action = "send_pixelmug"
action_hash = keccak(to_bytes(text=action))
print(f"0x{action_hash.hex()}")
```

### Solidity

```solidity
bytes32 actionHash = keccak256(bytes("send_pixelmug"));
```

### 在线工具

- [Keccak256 Online](https://emn178.github.io/online-tools/keccak_256.html)
- 输入 action 字符串，选择 "Text"，获取哈希值

## 常用 actionHash 参考

以下是常见 action 字符串的哈希值（用于快速查询）：

| Action String | actionHash (keccak256) |
|--------------|------------------------|
| `send_pixelmug` | `0x...` (部署后计算) |
| `aio_rpc_call` | `0x...` (部署后计算) |
| `verify_proof` | `0x...` (部署后计算) |

**注意**: 实际哈希值需要在部署后使用上述方法计算。

## 注意事项

1. **合约地址**: 部署后务必更新查询中的合约地址
2. **网络**: 确保查询的是正确的网络（Base Mainnet 或 Base Sepolia）
3. **索引字段**: `user` 和 `actionHash` 是 indexed 字段，查询这些字段时性能最佳
4. **Meta 字段**: `meta` 字段是字节数据，需要解码 JSON 才能查看内容
5. **时间戳**: `timestamp` 字段与 `evt_block_time` 相同（都是区块时间戳）

## 数据可视化建议

### Dashboard 建议包含：

1. **总体统计**
   - 总交互次数
   - 唯一用户数
   - 唯一 action 数

2. **时间序列**
   - 每日交互数量（折线图）
   - 每小时交互数量（热力图）

3. **用户分析**
   - Top 10 活跃用户
   - 用户交互分布（柱状图）

4. **Action 分析**
   - 各 action 使用频率（饼图）
   - Action 使用趋势（堆叠面积图）

5. **实时监控**
   - 最新交互记录（表格）
   - 实时交互速率

## 支持

如有问题，请参考：
- [Dune Analytics 文档](https://docs.dune.com/)
- [Dune SQL 参考](https://docs.dune.com/queries/dune-sql-reference)
- 项目 README.md

