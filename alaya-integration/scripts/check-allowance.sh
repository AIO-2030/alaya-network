#!/bin/bash

# 检查 AIO Token Allowance 诊断脚本
# 用于诊断 claimAIO 失败的原因

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "AIO Token Allowance 诊断工具"
echo "=========================================="
echo ""

# 从环境变量或参数获取配置
INTERACTION_ADDR="${1:-0x194B90670ba16E5ceF54A595e56b8157962c2E88}"
AIO_TOKEN_ADDR="${2:-0x7a1d1F7Cb42997E3cCc32E69BD26BEbe33ef8F57}"
AIO_REWARD_POOL="${3:-0xc3464b2Ae8507d6977e2815ab1A6825811623433}"
RPC_URL="${RPC_URL:-https://sepolia.base.org}"

echo "配置信息:"
echo "  Interaction 合约: $INTERACTION_ADDR"
echo "  AIO Token 合约: $AIO_TOKEN_ADDR"
echo "  AIO Reward Pool: $AIO_REWARD_POOL"
echo "  RPC URL: $RPC_URL"
echo ""

# 检查 Interaction 合约配置
echo "1. 检查 Interaction 合约配置..."
INTERACTION_CONFIG=$(cast call "$INTERACTION_ADDR" "getConfig()(uint256,address,address,address)" --rpc-url "$RPC_URL" 2>/dev/null || echo "")
if [ -z "$INTERACTION_CONFIG" ]; then
    echo -e "${RED}✗ 无法读取 Interaction 合约配置${NC}"
    exit 1
fi

# 解析配置
read -r FEE_WEI FEE_DISTRIBUTOR CONFIG_AIO_TOKEN CONFIG_AIO_REWARD_POOL <<< "$INTERACTION_CONFIG"
echo -e "${GREEN}✓ Interaction 合约配置:${NC}"
echo "  AIO Token: $CONFIG_AIO_TOKEN"
echo "  AIO Reward Pool: $CONFIG_AIO_REWARD_POOL"
echo ""

# 验证配置是否匹配（只有当配置不为空时才比较）
if [ -n "$CONFIG_AIO_TOKEN" ] && [ "$CONFIG_AIO_TOKEN" != "0x0000000000000000000000000000000000000000" ]; then
    CONFIG_TOKEN_CHECKSUM=$(cast --to-checksum-address "$CONFIG_AIO_TOKEN" 2>/dev/null || echo "")
    PROVIDED_TOKEN_CHECKSUM=$(cast --to-checksum-address "$AIO_TOKEN_ADDR" 2>/dev/null || echo "")
    if [ -n "$CONFIG_TOKEN_CHECKSUM" ] && [ -n "$PROVIDED_TOKEN_CHECKSUM" ] && [ "$CONFIG_TOKEN_CHECKSUM" != "$PROVIDED_TOKEN_CHECKSUM" ]; then
        echo -e "${YELLOW}⚠ 警告: 配置的 AIO Token 地址与提供的地址不匹配${NC}"
        echo "    配置的: $CONFIG_TOKEN_CHECKSUM"
        echo "    提供的: $PROVIDED_TOKEN_CHECKSUM"
    fi
fi

if [ -n "$CONFIG_AIO_REWARD_POOL" ] && [ "$CONFIG_AIO_REWARD_POOL" != "0x0000000000000000000000000000000000000000" ]; then
    CONFIG_POOL_CHECKSUM=$(cast --to-checksum-address "$CONFIG_AIO_REWARD_POOL" 2>/dev/null || echo "")
    PROVIDED_POOL_CHECKSUM=$(cast --to-checksum-address "$AIO_REWARD_POOL" 2>/dev/null || echo "")
    if [ -n "$CONFIG_POOL_CHECKSUM" ] && [ -n "$PROVIDED_POOL_CHECKSUM" ] && [ "$CONFIG_POOL_CHECKSUM" != "$PROVIDED_POOL_CHECKSUM" ]; then
        echo -e "${YELLOW}⚠ 警告: 配置的 AIO Reward Pool 地址与提供的地址不匹配${NC}"
        echo "    配置的: $CONFIG_POOL_CHECKSUM"
        echo "    提供的: $PROVIDED_POOL_CHECKSUM"
    fi
fi

# 先获取 AIO Token 的 decimals
echo "2. 获取 AIO Token 信息..."
DECIMALS=$(cast call "$AIO_TOKEN_ADDR" "decimals()(uint8)" --rpc-url "$RPC_URL" 2>/dev/null || echo "8")
echo "  Token Decimals: $DECIMALS"
echo ""

# 计算除数（10^decimals）- 使用更简单的方法
case "$DECIMALS" in
    8)
        DIVISOR="100000000"
        ;;
    18)
        DIVISOR="1000000000000000000"
        ;;
    *)
        # 尝试使用 bc 计算
        if command -v bc &> /dev/null; then
            DIVISOR=$(echo "10^$DECIMALS" | bc 2>/dev/null || echo "100000000")
        else
            DIVISOR="100000000"
        fi
        ;;
esac

# 检查 Reward Pool 的余额
echo "3. 检查 AIO Reward Pool 余额..."
REWARD_POOL_BALANCE=$(cast call "$AIO_TOKEN_ADDR" "balanceOf(address)(uint256)" "$AIO_REWARD_POOL" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")

# 检查余额是否为空或无效
if [ -z "$REWARD_POOL_BALANCE" ] || [ "$REWARD_POOL_BALANCE" = "" ]; then
    echo -e "${RED}✗ 无法读取 Reward Pool 余额${NC}"
    exit 1
fi

# 转换为可读格式（根据实际的 decimals）
if command -v bc &> /dev/null; then
    REWARD_POOL_BALANCE_ETH=$(echo "scale=$DECIMALS; $REWARD_POOL_BALANCE / $DIVISOR" | bc 2>/dev/null || echo "$REWARD_POOL_BALANCE")
else
    # 如果没有 bc，尝试使用 cast（仅适用于 18 位小数）
    if [ "$DECIMALS" = "18" ]; then
        REWARD_POOL_BALANCE_ETH=$(cast --to-unit "$REWARD_POOL_BALANCE" ether 2>/dev/null || echo "$REWARD_POOL_BALANCE")
    else
        # 对于其他 decimals，显示原始值
        REWARD_POOL_BALANCE_ETH="$REWARD_POOL_BALANCE"
    fi
fi

echo "  Reward Pool 余额: $REWARD_POOL_BALANCE_ETH AIO (原始值: $REWARD_POOL_BALANCE)"
if [ "$REWARD_POOL_BALANCE" = "0" ] || [ "$REWARD_POOL_BALANCE" = "0x0" ] || [ "$REWARD_POOL_BALANCE" = "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
    echo -e "${RED}✗ Reward Pool 余额为 0，无法进行 claim${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Reward Pool 有足够的余额${NC}"
echo ""

# 检查 Allowance
echo "4. 检查 Allowance (关键检查)..."
ALLOWANCE=$(cast call "$AIO_TOKEN_ADDR" "allowance(address,address)(uint256)" "$AIO_REWARD_POOL" "$INTERACTION_ADDR" --rpc-url "$RPC_URL" 2>/dev/null || echo "0")

# 检查 allowance 是否为空或无效
if [ -z "$ALLOWANCE" ] || [ "$ALLOWANCE" = "" ]; then
    ALLOWANCE="0"
fi

# 转换为可读格式（根据实际的 decimals）
if command -v bc &> /dev/null; then
    ALLOWANCE_ETH=$(echo "scale=$DECIMALS; $ALLOWANCE / $DIVISOR" | bc 2>/dev/null || echo "$ALLOWANCE")
else
    # 如果没有 bc，尝试使用 cast（仅适用于 18 位小数）
    if [ "$DECIMALS" = "18" ]; then
        ALLOWANCE_ETH=$(cast --to-unit "$ALLOWANCE" ether 2>/dev/null || echo "$ALLOWANCE")
    else
        # 对于其他 decimals，显示原始值
        ALLOWANCE_ETH="$ALLOWANCE"
    fi
fi

echo "  Reward Pool 授权给 Interaction 合约的额度: $ALLOWANCE_ETH AIO (原始值: $ALLOWANCE)"
echo "  (Reward Pool -> Interaction 合约)"

if [ "$ALLOWANCE" = "0" ] || [ "$ALLOWANCE" = "0x0" ] || [ "$ALLOWANCE" = "0x0000000000000000000000000000000000000000000000000000000000000000" ]; then
    echo -e "${RED}✗ Allowance 为 0！${NC}"
    echo ""
    echo "解决方案:"
    echo "  需要从 aioRewardPool 地址调用 AIO Token 的 approve 函数"
    echo ""
    echo "  命令示例:"
    echo "  cast send $AIO_TOKEN_ADDR \\"
    echo "    \"approve(address,uint256)(bool)\" \\"
    echo "    $INTERACTION_ADDR \\"
    echo "    $(cast --to-wei 1000 ether) \\"
    echo "    --rpc-url $RPC_URL \\"
    echo "    --private-key <REWARD_POOL_PRIVATE_KEY>"
    echo ""
    echo "  或者使用更大的额度（推荐）:"
    echo "  cast send $AIO_TOKEN_ADDR \\"
    echo "    \"approve(address,uint256)(bool)\" \\"
    echo "    $INTERACTION_ADDR \\"
    echo "    0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff \\"
    echo "    --rpc-url $RPC_URL \\"
    echo "    --private-key <REWARD_POOL_PRIVATE_KEY>"
    echo ""
    echo "  ⚠️  重要：确保交易发送到 AIO Token 地址 ($AIO_TOKEN_ADDR)，"
    echo "     而不是 aioRewardPool 地址！"
    exit 1
else
    echo -e "${GREEN}✓ Allowance 已设置: $ALLOWANCE_ETH AIO${NC}"
fi
echo ""

# 检查常见错误
echo "5. 常见错误检查..."
echo ""

# 检查是否从错误的地址调用了 approve
echo "  ⚠️  重要提示:"
echo "  1. approve 交易必须发送到 AIO Token 合约地址 ($AIO_TOKEN_ADDR)"
echo "     ❌ 错误：发送到 aioRewardPool 地址 ($AIO_REWARD_POOL)"
echo "     ✅ 正确：发送到 AIO Token 地址 ($AIO_TOKEN_ADDR)"
echo ""
echo "  2. approve 必须从 aioRewardPool 地址 ($AIO_REWARD_POOL) 调用"
echo "     （使用 aioRewardPool 的私钥签名交易）"
echo ""
echo "  3. approve 的 spender 必须是 Interaction 合约地址 ($INTERACTION_ADDR)"
echo ""
echo "  4. approve 的 owner 是 aioRewardPool，不是用户地址"
echo ""

echo "=========================================="
echo "诊断完成"
echo "=========================================="

