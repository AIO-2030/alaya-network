// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {FeeDistributor} from "../src/FeeDistributor.sol";

/**
 * @title SetFeeWeiScript
 * @notice 更新 FeeDistributor 合约的 feeWei 值
 * @dev 需要通过合约所有者（Safe multisig）来执行
 * 
 * 使用方法:
 * 1. 设置环境变量:
 *    export FEE_DISTRIBUTOR_ADDRESS=0x...
 *    export NEW_FEE_WEI=1  # 1 wei
 * 
 * 2. 使用 Safe multisig 的私钥运行:
 *    forge script script/SetFeeWei.s.sol:SetFeeWeiScript \
 *      --rpc-url $RPC_URL \
 *      --broadcast \
 *      --verify \
 *      -vvvv
 */
contract SetFeeWeiScript is Script {
    function run() public {
        // 从环境变量获取配置
        address feeDistributorAddress = vm.envAddress("FEE_DISTRIBUTOR_ADDRESS");
        uint256 newFeeWei = vm.envUint("NEW_FEE_WEI");
        
        console.log("=== 更新 FeeDistributor feeWei ===");
        console.log("FeeDistributor 地址:", feeDistributorAddress);
        console.log("新的 feeWei 值:", newFeeWei);
        console.log("当前调用者:", msg.sender);
        
        FeeDistributor feeDistributor = FeeDistributor(feeDistributorAddress);
        
        // 检查当前值
        uint256 currentFeeWei = feeDistributor.feeWei();
        console.log("当前 feeWei 值:", currentFeeWei);
        
        if (currentFeeWei == newFeeWei) {
            console.log("feeWei 已经是目标值，无需更新");
            return;
        }
        
        // 检查调用者是否有权限
        address owner = feeDistributor.owner();
        bool governanceModeEnabled = feeDistributor.governanceModeEnabled();
        
        console.log("合约所有者:", owner);
        console.log("治理模式是否启用:", governanceModeEnabled);
        
        if (governanceModeEnabled) {
            bytes32 PARAM_SETTER_ROLE = feeDistributor.PARAM_SETTER_ROLE();
            bool hasRole = feeDistributor.hasRole(PARAM_SETTER_ROLE, msg.sender);
            console.log("调用者是否有 PARAM_SETTER_ROLE:", hasRole);
            
            if (!hasRole && msg.sender != owner) {
                revert("调用者没有权限更新 feeWei（需要 owner 或 PARAM_SETTER_ROLE）");
            }
        } else {
            if (msg.sender != owner) {
                revert("调用者不是合约所有者");
            }
        }
        
        console.log("开始更新 feeWei...");
        
        vm.startBroadcast();
        
        // 调用 setFeeWei
        feeDistributor.setFeeWei(newFeeWei);
        
        vm.stopBroadcast();
        
        // 验证更新
        uint256 updatedFeeWei = feeDistributor.feeWei();
        console.log("更新后的 feeWei 值:", updatedFeeWei);
        
        if (updatedFeeWei == newFeeWei) {
            console.log("✅ feeWei 更新成功！");
        } else {
            revert("❌ feeWei 更新失败！");
        }
    }
}

