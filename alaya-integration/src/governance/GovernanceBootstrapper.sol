// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {FeeDistributor} from "../FeeDistributor.sol";
import {Interaction} from "../Interaction.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title GovernanceBootstrapper
 * @notice Helper contract to bootstrap governance roles for FeeDistributor and Interaction contracts
 * @dev This contract helps set up roles in a single transaction by calling enableGovernanceMode on both contracts
 *      IMPORTANT: The caller must be the owner of the contract being bootstrapped. This contract
 *      cannot bypass the onlyOwner modifier, so it simply provides a convenience wrapper.
 */
contract GovernanceBootstrapper {
    /// @notice Emitted when governance is bootstrapped for a contract
    /// @param contractAddress The contract that was bootstrapped
    /// @param timelock The timelock address that received DEFAULT_ADMIN_ROLE
    /// @param paramSetter The paramSetter address that received PARAM_SETTER_ROLE
    event GovernanceBootstrapped(
        address indexed contractAddress,
        address indexed timelock,
        address indexed paramSetter
    );

    /**
     * @notice Bootstrap governance for FeeDistributor
     * @param feeDistributor Address of the FeeDistributor contract
     * @param timelock Address of the TimelockController (or Safe multisig)
     * @param paramSetter Address that can set parameters
     * @dev This function should be called by the owner of FeeDistributor.
     *      IMPORTANT: The owner must first call setTrustedBootstrapper(address(this)) on FeeDistributor
     *      before calling this function. This allows the bootstrapper to call enableGovernanceMode.
     */
    function bootstrapFeeDistributor(
        address feeDistributor,
        address timelock,
        address paramSetter
    ) external {
        // Verify that this bootstrapper is set as trusted
        FeeDistributor fd = FeeDistributor(payable(feeDistributor));
        if (fd.trustedBootstrapper() != address(this)) {
            revert("GovernanceBootstrapper: not set as trusted bootstrapper. Owner must call setTrustedBootstrapper(address(this)) first");
        }
        
        // Verify caller is the owner (bootstrapper validates this to ensure only owner can bootstrap)
        if (Ownable(feeDistributor).owner() != msg.sender) {
            revert("GovernanceBootstrapper: caller is not the owner");
        }
        
        _bootstrapFeeDistributor(feeDistributor, timelock, paramSetter);
    }

    /**
     * @notice Bootstrap governance for Interaction
     * @param interaction Address of the Interaction contract
     * @param timelock Address of the TimelockController (or Safe multisig)
     * @param paramSetter Address that can set allowlist
     * @dev This function should be called by the owner of Interaction.
     *      IMPORTANT: The owner must first call setTrustedBootstrapper(address(this)) on Interaction
     *      before calling this function. This allows the bootstrapper to call enableGovernanceMode.
     */
    function bootstrapInteraction(
        address interaction,
        address timelock,
        address paramSetter
    ) external {
        // Verify that this bootstrapper is set as trusted
        Interaction it = Interaction(interaction);
        if (it.trustedBootstrapper() != address(this)) {
            revert("GovernanceBootstrapper: not set as trusted bootstrapper. Owner must call setTrustedBootstrapper(address(this)) first");
        }
        
        // Verify caller is the owner
        if (Ownable(interaction).owner() != msg.sender) {
            revert("GovernanceBootstrapper: caller is not the owner");
        }
        
        _bootstrapInteraction(interaction, timelock, paramSetter);
    }

    /**
     * @notice Internal helper to bootstrap FeeDistributor
     * @dev Calls enableGovernanceMode directly. Note: This will only work if the caller
     *      is the owner of the FeeDistributor contract, as enableGovernanceMode has onlyOwner modifier.
     *      The bootstrapper acts as a convenience wrapper that validates ownership and emits events.
     */
    function _bootstrapFeeDistributor(
        address feeDistributor,
        address timelock,
        address paramSetter
    ) internal {
        // Direct call - msg.sender (bootstrapper) will be checked by onlyOwner modifier
        // This means the caller must have set this bootstrapper as owner, or we need a different approach
        // For now, we require that the caller is the owner and call directly
        // The limitation is that bootstrapper cannot truly bypass onlyOwner without contract modifications
        FeeDistributor(payable(feeDistributor)).enableGovernanceMode(timelock, paramSetter);
        
        emit GovernanceBootstrapped(feeDistributor, timelock, paramSetter);
    }

    /**
     * @notice Internal helper to bootstrap Interaction
     * @dev Calls enableGovernanceMode directly. See _bootstrapFeeDistributor for limitations.
     */
    function _bootstrapInteraction(
        address interaction,
        address timelock,
        address paramSetter
    ) internal {
        Interaction(interaction).enableGovernanceMode(timelock, paramSetter);
        
        emit GovernanceBootstrapped(interaction, timelock, paramSetter);
    }

    /**
     * @notice Bootstrap both contracts in one transaction
     * @param feeDistributor Address of the FeeDistributor contract
     * @param interaction Address of the Interaction contract
     * @param timelock Address of the TimelockController (or Safe multisig)
     * @param paramSetter Address that can set parameters
     * @dev This function should be called by the owners of both contracts (can be same owner).
     *      IMPORTANT: The owner must first call setTrustedBootstrapper(address(this)) on both contracts
     *      before calling this function. This allows the bootstrapper to call enableGovernanceMode.
     *      After the first enableGovernanceMode call, ownership is transferred, but both trustedBootstrapper
     *      are already set, so the second call will succeed.
     */
    function bootstrapBoth(
        address feeDistributor,
        address interaction,
        address timelock,
        address paramSetter
    ) external {
        // Verify that this bootstrapper is set as trusted for both contracts
        FeeDistributor fd = FeeDistributor(payable(feeDistributor));
        Interaction it = Interaction(interaction);
        
        if (fd.trustedBootstrapper() != address(this)) {
            revert("GovernanceBootstrapper: not set as trusted bootstrapper for FeeDistributor");
        }
        if (it.trustedBootstrapper() != address(this)) {
            revert("GovernanceBootstrapper: not set as trusted bootstrapper for Interaction");
        }
        
        // Verify caller is the owner of both contracts
        if (Ownable(feeDistributor).owner() != msg.sender) {
            revert("GovernanceBootstrapper: caller is not the owner of FeeDistributor");
        }
        if (Ownable(interaction).owner() != msg.sender) {
            revert("GovernanceBootstrapper: caller is not the owner of Interaction");
        }
        
        // Call both - note that after first call, ownership transfers, but trustedBootstrapper
        // is already set so the second call will succeed
        _bootstrapFeeDistributor(feeDistributor, timelock, paramSetter);
        _bootstrapInteraction(interaction, timelock, paramSetter);
    }
}

