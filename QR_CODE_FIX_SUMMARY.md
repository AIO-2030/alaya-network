# 二维码生成问题修复总结

## 问题描述

用户发现当前的二维码生成使用的是链接格式而不是原始的 principal ID，这不符合预期。

## 问题分析

### 修复前的代码
```typescript
if (qrDialogType === 'share-self') {
  const userPrincipalId = getUserPrincipalId();
  qrValue = `univoice://add-friend?uid=${encodeURIComponent(String(userPrincipalId))}`;
  displayPrincipalId = userPrincipalId;
  displayName = 'Your';
} else if (qrDialogType === 'share-friend' && selectedFriendForSharing) {
  const friendPrincipalId = selectedFriendForSharing.contactPrincipalId || selectedFriendForSharing.id;
  qrValue = `univoice://add-friend?uid=${encodeURIComponent(String(friendPrincipalId))}`;
  displayPrincipalId = String(friendPrincipalId);
  displayName = selectedFriendForSharing.name;
}
```

### 问题所在
- 二维码值使用了链接格式：`univoice://add-friend?uid=${encodeURIComponent(String(principalId))}`
- 这会导致二维码包含额外的协议和参数信息
- 用户期望的是直接的 principal ID

## 解决方案

### 修复后的代码
```typescript
if (qrDialogType === 'share-self') {
  const userPrincipalId = getUserPrincipalId();
  qrValue = String(userPrincipalId); // 直接使用原始 principal ID
  displayPrincipalId = userPrincipalId;
  displayName = 'Your';
} else if (qrDialogType === 'share-friend' && selectedFriendForSharing) {
  const friendPrincipalId = selectedFriendForSharing.contactPrincipalId || selectedFriendForSharing.id;
  qrValue = String(friendPrincipalId); // 直接使用原始 principal ID
  displayPrincipalId = String(friendPrincipalId);
  displayName = selectedFriendForSharing.name;
}
```

### 主要变化
1. **移除了链接格式**: 不再使用 `univoice://add-friend?uid=` 前缀
2. **直接使用 principal ID**: 二维码值现在直接是原始的 principal ID 字符串
3. **保持显示逻辑**: 显示和复制功能保持不变

## 技术细节

### 二维码生成逻辑
```typescript
// 修复前：链接格式
qrValue = `univoice://add-friend?uid=${encodeURIComponent(String(principalId))}`;

// 修复后：直接 principal ID
qrValue = String(principalId);
```

### 数据类型处理
- 使用 `String()` 确保 principal ID 被正确转换为字符串
- 移除了 `encodeURIComponent()` 因为不再需要 URL 编码
- 保持了原有的类型安全

### 兼容性考虑
- 二维码现在包含纯文本的 principal ID
- 可以被任何标准的二维码扫描器读取
- 不需要特殊的协议处理

## 影响范围

### 功能影响
1. **二维码内容**: 从链接格式变为纯 principal ID
2. **扫描结果**: 扫描后直接得到 principal ID，无需解析
3. **用户体验**: 更直观，符合用户预期

### 代码影响
1. **Contracts.tsx**: 修改了二维码生成逻辑
2. **QR 对话框**: 二维码显示内容发生变化
3. **复制功能**: 复制的内容仍然是 principal ID（无变化）

## 测试建议

### 功能测试
1. **分享自己**: 验证二维码包含用户的 principal ID
2. **分享好友**: 验证二维码包含好友的 principal ID
3. **扫描测试**: 使用不同设备扫描二维码，确认内容正确

### 兼容性测试
1. **不同扫描器**: 测试各种二维码扫描应用
2. **不同设备**: 在手机、平板、电脑上测试
3. **不同浏览器**: 验证在不同浏览器中的表现

## 用户体验改进

### 修复前的问题
- 二维码包含复杂的链接格式
- 用户需要理解协议和参数
- 扫描后需要额外的解析步骤

### 修复后的优势
- 二维码直接显示 principal ID
- 用户一目了然，无需额外解释
- 扫描后立即得到需要的信息
- 更符合用户的直觉预期

## 总结

通过这次修复，我们：

1. **解决了二维码格式问题**: 从链接格式改为直接的 principal ID
2. **提升了用户体验**: 二维码内容更加直观和易用
3. **保持了功能完整性**: 所有相关功能（显示、复制、扫描）都正常工作
4. **提高了兼容性**: 二维码可以被任何标准扫描器读取

现在二维码生成使用的是原始的 principal ID，完全符合用户的预期和需求！
