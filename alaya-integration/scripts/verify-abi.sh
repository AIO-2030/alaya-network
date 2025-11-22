#!/bin/bash

# 验证 ABI 文件与合约源码的一致性
# 检查 getConfig 函数的返回值数量

echo "正在验证 ABI 文件与合约源码的一致性..."
echo ""

# 检查合约源码中的 getConfig 返回值
SOL_RETURNS=$(grep -A 5 "function getConfig()" src/Interaction.sol | grep -E "returns|uint256|address" | head -6)
echo "合约源码中的 getConfig 返回值:"
echo "$SOL_RETURNS"
echo ""

# 检查 ABI 文件中的 getConfig 返回值
ABI_OUTPUTS=$(python3 << 'EOF'
import json
import sys

try:
    with open('abi/Interaction.json', 'r') as f:
        abi = json.load(f)
    
    getConfig = [f for f in abi if f.get('name') == 'getConfig']
    if not getConfig:
        print("错误：找不到 getConfig 函数")
        sys.exit(1)
    
    outputs = getConfig[0].get('outputs', [])
    print(f"ABI 文件中的 getConfig outputs 数量: {len(outputs)}")
    print("返回值列表:")
    for i, output in enumerate(outputs):
        print(f"  {i+1}. {output['name']} ({output['type']})")
    
    # 验证
    if len(outputs) != 4:
        print(f"\n❌ 错误：应该有 4 个返回值，但找到 {len(outputs)} 个")
        sys.exit(1)
    
    # 检查是否包含 allowlistEnabled
    has_allowlist = any('allowlist' in o['name'].lower() for o in outputs)
    if has_allowlist:
        print("\n❌ 错误：不应该包含 allowlistEnabled")
        sys.exit(1)
    
    print("\n✅ ABI 验证通过：getConfig 有 4 个返回值，不包含 allowlistEnabled")
    sys.exit(0)
    
except Exception as e:
    print(f"错误：{e}")
    sys.exit(1)
EOF
)

echo "$ABI_OUTPUTS"

if [ $? -eq 0 ]; then
    echo ""
    echo "============================================================"
    echo "✅ 所有验证通过！ABI 文件与合约源码一致"
    echo "============================================================"
else
    echo ""
    echo "============================================================"
    echo "❌ 验证失败！请检查 ABI 文件"
    echo "============================================================"
    exit 1
fi

