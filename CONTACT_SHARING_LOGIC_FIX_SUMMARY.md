# 联系人分享逻辑修复和功能增强总结

## 概述
已成功修复 `Contracts.tsx` 和 `userApi.ts` 中的联系人分享逻辑，并新增了分享自己 principal ID + QR Code 的功能。

## 修复的问题

### 1. 分享好友逻辑错误
**问题描述**: 之前的 QR 码分享功能显示的是当前用户的 principal ID，而不是被选中好友的 principal ID。

**修复方案**: 
- 更新了 `ContactInfo` 接口，添加了 `contactPrincipalId` 字段
- 修改了分享好友的逻辑，优先使用 `contactPrincipalId`，如果没有则回退到 `id`
- 确保 QR 码内容正确反映被分享的联系人信息

### 2. 数据结构不完整
**问题描述**: 前端缺少 `contactPrincipalId` 字段，无法正确识别联系人的真实 principal ID。

**修复方案**:
- 在 `ContactInfo` 接口中添加了 `contactPrincipalId?: string` 字段
- 更新了 `convertFromContact` 函数，从后端数据中提取 `contact_principal_id`
- 更新了 `convertToContact` 函数，支持传入的 `contactPrincipalId`

## 新增功能

### 1. 分享自己功能
**功能描述**: 在 'New Contract' 按钮旁边新增了 "Share Self" 按钮，用户可以分享自己的 principal ID + QR Code。

**实现细节**:
- 新增了 `qrDialogType` 状态，用于区分分享自己和分享好友
- 新增了 `selectedFriendForSharing` 状态，用于存储被分享的联系人信息
- 在按钮区域添加了两个按钮：
  - "Share Self": 分享自己的 principal ID + QR Code
  - "New Contract": 原有的添加新联系人功能

### 2. 智能对话框标题
**功能描述**: 对话框标题会根据分享类型动态变化。

**实现细节**:
- 分享自己时显示: "Share Your QR Code"
- 分享好友时显示: "Share [好友名称] QR Code"

### 3. 动态内容显示
**功能描述**: 对话框内容会根据分享类型动态调整。

**实现细节**:
- Principal ID 标签会根据分享类型变化
- 分享链接会根据分享类型生成不同的内容
- 说明文字会根据分享类型提供相应的指导

## 技术实现

### 1. 状态管理
```typescript
const [qrDialogType, setQrDialogType] = useState<'share-self' | 'share-friend' | null>(null);
const [selectedFriendForSharing, setSelectedFriendForSharing] = useState<ContactInfo | null>(null);
```

### 2. 条件渲染
```typescript
{qrDialogType === 'share-self' 
  ? 'Share your QR code to let others add you as a friend'
  : `Share ${selectedFriendForSharing?.name || 'contact'} QR code to add them as a friend`
}
```

### 3. 数据转换
```typescript
const friendPrincipalId = selectedFriendForSharing.contactPrincipalId || selectedFriendForSharing.id;
```

## 用户体验改进

### 1. 清晰的按钮布局
- "Share Self" 和 "New Contract" 按钮并排显示
- 使用不同的图标区分功能（QR Code vs Plus）
- 保持一致的视觉风格

### 2. 智能的对话框内容
- 根据操作类型显示相应的内容
- 提供清晰的说明文字
- 支持复制 principal ID 和分享链接

### 3. 错误处理
- 优先使用 `contactPrincipalId`，如果没有则回退到 `id`
- 确保所有功能都有适当的回退机制

## 数据结构更新

### 1. ContactInfo 接口
```typescript
export interface ContactInfo {
  // ... 现有字段
  contactPrincipalId?: string; // 新增字段
}
```

### 2. 转换函数更新
- `convertFromContact`: 从后端提取 `contact_principal_id`
- `convertToContact`: 支持传入的 `contactPrincipalId`

### 3. 默认数据更新
- 为所有默认联系人添加了示例 `contactPrincipalId`
- 确保测试数据的一致性

## 测试建议

### 1. 功能测试
- 测试分享自己功能
- 测试分享好友功能
- 验证 QR 码内容正确性

### 2. 数据测试
- 测试有 `contactPrincipalId` 的联系人
- 测试没有 `contactPrincipalId` 的联系人（回退到 `id`）
- 验证数据转换的正确性

### 3. 用户体验测试
- 测试按钮布局和响应
- 测试对话框标题和内容
- 测试复制功能

## 下一步优化

1. **国际化支持**: 为新增的文本添加多语言支持
2. **分享历史**: 记录分享历史，便于用户管理
3. **分享统计**: 统计分享次数和成功添加的好友数
4. **自定义链接**: 允许用户自定义分享链接格式
5. **社交分享**: 集成社交媒体分享功能

## 注意事项

- 所有分享功能都使用真实的 principal ID
- 支持回退机制，确保功能的稳定性
- 保持了原有的代码结构和风格
- 新增功能不影响现有功能
- 代码已通过 TypeScript 类型检查
