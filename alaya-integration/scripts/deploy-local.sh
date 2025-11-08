#!/bin/bash

# 部署合约到本地测试网络
# 使用方法: ./scripts/deploy-local.sh

# Anvil 默认的第一个账户私钥（仅用于本地测试）
# 地址: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
ANVIL_DEFAULT_PRIVATE_KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"

echo "🚀 部署合约到本地测试网络..."
echo ""
echo "配置:"
echo "  - RPC URL: http://127.0.0.1:8545"
echo "  - 使用 Anvil 默认账户"
echo ""

# 检查 Anvil 是否运行
if ! curl -s http://127.0.0.1:8545 > /dev/null 2>&1; then
    echo "❌ 错误: 本地测试网络未运行"
    echo "请先启动 Anvil: ./scripts/start-local-network.sh"
    exit 1
fi

echo "✅ 检测到本地测试网络正在运行"
echo ""

# 部署合约
# 使用 --private-key 和 --sender 确保 Foundry 正确识别发送者
forge script script/Deploy.s.sol:DeployScript \
  --sig "deployLocal()" \
  --rpc-url http://127.0.0.1:8545 \
  --private-key "$ANVIL_DEFAULT_PRIVATE_KEY" \
  --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 \
  --broadcast

echo ""
echo "✅ 部署完成！"

