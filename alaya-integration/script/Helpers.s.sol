// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {FeeDistributor} from "../src/FeeDistributor.sol";
import {Interaction} from "../src/Interaction.sol";
import {AIOERC20} from "../src/AIOERC20.sol";
import {GovernanceBootstrapper} from "../src/governance/GovernanceBootstrapper.sol";

/**
 * @title HelperScripts
 * @notice Utility scripts for post-deployment operations
 */
contract HelperScripts is Script {
    /**
     * @notice Enables governance mode for deployed contracts
     * @dev Set SAFE_MULTISIG and PARAM_SETTER_ADDRESS in environment
     */
    function enableGovernance() public {
        address safeMultisig = vm.envAddress("SAFE_MULTISIG");
        address paramSetter = vm.envAddress("PARAM_SETTER_ADDRESS");
        address feeDistributorAddr = vm.envAddress("FEE_DISTRIBUTOR_ADDRESS");
        address interactionAddr = vm.envAddress("INTERACTION_ADDRESS");

        FeeDistributor fd = FeeDistributor(payable(feeDistributorAddr));
        Interaction interaction = Interaction(payable(interactionAddr));

        vm.startBroadcast();

        fd.enableGovernanceMode(safeMultisig, paramSetter);
        console.log("FeeDistributor governance enabled");

        interaction.enableGovernanceMode(safeMultisig, paramSetter);
        console.log("Interaction governance enabled");

        vm.stopBroadcast();
    }

    /**
     * @notice Uses GovernanceBootstrapper to enable governance in one transaction
     * @dev Set all required addresses in environment (SAFE_MULTISIG)
     */
    function bootstrapGovernance() public {
        address safeMultisig = vm.envAddress("SAFE_MULTISIG");
        address paramSetter = vm.envAddress("PARAM_SETTER_ADDRESS");
        address feeDistributorAddr = vm.envAddress("FEE_DISTRIBUTOR_ADDRESS");
        address interactionAddr = vm.envAddress("INTERACTION_ADDRESS");
        address bootstrapperAddr = vm.envAddress("BOOTSTRAPPER_ADDRESS");

        GovernanceBootstrapper bootstrapper = GovernanceBootstrapper(
            payable(bootstrapperAddr)
        );

        vm.startBroadcast();

        bootstrapper.bootstrapBoth(
            feeDistributorAddr,
            interactionAddr,
            safeMultisig,
            paramSetter
        );

        console.log("Governance bootstrapped for both contracts");

        vm.stopBroadcast();
    }

    /**
     * @notice Updates project wallet address
     * @dev Requires caller to have PARAM_SETTER_ROLE or be owner
     */
    function updateProjectWallet() public {
        address feeDistributorAddr = vm.envAddress("FEE_DISTRIBUTOR_ADDRESS");
        address newWallet = vm.envAddress("NEW_PROJECT_WALLET");

        FeeDistributor fd = FeeDistributor(payable(feeDistributorAddr));

        vm.startBroadcast();
        fd.setProjectWallet(newWallet);
        console.log("Project wallet updated to:", newWallet);
        vm.stopBroadcast();
    }

    /**
     * @notice Updates minimum fee
     * @dev Requires caller to have PARAM_SETTER_ROLE or be owner
     */
    function updateFee() public {
        address feeDistributorAddr = vm.envAddress("FEE_DISTRIBUTOR_ADDRESS");
        uint256 newFee = vm.envUint("NEW_FEE_WEI");

        FeeDistributor fd = FeeDistributor(payable(feeDistributorAddr));

        vm.startBroadcast();
        fd.setFeeWei(newFee);
        console.log("Fee updated to:", newFee);
        vm.stopBroadcast();
    }

    /**
     * @notice Adds an action to the Interaction allowlist
     * @dev Requires caller to have PARAM_SETTER_ROLE or be owner
     */
    function addAllowedAction() public {
        address interactionAddr = vm.envAddress("INTERACTION_ADDRESS");
        string memory action = vm.envString("ALLOWED_ACTION");

        Interaction interaction = Interaction(payable(interactionAddr));

        vm.startBroadcast();
        interaction.setActionAllowlistByString(action, true);
        console.log("Action allowed:", action);
        vm.stopBroadcast();
    }
}

