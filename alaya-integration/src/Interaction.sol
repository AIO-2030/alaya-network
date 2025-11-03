// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IFeeDistributor} from "./interfaces/IFeeDistributor.sol";

/**
 * @title Interaction
 * @notice Lightweight on-chain "Proof of Interaction" contract
 * @dev Records verifiable interaction events and pipes fees to FeeDistributor
 */
contract Interaction is Ownable, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice FeeDistributor contract address (immutable)
    IFeeDistributor public immutable feeDistributor;

    /// @notice Flag to enable/disable action allowlist feature
    bool public allowlistEnabled;

    /// @notice Mapping from action hash to allowlist status
    mapping(bytes32 => bool) public actionAllowlist;

    /// @notice Role for setting allowlist parameters
    bytes32 public constant PARAM_SETTER_ROLE = keccak256("PARAM_SETTER_ROLE");

    /// @notice Whether governance mode is enabled
    bool public governanceModeEnabled;

    /// @notice Optional trusted bootstrapper address that can call enableGovernanceMode
    /// @dev Set once during deployment, can be used to bootstrap governance via GovernanceBootstrapper
    address public trustedBootstrapper;

    /// @notice Emitted when an interaction is recorded
    /// @param user Address that performed the interaction
    /// @param actionHash Hash of the action string (keccak256(bytes(action))) - indexed for Dune filtering
    /// @param action Action string identifier
    /// @param meta Opaque metadata blob
    /// @param timestamp Block timestamp of the interaction
    event InteractionRecorded(
        address indexed user,
        bytes32 indexed actionHash,
        string action,
        bytes meta,
        uint256 timestamp
    );

    /// @notice Emitted when action allowlist is enabled/disabled
    /// @param enabled New allowlist status
    event AllowlistToggled(bool enabled);

    /// @notice Emitted when an action is added/removed from allowlist
    /// @param actionHash Hash of the action string
    /// @param allowed Whether the action is now allowed
    event ActionAllowlistUpdated(bytes32 indexed actionHash, bool allowed);

    /// @notice Emitted when governance mode is enabled
    /// @param timelock TimelockController or Safe multisig address
    /// @param paramSetter Address that can set parameters
    event GovernanceModeEnabled(address indexed timelock, address indexed paramSetter);

    /**
     * @notice Deploys Interaction contract
     * @param feeDistributor_ Address of the FeeDistributor contract
     * @param owner_ Address that will own the contract
     */
    constructor(address feeDistributor_, address owner_) Ownable(owner_) {
        if (feeDistributor_ == address(0)) {
            revert("Interaction: feeDistributor cannot be zero address");
        }
        feeDistributor = IFeeDistributor(feeDistributor_);
        
        // Grant DEFAULT_ADMIN_ROLE to owner for potential governance mode
        _grantRole(DEFAULT_ADMIN_ROLE, owner_);
    }

    /**
     * @notice Records an interaction with ETH fee payment
     * @param action Action string identifier
     * @param meta Opaque metadata blob
     * @dev Requires msg.value >= feeWei(). Forwards ETH to FeeDistributor.
     *      Protected by nonReentrant to prevent reentrancy attacks.
     */
    function interact(string calldata action, bytes calldata meta)
        external
        payable
        nonReentrant
    {
        // Check fee requirement upfront to save gas downstream
        uint256 requiredFee = feeDistributor.feeWei();
        if (msg.value < requiredFee) {
            revert("Interaction: insufficient fee");
        }

        // Calculate action hash for event emission and allowlist check
        bytes32 actionHash = keccak256(bytes(action));

        // Check allowlist if enabled
        if (allowlistEnabled) {
            if (!actionAllowlist[actionHash]) {
                revert("Interaction: action not allowed");
            }
        }

        // Forward ETH to FeeDistributor
        feeDistributor.collectEth{value: msg.value}();

        // Emit interaction event with indexed actionHash for Dune Analytics filtering
        emit InteractionRecorded(msg.sender, actionHash, action, meta, block.timestamp);
    }

    /**
     * @notice Records an interaction with ERC20 token fee payment
     * @param token The ERC20 token address
     * @param amount Amount of tokens to pay as fee
     * @param action Action string identifier
     * @param meta Opaque metadata blob
     * @dev User must approve this contract beforehand. Protected by nonReentrant.
     */
    function interact20(
        address token,
        uint256 amount,
        string calldata action,
        bytes calldata meta
    ) external nonReentrant {
        if (token == address(0)) {
            revert("Interaction: token cannot be zero address");
        }
        if (amount == 0) {
            revert("Interaction: amount cannot be zero");
        }

        // Calculate action hash for event emission and allowlist check
        bytes32 actionHash = keccak256(bytes(action));

        // Check allowlist if enabled
        if (allowlistEnabled) {
            if (!actionAllowlist[actionHash]) {
                revert("Interaction: action not allowed");
            }
        }

        // Pull tokens from user to this contract
        IERC20 tokenContract = IERC20(token);
        tokenContract.safeTransferFrom(msg.sender, address(this), amount);

        // Approve FeeDistributor to pull tokens from this contract
        // Note: We reset approval first to handle tokens that require zero allowance first
        tokenContract.approve(address(feeDistributor), 0);
        tokenContract.approve(address(feeDistributor), amount);

        // Forward ERC20 tokens to FeeDistributor
        // FeeDistributor will pull from this contract and forward to projectWallet
        feeDistributor.collectErc20(token, amount);

        // Emit interaction event with indexed actionHash for Dune Analytics filtering
        emit InteractionRecorded(msg.sender, actionHash, action, meta, block.timestamp);
    }

    /**
     * @notice Returns configuration information
     * @return feeWei_ The minimum ETH fee in wei
     * @return feeDistributor_ The FeeDistributor contract address
     * @return allowlistEnabled_ Whether allowlist is currently enabled
     */
    function getConfig()
        external
        view
        returns (
            uint256 feeWei_,
            address feeDistributor_,
            bool allowlistEnabled_
        )
    {
        return (
            feeDistributor.feeWei(),
            address(feeDistributor),
            allowlistEnabled
        );
    }

    /**
     * @notice Enables or disables the action allowlist feature
     * @dev Only callable by owner or PARAM_SETTER_ROLE (if governance mode enabled)
     * @param enabled Whether to enable the allowlist
     */
    function setAllowlistEnabled(bool enabled) external {
        _checkParamSetter();
        allowlistEnabled = enabled;
        emit AllowlistToggled(enabled);
    }

    /**
     * @notice Adds or removes an action from the allowlist
     * @dev Only callable by owner or PARAM_SETTER_ROLE (if governance mode enabled). Action should be hashed before calling.
     * @param actionHash Hash of the action string (keccak256(bytes(action)))
     * @param allowed Whether the action should be allowed
     */
    function setActionAllowlist(bytes32 actionHash, bool allowed)
        external
    {
        _checkParamSetter();
        actionAllowlist[actionHash] = allowed;
        emit ActionAllowlistUpdated(actionHash, allowed);
    }

    /**
     * @notice Convenience function to set action allowlist by string
     * @dev Only callable by owner or PARAM_SETTER_ROLE (if governance mode enabled)
     * @param action The action string to allow/deny
     * @param allowed Whether the action should be allowed
     */
    function setActionAllowlistByString(string calldata action, bool allowed)
        external
    {
        _checkParamSetter();
        bytes32 actionHash = keccak256(bytes(action));
        actionAllowlist[actionHash] = allowed;
        emit ActionAllowlistUpdated(actionHash, allowed);
    }

    /**
     * @notice Sets the trusted bootstrapper address
     * @dev Only callable by owner before governance mode is enabled
     * @param bootstrapper Address of the trusted bootstrapper contract
     */
    function setTrustedBootstrapper(address bootstrapper) external onlyOwner {
        if (governanceModeEnabled) {
            revert("Interaction: cannot set bootstrapper after governance mode enabled");
        }
        trustedBootstrapper = bootstrapper;
    }

    /**
     * @notice Enables governance mode with timelock and parameter setter role
     * @dev Only callable once by owner or trustedBootstrapper. After enabling, owner renounces control to timelock/admin.
     * @param timelock TimelockController or Safe multisig address (will receive DEFAULT_ADMIN_ROLE)
     * @param paramSetter Address that can set parameters (will receive PARAM_SETTER_ROLE)
     */
    function enableGovernanceMode(address timelock, address paramSetter) external {
        // Allow owner or trusted bootstrapper to call
        if (msg.sender != owner() && msg.sender != trustedBootstrapper) {
            revert("Interaction: caller is not the owner or trusted bootstrapper");
        }
        
        // If called by bootstrapper, bootstrapper should verify caller is owner before calling
        if (governanceModeEnabled) {
            revert("Interaction: governance mode already enabled");
        }
        if (timelock == address(0)) {
            revert("Interaction: timelock cannot be zero address");
        }
        if (paramSetter == address(0)) {
            revert("Interaction: paramSetter cannot be zero address");
        }

        governanceModeEnabled = true;

        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, timelock);
        _grantRole(PARAM_SETTER_ROLE, paramSetter);

        // Revoke owner's admin role
        _revokeRole(DEFAULT_ADMIN_ROLE, owner());
        
        // Transfer ownership to timelock to ensure EOA owner calls revert after governance mode
        // Use _transferOwnership directly to allow trusted bootstrapper to transfer on behalf of owner
        _transferOwnership(timelock);

        emit GovernanceModeEnabled(timelock, paramSetter);
    }

    /**
     * @notice Internal function to check if caller can set parameters
     * @dev Allows owner (if governance not enabled) or PARAM_SETTER_ROLE (if enabled)
     */
    function _checkParamSetter() internal view {
        if (governanceModeEnabled) {
            if (!hasRole(PARAM_SETTER_ROLE, msg.sender)) {
                revert("Interaction: caller does not have PARAM_SETTER_ROLE");
            }
        } else {
            if (msg.sender != owner()) {
                revert("Interaction: caller is not the owner");
            }
        }
    }
}

