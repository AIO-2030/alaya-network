#!/bin/bash

# Build script for aio-base-frontend (independent project)
echo "Building aio-base-frontend independently..."

# Navigate to the aio-base-frontend directory
cd src/aio-base-frontend

# Install dependencies
echo "Installing dependencies..."
npm install

# TypeScript compilation
echo "Running TypeScript compilation..."
npx tsc --noEmit

# Vite build
echo "Running Vite build..."
npm run build

echo "aio-base-frontend build completed successfully!"
