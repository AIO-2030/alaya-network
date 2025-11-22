#!/bin/bash

# 部署合约到 Base Sepolia 测试网
# 使用方法: ./scripts/deploy-testnet.sh
#
# 前置要求:
# 1. 确保 .env 文件已配置所有必需的环境变量
# 2. 确保部署钱包有足够的 Base Sepolia ETH
# 3. 确保 SAFE_MULTISIG 地址正确
#
# 参考文档: DEPLOY_BASE_TESTNET.md

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Base Sepolia 网络信息
CHAIN_ID=84532
NETWORK_NAME="Base Sepolia Testnet"
DEFAULT_RPC="https://base-sepolia.g.alchemy.com/v2/Br9B6PkCm4u7NhukuwdGihx6SZnhrLWI"

# 获取脚本所在目录和项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 切换到项目根目录（确保 .env 文件和 forge 命令在正确的位置）
cd "$PROJECT_ROOT"

echo -e "${GREEN}🚀 部署合约到 Base Sepolia 测试网...${NC}"
echo "项目根目录: $PROJECT_ROOT"
echo "当前工作目录: $(pwd)"
echo ""

# 验证项目根目录（检查 foundry.toml 是否存在）
if [ ! -f "$PROJECT_ROOT/foundry.toml" ]; then
    echo -e "${RED}❌ 错误: 未找到 foundry.toml 文件${NC}"
    echo "当前目录可能不是项目根目录"
    echo "预期路径: $PROJECT_ROOT/foundry.toml"
    exit 1
fi

# 验证部署脚本是否存在
if [ ! -f "$PROJECT_ROOT/script/Deploy.s.sol" ]; then
    echo -e "${RED}❌ 错误: 未找到部署脚本${NC}"
    echo "预期路径: $PROJECT_ROOT/script/Deploy.s.sol"
    exit 1
fi

# 检查 Foundry 是否安装
if ! command -v forge &> /dev/null; then
    echo -e "${RED}❌ 错误: Foundry 未安装${NC}"
    echo "请参考 https://book.getfoundry.sh/getting-started/installation 安装 Foundry"
    exit 1
fi

# 检查 .env 文件是否存在（在项目根目录）
ENV_FILE="$PROJECT_ROOT/.env"
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}❌ 错误: .env 文件不存在${NC}"
    echo "预期路径: $ENV_FILE"
    echo ""
    echo "请创建 .env 文件并配置以下环境变量:"
    echo "  - PRIVATE_KEY (必填)"
    echo "  - PROJECT_WALLET (必填)"
    echo "  - SAFE_MULTISIG (必填)"
    echo "  - BASE_SEPOLIA_RPC (可选，有默认值)"
    echo "  - BASESCAN_API_KEY (可选，用于合约验证)"
    echo "  - MAX_SUPPLY (可选)"
    echo "  - FEE_WEI (可选)"
    echo ""
    echo "参考文档: DEPLOY_BASE_TESTNET.md"
    exit 1
fi

# 加载环境变量（使用绝对路径）
echo -e "${BLUE}📄 加载环境变量: $ENV_FILE${NC}"
source "$ENV_FILE"

# 验证以太坊地址格式
validate_address() {
    local addr=$1
    local name=$2
    
    if [ -z "$addr" ]; then
        echo -e "${RED}❌ 错误: $name 未设置${NC}"
        return 1
    fi
    
    # 检查地址格式 (0x 开头，42 字符)
    if [[ ! "$addr" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        echo -e "${RED}❌ 错误: $name 地址格式无效: $addr${NC}"
        echo "地址必须是 0x 开头的 42 字符十六进制地址"
        return 1
    fi
    
    return 0
}

# 检查必需的环境变量
if [ -z "$PRIVATE_KEY" ]; then
    echo -e "${RED}❌ 错误: PRIVATE_KEY 未设置${NC}"
    echo "请参考 DEPLOY_BASE_TESTNET.md 了解如何获取私钥"
    exit 1
fi

if ! validate_address "$PROJECT_WALLET" "PROJECT_WALLET"; then
    exit 1
fi

if ! validate_address "$SAFE_MULTISIG" "SAFE_MULTISIG"; then
    echo -e "${YELLOW}⚠️  警告: SAFE_MULTISIG 是必需的，所有合约将以此地址作为所有者${NC}"
    echo "请参考 SAFE_MULTISIG_GUIDE.md 了解如何获取 Safe 多签地址"
    exit 1
fi

# 设置默认 RPC URL（如果未设置）
if [ -z "$BASE_SEPOLIA_RPC" ]; then
    echo -e "${YELLOW}⚠️  警告: BASE_SEPOLIA_RPC 未设置，使用默认 Alchemy RPC${NC}"
    export BASE_SEPOLIA_RPC="$DEFAULT_RPC"
fi

# 检查 BASESCAN_API_KEY
if [ -z "$BASESCAN_API_KEY" ]; then
    echo -e "${YELLOW}⚠️  警告: BASESCAN_API_KEY 未设置，将跳过合约验证${NC}"
    echo "如需自动验证合约，请设置 BASESCAN_API_KEY（参考 DEPLOY_BASE_TESTNET.md）"
    VERIFY_FLAG=""
else
    VERIFY_FLAG="--verify --etherscan-api-key $BASESCAN_API_KEY"
fi

# 获取部署钱包地址
echo -e "${BLUE}📋 获取部署钱包地址...${NC}"
DEPLOYER_ADDRESS=$(cast wallet address --private-key "$PRIVATE_KEY" 2>/dev/null || echo "")
if [ -z "$DEPLOYER_ADDRESS" ]; then
    echo -e "${RED}❌ 错误: 无法从私钥获取地址，请检查 PRIVATE_KEY 格式${NC}"
    exit 1
fi
echo "部署钱包地址: $DEPLOYER_ADDRESS"

# 检查钱包余额（可选，如果 cast 可用）
if command -v cast &> /dev/null; then
    echo -e "${BLUE}💰 检查钱包余额...${NC}"
    BALANCE=$(cast balance "$DEPLOYER_ADDRESS" --rpc-url "$BASE_SEPOLIA_RPC" 2>/dev/null || echo "0")
    if [ "$BALANCE" != "0" ]; then
        BALANCE_ETH=$(cast --to-unit "$BALANCE" ether 2>/dev/null || echo "未知")
        echo "当前余额: $BALANCE_ETH ETH"
        
        # 检查余额是否可能不足（小于 0.01 ETH）
        BALANCE_WEI=$(cast --to-wei "$BALANCE_ETH" wei 2>/dev/null || echo "0")
        MIN_BALANCE_WEI=$(cast --to-wei "0.01" ether 2>/dev/null || echo "0")
        if [ "$BALANCE_WEI" -lt "$MIN_BALANCE_WEI" ] 2>/dev/null; then
            echo -e "${YELLOW}⚠️  警告: 余额可能不足，建议至少准备 0.01 - 0.05 ETH${NC}"
            echo "可以从水龙头获取测试网 ETH: https://www.coinbase.com/faucets/base-ethereum-goerli-faucet"
        fi
    else
        echo -e "${YELLOW}⚠️  警告: 无法获取余额或余额为 0${NC}"
        echo "请确保钱包有足够的 Base Sepolia ETH 用于支付 gas 费用"
    fi
    echo ""
fi

# 显示配置信息
echo -e "${GREEN}=== 部署配置 ===${NC}"
echo "网络: $NETWORK_NAME"
echo "Chain ID: $CHAIN_ID"
echo "RPC URL: $BASE_SEPOLIA_RPC"
echo "部署钱包: $DEPLOYER_ADDRESS"
echo "项目钱包: $PROJECT_WALLET"
echo "Safe 多签: $SAFE_MULTISIG"
if [ -n "$MAX_SUPPLY" ]; then
    echo "最大供应量: $MAX_SUPPLY"
else
    echo "最大供应量: 默认 (1,000,000,000 * 1e18)"
fi
if [ -n "$FEE_WEI" ]; then
    echo "初始手续费: $FEE_WEI wei"
else
    echo "初始手续费: 默认 (0.001 ETH = 1e15 wei)"
fi
echo "=================="
echo ""

# 确认部署
echo -e "${YELLOW}⚠️  即将部署到 Base Sepolia 测试网${NC}"
echo -e "${YELLOW}⚠️  请确认所有配置正确，特别是 SAFE_MULTISIG 地址${NC}"
echo -e "${YELLOW}⚠️  此操作将消耗 gas 费用${NC}"
read -p "确认继续部署? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "部署已取消"
    exit 0
fi

echo ""
echo -e "${GREEN}开始部署...${NC}"
echo ""

# 编译合约
echo -e "${BLUE}📦 编译合约...${NC}"
if ! forge build; then
    echo -e "${RED}❌ 编译失败，请检查合约代码${NC}"
    exit 1
fi
echo -e "${GREEN}✅ 编译成功${NC}"
echo ""

# 模拟部署（检查是否有错误）
echo -e "${BLUE}🔍 模拟部署（检查配置）...${NC}"
if ! forge script script/Deploy.s.sol:DeployScript \
  --rpc-url "$BASE_SEPOLIA_RPC" \
  --private-key "$PRIVATE_KEY"; then
    echo -e "${RED}❌ 模拟部署失败，请检查配置${NC}"
    echo "常见问题:"
    echo "  1. 钱包余额不足"
    echo "  2. RPC 端点连接失败"
    echo "  3. 环境变量配置错误"
    echo "  4. 网络连接问题"
    echo ""
    echo "参考文档: DEPLOY_BASE_TESTNET.md 的故障排查部分"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ 模拟部署成功${NC}"
echo ""

# 实际部署
echo -e "${BLUE}🚀 开始实际部署...${NC}"
if ! forge script script/Deploy.s.sol:DeployScript \
  --rpc-url "$BASE_SEPOLIA_RPC" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  $VERIFY_FLAG; then
    echo -e "${RED}❌ 部署失败${NC}"
    echo "请检查错误信息并参考 DEPLOY_BASE_TESTNET.md 的故障排查部分"
    exit 1
fi

echo ""
echo -e "${GREEN}✅ 部署完成！${NC}"
echo ""

# 尝试解析并显示部署地址（从输出中提取 JSON）
echo -e "${GREEN}=== 部署地址 ===${NC}"
echo "请查看上方的 JSON 输出获取所有合约地址"
echo ""
echo "部署的合约包括:"
echo "  - AIOERC20: AIO 代币合约"
echo "  - FeeDistributor: 手续费分配合约"
echo "  - Interaction: 交互合约"
echo "  - GovernanceBootstrapper: 治理引导合约"
echo ""
echo "所有合约的所有者都是: $SAFE_MULTISIG"
echo "=================="
echo ""

# 验证合约所有权（可选，如果 cast 可用）
if command -v cast &> /dev/null; then
    echo -e "${BLUE}🔍 验证合约所有权...${NC}"
    echo "（此步骤需要从部署输出中获取合约地址）"
    echo "可以使用以下命令验证:"
    echo ""
    echo "  # 检查 AIOERC20 所有者"
    echo "  cast call <AIO_TOKEN_ADDRESS> \"owner()(address)\" --rpc-url $BASE_SEPOLIA_RPC"
    echo ""
    echo "  # 检查 FeeDistributor 所有者"
    echo "  cast call <FEE_DISTRIBUTOR_ADDRESS> \"owner()(address)\" --rpc-url $BASE_SEPOLIA_RPC"
    echo ""
    echo "  # 检查 Interaction 所有者"
    echo "  cast call <INTERACTION_ADDRESS> \"owner()(address)\" --rpc-url $BASE_SEPOLIA_RPC"
    echo ""
fi

echo -e "${YELLOW}📝 后续步骤:${NC}"
echo "1. ✅ 保存所有合约地址（从上方 JSON 输出中获取）"
if [ -z "$BASESCAN_API_KEY" ]; then
    echo "2. ⚠️  手动在 Basescan 上验证合约（如果自动验证失败）"
else
    echo "2. ✅ 合约应该已自动验证（如果使用了 --verify）"
fi
echo "3. 📖 配置 AIO Token 和奖励池（见 DEPLOY_BASE_TESTNET.md 的'部署后操作'部分）"
echo "4. 🧪 测试合约功能"
echo ""
echo "重要提示:"
echo "  - 所有合约的所有者都是 Safe 多签地址: $SAFE_MULTISIG"
echo "  - 后续配置操作需要通过 Safe 多签执行"
echo "  - 参考 DEPLOY_BASE_TESTNET.md 了解详细配置步骤"
