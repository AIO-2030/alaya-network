# AI Agent：仓库导航

面向在本仓库内协助开发的 AI：优先从这里定位子工程与文档，再深入具体文件。

## Univoice Chat（后端 DM / REST / SSE）

**根路径：** `src/univoice-chat/`（pnpm monorepo，NestJS）

| 路径 | 说明 |
|------|------|
| `src/univoice-chat/apps/chat-api` | REST：认证、`/dm` 会话、`/messages`、已读、输入状态、附件等 |
| `src/univoice-chat/apps/chat-sse` | SSE 推送服务（与 chat-api 配合） |
| `src/univoice-chat/packages/` | 共享包（如 `@univoice/shared`） |
| `src/univoice-chat/docker/` | 本地 PostgreSQL / Redis / MinIO 等 |
| `src/univoice-chat/README.md` | **主文档**：端口、启动命令、结构说明 |
| `src/univoice-chat/integration_chat_api_chat_sse_guide.md` | 与 `alaya-chat-nexus-frontend` 集成说明 |

**SSE 实现索引（核对协议时从这里进）：**

| 路径 | 说明 |
|------|------|
| `src/univoice-chat/apps/chat-sse/src/stream/stream.controller.ts` | `GET /stream`，按用户 `sub` 订阅 Redis `uv:fanout:user:{userUid}` |
| `src/univoice-chat/apps/chat-sse/src/stream/stream-connection.service.ts` | Redis 消息 → SSE 写出（`event:` + `data:` JSON） |
| `src/univoice-chat/apps/chat-api/src/redis/redis.service.ts` | chat-api 向双方用户频道 `publish`（`message.new`、`read.update`、`sync.hint` 等） |
| `src/univoice-chat/packages/shared/src/types/index.ts` | `SseEventEnvelope`、共享 DTO |
| `src/univoice-chat/packages/shared/src/constants/index.ts` | `SSE_EVENT_*` 事件名字符串 |
| `src/univoice-chat/packages/shared/src/utils/index.ts` | `buildSseEvent` |

**前端对接（Alaya Chat Nexus）：** `src/alaya-chat-nexus-frontend/src/services/api/univoiceChatApi.ts`（`VITE_UNIVOICE_CHAT_API_BASE_URL` 等）；SSE 客户端：`src/alaya-chat-nexus-frontend/src/hooks/useChatSse.ts`（`VITE_UNIVOICE_CHAT_SSE_BASE_URL`）。

修改 DM 创建、会话列表、消息或 SSE 协议时：**先查 `chat-api` / `chat-sse` 源码与上述 README**，再改前端适配层。

## 其他常见子工程（简要）

- **Alaya 聊天前端：** `src/alaya-chat-nexus-frontend/`
- **AIO 后端 canister：** `src/aio-base-backend/`
- **AIO 前端：** `src/aio-base-frontend/`

## 约定

- 大段架构说明以各子目录 `README.md` 为准；本文件只作**索引**，避免重复粘贴易过时细节。
