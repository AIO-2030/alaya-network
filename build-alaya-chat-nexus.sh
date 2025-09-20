#!/bin/bash

# Build script for alaya-chat-nexus-frontend (independent project)
echo "Building alaya-chat-nexus-frontend independently..."

# Navigate to the alaya-chat-nexus-frontend directory
cd src/alaya-chat-nexus-frontend

# Install dependencies
echo "Installing dependencies..."
npm install

# TypeScript compilation
echo "Running TypeScript compilation..."
npx tsc --noEmit

# Vite build
echo "Running Vite build..."
npm run build

echo "alaya-chat-nexus-frontend build completed successfully!"
