// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {Interaction} from "../src/Interaction.sol";
import {FeeDistributor} from "../src/FeeDistributor.sol";

/**
 * @title DeployInteractionScript
 * @notice Deploy Interaction contract to testnet
 * @dev Reads configuration from environment variables
 * 
 * Usage:
 *   forge script script/DeployInteraction.s.sol:DeployInteractionScript --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
 * 
 * Environment Variables:
 *   - FEE_DISTRIBUTOR: FeeDistributor contract address (required)
 *   - SAFE_MULTISIG: Safe multisig address, will be set as Interaction contract owner (required)
 * 
 * Important:
 *   - Interaction contract will set Safe multisig as owner during deployment
 *   - No need to call transferOwnership after deployment
 */
contract DeployInteractionScript is Script {
    // Deployed contract addresses
    Interaction public interaction;
    FeeDistributor public feeDistributor;

    function run() public {
        // Get deployer address
        address deployer = msg.sender;
        
        // Read config from environment variables
        address feeDistributorAddr = vm.envOr("FEE_DISTRIBUTOR", address(0));
        address safeMultisig = vm.envOr("SAFE_MULTISIG", address(0));

        // Validate required parameters
        require(feeDistributorAddr != address(0), "FEE_DISTRIBUTOR cannot be zero");
        require(safeMultisig != address(0), "SAFE_MULTISIG must be set (cannot be zero address)");
        
        console.log(unicode"=== Interaction 合约部署配置 ===");
        console.log(unicode"部署者:", deployer);
        console.log(unicode"FeeDistributor 地址:", feeDistributorAddr);
        console.log(unicode"Safe Multisig (所有者):", safeMultisig);
        console.log("=================================");
        console.log(unicode"注意: Interaction 合约将直接以 Safe multisig 作为所有者部署");
        console.log(unicode"不需要在部署后调用 transferOwnership");

        vm.startBroadcast(deployer);

        // Deploy Interaction contract
        console.log("\nDeploy Interaction contract...");
        interaction = new Interaction(feeDistributorAddr, safeMultisig);
        console.log("Interaction contract deployed at:", address(interaction));
        console.log(unicode"Interaction contract owner (从构造函数):", interaction.owner());

        vm.stopBroadcast();

        // Output deployment addresses in JSON format
        _logDeploymentAddress();
    }

    /**
     * @notice Output deployment addresses in JSON format for parsing
     */
    function _logDeploymentAddress() internal {
        string memory json = string.concat(
            "{\n",
            '  "interaction": "', vm.toString(address(interaction)), '",\n',
            '  "feeDistributor": "', vm.toString(address(interaction.feeDistributor())), '",\n',
            '  "owner": "', vm.toString(interaction.owner()), '",\n',
            '  "network": "', vm.envOr("DEPLOY_NETWORK", string("unknown")), '"\n',
            "}\n"
        );
        
        console.log("=== Deployment Addresses ===");
        console.log(json);
        console.log("=== End Deployment Addresses ===");
    }

    /**
     * @notice Deploy Interaction contract到本地测试网络
     * @dev 此函数设计用于本地测试（Anvil, Hardhat 等）
     *      - 使用部署者地址作为所有者
     *      - 如果未提供 FEE_DISTRIBUTOR，会自动部署一个新的 FeeDistributor
     *      - 使用较小的测试值
     *      - 不需要环境变量（可选）
     * 
     * 使用方法:
     *   forge script script/DeployInteraction.s.sol:DeployInteractionScript --sig "deployLocal()" --rpc-url http://localhost:8545 --broadcast
     * 
     * 可选环境变量:
     *   - FEE_DISTRIBUTOR: 如果已存在 FeeDistributor 合约，使用此地址（可选）
     *   - PROJECT_WALLET: 如果部署新的 FeeDistributor，使用此地址作为Project Wallet（默认: deployer）
     *   - FEE_WEI: 如果部署新的 FeeDistributor，使用此手续费（默认: 1e14 = 0.0001 ETH）
     */
    function deployLocal() public {
        // Get deployer address（将用作所有者）
        address deployer = msg.sender;
        
        // 本地测试配置
        address projectWallet = vm.envOr("PROJECT_WALLET", deployer);
        uint256 feeWei = vm.envOr("FEE_WEI", uint256(1e14)); // 0.0001 ETH for testing
        address existingFeeDistributor = vm.envOr("FEE_DISTRIBUTOR", address(0));
        
        console.log("=== Local test network deployment ===");
        console.log("Deployer (Owner):", deployer);
        console.log("Project Wallet:", projectWallet);
        console.log("Fee (wei):", feeWei);
        console.log("=============================");

        vm.startBroadcast(deployer);

        // If FeeDistributor address not provided, deploy a new one
        if (existingFeeDistributor == address(0)) {
            console.log("\nDeploy FeeDistributor contract...");
            feeDistributor = new FeeDistributor(
                projectWallet,
                feeWei,
                deployer // owner
            );
            console.log("FeeDistributor deployed at:", address(feeDistributor));
            console.log("FeeDistributor owner:", feeDistributor.owner());
            existingFeeDistributor = address(feeDistributor);
        } else {
            console.log("\nUsing existing FeeDistributor:", existingFeeDistributor);
            // No need to assign to feeDistributor variable, we only need the address
        }

        // Deploy Interaction contract
        console.log("\nDeploy Interaction contract...");
        interaction = new Interaction(existingFeeDistributor, deployer);
        console.log("Interaction contract deployed at:", address(interaction));
        console.log("Interaction contract owner:", interaction.owner());

        vm.stopBroadcast();

        // Output deployment addresses in JSON format
        _logLocalDeploymentAddress();
    }

    /**
     * @notice Output local deployment addresses in JSON format for parsing
     */
    function _logLocalDeploymentAddress() internal {
        string memory json = string.concat(
            "{\n",
            '  "interaction": "', vm.toString(address(interaction)), '",\n',
            '  "feeDistributor": "', vm.toString(address(interaction.feeDistributor())), '",\n',
            '  "owner": "', vm.toString(interaction.owner()), '",\n',
            '  "network": "local"\n',
            "}\n"
        );
        
        console.log("=== Local deployment addresses ===");
        console.log(json);
        console.log(unicode"=== Local deployment addresses结束 ===");
    }
}

