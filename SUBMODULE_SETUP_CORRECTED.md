# Git Submodules Setup Guide (Corrected Version)

## Subrepository Branch Information Confirmation
- **Backend**: https://github.com/AIO-2030/aio-base-backend (**master** branch)
- **Frontend**: https://github.com/AIO-2030/aio-base-frontend (**main** branch)
- **Main Repository**: git@github.com:AIO-2030/alaya-network.git

## Step 1: Clean Up Previous Failed Setup

```bash
cd /Users/senyang/project

# Completely clean failed submodule setup
git submodule deinit --force src/aio-base-backend 2>/dev/null || true
git submodule deinit --force src/aio-base-frontend 2>/dev/null || true
rm -rf .git/modules/src/aio-base-backend 2>/dev/null || true
rm -rf .git/modules/src/aio-base-frontend 2>/dev/null || true
rm -rf src/aio-base-backend 2>/dev/null || true
rm -rf src/aio-base-frontend 2>/dev/null || true
rm -f .gitmodules 2>/dev/null || true

# Clean git status
git reset --hard
git clean -fd
```

## Step 2: Backup Original Code (If Needed)

```bash
# If your backup is still there, ensure data safety
ls -la src/aio-base-backend-backup 2>/dev/null || echo "No backup needed, continue..."
ls -la src/aio-base-frontend-backup 2>/dev/null || echo "No backup needed, continue..."
```

## Step 3: Add Git Submodules (Using Correct Branches)

```bash
# Add backend submodule (master branch)
git submodule add -b master https://github.com/AIO-2030/aio-base-backend.git src/aio-base-backend

# Add frontend submodule (main branch)
git submodule add -b main https://github.com/AIO-2030/aio-base-frontend.git src/aio-base-frontend

# Initialize and update submodules
git submodule update --init --recursive
```

## Step 4: Verify Submodules Setup

```bash
# Check submodules status
git submodule status

# Verify branch correctness
echo "=== Check Backend Branch ==="
cd src/aio-base-backend
git branch -a
git log --oneline -5
cd ../..

echo "=== Check Frontend Branch ==="
cd src/aio-base-frontend  
git branch -a
git log --oneline -5
cd ../..

# View .gitmodules content
echo "=== .gitmodules Content ==="
cat .gitmodules
```

## Step 5: Create Root Directory Configuration Files

### .gitignore
```bash
cat > .gitignore << 'EOF'
# macOS
.DS_Store

# Node.js root directory
node_modules/
package-lock.json

# Rust root directory  
target/

# Internet Computer
.dfx/

# Binary files
*.bin
mcp_*.bin
mcp_server_memory.*

# Large file directory
aio-pod/uploads/*
!aio-pod/uploads/.gitkeep

# Certificates
certificates/*
!certificates/.gitkeep

# IDE
.vscode/
.idea/

# Environment
.env
.env.local

# Build outputs (root level)
/dist/
/build/

# Test files
test_files/*.bin
test_files/*.exe

# Media files (root directory)
/*.mp4
/*.wav
/*.jpg
/*.png
/*.ico
EOF
```

### README.md
```bash
cat > README.md << 'EOF'
# Alaya Network

A decentralized AI ecosystem main repository based on Internet Computer Protocol (ICP).

## Project Structure

This project uses Git Submodules architecture to manage the following components:

### Core Submodules

- **`src/aio-base-backend`** - Backend Services (Rust + ICP)
  - Repository: https://github.com/AIO-2030/aio-base-backend
  - Branch: **master**
  - Tech Stack: Rust, Internet Computer SDK
  
- **`src/aio-base-frontend`** - Frontend Application (TypeScript + React)
  - Repository: https://github.com/AIO-2030/aio-base-frontend  
  - Branch: **main**
  - Tech Stack: TypeScript (93.9%), JavaScript (5.4%)
  - Development Status: 531+ commits, actively developing

### Other Components

- **`aio-pod/`** - AIO Pod Server Components
- **`univoice-whisper-chat/`** - Voice Chat Components
- **`alaya-chat-nexus-backend/`** - Chat Backend
- **`alaya-chat-nexus-frontend/`** - Chat Frontend

## Quick Start

### Clone Project (Including All Submodules)

```bash
git clone --recurse-submodules git@github.com:AIO-2030/alaya-network.git
cd alaya-network
```

### Update Submodules

```bash
# Update all submodules to latest version
git submodule update --remote --merge

# Update individually (note different branches)
git submodule update --remote src/aio-base-backend    # master branch
git submodule update --remote src/aio-base-frontend   # main branch
```

### Submodule Development Workflow

#### Backend Development (master branch)
```bash
cd src/aio-base-backend
git checkout master
git pull origin master

# Development...
git add .
git commit -m "Backend: new feature"
git push origin master

# Return to main repository to update reference
cd ../..
git add src/aio-base-backend
git commit -m "Update backend submodule"
git push
```

#### Frontend Development (main branch)
```bash
cd src/aio-base-frontend
git checkout main
git pull origin main

# Development...
git add .
git commit -m "Frontend: new feature"
git push origin main

# Return to main repository to update reference
cd ../..
git add src/aio-base-frontend
git commit -m "Update frontend submodule"
git push
```

## Important Notes

⚠️ **Branch Differences**:
- Backend repository uses `master` branch
- Frontend repository uses `main` branch
- Please pay attention to branch switching during development

## Contributing Guide

Please refer to specific documentation for each submodule:
- [Backend Development Guide](src/aio-base-backend/README.md)
- [Frontend Development Guide](src/aio-base-frontend/README.md)

## License

MIT License
EOF
```

### SUBMODULE_GUIDE.md
```bash
cat > SUBMODULE_GUIDE.md << 'EOF'
# Git Submodules Usage Guide (Branch Differences Version)

## Project Architecture

⚠️ **Important**: Submodules use different default branches

- **src/aio-base-backend** (**master**) - https://github.com/AIO-2030/aio-base-backend
- **src/aio-base-frontend** (**main**) - https://github.com/AIO-2030/aio-base-frontend

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
git submodule update --remote src/aio-base-backend   # master
git submodule update --remote src/aio-base-frontend  # main
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

### Sync All Changes
```bash
# Update all submodules to latest
git submodule foreach git pull

# Or update separately
cd src/aio-base-backend && git pull origin master && cd ../..
cd src/aio-base-frontend && git pull origin main && cd ../..

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

# Commit fixes
git add .
git commit -m "Fix submodule branch references"
```
EOF
```

## Step 6: Commit Setup

```bash
# Add all files
git add .

# Commit initial setup
git commit -m "Setup Alaya Network with correct submodule branches

- Add AIO-2030/aio-base-backend as submodule (master branch)
- Add AIO-2030/aio-base-frontend as submodule (main branch)
- Add comprehensive documentation with branch differences noted
- Setup root level configuration files"

# Push to remote
git push -u origin main
```

## Step 7: Final Verification

```bash
# Check final status
echo "=== Submodules Status ==="
git submodule status

echo "=== .gitmodules Content ==="
cat .gitmodules

echo "=== Directory Structure ==="
ls -la src/

echo "=== Remote Status ==="
git remote -v

echo "Setup completed!"
```

## One-Click Execution Script

```bash
#!/bin/bash
set -e

echo "=== Alaya Network Submodules Setup (Branch Corrected Version) ==="

# Cleanup
git submodule deinit --force src/aio-base-backend 2>/dev/null || true
git submodule deinit --force src/aio-base-frontend 2>/dev/null || true
rm -rf .git/modules/src 2>/dev/null || true
rm -rf src/aio-base-backend src/aio-base-frontend 2>/dev/null || true
rm -f .gitmodules 2>/dev/null || true

# Add correct submodules
git submodule add -b master https://github.com/AIO-2030/aio-base-backend.git src/aio-base-backend
git submodule add -b main https://github.com/AIO-2030/aio-base-frontend.git src/aio-base-frontend

# Initialize
git submodule update --init --recursive

# Verify
echo "Backend branch:"
cd src/aio-base-backend && git branch && cd ../..
echo "Frontend branch:"  
cd src/aio-base-frontend && git branch && cd ../..

echo "=== Setup Completed ==="
git submodule status
```

This corrected version ensures:
1. Backend uses `master` branch
2. Frontend uses `main` branch  
3. Documentation clearly notes branch differences
4. Provides operation guides for different branches 