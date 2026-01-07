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
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# 获取脚本所在目录和项目根目录
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# 切换到项目根目录（确保 .env 文件和 forge 命令在正确的位置）
cd "$PROJECT_ROOT"

echo -e "${BOLD}${RED}⚠️  ⚠️  ⚠️  主网部署警告 ⚠️  ⚠️  ⚠️${NC}"
echo -e "${RED}主网部署涉及真实资金，请务必谨慎操作！${NC}"
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
    echo "  - BASE_RPC (可选，有默认值)"
    echo "  - BASESCAN_API_KEY (可选，用于合约验证)"
    echo "  - MAX_SUPPLY (可选)"
    echo "  - FEE_WEI (可选)"
    echo ""
    echo "参考文档: DEPLOY_BASE_MAINNET.md"
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
    echo "请参考 DEPLOY_BASE_MAINNET.md 了解如何获取私钥"
    exit 1
fi

if ! validate_address "$PROJECT_WALLET" "PROJECT_WALLET"; then
    exit 1
fi

if ! validate_address "$SAFE_MULTISIG" "SAFE_MULTISIG"; then
    echo -e "${RED}⚠️  严重错误: SAFE_MULTISIG 是必需的，所有合约将以此地址作为所有者${NC}"
    echo -e "${RED}⚠️  主网部署后无法更改，请务必确认地址正确！${NC}"
    echo "请参考 SAFE_MULTISIG_GUIDE.md 了解如何获取 Safe 多签地址"
    exit 1
fi

# 备用 RPC URL 列表（按优先级排序）
FALLBACK_RPCS=(
    "https://base-mainnet.g.alchemy.com/v2/Br9B6PkCm4u7NhukuwdGihx6SZnhrLWI"
    "https://base-mainnet.public.blastapi.io"
    "https://1rpc.io/base"
    "https://base.gateway.tenderly.co"
    "https://base.drpc.org"
    "https://base-rpc.publicnode.com"
)

# 测试 RPC 连接（更严格的测试）
test_rpc_connection() {
    local rpc_url=$1
    if command -v cast &> /dev/null; then
        # 测试 1: 获取链 ID
        local chain_id=$(timeout 10 cast chain-id --rpc-url "$rpc_url" 2>/dev/null || echo "")
        if [ "$chain_id" != "8453" ]; then
            return 1
        fi
        
        # 测试 2: 获取最新区块号（验证 RPC 完全可用）
        local block_number=$(timeout 10 cast block-number --rpc-url "$rpc_url" 2>/dev/null || echo "")
        if [ -z "$block_number" ] || [ "$block_number" = "0" ]; then
            return 1
        fi
        
        return 0
    else
        # 如果没有 cast，使用 curl 简单测试
        local response=$(timeout 5 curl -s -X POST "$rpc_url" \
            -H "Content-Type: application/json" \
            -d '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' 2>/dev/null || echo "")
        if echo "$response" | grep -q '"result":"0x2105"'; then
            return 0
        fi
        return 1
    fi
}

# 设置默认 RPC URL（如果未设置）
if [ -z "$BASE_RPC" ]; then
    echo -e "${YELLOW}⚠️  警告: BASE_RPC 未设置，尝试使用备用 RPC${NC}"
    
    # 尝试找到可用的 RPC
    RPC_FOUND=false
    for rpc in "${FALLBACK_RPCS[@]}"; do
        echo -e "${BLUE}测试 RPC: $rpc${NC}"
        if test_rpc_connection "$rpc"; then
            export BASE_RPC="$rpc"
            echo -e "${GREEN}✅ 找到可用的 RPC: $rpc${NC}"
            RPC_FOUND=true
            break
        else
            echo -e "${YELLOW}⚠️  RPC 不可用，尝试下一个...${NC}"
        fi
    done
    
    if [ "$RPC_FOUND" = false ]; then
        echo -e "${RED}❌ 错误: 所有备用 RPC 都不可用${NC}"
        echo ""
        echo "可能的原因:"
        echo "  1. 网络连接问题（防火墙、代理等）"
        echo "  2. 所有公共 RPC 暂时不可用"
        echo "  3. TLS/SSL 证书问题"
        echo ""
        echo "解决方案:"
        echo "1. 检查网络连接和防火墙设置"
        echo "2. 在 .env 文件中设置您自己的 RPC URL（推荐）:"
        echo ""
        echo "   # 选项 1: 使用 Alchemy（推荐，稳定）"
        echo "   BASE_RPC=https://base-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
        echo ""
        echo "   # 选项 2: 使用 Infura"
        echo "   BASE_RPC=https://base-mainnet.infura.io/v3/YOUR_PROJECT_ID"
        echo ""
        echo "   # 选项 3: 使用 QuickNode"
        echo "   BASE_RPC=https://YOUR_ENDPOINT.base-mainnet.quiknode.pro/YOUR_KEY/"
        echo ""
        echo "   # 选项 4: 使用公共 RPC（可能不稳定）"
        echo "   BASE_RPC=https://base-mainnet.public.blastapi.io"
        echo ""
        echo "3. 注册并获取 RPC API key:"
        echo "  - Alchemy: https://www.alchemy.com/"
        echo "  - Infura: https://www.infura.io/"
        echo "  - QuickNode: https://www.quicknode.com/"
        echo ""
        echo "设置完成后，重新运行部署脚本。"
        exit 1
    fi
else
    # 如果用户提供了 RPC，测试连接
    echo -e "${BLUE}📡 测试 RPC 连接: $BASE_RPC${NC}"
    if ! test_rpc_connection "$BASE_RPC"; then
        echo -e "${RED}❌ 错误: 指定的 RPC 连接测试失败${NC}"
        echo ""
        echo "可能的原因:"
        echo "  1. RPC URL 不正确"
        echo "  2. RPC 端点暂时不可用"
        echo "  3. 网络连接问题"
        echo "  4. API key 无效或过期"
        echo ""
        echo "建议:"
        echo "  1. 检查 RPC URL 是否正确"
        echo "  2. 尝试其他 RPC 提供商"
        echo "  3. 检查网络连接"
        echo "  4. 验证 API key 是否有效"
        echo ""
        read -p "是否继续尝试部署? (yes/no): " continue_anyway
        if [ "$continue_anyway" != "yes" ]; then
            echo "部署已取消"
            exit 0
        fi
        echo -e "${YELLOW}⚠️  继续部署，但可能会失败${NC}"
    else
        echo -e "${GREEN}✅ RPC 连接正常${NC}"
    fi
fi

# 检查 BASESCAN_API_KEY
if [ -z "$BASESCAN_API_KEY" ]; then
    echo -e "${YELLOW}⚠️  警告: BASESCAN_API_KEY 未设置，将跳过合约验证${NC}"
    echo "如需自动验证合约，请设置 BASESCAN_API_KEY（参考 DEPLOY_BASE_MAINNET.md）"
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
    BALANCE=$(cast balance "$DEPLOYER_ADDRESS" --rpc-url "$BASE_RPC" 2>/dev/null || echo "0")
    if [ "$BALANCE" != "0" ]; then
        BALANCE_ETH=$(cast --to-unit "$BALANCE" ether 2>/dev/null || echo "未知")
        echo "当前余额: $BALANCE_ETH ETH"
        
        # 检查余额是否可能不足（小于 0.01 ETH）
        BALANCE_WEI=$(cast --to-wei "$BALANCE_ETH" wei 2>/dev/null || echo "0")
        MIN_BALANCE_WEI=$(cast --to-wei "0.01" ether 2>/dev/null || echo "0")
        if [ "$BALANCE_WEI" -lt "$MIN_BALANCE_WEI" ] 2>/dev/null; then
            echo -e "${YELLOW}⚠️  警告: 余额可能不足，建议至少准备 0.01 - 0.05 ETH${NC}"
            echo "主网部署需要更多 ETH，建议准备 0.05 - 0.1 ETH"
        fi
    else
        echo -e "${YELLOW}⚠️  警告: 无法获取余额或余额为 0${NC}"
        echo "请确保钱包有足够的 Base ETH 用于支付 gas 费用"
    fi
    echo ""
fi

# 显示配置信息
echo -e "${GREEN}=== 部署配置 ===${NC}"
echo "网络: Base Mainnet"
echo "Chain ID: 8453"
echo "RPC URL: $BASE_RPC"
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
  --rpc-url "$BASE_RPC" \
  --private-key "$PRIVATE_KEY"; then
    echo -e "${RED}❌ 模拟部署失败，请检查配置${NC}"
    echo ""
    echo "常见问题:"
    echo "  1. 钱包余额不足"
    echo "  2. RPC 端点连接失败或超时"
    echo "  3. 环境变量配置错误"
    echo "  4. 网络连接问题"
    echo ""
    echo "RPC 连接问题解决方案:"
    echo "  1. 检查网络连接和防火墙设置"
    echo "  2. 在 .env 文件中设置您自己的 RPC URL:"
    echo "     BASE_RPC=https://base-mainnet.g.alchemy.com/v2/YOUR_API_KEY"
    echo "  3. 使用 VPN 或代理（如果在受限网络环境中）"
    echo "  4. 尝试其他 RPC 提供商（Alchemy/Infura/QuickNode）"
    echo "  5. 检查 RPC URL 格式是否正确（确保以 https:// 开头）"
    echo ""
    echo "参考文档: DEPLOY_BASE_MAINNET.md 的故障排查部分"
    exit 1
fi

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

# 实际部署
echo -e "${BLUE}🚀 开始实际部署...${NC}"
echo -e "${YELLOW}提示: 如果遇到 RPC 超时，可以尝试:${NC}"
echo "  1. 更换 RPC 提供商（在 .env 中设置 BASE_RPC）"
echo "  2. 检查网络连接"
echo "  3. 稍后重试"
echo ""

# 尝试部署，如果失败提供更详细的错误信息
if ! forge script script/Deploy.s.sol:DeployScript \
  --rpc-url "$BASE_RPC" \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  $VERIFY_FLAG; then
    echo ""
    echo -e "${RED}❌ 部署失败${NC}"
    echo ""
    echo "可能的解决方案:"
    echo "1. RPC 连接超时:"
    echo "   - 在 .env 文件中设置其他 RPC URL:"
    echo "     BASE_RPC=https://base.llamarpc.com"
    echo "   - 或使用您自己的 RPC 提供商（Alchemy/Infura/QuickNode）"
    echo ""
    echo "2. 网络问题:"
    echo "   - 检查网络连接"
    echo "   - 尝试使用 VPN"
    echo "   - 稍后重试"
    echo ""
    echo "3. 其他问题:"
    echo "   - 检查钱包余额是否充足"
    echo "   - 检查环境变量配置"
    echo "   - 查看上方详细错误信息"
    echo ""
    echo "参考文档: DEPLOY_BASE_MAINNET.md 的故障排查部分"
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
    echo "  cast call <AIO_TOKEN_ADDRESS> \"owner()(address)\" --rpc-url $BASE_RPC"
    echo ""
    echo "  # 检查 FeeDistributor 所有者"
    echo "  cast call <FEE_DISTRIBUTOR_ADDRESS> \"owner()(address)\" --rpc-url $BASE_RPC"
    echo ""
    echo "  # 检查 Interaction 所有者"
    echo "  cast call <INTERACTION_ADDRESS> \"owner()(address)\" --rpc-url $BASE_RPC"
    echo ""
fi

echo -e "${YELLOW}📝 后续步骤:${NC}"
echo "1. ✅ 立即保存所有合约地址（备份多份）"
if [ -z "$BASESCAN_API_KEY" ]; then
    echo "2. ⚠️  手动在 Basescan 上验证合约（如果自动验证失败）"
else
    echo "2. ✅ 合约应该已自动验证（如果使用了 --verify）"
fi
echo "3. 🔍 验证所有合约的所有者都是 Safe 多签地址"
echo "4. 📖 配置 AIO Token 和奖励池（见 DEPLOY_BASE_MAINNET.md 的'部署后操作'部分）"
echo "5. 🧪 测试合约功能"
echo ""
echo "重要提示:"
echo "  - 所有合约的所有者都是 Safe 多签地址: $SAFE_MULTISIG"
echo "  - 后续配置操作需要通过 Safe 多签执行"
echo "  - 参考 DEPLOY_BASE_MAINNET.md 了解详细配置步骤"
echo ""
echo -e "${RED}⚠️  重要: 主网部署已完成，请妥善保管所有信息${NC}"

