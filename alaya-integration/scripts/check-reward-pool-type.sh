#!/bin/bash

# 检查 aioRewardPool 是 EOA 还是合约
# 用于确定如何设置 approve

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo "=========================================="
echo "aioRewardPool 类型检查工具"
echo "=========================================="
echo ""

# 从环境变量或参数获取配置
AIO_REWARD_POOL="${1:-0xc3464b2Ae8507d6977e2815ab1A6825811623433}"
AIO_TOKEN_ADDR="${2:-0x7a1d1F7Cb42997E3cCc32E69BD26BEbe33ef8F57}"
INTERACTION_ADDR="${3:-0x194B90670ba16E5ceF54A595e56b8157962c2E88}"
RPC_URL="${RPC_URL:-https://sepolia.base.org}"

echo "配置信息:"
echo "  aioRewardPool: $AIO_REWARD_POOL"
echo "  AIO Token: $AIO_TOKEN_ADDR"
echo "  Interaction 合约: $INTERACTION_ADDR"
echo "  RPC URL: $RPC_URL"
echo ""

# 检查地址是否有代码
echo "1. 检查 aioRewardPool 类型..."
CODE_SIZE=$(cast code "$AIO_REWARD_POOL" --rpc-url "$RPC_URL" 2>/dev/null | wc -c | tr -d ' ')

if [ "$CODE_SIZE" -gt 2 ]; then
    # 有代码，是合约
    echo -e "${BLUE}✓ aioRewardPool 是一个智能合约${NC}"
    echo ""
    echo "合约代码长度: $CODE_SIZE 字节"
    echo ""
    
    # 尝试检查是否是 Safe 多签钱包
    echo "2. 检查是否是 Safe 多签钱包..."
    SAFE_VERSION=$(cast call "$AIO_REWARD_POOL" "VERSION()(string)" --rpc-url "$RPC_URL" 2>/dev/null || echo "")
    if [ -n "$SAFE_VERSION" ]; then
        echo -e "${GREEN}✓ 这是一个 Safe 多签钱包 (版本: $SAFE_VERSION)${NC}"
        echo ""
        echo "=== 使用 Safe 多签钱包设置 approve ==="
        echo ""
        echo "方法 1: 通过 Safe Web 界面"
        echo "  1. 访问 Safe Web 界面: https://app.safe.global/"
        echo "  2. 连接到您的 Safe 钱包 ($AIO_REWARD_POOL)"
        echo "  3. 创建新交易"
        echo "  4. 设置以下参数:"
        echo "     - To: $AIO_TOKEN_ADDR (AIO Token 合约地址)"
        echo "     - Value: 0"
        echo "     - Data: 调用 approve 函数"
        echo ""
        echo "方法 2: 使用 Safe CLI"
        echo "  safe-cli send --safe $AIO_REWARD_POOL \\"
        echo "    --to $AIO_TOKEN_ADDR \\"
        echo "    --data \"$(cast calldata 'approve(address,uint256)' $INTERACTION_ADDR 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff)\" \\"
        echo "    --rpc-url $RPC_URL"
        echo ""
        echo "方法 3: 使用 cast 通过 Safe 合约调用"
        echo "  需要先通过 Safe 的 execTransaction 函数"
        echo ""
    else
        echo -e "${YELLOW}⚠ 无法确定合约类型，可能是其他类型的合约钱包${NC}"
        echo ""
        echo "=== 通用合约设置 approve 方法 ==="
        echo ""
        echo "如果合约有 approve 函数，可以通过合约的接口调用:"
        echo "  - 检查合约是否有 owner/multisig 机制"
        echo "  - 通过合约的授权机制调用 AIO Token 的 approve"
        echo ""
    fi
    
    echo "=== 生成 approve 交易数据 ==="
    echo ""
    echo "使用 cast 生成交易数据:"
    echo "  cast calldata 'approve(address,uint256)' \\"
    echo "    $INTERACTION_ADDR \\"
    echo "    0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"
    echo ""
    
else
    # 没有代码，是 EOA
    echo -e "${GREEN}✓ aioRewardPool 是一个 EOA (外部账户)${NC}"
    echo ""
    echo "=== 使用 EOA 设置 approve ==="
    echo ""
    echo "方法 1: 使用 cast 命令（推荐）"
    echo ""
    echo "  # 授权最大金额（推荐）"
    echo "  cast send $AIO_TOKEN_ADDR \\"
    echo "    \"approve(address,uint256)(bool)\" \\"
    echo "    $INTERACTION_ADDR \\"
    echo "    0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff \\"
    echo "    --rpc-url $RPC_URL \\"
    echo "    --private-key <AIO_REWARD_POOL_PRIVATE_KEY>"
    echo ""
    echo "  # 或授权固定金额（例如 1000 AIO，注意 AIO 使用 8 位小数）"
    echo "  cast send $AIO_TOKEN_ADDR \\"
    echo "    \"approve(address,uint256)(bool)\" \\"
    echo "    $INTERACTION_ADDR \\"
    echo "    $(echo '1000 * 10^8' | bc) \\"
    echo "    --rpc-url $RPC_URL \\"
    echo "    --private-key <AIO_REWARD_POOL_PRIVATE_KEY>"
    echo ""
    echo "方法 2: 使用前端代码"
    echo "  const signer = new ethers.Wallet(REWARD_POOL_PRIVATE_KEY, provider);"
    echo "  const aioToken = new ethers.Contract("
    echo "    '$AIO_TOKEN_ADDR',"
    echo "    ['function approve(address,uint256) returns (bool)'],"
    echo "    signer"
    echo "  );"
    echo "  await aioToken.approve("
    echo "    '$INTERACTION_ADDR',"
    echo "    ethers.MaxUint256"
    echo "  );"
    echo ""
fi

echo ""
echo "=== 验证 approve 是否成功 ==="
echo ""
echo "执行以下命令检查 allowance:"
echo "  cast call $AIO_TOKEN_ADDR \\"
echo "    \"allowance(address,address)(uint256)\" \\"
echo "    $AIO_REWARD_POOL \\"
echo "    $INTERACTION_ADDR \\"
echo "    --rpc-url $RPC_URL"
echo ""
echo "如果返回 0，说明 approve 未成功。"
echo ""

echo "=========================================="
echo "检查完成"
echo "=========================================="

