#!/bin/bash

# 部署 Interaction 合约到本地测试网络（Anvil）
# 使用方法: ./scripts/deploy-interaction-local.sh
#
# 前置要求:
# 1. 确保 Anvil 或其他本地节点正在运行（默认: http://localhost:8545）
# 2. 可选：在 .env 文件中配置环境变量
#
# 环境变量（全部可选）:
#   - FEE_DISTRIBUTOR: 已存在的 FeeDistributor 合约地址（如果未设置，会自动部署一个新的）
#   - PROJECT_WALLET: 如果部署新的 FeeDistributor，使用此地址作为项目钱包（默认: deployer）
#   - FEE_WEI: 如果部署新的 FeeDistributor，使用此手续费（默认: 1e14 = 0.0001 ETH）
#   - LOCAL_RPC: 本地 RPC URL（默认: http://localhost:8545）
#   - ANVIL_PRIVATE_KEY: Anvil 账户私钥（默认: 使用 Anvil 的第一个账户）

set -e  # 遇到错误立即退出

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 默认配置
DEFAULT_RPC="http://localhost:8545"
DEFAULT_FEE_WEI="100000000000000"  # 0.0001 ETH (1e14)

# 获取脚本所在目录和项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 切换到项目根目录
cd "$PROJECT_ROOT"

echo -e "${GREEN}🚀 部署 Interaction 合约到本地测试网络...${NC}"
echo "项目根目录: $PROJECT_ROOT"
echo "当前工作目录: $(pwd)"
echo ""

# 验证项目根目录
if [ ! -f "$PROJECT_ROOT/foundry.toml" ]; then
    echo -e "${RED}❌ 错误: 未找到 foundry.toml 文件${NC}"
    echo "当前目录可能不是项目根目录"
    exit 1
fi

# 验证部署脚本是否存在
if [ ! -f "$PROJECT_ROOT/script/DeployInteraction.s.sol" ]; then
    echo -e "${RED}❌ 错误: 未找到部署脚本${NC}"
    echo "预期路径: $PROJECT_ROOT/script/DeployInteraction.s.sol"
    exit 1
fi

# 检查 Foundry 是否安装
if ! command -v forge &> /dev/null; then
    echo -e "${RED}❌ 错误: Foundry 未安装${NC}"
    echo "请参考 https://book.getfoundry.sh/getting-started/installation 安装 Foundry"
    exit 1
fi

# 检查 Anvil 是否运行（可选检查）
if command -v cast &> /dev/null; then
    LOCAL_RPC="${LOCAL_RPC:-$DEFAULT_RPC}"
    if ! cast block-number --rpc-url "$LOCAL_RPC" &> /dev/null; then
        echo -e "${YELLOW}⚠️  警告: 无法连接到本地节点: $LOCAL_RPC${NC}"
        echo "请确保 Anvil 或其他本地节点正在运行"
        echo "启动 Anvil: anvil"
        echo ""
        read -p "是否继续? (yes/no): " continue_anyway
        if [ "$continue_anyway" != "yes" ]; then
            echo "部署已取消"
            exit 0
        fi
    fi
fi

# 加载环境变量（如果 .env 文件存在）
ENV_FILE="$PROJECT_ROOT/.env"
if [ -f "$ENV_FILE" ]; then
    echo -e "${BLUE}📄 加载环境变量: $ENV_FILE${NC}"
    source "$ENV_FILE"
fi

# 设置默认值
export LOCAL_RPC="${LOCAL_RPC:-$DEFAULT_RPC}"
export FEE_WEI="${FEE_WEI:-$DEFAULT_FEE_WEI}"

# 获取部署者地址（使用 Anvil 默认账户或环境变量中的私钥）
if [ -n "$ANVIL_PRIVATE_KEY" ]; then
    DEPLOYER_ADDRESS=$(cast wallet address --private-key "$ANVIL_PRIVATE_KEY" 2>/dev/null || echo "")
    PRIVATE_KEY_ARG="--private-key $ANVIL_PRIVATE_KEY"
    echo -e "${BLUE}📋 使用环境变量中的私钥${NC}"
    echo "部署钱包地址: $DEPLOYER_ADDRESS"
elif [ -n "$PRIVATE_KEY" ]; then
    DEPLOYER_ADDRESS=$(cast wallet address --private-key "$PRIVATE_KEY" 2>/dev/null || echo "")
    PRIVATE_KEY_ARG="--private-key $PRIVATE_KEY"
    echo -e "${BLUE}📋 使用 .env 中的私钥${NC}"
    echo "部署钱包地址: $DEPLOYER_ADDRESS"
else
    # 使用 Anvil 默认账户（不需要私钥参数）
    PRIVATE_KEY_ARG=""
    # Anvil 默认第一个账户地址
    DEPLOYER_ADDRESS="0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266"
    echo -e "${BLUE}📋 使用 Anvil 默认账户${NC}"
    echo "部署钱包地址: $DEPLOYER_ADDRESS"
    echo "（Anvil 默认账户有足够的余额，不需要私钥参数）"
fi

# 检查账户余额
if command -v cast &> /dev/null && [ -n "$DEPLOYER_ADDRESS" ]; then
    echo -e "${BLUE}💰 检查账户余额...${NC}"
    BALANCE=$(cast balance "$DEPLOYER_ADDRESS" --rpc-url "$LOCAL_RPC" 2>/dev/null || echo "0")
    if [ "$BALANCE" = "0" ] || [ -z "$BALANCE" ]; then
        echo -e "${RED}❌ 错误: 账户余额为 0${NC}"
        echo "账户地址: $DEPLOYER_ADDRESS"
        echo ""
        echo "解决方案:"
        echo "1. 使用 Anvil 默认账户（推荐）: 不要设置 PRIVATE_KEY 或 ANVIL_PRIVATE_KEY 环境变量"
        echo "2. 给账户充值: 在 Anvil 中，可以使用以下命令给账户充值:"
        echo "   cast send $DEPLOYER_ADDRESS --value 100ether --private-key <anvil_default_key> --rpc-url $LOCAL_RPC"
        echo "3. 使用 Anvil 默认账户的私钥: 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
        echo ""
        exit 1
    else
        BALANCE_ETH=$(cast --to-unit "$BALANCE" ether 2>/dev/null || echo "未知")
        echo "当前余额: $BALANCE_ETH ETH"
        
        # 检查余额是否可能不足（小于 0.01 ETH）
        BALANCE_WEI=$(cast --to-wei "$BALANCE_ETH" wei 2>/dev/null || echo "0")
        MIN_BALANCE_WEI=$(cast --to-wei "0.01" ether 2>/dev/null || echo "0")
        if [ "$BALANCE_WEI" -lt "$MIN_BALANCE_WEI" ] 2>/dev/null; then
            echo -e "${YELLOW}⚠️  警告: 余额可能不足，建议至少准备 0.01 ETH${NC}"
        fi
    fi
    echo ""
fi

# 显示配置信息
echo -e "${GREEN}=== 部署配置 ===${NC}"
echo "网络: 本地测试网络"
echo "RPC URL: $LOCAL_RPC"
if [ -n "$DEPLOYER_ADDRESS" ]; then
    echo "部署钱包: $DEPLOYER_ADDRESS"
fi
if [ -n "$FEE_DISTRIBUTOR" ]; then
    echo "FeeDistributor: $FEE_DISTRIBUTOR (使用已存在的合约)"
else
    echo "FeeDistributor: 将自动部署新的合约"
    if [ -n "$PROJECT_WALLET" ]; then
        echo "项目钱包: $PROJECT_WALLET"
    else
        echo "项目钱包: 部署者地址"
    fi
    echo "手续费: $FEE_WEI wei"
fi
echo "所有者: 部署者地址"
echo "=================="
echo ""

# 确认部署
echo -e "${YELLOW}⚠️  即将部署到本地测试网络${NC}"
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
if [ -n "$PRIVATE_KEY_ARG" ]; then
    if ! forge script script/DeployInteraction.s.sol:DeployInteractionScript \
      --sig "deployLocal()" \
      --rpc-url "$LOCAL_RPC" \
      $PRIVATE_KEY_ARG; then
        echo -e "${RED}❌ 模拟部署失败，请检查配置${NC}"
        exit 1
    fi
else
    if ! forge script script/DeployInteraction.s.sol:DeployInteractionScript \
      --sig "deployLocal()" \
      --rpc-url "$LOCAL_RPC"; then
        echo -e "${RED}❌ 模拟部署失败，请检查配置${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}✅ 模拟部署成功${NC}"
echo ""

# 实际部署
echo -e "${BLUE}🚀 开始实际部署...${NC}"
if [ -n "$PRIVATE_KEY_ARG" ]; then
    if ! forge script script/DeployInteraction.s.sol:DeployInteractionScript \
      --sig "deployLocal()" \
      --rpc-url "$LOCAL_RPC" \
      $PRIVATE_KEY_ARG \
      --broadcast; then
        echo -e "${RED}❌ 部署失败${NC}"
        exit 1
    fi
else
    if ! forge script script/DeployInteraction.s.sol:DeployInteractionScript \
      --sig "deployLocal()" \
      --rpc-url "$LOCAL_RPC" \
      --broadcast; then
        echo -e "${RED}❌ 部署失败${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${GREEN}✅ 部署完成！${NC}"
echo ""

# 显示部署地址
echo -e "${GREEN}=== 部署地址 ===${NC}"
echo "请查看上方的 JSON 输出获取合约地址"
echo ""
echo "部署的合约:"
if [ -z "$FEE_DISTRIBUTOR" ]; then
    echo "  - FeeDistributor: 新部署的合约（如果自动部署）"
fi
echo "  - Interaction: 交互合约"
echo ""
echo "合约配置:"
echo "  - 所有者: 部署者地址"
echo "=================="
echo ""

# 验证合约配置（如果 cast 可用）
if command -v cast &> /dev/null; then
    echo -e "${BLUE}🔍 验证合约配置...${NC}"
    echo "（此步骤需要从部署输出中获取合约地址）"
    echo "可以使用以下命令验证:"
    echo ""
    echo "  # 检查 Interaction 所有者"
    echo "  cast call <INTERACTION_ADDRESS> \"owner()(address)\" --rpc-url $LOCAL_RPC"
    echo ""
    echo "  # 检查 FeeDistributor 地址"
    echo "  cast call <INTERACTION_ADDRESS> \"feeDistributor()(address)\" --rpc-url $LOCAL_RPC"
    echo ""
    echo "  # 获取完整配置"
    echo "  cast call <INTERACTION_ADDRESS> \"getConfig()(uint256,address,address,address)\" --rpc-url $LOCAL_RPC"
    echo ""
fi

echo -e "${YELLOW}📝 提示:${NC}"
echo "1. ✅ 合约已部署到本地网络"
echo "2. 🧪 可以在本地测试合约功能"
echo "3. 📖 如果需要，可以配置 AIO Token 和奖励池"
echo ""

