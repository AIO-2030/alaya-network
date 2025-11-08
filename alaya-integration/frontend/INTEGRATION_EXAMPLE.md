# 集成示例：将 frontend 目录集成到现有 React 项目

本示例展示如何将 `frontend` 目录集成到不同类型的 React 项目中。

## 📁 项目结构

假设您的 React 项目结构如下：

```
your-react-app/
├── src/                    # 或 app/ (Next.js App Router)
│   ├── components/
│   ├── pages/             # 或 app/ (Next.js)
│   └── ...
├── public/
├── package.json
└── ...
```

## 🔧 集成步骤

### 方法 1: 复制文件到项目（推荐）

将 `frontend` 目录的内容复制到您的项目中：

```bash
# 从 alaya-integration 项目根目录执行
cp -r frontend/* your-react-app/src/
```

或者手动复制：
- `frontend/components/` → `your-react-app/src/components/`
- `frontend/utils/` → `your-react-app/src/utils/`

同时需要复制 ABI 文件：
```bash
cp -r abi/ your-react-app/src/
```

### 方法 2: 使用符号链接（开发时）

```bash
# 在您的 React 项目中
ln -s /path/to/alaya-integration/frontend src/aio-integration
ln -s /path/to/alaya-integration/abi src/abi
```

### 方法 3: 作为 npm 包（高级）

如果您想将其作为 npm 包使用，可以：

1. 在 `alaya-integration` 项目中创建 `package.json`
2. 发布到 npm 或使用本地包
3. 在您的项目中安装：`npm install @your-org/aio-integration`

## 📝 导入路径调整

根据您选择的集成方法，调整导入路径：

### 方法 1（复制文件）:
```typescript
// ✅ 直接导入
import { InteractionButton } from '@/components/InteractionButton.wagmi';
import { getConfig, interact } from '@/utils/aio';
import InteractionABI from '@/abi/Interaction.json';
```

### 方法 2（符号链接）:
```typescript
// ✅ 使用符号链接路径
import { InteractionButton } from '@/aio-integration/components/InteractionButton.wagmi';
import { getConfig, interact } from '@/aio-integration/utils/aio';
import InteractionABI from '@/abi/Interaction.json';
```

### 方法 3（npm 包）:
```typescript
// ✅ 从 npm 包导入
import { InteractionButton } from '@your-org/aio-integration/components/InteractionButton.wagmi';
import { getConfig, interact } from '@your-org/aio-integration/utils/aio';
```

## 🎯 Next.js 项目集成示例

### Next.js App Router (app/)

```tsx
// app/layout.tsx
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

if (process.env.NEXT_PUBLIC_INTERACTION_ADDRESS) {
  setInteractionAddress(process.env.NEXT_PUBLIC_INTERACTION_ADDRESS);
}

export default function RootLayout({ children }) {
  return (
    <html>
      <body>
        <WagmiProvider config={config}>
          <QueryClientProvider client={queryClient}>
            {children}
          </QueryClientProvider>
        </WagmiProvider>
      </body>
    </html>
  );
}
```

```tsx
// app/page.tsx
'use client';

import { InteractionButton } from '@/components/InteractionButton.wagmi';

export default function HomePage() {
  return (
    <div>
      <h1>我的 DApp</h1>
      <InteractionButton
        action="send_pixelmug"
        meta={{ userId: '123' }}
        buttonText="发送像素杯"
      />
    </div>
  );
}
```

### Next.js Pages Router (pages/)

```tsx
// pages/_app.tsx
import { WagmiProvider, createConfig, http } from 'wagmi';
import { mainnet } from 'wagmi/chains';
import { metaMask } from 'wagmi/connectors';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { setInteractionAddress } from '../utils/aio';

const config = createConfig({
  chains: [mainnet],
  connectors: [metaMask()],
  transports: {
    [mainnet.id]: http(),
  },
});

const queryClient = new QueryClient();

if (process.env.NEXT_PUBLIC_INTERACTION_ADDRESS) {
  setInteractionAddress(process.env.NEXT_PUBLIC_INTERACTION_ADDRESS);
}

function MyApp({ Component, pageProps }) {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <Component {...pageProps} />
      </QueryClientProvider>
    </WagmiProvider>
  );
}

export default MyApp;
```

```tsx
// pages/index.tsx
import { InteractionButton } from '../components/InteractionButton.wagmi';

export default function HomePage() {
  return (
    <div>
      <h1>我的 DApp</h1>
      <InteractionButton
        action="send_pixelmug"
        meta={{ userId: '123' }}
        buttonText="发送像素杯"
      />
    </div>
  );
}
```

## ⚛️ Create React App 集成示例

```tsx
// src/App.tsx
import { WagmiProvider, createConfig, http } from 'wagmi';
import { mainnet } from 'wagmi/chains';
import { metaMask } from 'wagmi/connectors';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { setInteractionAddress } from './utils/aio';
import { InteractionButton } from './components/InteractionButton.wagmi';

const config = createConfig({
  chains: [mainnet],
  connectors: [metaMask()],
  transports: {
    [mainnet.id]: http(),
  },
});

const queryClient = new QueryClient();

if (process.env.REACT_APP_INTERACTION_ADDRESS) {
  setInteractionAddress(process.env.REACT_APP_INTERACTION_ADDRESS);
}

function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <div className="App">
          <h1>我的 DApp</h1>
          <InteractionButton
            action="send_pixelmug"
            meta={{ userId: '123' }}
            buttonText="发送像素杯"
          />
        </div>
      </QueryClientProvider>
    </WagmiProvider>
  );
}

export default App;
```

## 🔨 Vite + React 集成示例

```tsx
// src/App.tsx
import { WagmiProvider, createConfig, http } from 'wagmi';
import { mainnet } from 'wagmi/chains';
import { metaMask } from 'wagmi/connectors';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { setInteractionAddress } from './utils/aio';
import { InteractionButton } from './components/InteractionButton.wagmi';

const config = createConfig({
  chains: [mainnet],
  connectors: [metaMask()],
  transports: {
    [mainnet.id]: http(),
  },
});

const queryClient = new QueryClient();

if (import.meta.env.VITE_INTERACTION_ADDRESS) {
  setInteractionAddress(import.meta.env.VITE_INTERACTION_ADDRESS);
}

function App() {
  return (
    <WagmiProvider config={config}>
      <QueryClientProvider client={queryClient}>
        <div>
          <h1>我的 DApp</h1>
          <InteractionButton
            action="send_pixelmug"
            meta={{ userId: '123' }}
            buttonText="发送像素杯"
          />
        </div>
      </QueryClientProvider>
    </WagmiProvider>
  );
}

export default App;
```

```env
# .env
VITE_INTERACTION_ADDRESS=0x...
```

## 📦 TypeScript 配置

确保您的 `tsconfig.json` 包含路径别名（如果使用）：

```json
{
  "compilerOptions": {
    "baseUrl": ".",
    "paths": {
      "@/*": ["src/*"]
    }
  }
}
```

## ✅ 检查清单

集成完成后，请确认：

- [ ] 已安装所有依赖：`wagmi`, `viem`, `@tanstack/react-query`
- [ ] 已复制或链接 `frontend/components/` 和 `frontend/utils/`
- [ ] 已复制或链接 `abi/` 目录
- [ ] 已配置 Wagmi Provider
- [ ] 已设置环境变量（合约地址）
- [ ] 已测试钱包连接
- [ ] 已测试交互功能

## 🐛 常见问题

### Q: 导入路径找不到？

**A**: 检查：
1. 文件是否已正确复制/链接
2. `tsconfig.json` 中的路径别名配置
3. 导入路径是否正确（区分大小写）

### Q: ABI 文件找不到？

**A**: 确保 `abi/` 目录已复制到项目中，并且导入路径正确：
```typescript
import InteractionABI from '@/abi/Interaction.json';
// 或
import InteractionABI from '../abi/Interaction.json';
```

### Q: 环境变量未读取？

**A**: 不同框架使用不同的环境变量前缀：
- Next.js: `NEXT_PUBLIC_`
- Create React App: `REACT_APP_`
- Vite: `VITE_`

### Q: TypeScript 类型错误？

**A**: 确保安装了类型定义：
```bash
npm install --save-dev @types/node
```

## 📚 下一步

集成完成后，查看：
- [QUICK_START.md](./QUICK_START.md) - 快速开始指南
- [README.md](./README.md) - 完整文档
- [components/InteractionButton.wagmi.tsx](./components/InteractionButton.wagmi.tsx) - 组件示例

