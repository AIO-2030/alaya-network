# useDeviceStatus 开发板设备映射修复

## 问题描述

`useDeviceStatus.ts` 中的 `updateDeviceStatus` 方法缺少开发板设备名称的转换逻辑。当设备名称是 `142B2F6AF8B4`（开发板）时，需要映射到生产环境的设备名称 `3CDC7580F950`。

## 解决方案

在 `updateDeviceStatus` 方法中添加与 `deviceMessageService.parseDeviceId` 相同的开发板检测和映射逻辑。

### 修改内容

#### 文件：`src/alaya-chat-nexus-frontend/src/hooks/useDeviceStatus.ts`

#### 1. 主要设备处理逻辑（第131-159行）

**修改前**：
```typescript
const extendedDevice: DeviceStatus = {
  ...device,
  productId: device.id.includes(':') ? device.id.split(':')[0] : 'DEFAULT_PRODUCT',
  deviceName: device.id.includes(':') ? device.id.split(':')[1] : device.id,
  // ...
};
```

**修改后**：
```typescript
// Parse device ID to get product_id and device_name
let deviceName = device.id.includes(':') ? device.id.split(':')[1] : device.id;

// Check if this is a development board (142B2F6AF8B4) and map to production device name
if (deviceName === '142B2F6AF8B4') {
  console.log('[useDeviceStatus] Development board detected, mapping to production device name');
  deviceName = '3CDC7580F950';
}

// Convert basic device to extended device type
const extendedDevice: DeviceStatus = {
  ...device,
  productId: 'H3PI4FBTV5',
  deviceName,
  // ...
};
```

#### 2. 错误处理逻辑（第188-208行）

在 catch 块中也添加相同的转换逻辑：

**修改前**：
```typescript
return {
  ...device,
  productId: device.id.includes(':') ? device.id.split(':')[0] : 'DEFAULT_PRODUCT',
  deviceName: device.id.includes(':') ? device.id.split(':')[1] : device.id,
  // ...
};
```

**修改后**：
```typescript
// Parse device name with development board mapping
let deviceName = device.id.includes(':') ? device.id.split(':')[1] : device.id;
if (deviceName === '142B2F6AF8B4') {
  deviceName = '3CDC7580F950';
}

// Keep device in current state if MCP call fails
return {
  ...device,
  productId: 'H3PI4FBTV5',
  deviceName,
  // ...
};
```

## 关键改进

1. **开发板自动检测**
   ```typescript
   if (deviceName === '142B2F6AF8B4') {
     console.log('[useDeviceStatus] Development board detected, mapping to production device name');
     deviceName = '3CDC7580F950';
   }
   ```

2. **统一的 productId**
   - 所有设备统一使用 `'H3PI4FBTV5'` 作为 productId
   - 与 `deviceMessageService` 保持一致

3. **错误处理中的映射**
   - 在 MCP 调用失败时，也应用开发板映射
   - 确保设备状态信息的一致性

4. **增强的日志记录**
   - 记录开发板检测和映射过程
   - 显示最终使用的 productId 和 deviceName

## 工作流程

```
设备ID: "device_142B2F6AF8B4" 或 "BLUFI_142B2F6AF8B4"
    ↓
解析: deviceName = "142B2F6AF8B4"
    ↓
检测: isDevelopment = true
    ↓
映射: deviceName = "3CDC7580F950"
    ↓
查询MCP: getDeviceStatus('H3PI4FBTV5', '3CDC7580F950')
    ↓
返回设备状态
```

## 一致性保证

现在 `useDeviceStatus` 中的设备状态查询与 `deviceMessageService` 中的设备操作使用相同的转换逻辑：

| 位置 | 方法 | 开发板映射 |
|------|------|-----------|
| `deviceMessageService.ts` | `parseDeviceId()` | ✅ 已实现 |
| `useDeviceStatus.ts` | `updateDeviceStatus()` | ✅ 已实现 |

## 修改的文件

- `src/alaya-chat-nexus-frontend/src/hooks/useDeviceStatus.ts`

## 测试建议

1. **开发板设备状态查询**：
   - 使用设备名称 `142B2F6AF8B4` 的设备
   - 验证日志中显示映射到 `3CDC7580F950`
   - 验证设备状态查询使用映射后的设备名称

2. **生产环境设备测试**：
   - 使用生产环境设备进行测试
   - 验证设备状态查询正常工作

3. **错误处理测试**：
   - 模拟 MCP 调用失败
   - 验证 catch 块中也正确应用映射

## 日期

2025-10-26

