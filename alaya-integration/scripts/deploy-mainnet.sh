#!/bin/bash

# 部署合约到 Base 主网
# 使用方法: ./scripts/deploy-mainnet.sh
#
# ⚠️  警告: 主网部署涉及真实资金，请务必谨慎操作！
#
# 前置要求:
# 1. 已在测试网充分测试
# 2. 确保 .env 文件已配置所有必需的环境变量
# 3. 确保部署钱包有足够的 Base ETH
# 4. 确保 SAFE_MULTISIG 地址正确（主网部署后无法更改）
# 5. 已进行最终的安全检查

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m' # No Color

echo -e "${BOLD}${RED}⚠️  ⚠️  ⚠️  主网部署警告 ⚠️  ⚠️  ⚠️${NC}"
echo -e "${RED}主网部署涉及真实资金，请务必谨慎操作！${NC}"
echo ""

# 检查 .env 文件是否存在
if [ ! -f .env ]; then
    echo -e "${RED}❌ 错误: .env 文件不存在${NC}"
    echo "请创建 .env 文件并配置以下环境变量:"
    echo "  - PRIVATE_KEY"
    echo "  - PROJECT_WALLET"
    echo "  - SAFE_MULTISIG"
    echo "  - BASE_RPC"
    echo "  - BASESCAN_API_KEY"
    exit 1
fi

# 加载环境变量
source .env

# 检查必需的环境变量
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}❌ 错误: PRIVATE_KEY 未设置${NC}"
    exit 1
fi

if [ -z "$PROJECT_WALLET" ]; then
    echo -e "${RED}❌ 错误: PROJECT_WALLET 未设置${NC}"
    exit 1
fi

if [ -z "$SAFE_MULTISIG" ]; then
    echo -e "${RED}❌ 错误: SAFE_MULTISIG 未设置${NC}"
    echo -e "${RED}⚠️  严重错误: SAFE_MULTISIG 是必需的，所有合约将以此地址作为所有者${NC}"
    echo -e "${RED}⚠️  主网部署后无法更改，请务必确认地址正确！${NC}"
    exit 1
fi

# 设置默认 RPC URL（如果未设置）
if [ -z "$BASE_RPC" ]; then
    echo -e "${YELLOW}⚠️  警告: BASE_RPC 未设置，使用默认 Alchemy RPC${NC}"
    export BASE_RPC="https://base-mainnet.g.alchemy.com/v2/Br9B6PkCm4u7NhukuwdGihx6SZnhrLWI"
fi

if [ -z "$BASESCAN_API_KEY" ]; then
    echo -e "${YELLOW}⚠️  警告: BASESCAN_API_KEY 未设置，将跳过合约验证${NC}"
    VERIFY_FLAG=""
else
    VERIFY_FLAG="--verify --etherscan-api-key $BASESCAN_API_KEY"
fi

# 显示配置信息
echo -e "${GREEN}=== 部署配置 ===${NC}"
echo "网络: Base Mainnet"
echo "RPC URL: $BASE_RPC"
echo "项目钱包: $PROJECT_WALLET"
echo "Safe 多签: $SAFE_MULTISIG"
if [ -n "$MAX_SUPPLY" ]; then
    echo "最大供应量: $MAX_SUPPLY"
fi
if [ -n "$FEE_WEI" ]; then
    echo "初始手续费: $FEE_WEI wei"
fi
echo "=================="
echo ""

# 主网部署安全检查清单
echo -e "${YELLOW}=== 主网部署安全检查清单 ===${NC}"
echo "请确认以下所有项目:"
echo ""
echo "[ ] 已在测试网（Base Sepolia）成功部署并测试"
echo "[ ] 所有合约代码已通过审查"
echo "[ ] SAFE_MULTISIG 地址已多次确认正确"
echo "[ ] PROJECT_WALLET 地址正确"
echo "[ ] 部署钱包有足够的 Base ETH（建议多准备 20-30% 缓冲）"
echo "[ ] 私钥安全保存，不会泄露"
echo "[ ] .env 文件已添加到 .gitignore"
echo "[ ] 所有环境变量都已正确设置"
echo "[ ] 已备份所有配置和地址"
echo "[ ] 在安全、干净的环境中操作"
echo ""
read -p "已确认所有检查项? (yes/no): " checklist_confirm

if [ "$checklist_confirm" != "yes" ]; then
    echo -e "${RED}部署已取消，请完成所有检查项后再试${NC}"
    exit 0
fi

echo ""

# 最终确认
echo -e "${BOLD}${RED}⚠️  最终确认 ⚠️${NC}"
echo -e "${RED}这是最后一次确认机会！${NC}"
echo ""
echo -e "${RED}确认信息:${NC}"
echo "  - 网络: Base Mainnet (主网)"
echo "  - Safe 多签: $SAFE_MULTISIG"
echo "  - 项目钱包: $PROJECT_WALLET"
echo ""
echo -e "${RED}主网部署后:${NC}"
echo "  - 合约将永久存在于主网上"
echo "  - 所有者地址无法更改"
echo "  - 将消耗真实的 ETH"
echo ""
read -p "确认继续主网部署? (输入 'DEPLOY_TO_MAINNET' 以确认): " final_confirm

if [ "$final_confirm" != "DEPLOY_TO_MAINNET" ]; then
    echo -e "${GREEN}部署已取消${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}开始部署...${NC}"
echo ""

# 编译合约
echo "📦 编译合约..."
forge build
echo ""

# 模拟部署（检查是否有错误）
echo "🔍 模拟部署（检查配置）..."
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url "$BASE_RPC" \
  --private-key "$PRIVATE_KEY" \
  || {
    echo -e "${RED}❌ 模拟部署失败，请检查配置${NC}"
    exit 1
  }

echo ""
echo -e "${GREEN}✅ 模拟部署成功${NC}"
echo ""

# 最终确认
echo -e "${YELLOW}⚠️  即将发送真实交易到主网${NC}"
read -p "最后确认: 继续部署? (yes/no): " last_confirm

if [ "$last_confirm" != "yes" ]; then
    echo -e "${GREEN}部署已取消${NC}"
    exit 0
fi

echo ""
echo -e "${GREEN}🚀 开始实际部署...${NC}"
echo ""

# 实际部署
forge script script/Deploy.s.sol:DeployScript \
  --rpc-url "$BASE_RPC" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  $VERIFY_FLAG

echo ""
echo -e "${GREEN}✅ 部署完成！${NC}"
echo ""
echo -e "${GREEN}=== 部署地址 ===${NC}"
echo "请查看上方的 JSON 输出获取所有合约地址"
echo "=================="
echo ""
echo -e "${YELLOW}📝 后续步骤:${NC}"
echo "1. 立即保存所有合约地址（备份多份）"
echo "2. 在 Basescan 上验证合约"
echo "3. 验证所有合约的所有者都是 Safe 多签地址"
echo "4. 配置 AIO Token 和奖励池（见 DEPLOY_BASE_MAINNET.md）"
echo "5. 测试合约功能"
echo ""
echo -e "${RED}⚠️  重要: 主网部署已完成，请妥善保管所有信息${NC}"

