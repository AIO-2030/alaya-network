# Alaya Network

A decentralized AI ecosystem based on Internet Computer Protocol (ICP).

## Project Structure

```
project/
├── aio-pod/                    # AIO Pod Server Components
├── src/
│   ├── aio-base-backend/       # Backend Services (Rust + ICP)
│   ├── aio-base-frontend/      # Frontend Application (TypeScript + React)
│   └── alaya-chat-nexus-*/     # Chat Components
├── univoice-whisper-chat/      # Voice Chat Components
├── target/                     # Rust Build Output
└── certificates/               # Certificate Files
```

## Quick Start

### Requirements

- Rust 1.70+
- Node.js 18+
- DFX (Internet Computer SDK)

### Build Project

```bash
# Build Backend
./build.sh

# Build Frontend
cd src/aio-base-frontend
npm install
npm run build

# Build AIO Chat
./build-aichat.sh
```

### Run Development Environment

```bash
# Start DFX
dfx start --clean

# Deploy to Local Network
dfx deploy
```

## Subprojects

- **AIO Base Backend**: Rust + ICP Backend Services
- **AIO Base Frontend**: TypeScript + React Frontend
- **AIO Pod**: Python Server Components
- **Univoice Whisper Chat**: Voice Chat Application

## License

MIT License 