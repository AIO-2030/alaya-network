// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AIOERC20} from "../src/AIOERC20.sol";
import {FeeDistributor} from "../src/FeeDistributor.sol";
import {Interaction} from "../src/Interaction.sol";
import {GovernanceBootstrapper} from "../src/governance/GovernanceBootstrapper.sol";

/**
 * @title DeployScript
 * @notice Deploys all contracts for the AIO2030 Base Proof system
 * @dev Reads configuration from environment variables or uses defaults
 * 
 * IMPORTANT: All contracts are deployed with Safe multisig as the owner in the constructor.
 * No transferOwnership is needed after deployment as ownership is set correctly during deployment.
 * 
 * Before mainnet deployment:
 * 1. Ensure SAFE_MULTISIG environment variable is set to the correct Safe multisig address
 * 2. Verify the Safe multisig address is correct on the target network
 * 3. All contracts (AIOERC20, FeeDistributor, Interaction) will be owned by Safe multisig from deployment
 */
contract DeployScript is Script {
    // Deployment addresses (will be populated during deployment)
    AIOERC20 public aioToken;
    FeeDistributor public feeDistributor;
    Interaction public interaction;
    GovernanceBootstrapper public bootstrapper;

    // Configuration constants (can be overridden via environment variables)
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18; // 1 billion tokens
    uint256 public constant INITIAL_FEE_WEI = 1e15; // 0.001 ETH

    function run() public {
        // Get deployer address
        address deployer = msg.sender;
        
        // Get configuration from environment or use defaults
        address projectWallet = vm.envOr("PROJECT_WALLET", address(0x100));
        address safeMultisig = vm.envOr("SAFE_MULTISIG", address(0));
        address usdtToken = vm.envOr("USDT_TOKEN", address(0));
        uint256 maxSupply = vm.envOr("MAX_SUPPLY", MAX_SUPPLY);
        uint256 feeWei = vm.envOr("FEE_WEI", INITIAL_FEE_WEI);

        require(projectWallet != address(0), "PROJECT_WALLET cannot be zero");
        require(safeMultisig != address(0), "SAFE_MULTISIG must be set (cannot be zero address)");
        require(usdtToken != address(0), "USDT_TOKEN must be set");
        
        console.log("=== Deployment Configuration ===");
        console.log("Deployer:", deployer);
        console.log("Safe Multisig (Owner - ALL CONTRACTS):", safeMultisig);
        console.log("Project Wallet:", projectWallet);
        console.log("================================");
        console.log("NOTE: All contracts will be owned by Safe multisig from deployment.");
        console.log("No transferOwnership needed - owner is set in constructor.");

        vm.startBroadcast(deployer);

        // 1. Deploy AIOERC20 token with Safe multisig as owner
        // Owner is set directly in constructor - no transferOwnership needed
        console.log("Deploying AIOERC20...");
        aioToken = new AIOERC20(maxSupply, safeMultisig);
        console.log("AIOERC20 deployed at:", address(aioToken));
        console.log("AIOERC20 owner (from constructor):", aioToken.owner());

        // 2. Deploy FeeDistributor with Safe multisig as owner
        // Owner is set directly in constructor - no transferOwnership needed
        console.log("Deploying FeeDistributor...");
        feeDistributor = new FeeDistributor(
            projectWallet,
            feeWei,
            usdtToken,
            address(aioToken),
            safeMultisig // Owner set to Safe multisig in constructor
        );
        console.log("FeeDistributor deployed at:", address(feeDistributor));
        console.log("FeeDistributor owner (from constructor):", feeDistributor.owner());

        // 3. Deploy Interaction contract with Safe multisig as owner
        // Owner is set directly in constructor - no transferOwnership needed
        console.log("Deploying Interaction...");
        interaction = new Interaction(address(feeDistributor), safeMultisig);
        console.log("Interaction deployed at:", address(interaction));
        console.log("Interaction owner (from constructor):", interaction.owner());

        // 4. Deploy GovernanceBootstrapper (stateless helper contract, no owner)
        console.log("Deploying GovernanceBootstrapper...");
        bootstrapper = new GovernanceBootstrapper();
        console.log("GovernanceBootstrapper deployed at:", address(bootstrapper));
        console.log("GovernanceBootstrapper is stateless (no owner)");
        
        // 5. Verify all contract ownerships match Safe multisig
        // All contracts should be owned by Safe multisig from constructor
        console.log("\n=== Ownership Verification ===");
        require(aioToken.owner() == safeMultisig, "AIOERC20 owner mismatch - expected Safe multisig");
        require(feeDistributor.owner() == safeMultisig, "FeeDistributor owner mismatch - expected Safe multisig");
        require(interaction.owner() == safeMultisig, "Interaction owner mismatch - expected Safe multisig");
        console.log("[OK] All contracts owned by Safe multisig:", safeMultisig);
        console.log("[OK] No transferOwnership needed - ownership set in constructor");
        console.log("=============================");

        vm.stopBroadcast();

        // Output deployment addresses as JSON
        _logDeploymentAddresses();
    }

    /**
     * @notice Logs deployment addresses in JSON format for easy parsing
     */
    function _logDeploymentAddresses() internal {
        string memory json = string.concat(
            "{\n",
            '  "aioToken": "', vm.toString(address(aioToken)), '",\n',
            '  "feeDistributor": "', vm.toString(address(feeDistributor)), '",\n',
            '  "interaction": "', vm.toString(address(interaction)), '",\n',
            '  "governanceBootstrapper": "', vm.toString(address(bootstrapper)), '",\n',
            '  "safeMultisig": "', vm.toString(aioToken.owner()), '",\n',
            '  "network": "', vm.envOr("DEPLOY_NETWORK", string("unknown")), '"\n',
            "}\n"
        );
        
        console.log("=== Deployment Addresses ===");
        console.log(json);
        console.log("=== End Deployment Addresses ===");
    }
}

