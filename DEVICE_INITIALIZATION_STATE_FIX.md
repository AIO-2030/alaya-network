# 设备初始化状态管理优化

## 问题描述

原有的 `isInitialized` 状态管理存在以下问题：

1. **状态不持久**：页面刷新后状态丢失，需要重新初始化
2. **初始化时机不合理**：在服务初始化时就设置为 `true`，而不是在设备真正配网成功并上线后
3. **没有状态保持机制**：状态会自动过期，没有持久化到 localStorage

## 解决方案

### 1. 持久化状态存储

使用 localStorage 保存 `isInitialized` 状态，确保页面刷新后状态不丢失：

```typescript
const [isInitialized, setIsInitialized] = useState(() => {
  const stored = localStorage.getItem('deviceServiceInitialized');
  return stored === 'true';
});

const persistInitializedState = useCallback((value: boolean) => {
  setIsInitialized(value);
  localStorage.setItem('deviceServiceInitialized', value.toString());
  console.log('[useDeviceStatus] Device service initialized state updated:', value);
}, []);
```

### 2. 优化初始化逻辑

**修改前**：服务初始化时立即设置 `isInitialized = true`

**修改后**：
- 如果从 canister 中检测到已有设备，则设置 `isInitialized = true`
- 如果没有设备，等待首次设备配网成功并上线后再设置

```typescript
// 在 initializeService 中
if (summary.deviceList.length > 0) {
  persistInitializedState(true);
  console.log('[useDeviceStatus] Found devices from canister, marking service as initialized');
} else {
  console.log('[useDeviceStatus] No devices found in canister, will initialize on first device connection');
  // 不立即标记为已初始化，等待首次设备连接
}
```

### 3. 首次设备上线时自动初始化

在 `updateDeviceStatus` 中添加逻辑，当首次检测到设备在线时自动设置 `isInitialized = true`：

```typescript
// 如果有至少一个已连接的设备且服务尚未初始化，现在标记为已初始化
if (updatedSummary.connectedDevices > 0 && !isInitialized) {
  persistInitializedState(true);
  console.log('[useDeviceStatus] First device connected and online, marking service as initialized');
}
```

### 4. 智能的离线检测

只有在所有设备长时间离线（超过1小时）时才将状态设置为未初始化，避免临时网络问题导致的误判：

```typescript
if (updatedSummary.totalDevices > 0 && updatedSummary.connectedDevices === 0 && isInitialized) {
  // 检查所有设备是否长时间离线（例如 > 1小时）
  const allDevicesLongOffline = updatedDevices.every(device => {
    if (!device.lastSeen) return false;
    const hoursSinceLastSeen = (Date.now() - device.lastSeen) / (1000 * 60 * 60);
    return hoursSinceLastSeen > 1;
  });
  
  if (allDevicesLongOffline) {
    console.warn('[useDeviceStatus] All devices have been offline for over 1 hour, marking service as uninitialized');
    persistInitializedState(false);
  } else {
    console.log('[useDeviceStatus] All devices currently offline but recently seen, keeping initialized state');
  }
}
```

### 5. 手动重置功能

添加 `resetInitializationState` 方法，用于调试或特殊情况下手动重置状态：

```typescript
const resetInitializationState = useCallback(() => {
  console.log('[useDeviceStatus] Manually resetting initialization state');
  persistInitializedState(false);
}, [persistInitializedState]);
```

## 状态转换流程

```
初始状态（从 localStorage 读取）
    ↓
服务初始化
    ↓
检查 canister 中的设备
    ↓
    ├─ 有设备 → isInitialized = true (持久化)
    │
    └─ 无设备 → 等待首次设备连接
           ↓
       设备配网成功
           ↓
       首次检测到设备在线 → isInitialized = true (持久化)
           ↓
       保持 true 状态
           ↓
       所有设备离线超过1小时 → isInitialized = false (持久化)
```

## 优势

1. ✅ **状态持久化**：页面刷新后状态保持，无需重新初始化
2. ✅ **准确的初始化时机**：只在设备真正上线后才标记为已初始化
3. ✅ **容错性强**：临时网络问题不会导致状态错误
4. ✅ **智能离线检测**：只有长时间离线才标记为未初始化
5. ✅ **可调试**：提供手动重置功能

## 影响的文件

- `src/alaya-chat-nexus-frontend/src/hooks/useDeviceStatus.ts`

## 测试建议

1. **首次配网测试**：
   - 清除 localStorage
   - 进行设备配网
   - 验证配网成功并检测到设备在线后 `isInitialized` 变为 `true`

2. **页面刷新测试**：
   - 配网成功后刷新页面
   - 验证 `isInitialized` 状态保持为 `true`

3. **临时离线测试**：
   - 设备短暂离线（< 1小时）
   - 验证 `isInitialized` 保持为 `true`

4. **长时间离线测试**：
   - 设备离线超过1小时
   - 验证 `isInitialized` 变为 `false`

## 日期

2025-10-26

