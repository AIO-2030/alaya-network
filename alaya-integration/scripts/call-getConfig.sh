#!/bin/bash

# 调用 Interaction 合约的 getConfig 方法
# 网络: Base Sepolia Testnet (84532)
# 合约地址: 0x5e9f531503322b77c6AA492Ef0b3410C4Ee8CF47

INTERACTION_ADDRESS="0x194B90670ba16E5ceF54A595e56b8157962c2E88"
RPC_URL="https://base-sepolia.g.alchemy.com/v2/Br9B6PkCm4u7NhukuwdGihx6SZnhrLWI"

echo "正在调用 Interaction.getConfig()..."
echo "合约地址: $INTERACTION_ADDRESS"
echo "网络: Base Sepolia Testnet"
echo ""

# 调用 getConfig 并按行读取结果
# cast 返回多行输出，每行一个值
# getConfig() 返回: uint256 feeWei_, address feeDistributor_, address aioToken_, address aioRewardPool_
RESULT=$(cast call "$INTERACTION_ADDRESS" \
    "getConfig()(uint256,address,address,address)" \
    --rpc-url "$RPC_URL")

# 按行读取结果到数组
IFS=$'\n' read -d '' -r -a RESULT_ARRAY <<< "$RESULT" || true

# 解析结果（按行索引）
# 第一行：feeWei (可能包含十六进制表示，需要提取数字部分)
fee_wei_line="${RESULT_ARRAY[0]}"
fee_wei=$(echo "$fee_wei_line" | awk '{print $1}')  # 提取第一个字段（数字部分）

fee_distributor="${RESULT_ARRAY[1]}"
aio_token="${RESULT_ARRAY[2]}"
aio_reward_pool="${RESULT_ARRAY[3]}"

# 转换 wei 到 ETH
fee_eth=$(echo "scale=6; $fee_wei / 1000000000000000000" | bc)

echo "============================================================"
echo "Interaction.getConfig() 返回值"
echo "============================================================"
echo ""
echo "1. feeWei (手续费):"
echo "   - Wei: $(printf "%'d" $fee_wei)"
echo "   - ETH: $fee_eth ETH"
echo ""
echo "2. feeDistributor (手续费分配合约地址):"
echo "   $fee_distributor"
echo ""
echo "3. aioToken (AIO 代币合约地址):"
if [ "$aio_token" = "0x0000000000000000000000000000000000000000" ]; then
    echo "   $aio_token (未设置)"
else
    echo "   $aio_token"
fi
echo ""
echo "4. aioRewardPool (AIO 奖励池地址):"
if [ "$aio_reward_pool" = "0x0000000000000000000000000000000000000000" ]; then
    echo "   $aio_reward_pool (未设置)"
else
    echo "   $aio_reward_pool"
fi
echo ""
echo "============================================================"

