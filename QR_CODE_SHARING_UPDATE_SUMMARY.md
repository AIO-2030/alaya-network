# QR 码分享功能更新总结

## 概述
已成功更新 `Contracts.tsx` 中的 QR 码分享功能，现在通过 principal ID 生成二维码，并在下方显示 principal ID 和分享链接，提供快速复制功能。

## 更新内容

### 1. QR 码生成逻辑
- **数据源**: 使用用户的 principal ID 作为唯一标识符
- **二维码内容**: `univoice://add-friend?uid={principalId}` 格式的深度链接
- **编码处理**: 对 principal ID 进行 URL 编码，确保特殊字符正确处理

### 2. Principal ID 显示
- **清晰展示**: 在二维码下方显示用户的 principal ID
- **格式美化**: 使用 `code` 标签和特殊样式，提高可读性
- **快速复制**: 提供 "Copy" 按钮，一键复制 principal ID 到剪贴板

### 3. 分享链接显示
- **完整链接**: 显示完整的 `univoice://` 协议链接
- **格式优化**: 使用等宽字体和背景色，便于阅读和复制
- **复制功能**: 独立的复制按钮，方便用户复制分享链接

### 4. 用户体验优化
- **视觉反馈**: 复制成功后显示绿色勾选图标
- **状态管理**: 使用 React state 管理复制成功状态
- **自动隐藏**: 复制成功提示 2 秒后自动消失
- **错误处理**: 复制失败时在控制台记录错误信息

## 技术实现

### 1. 状态管理
```typescript
const [copySuccess, setCopySuccess] = useState<'principal' | 'link' | null>(null);
```

### 2. 复制功能
```typescript
const copyToClipboard = async (text: string, type: 'principal' | 'link') => {
  try {
    await navigator.clipboard.writeText(text);
    setCopySuccess(type);
    setTimeout(() => setCopySuccess(null), 2000);
  } catch (err) {
    console.error('Failed to copy:', err);
  }
};
```

### 3. 视觉反馈
```typescript
{copySuccess === 'principal' ? (
  <CheckCircle className="h-4 w-4 text-green-400" />
) : (
  'Copy'
)}
```

## 界面布局

### 1. 二维码区域
- 居中显示，白色背景
- 200x200 像素大小
- 高纠错级别 (M)

### 2. Principal ID 区域
- 标签: "Your Principal ID:"
- 显示框: 等宽字体，青色文字，深色背景
- 复制按钮: 青色主题，悬停效果

### 3. 分享链接区域
- 标签: "Share Link:"
- 显示框: 等宽字体，蓝色文字，深色背景
- 复制按钮: 蓝色主题，悬停效果

### 4. 说明文字
- 底部显示使用说明
- 简洁明了的操作指引

## 功能特点

### 1. 数据完整性
- 使用真实的 principal ID 生成二维码
- 确保每个用户的分享链接都是唯一的
- 支持复杂的 principal ID 格式

### 2. 用户友好性
- 一键复制功能，减少手动输入
- 清晰的视觉反馈，确认操作成功
- 响应式设计，适配不同屏幕尺寸

### 3. 技术可靠性
- 完整的错误处理机制
- 异步操作的状态管理
- 浏览器兼容性考虑

## 使用流程

### 1. 打开分享对话框
- 用户点击联系人卡片上的 QR 码图标
- 显示包含二维码和信息的模态框

### 2. 查看分享信息
- 扫描二维码添加好友
- 查看自己的 principal ID
- 复制 principal ID 或分享链接

### 3. 分享给他人
- 通过二维码直接分享
- 复制链接发送给朋友
- 提供 principal ID 供手动添加

## 下一步优化

1. **国际化支持**: 添加多语言标签
2. **分享统计**: 记录分享次数和成功添加的好友数
3. **自定义链接**: 允许用户自定义分享链接格式
4. **社交分享**: 集成社交媒体分享功能
5. **历史记录**: 保存分享历史，便于管理

## 注意事项

- Principal ID 是用户的唯一标识，请谨慎分享
- 二维码内容包含完整的深度链接，确保正确编码
- 复制功能依赖浏览器的 Clipboard API
- 建议在 HTTPS 环境下使用，确保安全性
