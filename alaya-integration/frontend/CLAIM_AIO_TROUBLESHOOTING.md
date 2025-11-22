# claimAIO 失败问题诊断指南

## 错误现象

调用 `claimAIO` 时出现以下错误：

```
missing revert data (action="estimateGas", data=null, revert=null, code=CALL_EXCEPTION)
```

## 可能的原因

### 1. **合约状态未配置** ⚠️ 最常见

`claimAIO` 函数需要以下前置条件：

- ✅ `aioToken` 必须已设置（不能为零地址）
- ✅ `aioRewardPool` 必须已设置（不能为零地址）

**检查方法：**
```typescript
import { getConfig } from './utils/aio';

const config = await getConfig(provider, interactionAddress);
console.log('AIO Token:', config.aioToken);
console.log('Reward Pool:', config.aioRewardPool);
```

**解决方案：**
- 如果 `aioToken` 为零地址，需要调用 `setAIOToken(aioTokenAddress)`
- 如果 `aioRewardPool` 为零地址，需要调用 `setAIORewardPool(rewardPoolAddress)`

### 2. **奖励池余额不足**

奖励池必须有足够的 AIO token 余额来支付领取请求。

**检查方法：**
```typescript
// 使用诊断工具
import { diagnoseClaimAIO } from './utils/diagnoseClaim';

const diagnosis = await diagnoseClaimAIO(
  provider,
  interactionAddress,
  amount,
  userAddress
);
console.log(diagnosis);
```

**解决方案：**
- 向奖励池地址充值足够的 AIO token

### 3. **授权额度不足** ⚠️ 很常见

Interaction 合约必须被授权从奖励池转移 AIO token。

**检查方法：**
```typescript
// 检查授权额度
const tokenContract = new Contract(aioTokenAddress, AIOERC20ABI, provider);
const allowance = await tokenContract.allowance(
  rewardPoolAddress,
  interactionAddress
);
console.log('授权额度:', allowance.toString());
```

**解决方案：**
- 从奖励池地址（或奖励池的拥有者）调用：
  ```solidity
  aioToken.approve(interactionAddress, amount);
  // 或者授权最大额度
  aioToken.approve(interactionAddress, type(uint256).max);
  ```

### 4. **合约地址错误**

Interaction 合约地址可能不正确或合约未部署。

**检查方法：**
```typescript
const code = await provider.getCode(interactionAddress);
if (code === '0x') {
  console.error('合约地址不存在或未部署');
}
```

### 5. **网络连接问题**

RPC 节点可能无法访问或响应慢。

**检查方法：**
- 检查浏览器控制台是否有网络错误
- 尝试切换到其他 RPC 节点

## 使用诊断工具

我们提供了一个诊断工具来自动检查所有可能的问题：

```typescript
import { diagnoseClaimAIO } from './utils/diagnoseClaim';

const diagnosis = await diagnoseClaimAIO(
  provider,
  interactionAddress,
  amount,
  userAddress
);

// 查看检查结果
diagnosis.checks.forEach(check => {
  console.log(`${check.passed ? '✅' : '❌'} ${check.name}: ${check.message}`);
});

// 查看修复建议
diagnosis.suggestions.forEach(suggestion => {
  console.log(`💡 ${suggestion}`);
});
```

## 完整的设置检查清单

在调用 `claimAIO` 之前，确保：

- [ ] Interaction 合约已部署
- [ ] `aioToken` 已通过 `setAIOToken()` 设置
- [ ] `aioRewardPool` 已通过 `setAIORewardPool()` 设置
- [ ] 奖励池有足够的 AIO token 余额
- [ ] Interaction 合约已被授权从奖励池转移 token
- [ ] 领取金额大于零
- [ ] 网络连接正常

## 示例：完整的设置流程

```typescript
// 1. 部署合约后，设置 AIO Token
await interaction.setAIOToken(aioTokenAddress);

// 2. 设置奖励池地址
await interaction.setAIORewardPool(rewardPoolAddress);

// 3. 向奖励池充值 AIO token
await aioToken.transfer(rewardPoolAddress, amount);

// 4. 授权 Interaction 合约从奖励池转移 token
// 注意：这需要从奖励池地址（或拥有者）调用
await aioToken.connect(rewardPoolSigner).approve(
  interactionAddress,
  type(uint256).max
);

// 5. 现在可以调用 claimAIO
await interaction.claimAIO(amount);
```

## 常见错误消息对照

| 错误消息 | 原因 | 解决方案 |
|---------|------|---------|
| `missing revert data` | 合约调用会 revert，但未返回数据 | 检查合约状态、余额、授权 |
| `AIO token not set` | `aioToken` 为零地址 | 调用 `setAIOToken()` |
| `AIO reward pool not set` | `aioRewardPool` 为零地址 | 调用 `setAIORewardPool()` |
| `amount cannot be zero` | 领取金额为零 | 设置大于零的金额 |
| `AIO transfer failed` | 转账失败（余额不足或未授权） | 检查余额和授权 |

## 调试技巧

1. **启用详细日志：**
   ```typescript
   // 在调用前检查配置
   const config = await getConfig(provider, interactionAddress);
   console.log('合约配置:', config);
   ```

2. **使用诊断工具：**
   ```typescript
   const diagnosis = await diagnoseClaimAIO(provider, interactionAddress, amount);
   console.log('诊断结果:', JSON.stringify(diagnosis, null, 2));
   ```

3. **检查浏览器控制台：**
   - 查看完整的错误堆栈
   - 检查网络请求是否成功
   - 查看合约调用参数

## 联系支持

如果问题仍然存在，请提供：
1. 完整的错误消息和堆栈
2. 诊断工具的输出结果
3. 合约地址和网络信息
4. 尝试领取的金额

