# AIO Integration - React DApp 集成指南

本指南介绍如何在 React DApp 中集成 AIO Interaction 合约。合约仅支持 ETH 支付，不支持 ERC20 代币。

> 🚀 **快速开始**: 如果您想快速集成，请查看 [QUICK_START.md](./QUICK_START.md) - 5 分钟快速集成指南

## 📦 安装依赖

### 使用 Wagmi (推荐)

Wagmi 提供了更好的 React hooks 支持和类型安全。

```bash
npm install wagmi viem @tanstack/react-query
# 或
yarn add wagmi viem @tanstack/react-query
```

### 使用 Ethers v6

```bash
npm install ethers
# 或
yarn add ethers
```

## 🚀 快速开始

### 方式一：使用 Wagmi (推荐)

#### 1. 配置 Wagmi Provider

```tsx
// app.tsx 或 _app.tsx (Next.js)
// 或 App.tsx (Create React App)
import { WagmiProvider, createConfig, http } from 'wagmi';
import { mainnet, sepolia } from 'wagmi/chains';
import { injected, metaMask } from 'wagmi/connectors';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';

const config = createConfig({
  chains: [mainnet, sepolia], // 根据你的网络选择
  connectors: [injected(), metaMask()],
  transports: {
    [mainnet.id]: http(),
    [sepolia.id]: http(),
  },
});

const queryClient = new QueryClient();

function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <YourApp />
      </QueryClientProvider>
    </WagmiProvider>
  );
}
```

#### 2. 使用示例组件

参考 `components/InteractionButton.wagmi.tsx` 查看完整的 React 组件示例。

### 方式二：使用 Ethers v6

如果你更喜欢使用 ethers，可以参考 `utils/aio.examples.ts` 中的示例代码。

## 📝 核心功能

### 1. 设置合约地址

```typescript
import { setInteractionAddress } from './utils/aio';

// 在应用启动时设置一次（推荐）
const INTERACTION_ADDRESS = process.env.NEXT_PUBLIC_INTERACTION_ADDRESS as `0x${string}`;
setInteractionAddress(INTERACTION_ADDRESS);
```

### 2. 获取配置（费用信息）

```typescript
import { getConfig, setInteractionAddress } from './utils/aio';
import { usePublicClient } from 'wagmi';

const INTERACTION_ADDRESS = '0x...'; // 你的 Interaction 合约地址

function MyComponent() {
  const publicClient = usePublicClient();
  const [feeWei, setFeeWei] = useState<bigint | null>(null);
  
  useEffect(() => {
    setInteractionAddress(INTERACTION_ADDRESS);
    
    // 加载配置
    const loadConfig = async () => {
      try {
        const config = await getConfig(publicClient!, INTERACTION_ADDRESS);
        setFeeWei(config.feeWei);
        console.log('费用:', config.feeWei.toString());
        console.log('费用分发器:', config.feeDistributor);
      } catch (error) {
        console.error('加载配置失败:', error);
      }
    };
    
    if (publicClient) {
      loadConfig();
    }
  }, [publicClient]);
  
  return (
    <div>
      {feeWei && <p>所需费用: {Number(feeWei) / 1e18} ETH</p>}
    </div>
  );
}
```

### 3. 执行交互（ETH 支付）

```typescript
import { interact, getConfig } from './utils/aio';
import { useWalletClient, useAccount, usePublicClient } from 'wagmi';

function MyComponent() {
  const { data: walletClient } = useWalletClient();
  const { address } = useAccount();
  const publicClient = usePublicClient();
  const [isLoading, setIsLoading] = useState(false);
  
  const handleInteract = async () => {
    if (!walletClient || !address || !publicClient) {
      alert('请先连接钱包');
      return;
    }
    
    setIsLoading(true);
    try {
      // 获取最新配置（确保费用是最新的）
      const config = await getConfig(publicClient, INTERACTION_ADDRESS);
      
      // 执行交互
      const txHash = await interact(
        walletClient,
        'send_pixelmug', // action 字符串（简短，节省 gas）
        { userId: '123', data: '...' }, // meta 对象（会自动编码为 JSON bytes）
        config.feeWei, // ETH 费用（必须 >= feeWei）
        {
          interactionAddress: INTERACTION_ADDRESS,
          account: address
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
    <button onClick={handleInteract} disabled={isLoading}>
      {isLoading ? '处理中...' : '执行交互'}
    </button>
  );
}
```

## 🎯 Action 字符串建议

保持 action 字符串简短（< 20 字符）以节省 gas：

- `"send_pixelmug"` - 发送像素杯
- `"aio_rpc_call"` - AIO RPC 调用
- `"verify_proof"` - 验证证明
- `"submit_data"` - 提交数据
- `"mint_nft"` - 铸造 NFT
- `"claim_reward"` - 领取奖励

详细数据应存储在 `meta` JSON 对象中。

## ⚠️ 注意事项

1. **仅支持 ETH 支付**：合约已移除 ERC20 代币支持，只能使用 ETH 支付费用
2. **费用检查**：确保用户余额 >= `feeWei`，否则交易会失败
3. **错误处理**：所有错误消息都是中文，包含有用的提示
4. **Meta 编码**：`meta` 参数可以是 JSON 对象（会自动编码）或已编码的 hex 字符串
5. **合约地址**：建议使用 `setInteractionAddress()` 设置全局地址，避免重复传递
6. **Action 字符串**：保持简短（< 20 字符）以节省 gas，详细数据存储在 `meta` 中

## 📚 更多示例

查看以下文件获取更多示例：

- `components/InteractionButton.wagmi.tsx` - Wagmi 完整 React 组件示例
- `utils/aio.examples.ts` - 更多使用模式和最佳实践

## 🔧 环境变量配置

建议在 `.env.local` 或 `.env` 文件中配置：

```env
# Interaction 合约地址（部署后获取）
NEXT_PUBLIC_INTERACTION_ADDRESS=0x...

# 链 ID（1 = 主网, 11155111 = Sepolia 测试网）
NEXT_PUBLIC_CHAIN_ID=1
```

## 🎨 完整集成示例

### Next.js 项目集成

```tsx
// app/layout.tsx 或 pages/_app.tsx
'use client';

import { WagmiProvider, createConfig, http } from 'wagmi';
import { mainnet } from 'wagmi/chains';
import { metaMask } from 'wagmi/connectors';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { setInteractionAddress } from '@/utils/aio';

const config = createConfig({
  chains: [mainnet],
  connectors: [metaMask()],
  transports: {
    [mainnet.id]: http(),
  },
});

const queryClient = new QueryClient();

// 设置全局合约地址
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

### 使用 InteractionButton 组件

```tsx
// app/page.tsx 或 components/MyPage.tsx
'use client';

import { InteractionButton } from '@/components/InteractionButton.wagmi';

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
          console.log('成功:', hash);
          // 可以在这里显示成功提示
        }}
        onError={(err) => {
          console.error('失败:', err);
          // 可以在这里显示错误提示
        }}
      />
    </div>
  );
}
```

## 🔍 常见问题

### Q: 如何检查用户余额是否足够？

```typescript
import { useBalance } from 'wagmi';
import { getConfig } from './utils/aio';

function MyComponent() {
  const { address } = useAccount();
  const { data: balance } = useBalance({ address });
  const publicClient = usePublicClient();
  const [feeWei, setFeeWei] = useState<bigint | null>(null);
  
  useEffect(() => {
    const loadFee = async () => {
      const config = await getConfig(publicClient!, INTERACTION_ADDRESS);
      setFeeWei(config.feeWei);
    };
    if (publicClient) loadFee();
  }, [publicClient]);
  
  const hasEnoughBalance = balance && feeWei && balance.value >= feeWei;
  
  return (
    <div>
      {!hasEnoughBalance && feeWei && (
        <p style={{ color: 'red' }}>
          余额不足！需要至少 {Number(feeWei) / 1e18} ETH
        </p>
      )}
    </div>
  );
}
```

### Q: 如何等待交易确认？

```typescript
import { useWaitForTransactionReceipt } from 'wagmi';

function MyComponent() {
  const [txHash, setTxHash] = useState<`0x${string}` | null>(null);
  
  const { isLoading: isConfirming, isSuccess: isConfirmed } = 
    useWaitForTransactionReceipt({
      hash: txHash || undefined,
    });
  
  // 在 interact 成功后设置 txHash
  // const hash = await interact(...);
  // setTxHash(hash);
  
  return (
    <div>
      {isConfirming && <p>交易确认中...</p>}
      {isConfirmed && <p>✓ 交易已确认</p>}
    </div>
  );
}
```

