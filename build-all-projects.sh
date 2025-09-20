#!/bin/bash

# Comprehensive build script for all independent projects
echo "=========================================="
echo "Building All Independent Projects"
echo "=========================================="

# Build aio-base-frontend
echo ""
echo "1. Building aio-base-frontend..."
echo "----------------------------------------"
./build-aio-base-frontend.sh
if [ $? -eq 0 ]; then
    echo "✅ aio-base-frontend build successful"
else
    echo "❌ aio-base-frontend build failed"
    exit 1
fi

# Build alaya-chat-nexus-frontend
echo ""
echo "2. Building alaya-chat-nexus-frontend..."
echo "----------------------------------------"
./build-alaya-chat-nexus.sh
if [ $? -eq 0 ]; then
    echo "✅ alaya-chat-nexus-frontend build successful"
else
    echo "❌ alaya-chat-nexus-frontend build failed"
    exit 1
fi

echo ""
echo "=========================================="
echo "🎉 All projects built successfully!"
echo "=========================================="
echo ""
echo "Project Status:"
echo "- aio-base-frontend: ✅ Independent build"
echo "- alaya-chat-nexus-frontend: ✅ Independent build"
echo ""
echo "Both projects can now be deployed independently without cross-dependencies."
