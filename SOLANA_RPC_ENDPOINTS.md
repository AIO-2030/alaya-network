# Solana RPC 端点总结

## 当前代码中使用的 RPC 端点

### 1. 主 RPC（当前使用）
- **端点**: `https://api.mainnet-beta.solana.com`
- **类型**: Solana 官方公共 RPC
- **API Key**: ❌ 不需要
- **状态**: 免费但有限制，容易返回 403 Forbidden
- **说明**: 官方公共端点，有速率限制，不适合生产环境

### 2. Fallback RPC（当前使用）
- **端点**: `https://solana-api.projectserum.com`
- **类型**: Project Serum 公共 RPC
- **API Key**: ❌ 不需要（但可能有限制）
- **状态**: 免费公共端点
- **说明**: 可能已停止维护或有限制

- **端点**: `https://rpc.hellomoon.io`
- **类型**: HelloMoon 公共 RPC
- **API Key**: ❌ 不需要（但可能有限制）
- **状态**: 免费公共端点
- **说明**: 可能已停止维护或有限制

- **端点**: `https://api.devnet.solana.com`
- **类型**: Solana Devnet（测试网）
- **API Key**: ❌ 不需要
- **状态**: 免费，但这是测试网，不适合主网查询
- **说明**: 仅用于开发测试

---

## 推荐申请 API Key 的 RPC 服务商

### ⭐ 推荐（有免费额度）

#### 1. **Helius** ⭐⭐⭐⭐⭐
- **官网**: https://www.helius.dev/
- **注册**: https://dashboard.helius.dev
- **免费额度**: 有免费 tier
- **端点格式**: `https://mainnet.helius-rpc.com/?api-key=YOUR_API_KEY`
- **优点**: 
  - 高性能
  - 增强的 API 功能
  - 免费 tier 可用
- **申请链接**: https://dashboard.helius.dev/signup

#### 2. **QuickNode** ⭐⭐⭐⭐
- **官网**: https://www.quicknode.com/
- **注册**: https://www.quicknode.com/signup
- **免费额度**: 有免费 tier（有限制）
- **端点格式**: `https://YOUR_ENDPOINT.solana-mainnet.quiknode.pro/YOUR_API_KEY/`
- **优点**: 
  - 快速稳定
  - 全球节点
  - 免费 tier 可用
- **申请链接**: https://www.quicknode.com/signup

#### 3. **Alchemy** ⭐⭐⭐⭐
- **官网**: https://www.alchemy.com/
- **注册**: https://auth.alchemy.com/signup
- **免费额度**: 有免费 tier
- **端点格式**: `https://solana-mainnet.g.alchemy.com/v2/YOUR_API_KEY`
- **优点**: 
  - 可靠稳定
  - 开发者友好
  - 免费 tier 可用
- **申请链接**: https://auth.alchemy.com/signup

#### 4. **Ankr** ⭐⭐⭐
- **官网**: https://www.ankr.com/
- **注册**: https://www.ankr.com/rpc/
- **免费额度**: 有免费 tier（但可能有限制）
- **端点格式**: `https://rpc.ankr.com/solana/YOUR_API_KEY`
- **优点**: 
  - 多链支持
  - 免费 tier 可用
- **注意**: 免费 tier 可能对某些操作有限制
- **申请链接**: https://www.ankr.com/rpc/

### 其他选项（需要付费或企业级）

#### 5. **BlockPI**
- **官网**: https://blockpi.io/
- **端点格式**: `https://solana.blockpi.network/v1/rpc/{api_key}`
- **免费额度**: 需要确认
- **申请链接**: https://blockpi.io/

#### 6. **Chainstack**
- **官网**: https://chainstack.com/
- **免费额度**: 需要确认
- **申请链接**: https://chainstack.com/

#### 7. **Blockdaemon**
- **官网**: https://www.blockdaemon.com/
- **免费额度**: 企业级服务
- **申请链接**: https://www.blockdaemon.com/

---

## 推荐配置方案

### 方案 1：使用 Helius（推荐）
1. 访问 https://dashboard.helius.dev/signup
2. 注册账号并获取 API key
3. 端点格式：`https://mainnet.helius-rpc.com/?api-key=YOUR_API_KEY`
4. 优点：免费 tier 可用，性能好

### 方案 2：使用 QuickNode
1. 访问 https://www.quicknode.com/signup
2. 注册账号并创建 Solana 端点
3. 获取端点 URL 和 API key
4. 优点：免费 tier 可用，全球节点

### 方案 3：使用 Alchemy
1. 访问 https://auth.alchemy.com/signup
2. 注册账号并创建 Solana 应用
3. 获取 API key
4. 端点格式：`https://solana-mainnet.g.alchemy.com/v2/YOUR_API_KEY`
5. 优点：免费 tier 可用，稳定可靠

---

## 代码配置建议

建议在环境变量中配置 RPC 端点：

```typescript
// .env
VITE_SOLANA_RPC_URL=https://mainnet.helius-rpc.com/?api-key=YOUR_API_KEY
VITE_SOLANA_RPC_FALLBACK=https://solana-mainnet.g.alchemy.com/v2/YOUR_API_KEY
```

然后在代码中使用：
```typescript
const SOLANA_RPC_URL = import.meta.env.VITE_SOLANA_RPC_URL || 'https://api.mainnet-beta.solana.com';
```

---

## 注意事项

1. **不要将 API key 提交到 Git**：使用环境变量或配置文件（已加入 .gitignore）
2. **免费 tier 限制**：大多数服务商的免费 tier 有速率限制，生产环境建议升级
3. **备用方案**：建议配置多个 RPC 端点作为 fallback
4. **成本考虑**：如果流量较大，考虑付费计划

---

## 快速申请链接汇总

- **Helius**: https://dashboard.helius.dev/signup ⭐ 推荐
- **QuickNode**: https://www.quicknode.com/signup ⭐ 推荐
- **Alchemy**: https://auth.alchemy.com/signup ⭐ 推荐
- **Ankr**: https://www.ankr.com/rpc/
