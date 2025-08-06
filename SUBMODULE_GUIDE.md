# Git Submodules Usage Guide (Updated Version)

## Project Architecture

⚠️ **Important**: Submodules use different default branches

- **src/aio-base-backend** (**master**) - https://github.com/AIO-2030/aio-base-backend
- **src/aio-base-frontend** (**main**) - https://github.com/AIO-2030/aio-base-frontend  
- **src/alaya-chat-nexus-frontend** (**main**) - https://github.com/AIO-2030/alaya-ai-chat-nexus

## Submodule Information

### Backend (master branch)
- **Repository**: https://github.com/AIO-2030/aio-base-backend
- **Branch**: master
- **Tech Stack**: Rust, Internet Computer SDK
- **Purpose**: Backend services and smart contracts

### Frontend (main branch)
- **Repository**: https://github.com/AIO-2030/aio-base-frontend
- **Branch**: main
- **Tech Stack**: TypeScript, React, Vite
- **Purpose**: Main frontend application

### Chat Nexus Frontend (main branch)
- **Repository**: https://github.com/AIO-2030/alaya-ai-chat-nexus
- **Branch**: main
- **Tech Stack**: TypeScript, React, Vite
- **Purpose**: Chat nexus frontend application

## Common Commands

### Initial Clone
```bash
git clone --recurse-submodules git@github.com:AIO-2030/alaya-network.git
```

### Update Submodules
```bash
# Update all submodules
git submodule update --remote --merge

# Update specific submodule
git submodule update --remote src/aio-base-backend        # master
git submodule update --remote src/aio-base-frontend       # main
git submodule update --remote src/alaya-chat-nexus-frontend  # main
```

### Branch Management

#### Backend Development (master branch)
```bash
cd src/aio-base-backend
git checkout master
git pull origin master
# ... development ...
git push origin master
cd ../..
```

#### Frontend Development (main branch)
```bash
cd src/aio-base-frontend
git checkout main
git pull origin main
# ... development ...
git push origin main
cd ../..
```

#### Chat Nexus Frontend Development (main branch)
```bash
cd src/alaya-chat-nexus-frontend
git checkout main
git pull origin main
# ... development ...
git push origin main
cd ../..
```

### Sync All Changes
```bash
# Update all submodules to latest
git submodule foreach git pull

# Or update separately
cd src/aio-base-backend && git pull origin master && cd ../..
cd src/aio-base-frontend && git pull origin main && cd ../..
cd src/alaya-chat-nexus-frontend && git pull origin main && cd ../..

# Commit submodule reference updates
git add .
git commit -m "Update all submodules to latest"
git push
```

### Check Status
```bash
# View all submodule status
git submodule status

# View branch information
git submodule foreach 'echo "=== $name ===" && git branch -v'
```

## Development Workflow

### 1. Backend Development
```bash
# Navigate to backend
cd src/aio-base-backend

# Ensure on correct branch
git checkout master
git pull origin master

# Make changes...
git add .
git commit -m "Backend: new feature"
git push origin master

# Return to main repository
cd ../..
git add src/aio-base-backend
git commit -m "Update backend submodule reference"
git push
```

### 2. Frontend Development
```bash
# Navigate to frontend
cd src/aio-base-frontend

# Ensure on correct branch
git checkout main
git pull origin main

# Make changes...
git add .
git commit -m "Frontend: new feature"
git push origin main

# Return to main repository
cd ../..
git add src/aio-base-frontend
git commit -m "Update frontend submodule reference"
git push
```

### 3. Chat Nexus Frontend Development
```bash
# Navigate to chat nexus frontend
cd src/alaya-chat-nexus-frontend

# Ensure on correct branch
git checkout main
git pull origin main

# Make changes...
git add .
git commit -m "Chat Nexus: new feature"
git push origin main

# Return to main repository
cd ../..
git add src/alaya-chat-nexus-frontend
git commit -m "Update chat nexus frontend submodule reference"
git push
```

## Troubleshooting

### Reset Submodules
```bash
# Complete reset
git submodule deinit --all --force
rm -rf .git/modules
git submodule update --init --recursive
```

### Fix Branch References
```bash
# Ensure backend on master branch
cd src/aio-base-backend
git checkout master
git pull origin master
cd ../..

# Ensure frontend on main branch  
cd src/aio-base-frontend
git checkout main
git pull origin main
cd ../..

# Ensure chat nexus frontend on main branch
cd src/alaya-chat-nexus-frontend
git checkout main
git pull origin main
cd ../..

# Commit fixes
git add .
git commit -m "Fix submodule branch references"
```

### Clean and Reinitialize
```bash
# Remove all submodules
git submodule deinit --force src/aio-base-backend
git submodule deinit --force src/aio-base-frontend
git submodule deinit --force src/alaya-chat-nexus-frontend

# Remove from git
rm -rf .git/modules/src
rm -rf src/aio-base-backend src/aio-base-frontend src/alaya-chat-nexus-frontend
rm -f .gitmodules

# Re-add submodules
git submodule add -b master https://github.com/AIO-2030/aio-base-backend.git src/aio-base-backend
git submodule add -b main https://github.com/AIO-2030/aio-base-frontend.git src/aio-base-frontend
git submodule add -b main https://github.com/AIO-2030/alaya-ai-chat-nexus.git src/alaya-chat-nexus-frontend

# Initialize
git submodule update --init --recursive
```

## Important Notes

⚠️ **Branch Differences**:
- Backend repository uses `master` branch
- Frontend repositories use `main` branch
- Please pay attention to branch switching during development

⚠️ **Development Workflow**:
- Always work in the correct branch for each submodule
- Commit changes to submodule repositories first
- Then commit submodule reference updates to main repository
- Keep submodules up to date with latest changes

## Quick Reference

| Submodule | Branch | Repository | Purpose |
|-----------|--------|------------|---------|
| aio-base-backend | master | AIO-2030/aio-base-backend | Backend services |
| aio-base-frontend | main | AIO-2030/aio-base-frontend | Main frontend |
| alaya-chat-nexus-frontend | main | AIO-2030/alaya-ai-chat-nexus | Chat frontend | 