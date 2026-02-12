# Create My Voice 功能实现说明

## 概述

实现了用户自定义语音功能，允许用户录制30秒语音，创建个性化的 ElevenLabs AI Agent。

## 实现的功能

### 1. 后端实现

#### ai_types.rs
- 定义了 `UserAiConfig` 结构体，包含：
  - `principal_id`: 用户 Principal ID
  - `agent_id`: ElevenLabs Agent ID
  - `voice_id`: ElevenLabs Voice ID
  - `stable_memory`: 可选的稳定内存配置
- 实现了用户 AI 配置的 CRUD 操作

#### stable_mem_storage.rs
- 添加了 `USER_AI_CONFIG` 存储，使用 MemoryId::new(104)
- 使用 StableBTreeMap 存储用户配置

#### lib.rs
- 添加了以下 API 方法：
  - `get_user_ai_config`: 查询用户 AI 配置
  - `set_user_ai_config`: 设置用户 AI 配置
  - `delete_user_ai_config`: 删除用户 AI 配置
  - `has_user_ai_config`: 检查用户是否有 AI 配置

#### aio-base-backend.did
- 添加了 `UserAiConfig` 类型定义
- 添加了相应的 API 接口定义

### 2. 前端实现

#### Index.tsx
- 将 "Learn More" 按钮改为 "Create my voice"
- 添加了点击处理逻辑：
  1. 检查用户登录状态
  2. 如果已登录，查询用户是否有自定义 agent
  3. 如果有，显示删除确认对话框
  4. 删除后或没有配置时，打开语音录制对话框

#### VoiceRecordingDialog.tsx
- 实现了30秒语音录制功能
- 支持暂停/继续录制
- 支持播放录制的音频
- 支持重新录制

#### aiApi.ts
- 实现了与后端 canister 的通信
- 实现了 ElevenLabs API 调用：
  - `createIVCVoice`: 创建 IVC voice
  - `duplicateAgent`: 复制 master agent
  - `updateAgentVoice`: 更新 agent 的 TTS 配置
  - `deleteElevenLabsAgent`: 删除 ElevenLabs agent
  - `createCustomVoiceAgent`: 完整的创建流程

#### ElevenLabsChat.tsx
- 修改为支持使用用户自定义 agent
- 检查用户登录状态
- 如果用户有自定义 agent，使用自定义 agent
- 否则使用默认的 master agent

## 工作流程

### 创建自定义语音流程

1. 用户点击 "Create my voice" 按钮
2. 检查用户登录状态
3. 如果用户已有自定义 agent：
   - 显示删除确认对话框
   - 用户确认后：
     - 调用 ElevenLabs API 删除 agent
     - 删除后端记录
4. 打开语音录制对话框
5. 用户录制30秒语音
6. 创建流程：
   - 使用录音创建 IVC voice（得到 voice_id）
   - 复制 master agent（得到新的 agent_id）
   - 更新 agent 的 TTS 配置，使用新的 voice_id
   - 保存配置到后端 canister

### 使用自定义语音流程

1. 用户进入 ElevenLabs Chat 页面
2. 检查用户登录状态
3. 如果用户已登录：
   - 查询后端获取用户的 agent_id
   - 如果有记录，使用自定义 agent_id
   - 如果没有记录，使用默认 agent_id
4. 使用获取的 agent_id 发起会话

## API 接口

### 后端 Canister API

```candid
// 查询用户 AI 配置
get_user_ai_config: (text) -> (opt UserAiConfig) query;

// 设置用户 AI 配置
set_user_ai_config: (UserAiConfig) -> (variant { Ok; Err: text });

// 删除用户 AI 配置
delete_user_ai_config: (text) -> (variant { Ok; Err: text });

// 检查用户是否有 AI 配置
has_user_ai_config: (text) -> (bool) query;
```

### ElevenLabs API

- `POST /v1/voices/add`: 创建 IVC voice
- `POST /v1/convai/agents/{master_agent_id}/duplicate`: 复制 agent
- `PATCH /v1/convai/agents/{agent_id}`: 更新 agent 配置
- `DELETE /v1/convai/agents/{agent_id}`: 删除 agent
- `GET /v1/convai/conversation/token`: 获取会话 token（用于自定义 agent）

## 注意事项

1. 需要配置 `VITE_ELEVENLABS_API_KEY` 环境变量
2. Master agent ID 硬编码为 `agent_01jz8rr062f41tsyt56q8fzbrz`
3. 录音时长为30秒
4. 删除操作需要用户确认
5. 如果后端保存失败，会自动清理 ElevenLabs 资源

## 待优化项

1. 错误处理可以更详细
2. 可以添加进度提示
3. 可以支持更长的录音时长
4. 可以添加语音质量检测
