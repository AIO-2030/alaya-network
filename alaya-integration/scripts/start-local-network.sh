#!/bin/bash

# 启动本地测试网络 (Anvil)
# 使用方法: ./scripts/start-local-network.sh

echo "🚀 启动本地测试网络 (Anvil)..."
echo ""
echo "配置信息:"
echo "  - RPC URL: http://127.0.0.1:8545"
echo "  - Chain ID: 31337"
echo "  - 默认账户: 10 个预充值账户"
echo ""

# 启动 Anvil
# --host 0.0.0.0 允许外部连接
# --port 8545 使用标准端口
# --accounts 10 创建 10 个测试账户
# --balance 10000 每个账户预充值 10000 ETH
# --gas-limit 30000000 设置 gas limit
anvil \
  --host 0.0.0.0 \
  --port 8545 \
  --accounts 10 \
  --balance 10000 \
  --gas-limit 30000000

