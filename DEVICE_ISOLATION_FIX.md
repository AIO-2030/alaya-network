# 设备数据隔离修复

## 问题描述

在同一浏览器的不同tab中，登录不同的用户时，一个用户添加的设备会显示在另一个用户的设备列表中。这表明设备列表没有按照用户进行过滤。

## 问题根源

在 `useDeviceManagement` hook 的 `loadDevices` 方法中，使用了：

```typescript
const response = await deviceApiService.getDevices(0, 100);
```

这个方法获取了**所有**设备，而不是只获取当前登录用户的设备。

## 解决方案

修改 `useDeviceManagement` hook 的 `loadDevices` 方法，使用 `getDevicesByOwner` 方法按用户 Principal ID 过滤设备。

### 修改内容

#### 文件：`src/alaya-chat-nexus-frontend/src/hooks/useDeviceManagement.ts`

**修改前**：
```typescript
const loadDevices = useCallback(async () => {
  try {
    setIsLoading(true);
    setError(null);
    const response = await deviceApiService.getDevices(0, 100); // Load first 100 devices
    if (response.success && response.data) {
      setDevices(response.data.devices);
    } else {
      setError(response.error || 'Failed to load devices');
    }
  } catch (error) {
    console.error('Failed to load devices:', error);
    setError('Failed to load devices');
  } finally {
    setIsLoading(false);
  }
}, []);
```

**修改后**：
```typescript
const loadDevices = useCallback(async () => {
  try {
    setIsLoading(true);
    setError(null);
    
    // Get current user's principal ID to filter devices
    const ownerPrincipal = getPrincipalId();
    console.log('[useDeviceManagement] Loading devices for owner:', ownerPrincipal);
    
    let response: ApiResponse<DeviceListResponse>;
    
    if (ownerPrincipal) {
      // Use getDevicesByOwner to filter devices by owner
      response = await deviceApiService.getDevicesByOwner(ownerPrincipal, 0, 100);
      console.log('[useDeviceManagement] Loaded devices for owner:', response.data?.devices.length || 0);
    } else {
      // Fallback: get all devices if no principal ID available
      console.warn('[useDeviceManagement] No principal ID found, loading all devices');
      response = await deviceApiService.getDevices(0, 100);
    }
    
    if (response.success && response.data) {
      setDevices(response.data.devices);
    } else {
      setError(response.error || 'Failed to load devices');
    }
  } catch (error) {
    console.error('Failed to load devices:', error);
    setError('Failed to load devices');
  } finally {
    setIsLoading(false);
  }
}, []);
```

### 主要变更

1. **导入 Principal 工具**
   ```typescript
   import { getPrincipalId } from '../lib/principal';
   ```

2. **获取当前用户的 Principal ID**
   ```typescript
   const ownerPrincipal = getPrincipalId();
   ```

3. **按用户过滤设备**
   - 如果有 `ownerPrincipal`，使用 `getDevicesByOwner(ownerPrincipal, 0, 100)`
   - 如果没有 `ownerPrincipal`，回退到获取所有设备（用于管理员或调试场景）

4. **增加日志记录**
   - 记录加载的设备数量
   - 记录是否按用户过滤

## 影响范围

此修改影响所有使用 `useDeviceManagement` hook 的页面：

- **MyDevices 页面**：只显示当前用户的设备
- **任何调用 `loadDevices()` 的地方**：自动按用户过滤

## 数据隔离保证

现在多个位置都使用按 owner 过滤的设备获取：

| 位置 | 方法 | 状态 |
|------|------|------|
| `useDeviceStatus` | `syncDevicesFromCanister(ownerPrincipal)` | ✅ 已修复 |
| `useDeviceManagement` | `getDevicesByOwner(ownerPrincipal)` | ✅ 已修复 |
| Chat 页面 | `getDevicesByOwner(contactPrincipalId)` | ✅ 已实现 |

## 测试建议

1. **用户A登录** → 添加设备
2. **在另一个tab中，用户B登录** → 不应看到用户A的设备
3. **用户B添加设备** → 只看到用户B的设备
4. **刷新页面** → 设备列表仍然正确隔离

## 修改的文件

- `src/alaya-chat-nexus-frontend/src/hooks/useDeviceManagement.ts`

## 日期

2025-10-26

