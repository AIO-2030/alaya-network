# React DApp 快速集成指南

本指南将帮助您在 5 分钟内将 AIO Interaction 合约集成到您的 React DApp 中。

## 📋 前置要求

- React 项目（Next.js、Create React App 或 Vite）
- Node.js 16+ 和 npm/yarn/pnpm

## 🚀 三步集成

### 步骤 1: 安装依赖

```bash
# 使用 Wagmi (推荐)
npm install wagmi viem @tanstack/react-query

# 或使用 Ethers v6
npm install ethers
```

### 步骤 2: 配置 Provider

在您的应用根组件中配置 Wagmi Provider：

**Next.js (App Router):**
```tsx
// app/layout.tsx
'use client';

import { WagmiProvider, createConfig, http } from 'wagmi';
import { mainnet, sepolia } from 'wagmi/chains';
import { metaMask } from 'wagmi/connectors';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { setInteractionAddress } from '@/frontend/utils/aio';

const config = createConfig({
  chains: [mainnet, sepolia], // 根据您的网络选择
  connectors: [metaMask()],
  transports: {
    [mainnet.id]: http(),
    [sepolia.id]: http(),
  },
});

const queryClient = new QueryClient();

// 设置全局合约地址（从环境变量读取）
if (process.env.NEXT_PUBLIC_INTERACTION_ADDRESS) {
  setInteractionAddress(process.env.NEXT_PUBLIC_INTERACTION_ADDRESS);
}

export default function RootLayout({ children }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        {children}
      </QueryClientProvider>
    </WagmiProvider>
  );
}
```

**Create React App / Vite:**
```tsx
// src/App.tsx
import { WagmiProvider, createConfig, http } from 'wagmi';
import { mainnet } from 'wagmi/chains';
import { metaMask } from 'wagmi/connectors';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { setInteractionAddress } from './frontend/utils/aio';

const config = createConfig({
  chains: [mainnet],
  connectors: [metaMask()],
  transports: {
    [mainnet.id]: http(),
  },
});

const queryClient = new QueryClient();

// 设置全局合约地址
setInteractionAddress(process.env.REACT_APP_INTERACTION_ADDRESS || '');

function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <YourApp />
      </QueryClientProvider>
    </WagmiProvider>
  );
}

export default App;
```

### 步骤 3: 使用组件

**方式 A: 使用现成的 InteractionButton 组件（推荐）**

```tsx
// app/page.tsx 或 components/MyPage.tsx
'use client';

import { InteractionButton } from '@/frontend/components/InteractionButton.wagmi';

export default function HomePage() {
  return (
    <div>
      <h1>我的 DApp</h1>
      
      <InteractionButton
        action="send_pixelmug"
        meta={{
          userId: 'user123',
          pixelData: '0x1234...',
          timestamp: Date.now(),
        }}
        buttonText="发送像素杯"
        onSuccess={(hash) => {
          console.log('交易成功:', hash);
          // 显示成功提示
        }}
        onError={(err) => {
          console.error('交易失败:', err);
          // 显示错误提示
        }}
      />
    </div>
  );
}
```

**方式 B: 自定义实现**

```tsx
'use client';

import { useState } from 'react';
import { useAccount, useWalletClient, usePublicClient } from 'wagmi';
import { getConfig, interact, setInteractionAddress } from '@/frontend/utils/aio';

const INTERACTION_ADDRESS = process.env.NEXT_PUBLIC_INTERACTION_ADDRESS as `0x${string}`;

export default function MyComponent() {
  const { address, isConnected } = useAccount();
  const { data: walletClient } = useWalletClient();
  const publicClient = usePublicClient();
  const [isLoading, setIsLoading] = useState(false);

  // 设置全局合约地址
  useState(() => {
    if (INTERACTION_ADDRESS) {
      setInteractionAddress(INTERACTION_ADDRESS);
    }
  }, []);

  const handleInteract = async () => {
    if (!walletClient || !address || !publicClient) {
      alert('请先连接钱包');
      return;
    }

    setIsLoading(true);
    try {
      // 1. 获取最新配置（费用信息）
      const config = await getConfig(publicClient, INTERACTION_ADDRESS);
      
      // 2. 执行交互
      const txHash = await interact(
        walletClient,
        'send_pixelmug', // action 字符串
        { userId: '123', data: '...' }, // meta 对象（自动编码为 JSON）
        config.feeWei, // ETH 费用
        {
          interactionAddress: INTERACTION_ADDRESS,
          account: address,
        }
      );
      
      console.log('交易哈希:', txHash);
      alert(`交易已提交: ${txHash}`);
    } catch (error: any) {
      console.error('交互失败:', error);
      alert(`交互失败: ${error.message}`);
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div>
      <button onClick={handleInteract} disabled={!isConnected || isLoading}>
        {isLoading ? '处理中...' : '执行交互'}
      </button>
    </div>
  );
}
```

## ⚙️ 环境变量配置

在项目根目录创建 `.env.local` (Next.js) 或 `.env` (Create React App):

```env
# Interaction 合约地址（部署后获取）
NEXT_PUBLIC_INTERACTION_ADDRESS=0x...

# 或 Create React App
REACT_APP_INTERACTION_ADDRESS=0x...
```

## 📦 文件结构

确保您的项目包含以下文件：

```
your-react-app/
├── frontend/
│   ├── components/
│   │   ├── InteractionButton.wagmi.tsx  # 交互按钮组件
│   │   └── ClaimButton.wagmi.tsx         # 领取奖励按钮组件
│   └── utils/
│       └── aio.ts                        # 核心工具函数
├── abi/
│   ├── Interaction.json                 # Interaction 合约 ABI
│   └── FeeDistributor.json              # FeeDistributor 合约 ABI
└── .env.local                            # 环境变量
```

**注意**: 如果 `frontend` 目录不在项目根目录，请调整导入路径。

## 🎯 核心 API

### `getConfig(provider, interactionAddress?)`

获取合约配置（费用信息）：

```typescript
const config = await getConfig(publicClient, INTERACTION_ADDRESS);
console.log('费用:', config.feeWei.toString());
console.log('费用分发器:', config.feeDistributor);
```

### `interact(provider, action, meta, value, options?)`

执行交互（ETH 支付）：

```typescript
const txHash = await interact(
  walletClient,
  'send_pixelmug',           // action 字符串
  { userId: '123' },         // meta 对象（自动编码）
  config.feeWei,             // ETH 费用
  {
    interactionAddress: '0x...',
    account: userAddress,
  }
);
```

### `setInteractionAddress(address)`

设置全局合约地址（可选，避免重复传递）：

```typescript
setInteractionAddress('0x...');
// 之后调用 getConfig 和 interact 时可以不传 interactionAddress
```

### `claimAIO(provider, action, timestamp, options?)`

领取已完成交互的 AIO 奖励：

```typescript
// 从 InteractionRecorded 事件中获取 timestamp
const timestamp = 1699123456; // 区块时间戳

const txHash = await claimAIO(
  walletClient,
  'send_pixelmug',    // action 字符串（必须与原始交互匹配）
  timestamp,          // 原始交互的区块时间戳
  {
    interactionAddress: '0x...',
    account: userAddress,
  }
);
```

### `getClaimStatus(provider, user, action, timestamp, interactionAddress?)`

查询用户是否已领取某个交互的奖励：

```typescript
const status = await getClaimStatus(
  publicClient,
  userAddress,        // 用户地址
  'send_pixelmug',   // action 字符串
  timestamp,         // 原始交互的区块时间戳
  INTERACTION_ADDRESS
);

console.log('已领取:', status.claimed);
console.log('奖励数量:', status.rewardAmount.toString());
```

## 💡 最佳实践

1. **Action 字符串**: 保持简短（< 20 字符）以节省 gas
   - ✅ `"send_pixelmug"`
   - ❌ `"send_pixelmug_with_user_id_and_timestamp"`

2. **Meta 数据**: 详细数据存储在 `meta` JSON 对象中
   ```typescript
   meta: {
     userId: 'user123',
     pixelData: '0x1234...',
     timestamp: Date.now(),
   }
   ```

3. **错误处理**: 所有错误消息都是中文，包含有用提示
   ```typescript
   try {
     await interact(...);
   } catch (error: any) {
     if (error.message.includes('费用不足')) {
       // 显示费用不足提示
     }
   }
   ```

4. **余额检查**: 在交互前检查用户余额
   ```typescript
   import { useBalance } from 'wagmi';
   
   const { data: balance } = useBalance({ address });
   const hasEnoughBalance = balance && feeWei && balance.value >= feeWei;
   ```

5. **领取奖励流程**:
   ```typescript
   // 1. 用户完成交互
   const txHash = await interact(...);
   
   // 2. 等待交易确认，从事件中获取 timestamp
   // 从 InteractionRecorded 事件中获取 timestamp
   const timestamp = eventLog.args.timestamp;
   
   // 3. 用户领取奖励
   const claimTxHash = await claimAIO(
     walletClient,
     action,
     timestamp,
     { interactionAddress, account }
   );
   ```

6. **检查领取状态**: 在显示领取按钮前检查是否已领取
   ```typescript
   const status = await getClaimStatus(
     publicClient,
     userAddress,
     action,
     timestamp
   );
   
   if (status.claimed) {
     // 已领取，显示已领取状态
   } else if (status.rewardAmount > 0n) {
     // 可以领取，显示领取按钮
   }
   ```

## 🎁 使用 ClaimButton 组件

`ClaimButton` 是一个现成的 React 组件，用于领取 AIO 奖励：

```tsx
import { ClaimButton } from '@/frontend/components/ClaimButton.wagmi';

function MyComponent() {
  // 从 InteractionRecorded 事件中获取的 timestamp
  const timestamp = 1699123456;

  return (
    <ClaimButton
      action="send_pixelmug"
      timestamp={timestamp}
      buttonText="领取 AIO 奖励"
      onSuccess={(hash) => {
        console.log('领取成功:', hash);
        alert(`奖励领取成功: ${hash}`);
      }}
      onError={(err) => {
        console.error('领取失败:', err);
        alert(`领取失败: ${err.message}`);
      }}
    />
  );
}
```

**ClaimButton 特性**：
- ✅ 自动检查领取状态
- ✅ 显示奖励数量
- ✅ 已领取时自动禁用按钮
- ✅ 显示交易确认状态
- ✅ 完整的错误处理

## 🔍 常见问题

### Q: 如何从交互事件中获取 timestamp？

```typescript
import { usePublicClient } from 'wagmi';
import { decodeEventLog } from 'viem';

// 等待交易确认后获取事件
const receipt = await publicClient.waitForTransactionReceipt({ hash: txHash });

// 查找 InteractionRecorded 事件
const event = receipt.logs.find(log => {
  // 根据事件签名查找
  // InteractionRecorded 事件签名可以通过 ABI 获取
});

if (event) {
  const decoded = decodeEventLog({
    abi: InteractionABI,
    data: event.data,
    topics: event.topics,
  });
  
  const timestamp = decoded.args.timestamp;
  // 使用这个 timestamp 调用 claimAIO
}
```

### Q: 如何检查交易确认状态？

```typescript
import { useWaitForTransactionReceipt } from 'wagmi';

const [txHash, setTxHash] = useState<`0x${string}` | null>(null);

const { isLoading: isConfirming, isSuccess: isConfirmed } = 
  useWaitForTransactionReceipt({
    hash: txHash || undefined,
  });

// 在 interact 成功后设置 txHash
const hash = await interact(...);
setTxHash(hash);
```

### Q: 如何检查用户余额是否足够？

```typescript
import { useBalance } from 'wagmi';
import { getConfig } from '@/frontend/utils/aio';

const { data: balance } = useBalance({ address });
const [feeWei, setFeeWei] = useState<bigint | null>(null);

useEffect(() => {
  const loadFee = async () => {
    const config = await getConfig(publicClient!, INTERACTION_ADDRESS);
    setFeeWei(config.feeWei);
  };
  if (publicClient) loadFee();
}, [publicClient]);

const hasEnoughBalance = balance && feeWei && balance.value >= feeWei;
```

### Q: 支持哪些钱包？

支持所有与 Wagmi 兼容的钱包：
- MetaMask
- WalletConnect
- Coinbase Wallet
- 其他 EIP-1193 兼容钱包

### Q: 是否支持 ERC20 代币支付？

**不支持**。合约仅支持 ETH 支付。所有 ERC20 相关功能已移除。

## 📚 更多资源

- 完整文档: [README.md](./README.md)
- 组件示例: [InteractionButton.wagmi.tsx](./components/InteractionButton.wagmi.tsx)
- 工具函数示例: [aio.examples.ts](./utils/aio.examples.ts)

## 🆘 需要帮助？

如果遇到问题，请检查：
1. 合约地址是否正确配置
2. 网络是否匹配（主网/测试网）
3. 钱包是否已连接
4. 用户余额是否足够支付费用

