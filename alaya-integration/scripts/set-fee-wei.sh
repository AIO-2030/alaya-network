#!/bin/bash

# 更新 FeeDistributor 合约的 feeWei 值
# 网络: Base Sepolia Testnet (84532)

# 从环境变量或直接设置
FEE_DISTRIBUTOR_ADDRESS="${FEE_DISTRIBUTOR_ADDRESS:-0xA928B7Ab1f6d3B15C11b01d83680199bAb028BA9}"
NEW_FEE_WEI="${NEW_FEE_WEI:-1}"  # 1 wei
RPC_URL="${RPC_URL:-https://base-sepolia.g.alchemy.com/v2/Br9B6PkCm4u7NhukuwdGihx6SZnhrLWI}"

echo "============================================================"
echo "更新 FeeDistributor 合约的 feeWei"
echo "============================================================"
echo ""
echo "FeeDistributor 地址: $FEE_DISTRIBUTOR_ADDRESS"
echo "新的 feeWei 值: $NEW_FEE_WEI wei"
echo "网络: Base Sepolia Testnet"
echo ""

# 检查当前值
echo "检查当前 feeWei 值..."
CURRENT_FEE=$(cast call "$FEE_DISTRIBUTOR_ADDRESS" \
    "feeWei()(uint256)" \
    --rpc-url "$RPC_URL")

echo "当前 feeWei: $CURRENT_FEE wei"
echo ""

if [ "$CURRENT_FEE" = "$NEW_FEE_WEI" ]; then
    echo "✅ feeWei 已经是目标值 ($NEW_FEE_WEI wei)，无需更新"
    exit 0
fi

# 检查合约所有者
echo "检查合约所有者..."
OWNER=$(cast call "$FEE_DISTRIBUTOR_ADDRESS" \
    "owner()(address)" \
    --rpc-url "$RPC_URL")

echo "合约所有者: $OWNER"
echo ""

# 检查治理模式
GOVERNANCE_MODE=$(cast call "$FEE_DISTRIBUTOR_ADDRESS" \
    "governanceModeEnabled()(bool)" \
    --rpc-url "$RPC_URL")

echo "治理模式是否启用: $GOVERNANCE_MODE"
echo ""

echo "============================================================"
echo "准备更新 feeWei"
echo "============================================================"
echo ""
echo "⚠️  注意：此操作需要通过合约所有者（Safe multisig）来执行"
echo ""
echo "方法 1: 使用 Safe multisig 界面"
echo "  1. 访问 Safe 多签界面"
echo "  2. 创建新交易"
echo "  3. 调用合约: $FEE_DISTRIBUTOR_ADDRESS"
echo "  4. 函数: setFeeWei(uint256)"
echo "  5. 参数: $NEW_FEE_WEI"
echo ""
echo "方法 2: 使用 forge script（需要 Safe multisig 私钥）"
echo "  export FEE_DISTRIBUTOR_ADDRESS=$FEE_DISTRIBUTOR_ADDRESS"
echo "  export NEW_FEE_WEI=$NEW_FEE_WEI"
echo "  forge script script/SetFeeWei.s.sol:SetFeeWeiScript \\"
echo "    --rpc-url $RPC_URL \\"
echo "    --broadcast \\"
echo "    --verify \\"
echo "    -vvvv"
echo ""
echo "方法 3: 使用 cast send（需要 Safe multisig 私钥）"
echo "  cast send $FEE_DISTRIBUTOR_ADDRESS \\"
echo "    \"setFeeWei(uint256)\" $NEW_FEE_WEI \\"
echo "    --rpc-url $RPC_URL \\"
echo "    --private-key \$SAFE_MULTISIG_PRIVATE_KEY"
echo ""

# 生成编码后的调用数据
ENCODED_DATA=$(cast calldata "setFeeWei(uint256)" "$NEW_FEE_WEI")
echo "编码后的调用数据:"
echo "$ENCODED_DATA"
echo ""

echo "============================================================"

