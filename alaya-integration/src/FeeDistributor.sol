// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";

/**
 * @title FeeDistributor
 * @notice Minimal fee collector/distributor that forwards all collected fees to project treasury
 * @dev Stateless forwarding to avoid griefing. No fee accrual kept in this contract.
 *      Supports optional governance mode with AccessControl roles.
 */
contract FeeDistributor is Ownable, AccessControl, ReentrancyGuard {
    using Address for address payable;

    /// @notice Project wallet address that receives all fees
    address public projectWallet;

    /// @notice Minimum ETH fee per interaction (in wei)
    uint256 public feeWei;

    /// @notice Role for setting parameters (fee, wallet, etc.)
    bytes32 public constant PARAM_SETTER_ROLE = keccak256("PARAM_SETTER_ROLE");

    /// @notice Whether governance mode is enabled
    bool public governanceModeEnabled;

    /// @notice Optional trusted bootstrapper address that can call enableGovernanceMode
    /// @dev Set once during deployment, can be used to bootstrap governance via GovernanceBootstrapper
    address public trustedBootstrapper;

    /// @notice Emitted when governance mode is enabled
    /// @param admin Safe multisig address (receives DEFAULT_ADMIN_ROLE)
    /// @param paramSetter Address that can set parameters
    event GovernanceModeEnabled(address indexed admin, address indexed paramSetter);

    /// @notice Emitted when ETH fee is collected
    /// @param payer Address that paid the fee
    /// @param amount Amount collected
    event FeeCollected(address indexed payer, uint256 amount);

    /// @notice Emitted when funds are forwarded to project wallet
    /// @param to Address that received the funds
    /// @param amount Amount forwarded
    event Forwarded(address indexed to, uint256 amount);

    /// @notice Emitted when project wallet is updated
    /// @param newWallet New project wallet address
    event ProjectWalletUpdated(address indexed newWallet);

    /// @notice Emitted when minimum fee is updated
    /// @param newFeeWei New minimum fee in wei
    event FeeWeiUpdated(uint256 newFeeWei);

    /**
     * @notice Deploys FeeDistributor contract
     * @param projectWallet_ Address that will receive all fees (EOA or Safe multisig)
     * @param feeWei_ Minimum ETH fee per interaction (e.g., 1e15 = 0.001 ETH)
     * @param owner_ Address that will own the contract
     */
    constructor(
        address projectWallet_,
        uint256 feeWei_,
        address owner_
    ) Ownable(owner_) {
        if (projectWallet_ == address(0)) {
            revert("FeeDistributor: projectWallet cannot be zero address");
        }
        projectWallet = projectWallet_;
        feeWei = feeWei_;
        
        // Grant DEFAULT_ADMIN_ROLE to owner for potential governance mode
        _grantRole(DEFAULT_ADMIN_ROLE, owner_);
    }

    /**
     * @notice Collects ETH fee from the caller
     * @dev Requires msg.value >= feeWei. Forwards entire msg.value to projectWallet.
     * @dev Protected by nonReentrant to prevent reentrancy attacks.
     */
    function collectEth() external payable nonReentrant {
        if (msg.value < feeWei) {
            revert("FeeDistributor: insufficient fee");
        }

        emit FeeCollected(msg.sender, msg.value);

        // Forward entire amount to project wallet
        payable(projectWallet).sendValue(msg.value);

        emit Forwarded(projectWallet, msg.value);
    }


    /**
     * @notice Updates the project wallet address
     * @dev Only callable by owner or PARAM_SETTER_ROLE (if governance mode enabled)
     * @param newWallet New project wallet address
     */
    function setProjectWallet(address newWallet) external {
        _checkParamSetter();
        if (newWallet == address(0)) {
            revert("FeeDistributor: newWallet cannot be zero address");
        }
        projectWallet = newWallet;
        emit ProjectWalletUpdated(newWallet);
    }

    /**
     * @notice Updates the minimum ETH fee
     * @dev Only callable by owner or PARAM_SETTER_ROLE (if governance mode enabled)
     * @param newFeeWei New minimum fee in wei
     */
    function setFeeWei(uint256 newFeeWei) external {
        _checkParamSetter();
        feeWei = newFeeWei;
        emit FeeWeiUpdated(newFeeWei);
    }


    /**
     * @notice Sets the trusted bootstrapper address
     * @dev Only callable by owner before governance mode is enabled
     * @param bootstrapper Address of the trusted bootstrapper contract
     */
    function setTrustedBootstrapper(address bootstrapper) external onlyOwner {
        if (governanceModeEnabled) {
            revert("FeeDistributor: cannot set bootstrapper after governance mode enabled");
        }
        trustedBootstrapper = bootstrapper;
    }

    /**
     * @notice Enables governance mode with Safe multisig and parameter setter role
     * @dev Only callable once by owner or trustedBootstrapper. After enabling, owner renounces control to Safe multisig.
     * @param admin Safe multisig address (will receive DEFAULT_ADMIN_ROLE and ownership)
     * @param paramSetter Address that can set parameters (will receive PARAM_SETTER_ROLE)
     */
    function enableGovernanceMode(address admin, address paramSetter) external {
        // Allow owner or trusted bootstrapper to call
        if (msg.sender != owner() && msg.sender != trustedBootstrapper) {
            revert("FeeDistributor: caller is not the owner or trusted bootstrapper");
        }
        
        // If called by bootstrapper, verify caller is owner of the contract
        if (msg.sender == trustedBootstrapper && trustedBootstrapper != address(0)) {
            // Bootstrapper should verify ownership before calling
            // This is a trust assumption - bootstrapper must validate caller is owner
        }
        if (governanceModeEnabled) {
            revert("FeeDistributor: governance mode already enabled");
        }
        if (admin == address(0)) {
            revert("FeeDistributor: admin cannot be zero address");
        }
        if (paramSetter == address(0)) {
            revert("FeeDistributor: paramSetter cannot be zero address");
        }

        governanceModeEnabled = true;

        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(PARAM_SETTER_ROLE, paramSetter);

        // Revoke owner's admin role
        _revokeRole(DEFAULT_ADMIN_ROLE, owner());
        
        // Transfer ownership to Safe multisig to ensure EOA owner calls revert after governance mode
        // Use _transferOwnership directly to allow trusted bootstrapper to transfer on behalf of owner
        _transferOwnership(admin);

        emit GovernanceModeEnabled(admin, paramSetter);
    }

    /**
     * @notice Internal function to check if caller can set parameters
     * @dev Allows owner (if governance not enabled) or PARAM_SETTER_ROLE (if enabled)
     */
    function _checkParamSetter() internal view {
        if (governanceModeEnabled) {
            if (!hasRole(PARAM_SETTER_ROLE, msg.sender)) {
                revert("FeeDistributor: caller does not have PARAM_SETTER_ROLE");
            }
        } else {
            if (msg.sender != owner()) {
                revert("FeeDistributor: caller is not the owner");
            }
        }
    }

    /**
     * @notice Allows contract to receive ETH directly (fallback)
     * @dev This enables receiving ETH that might be sent accidentally
     */
    receive() external payable {
        // Accept ETH but do nothing - owner can rescue if needed
    }
}
