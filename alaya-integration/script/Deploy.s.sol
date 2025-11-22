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
    uint256 public constant MAX_SUPPLY = 2_100_000_000 * 1e8; // 2.1 billion tokens (8 decimals)
    uint256 public constant INITIAL_FEE_WEI = 1; // 0.003 ETH
    uint256 public constant INITIAL_MINT_AMOUNT = 100_000_000 * 1e8; // 210 million tokens (8 decimals)

    function run() public {
        // Get deployer address
        address deployer = msg.sender;
        
        // Get configuration from environment or use defaults
        address projectWallet = vm.envOr("PROJECT_WALLET", address(0x100));
        address safeMultisig = vm.envOr("SAFE_MULTISIG", address(0));
        uint256 maxSupply = vm.envOr("MAX_SUPPLY", MAX_SUPPLY);
        uint256 feeWei = vm.envOr("FEE_WEI", INITIAL_FEE_WEI);

        require(projectWallet != address(0), "PROJECT_WALLET cannot be zero");
        require(safeMultisig != address(0), "SAFE_MULTISIG must be set (cannot be zero address)");
        
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

        // 1.1. Initial mint is NOT performed here
        // IMPORTANT: vm.prank() does NOT work in broadcast mode - it only works in test/simulation
        // The actual transaction sender is still the deployer, not the Safe multisig
        // Therefore, mint must be performed separately through Safe multisig after deployment
        console.log("\n=== IMPORTANT: Initial Mint Required ===");
        console.log("Initial mint is NOT performed during deployment.");
        console.log("After deployment, you MUST mint tokens through Safe multisig:");
        console.log("  1. Go to Safe multisig interface");
        console.log("  2. Create a new transaction");
        console.log("  3. Call: aioToken.mint(projectWallet, amount)");
        console.log("  4. Or use Mint.s.sol script with Safe multisig private key");
        console.log("Token Address:", address(aioToken));
        console.log("Project Wallet:", projectWallet);
        console.log("Recommended Initial Mint Amount (without decimals):", INITIAL_MINT_AMOUNT / 1e8);
        console.log("========================================\n");

        // 2. Deploy FeeDistributor with Safe multisig as owner
        // Owner is set directly in constructor - no transferOwnership needed
        console.log("Deploying FeeDistributor...");
        feeDistributor = new FeeDistributor(
            projectWallet,
            feeWei,
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
     * @notice Deploys all contracts to local test network with simplified configuration
     * @dev This function is designed for local testing (Anvil, Hardhat, etc.)
     *      - Uses deployer address as owner and projectWallet
     *      - Uses smaller test values
     *      - No environment variables required
     * 
     * Usage:
     *   forge script script/Deploy.s.sol:DeployScript --sig "deployLocal()" --rpc-url http://localhost:8545 --broadcast
     */
    function deployLocal() public {
        // Get deployer address (will be used as owner and projectWallet for local testing)
        address deployer = msg.sender;
        
        // Local test configuration
        uint256 maxSupply = 1_000_000 * 1e8; // 1 million tokens for testing (8 decimals)
        uint256 feeWei = 1e14; // 0.0001 ETH for testing
        uint256 initialMintAmount = 2100 * 1e8; // 2100 tokens for local testing (8 decimals)
        
        console.log("=== Local Test Network Deployment ===");
        console.log("Deployer (Owner & Project Wallet):", deployer);
        console.log("Max Supply:", maxSupply);
        console.log("Fee Wei:", feeWei);
        console.log("=====================================");

        vm.startBroadcast(deployer);

        // 1. Deploy AIOERC20 token with deployer as owner
        console.log("Deploying AIOERC20...");
        aioToken = new AIOERC20(maxSupply, deployer);
        console.log("AIOERC20 deployed at:", address(aioToken));
        console.log("AIOERC20 owner:", aioToken.owner());

        // 1.1. Mint initial tokens
        console.log("Minting initial tokens...");
        aioToken.mint(deployer, initialMintAmount);
        console.log("Minted", initialMintAmount / 1e8, "tokens to deployer:", deployer);

        // 3. Deploy FeeDistributor with deployer as owner and projectWallet
        console.log("Deploying FeeDistributor...");
        feeDistributor = new FeeDistributor(
            deployer, // projectWallet
            feeWei,
            deployer // owner
        );
        console.log("FeeDistributor deployed at:", address(feeDistributor));
        console.log("FeeDistributor owner:", feeDistributor.owner());

        // 4. Deploy Interaction contract with deployer as owner
        console.log("Deploying Interaction...");
        interaction = new Interaction(address(feeDistributor), deployer);
        console.log("Interaction deployed at:", address(interaction));
        console.log("Interaction owner:", interaction.owner());

        // 5. Deploy GovernanceBootstrapper (stateless helper contract, no owner)
        console.log("Deploying GovernanceBootstrapper...");
        bootstrapper = new GovernanceBootstrapper();
        console.log("GovernanceBootstrapper deployed at:", address(bootstrapper));

        vm.stopBroadcast();

        // Output deployment addresses as JSON
        _logLocalDeploymentAddresses();
    }

    /**
     * @notice Logs deployment addresses in JSON format for local deployment
     */
    function _logLocalDeploymentAddresses() internal view {
        string memory json = string.concat(
            "{\n",
            '  "aioToken": "', vm.toString(address(aioToken)), '",\n',
            '  "feeDistributor": "', vm.toString(address(feeDistributor)), '",\n',
            '  "interaction": "', vm.toString(address(interaction)), '",\n',
            '  "governanceBootstrapper": "', vm.toString(address(bootstrapper)), '",\n',
            '  "owner": "', vm.toString(aioToken.owner()), '",\n',
            '  "network": "local"\n',
            "}\n"
        );
        
        console.log("=== Local Deployment Addresses ===");
        console.log(json);
        console.log("=== End Local Deployment Addresses ===");
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


