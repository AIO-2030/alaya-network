# 设备列表按用户过滤功能实现

## 问题描述

My Devices 页面当前显示所有用户的设备，而不是仅显示当前登录用户的设备。这导致用户可以看见不属于自己的设备。

## 解决方案

根据后端 Candid 定义的 `get_devices_by_owner` 方法，实现按用户 Principal ID 过滤设备的功能。

### 后端支持

后端 canister 已经提供了按 owner 查询设备的方法：

```candid
"get_devices_by_owner": (text) -> (vec DeviceInfo) query;
```

## 实现的修改

### 1. **`src/alaya-chat-nexus-frontend/src/services/api/deviceApi.ts`**

#### 修改 `getDevices` 方法
- 添加可选的 `ownerPrincipal` 参数
- 如果有 owner principal，使用 `actor.get_devices_by_owner()` 方法
- 手动实现分页功能（因为后端方法不支持分页）
- 如果没有 owner，回退到 `get_all_devices`

```typescript
async getDevices(offset: number = 0, limit: number = 20, ownerPrincipal?: string): Promise<ApiResponse<DeviceListResponse>> {
  if (ownerPrincipal) {
    const result = await actor.get_devices_by_owner(ownerPrincipal);
    const devices = result.map(device => this.convertDeviceInfoToRecord(device));
    const paginatedDevices = devices.slice(offset, offset + limit);
    // ... 返回分页结果
  }
  // ... 回退逻辑
}
```

#### 更新 `getDevicesByOwner` 方法
- 返回类型从 `DeviceRecord[]` 改为 `DeviceListResponse`
- 添加分页支持（offset, limit）
- 返回统一的分页响应格式

```typescript
async getDevicesByOwner(owner: string, offset: number = 0, limit: number = 20): Promise<ApiResponse<DeviceListResponse>> {
  // 实现分页逻辑
}
```

### 2. **`src/alaya-chat-nexus-frontend/src/services/realDeviceService.ts`**

#### 修改 `getDeviceList` 方法
- 添加可选的 `ownerPrincipal` 参数
- 将参数传递给 `deviceApiService.getDevices()`
- 记录日志以显示是否按用户过滤

```typescript
async getDeviceList(ownerPrincipal?: string): Promise<DeviceRecord[]> {
  const response = await deviceApiService.getDevices(0, 100, ownerPrincipal);
  // ... 处理响应
}
```

### 3. **`src/alaya-chat-nexus-frontend/src/services/deviceMessageService.ts`**

#### 修改 `syncDevicesFromCanister` 方法
- 添加可选的 `ownerPrincipal` 参数
- 将参数传递给 `realDeviceService.getDeviceList()`

```typescript
async syncDevicesFromCanister(ownerPrincipal?: string): Promise<void> {
  const devices = await realDeviceService.getDeviceList(ownerPrincipal);
  // ... 同步设备
}
```

### 4. **`src/alaya-chat-nexus-frontend/src/hooks/useDeviceStatus.ts`**

#### 导入 Principal 工具
```typescript
import { getPrincipalId } from '../lib/principal';
```

#### 修改 `initializeService` 方法
- 获取当前用户的 principal ID
- 在初始化时同步当前用户的设备

```typescript
const ownerPrincipal = getPrincipalId();
if (ownerPrincipal) {
  await deviceMessageService.syncDevicesFromCanister(ownerPrincipal);
}
```

#### 修改 `updateDeviceStatus` 方法
- 获取当前用户的 principal ID
- 更新状态时同步当前用户的设备

```typescript
const ownerPrincipal = getPrincipalId();
if (ownerPrincipal) {
  await deviceMessageService.syncDevicesFromCanister(ownerPrincipal);
}
```

## 工作流程

```
用户登录 → 获取 Principal ID
    ↓
初始化设备服务 → 传入 Principal ID
    ↓
调用 get_devices_by_owner(principal_id)
    ↓
后端返回该用户的设备列表
    ↓
前端显示仅属于该用户的设备
    ↓
定期刷新时也使用 Principal ID 过滤
```

## 数据流

1. **用户登录** → `getPrincipalId()` 获取当前用户的 principal ID
2. **初始化服务** → 调用 `syncDevicesFromCanister(ownerPrincipal)` 
3. **前端调用** → `realDeviceService.getDeviceList(ownerPrincipal)`
4. **API 调用** → `deviceApiService.getDevices(0, 100, ownerPrincipal)`
5. **后端方法** → `actor.get_devices_by_owner(ownerPrincipal)` 
6. **返回数据** → 仅包含该用户的设备

## 优势

1. ✅ **数据隔离**：每个用户只能看到自己的设备
2. ✅ **隐私保护**：防止用户看到其他用户的设备信息
3. ✅ **性能优化**：后端只返回相关设备，减少数据传输
4. ✅ **向后兼容**：如果没有提供 owner，仍然可以获取所有设备（用于管理员功能）

## 修改的文件

- `src/alaya-chat-nexus-frontend/src/services/api/deviceApi.ts`
- `src/alaya-chat-nexus-frontend/src/services/realDeviceService.ts`
- `src/alaya-chat-nexus-frontend/src/services/deviceMessageService.ts`
- `src/alaya-chat-nexus-frontend/src/hooks/useDeviceStatus.ts`

## 测试建议

1. **用户A登录** → 只应看到用户A的设备
2. **用户B登录** → 只应看到用户B的设备
3. **用户A添加设备** → 用户B不应看到用户A的新设备
4. **刷新页面** → 设备列表应该仍然只显示当前用户的设备
5. **登出再登录** → 显示正确的用户设备列表

## 日期

2025-10-26
