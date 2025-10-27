# 开发板设备名称映射功能

## 问题描述

当开发板设备名称（Device MAC Address: `142B2F6AF8B4`）被识别时，需要将其映射到生产环境的设备名称 `3CDC7580F950`，以确保与MCP服务正确通信。

## 解决方案

修改 `parseDeviceId` 方法，添加开发板检测和自动映射功能。

### 修改内容

#### 文件：`src/alaya-chat-nexus-frontend/src/services/deviceMessageService.ts`

**修改前**：
```typescript
private parseDeviceId(deviceId: string): { productId: string; deviceName: string } {
  const parts = deviceId.split('_');
  const deviceName = parts.length > 1 ? parts[parts.length - 1] : deviceId;
  
  return { productId: 'H3PI4FBTV5', deviceName };
}
```

**修改后**：
```typescript
private parseDeviceId(deviceId: string): { productId: string; deviceName: string; isDevelopment: boolean } {
  console.log('[DeviceMessageService] parseDeviceId called with:', deviceId);
  
  const parts = deviceId.split('_');
  let deviceName = parts.length > 1 ? parts[parts.length - 1] : deviceId;
  
  // Check if this is a development board (142B2F6AF8B4)
  const isDevelopment = deviceName === '142B2F6AF8B4';
  
  // If it's a development board, map to production device name
  if (isDevelopment) {
    console.log('[DeviceMessageService] Development board detected, mapping to production device name');
    deviceName = '3CDC7580F950';
  }
  
  return { productId: 'H3PI4FBTV5', deviceName, isDevelopment };
}
```

### 主要变更

1. **添加开发板检测**
   ```typescript
   const isDevelopment = deviceName === '142B2F6AF8B4';
   ```

2. **自动映射到生产环境设备名称**
   ```typescript
   if (isDevelopment) {
     deviceName = '3CDC7580F950';
   }
   ```

3. **返回开发板标识**
   - 新增 `isDevelopment` 字段在返回类型中
   - 用于日志记录和调试

4. **增强日志记录**
   - 记录原始设备ID和解析后的设备名称
   - 标记是否为开发板
   - 记录映射过程

## 工作流程

```
输入: deviceId = "device_142B2F6AF8B4" 或 "BLUFI_142B2F6AF8B4"
    ↓
解析: 提取设备名称 = "142B2F6AF8B4"
    ↓
检测: isDevelopment = true
    ↓
映射: deviceName = "3CDC7580F950"
    ↓
返回: { productId: 'H3PI4FBTV5', deviceName: '3CDC7580F950', isDevelopment: true }
```

## 支持的设备ID格式

1. **开发板格式**（会自动映射）：
   - `device_142B2F6AF8B4` → `3CDC7580F950`
   - `BLUFI_142B2F6AF8B4` → `3CDC7580F950`
   - `142B2F6AF8B4` → `3CDC7580F950`

2. **生产环境格式**（保持不变）：
   - `device_3CDC7580F950` → `3CDC7580F950`
   - `BLUFI_3CDC7580F950` → `3CDC7580F950`
   - 其他设备名称 → 原值

## 影响范围

此修改会影响以下功能：

1. **设备状态查询** (`getDeviceStatusViaMcp`)
   - 开发板会使用映射后的设备名称查询状态

2. **发送像素艺术** (`sendPixelArtViaAlayaMcp`)
   - 开发板会使用映射后的设备名称发送消息

3. **发送像素动画** (`sendPixelAnimationViaAlayaMcp`)
   - 开发板会使用映射后的设备名称发送消息

4. **发送GIF** (`sendGifViaAlayaMcp`)
   - 开发板会使用映射后的设备名称发送消息

5. **发送文本** (`sendTextViaAlayaMcp`)
   - 开发板会使用映射后的设备名称发送消息

6. **高级MCP调用** (`callAlayaMcpMethod`)
   - 开发板会使用映射后的设备名称调用MCP方法

## 日志输出示例

当使用开发板设备时：
```
[DeviceMessageService] parseDeviceId called with: device_142B2F6AF8B4
[DeviceMessageService] Development board detected, mapping to production device name
[DeviceMessageService] Parsed device ID: {
  originalDeviceId: "device_142B2F6AF8B4",
  parts: ["device", "142B2F6AF8B4"],
  deviceName: "3CDC7580F950",
  productId: "H3PI4FBTV5",
  isDevelopment: true
}
```

## 优势

1. ✅ **透明映射**：开发板可以无缝使用生产环境的MCP服务
2. ✅ **自动检测**：无需手动配置，自动识别开发板
3. ✅ **调试友好**：详细的日志记录，便于调试
4. ✅ **向后兼容**：不影响生产环境设备的正常使用

## 修改的文件

- `src/alaya-chat-nexus-frontend/src/services/deviceMessageService.ts`

## 测试建议

1. **开发板设备测试**：
   - 使用设备名称 `142B2F6AF8B4` 进行测试
   - 验证日志中显示映射到 `3CDC7580F950`
   - 验证MCP调用使用映射后的设备名称

2. **生产环境设备测试**：
   - 使用生产环境设备进行测试
   - 验证设备名称保持不变
   - 验证 `isDevelopment: false`

## 日期

2025-10-26

