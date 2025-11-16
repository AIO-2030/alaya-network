// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IFeeDistributor} from "./interfaces/IFeeDistributor.sol";
import {IAIOERC20} from "./interfaces/IAIOERC20.sol";

/**
 * @title Interaction
 * @notice Lightweight on-chain "Proof of Interaction" contract
 * @dev Records verifiable interaction events and pipes fees to FeeDistributor
 */
contract Interaction is Ownable, AccessControl, ReentrancyGuard {

    /// @notice FeeDistributor contract address (immutable)
    IFeeDistributor public immutable feeDistributor;

    /// @notice AIO token contract address
    IAIOERC20 public aioToken;

    /// @notice AIO reward pool address (where AIO tokens are stored for distribution)
    address public aioRewardPool;

    /// @notice Flag to enable/disable action allowlist feature
    bool public allowlistEnabled;

    /// @notice Mapping from action hash to allowlist status
    mapping(bytes32 => bool) public actionAllowlist;

    /// @notice Mapping from action hash to AIO reward amount (in wei)
    mapping(bytes32 => uint256) public actionReward;

    /// @notice Mapping to track claimed interactions: user => actionHash => timestamp => claimed
    mapping(address => mapping(bytes32 => mapping(uint256 => bool))) public claimedInteractions;

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
    /// @param admin Safe multisig address (receives DEFAULT_ADMIN_ROLE)
    /// @param paramSetter Address that can set parameters
    event GovernanceModeEnabled(address indexed admin, address indexed paramSetter);

    /// @notice Emitted when AIO tokens are claimed
    /// @param user Address that claimed the tokens
    /// @param actionHash Hash of the action string
    /// @param action Action string identifier
    /// @param amount Amount of AIO tokens claimed
    /// @param timestamp Block timestamp of the original interaction
    event AIOClaimed(
        address indexed user,
        bytes32 indexed actionHash,
        string action,
        uint256 amount,
        uint256 timestamp
    );

    /// @notice Emitted when action reward is set
    /// @param actionHash Hash of the action string
    /// @param rewardAmount New reward amount in wei
    event ActionRewardUpdated(bytes32 indexed actionHash, uint256 rewardAmount);

    /// @notice Emitted when AIO token address is set
    /// @param aioToken_ New AIO token contract address
    event AIOTokenUpdated(address indexed aioToken_);

    /// @notice Emitted when AIO reward pool address is set
    /// @param rewardPool_ New reward pool address
    event AIORewardPoolUpdated(address indexed rewardPool_);

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
     * @notice Claims AIO tokens for a completed interaction
     * @param action Action string identifier (must match the original interaction)
     * @param timestamp Block timestamp of the original interaction (from InteractionRecorded event)
     * @dev User must have completed an interaction with this action and timestamp.
     *      Each interaction can only be claimed once. Protected by nonReentrant.
     */
    function claimAIO(string calldata action, uint256 timestamp)
        external
        nonReentrant
    {
        if (address(aioToken) == address(0)) {
            revert("Interaction: AIO token not set");
        }
        if (aioRewardPool == address(0)) {
            revert("Interaction: AIO reward pool not set");
        }

        bytes32 actionHash = keccak256(bytes(action));
        uint256 rewardAmount = actionReward[actionHash];

        if (rewardAmount == 0) {
            revert("Interaction: no reward configured for this action");
        }

        // Check if already claimed
        if (claimedInteractions[msg.sender][actionHash][timestamp]) {
            revert("Interaction: already claimed");
        }

        // Mark as claimed before external call (reentrancy protection)
        claimedInteractions[msg.sender][actionHash][timestamp] = true;

        // Transfer AIO tokens from reward pool to user
        bool success = aioToken.transferFrom(aioRewardPool, msg.sender, rewardAmount);
        if (!success) {
            revert("Interaction: AIO transfer failed");
        }

        emit AIOClaimed(msg.sender, actionHash, action, rewardAmount, timestamp);
    }


    /**
     * @notice Returns configuration information
     * @return feeWei_ The minimum ETH fee in wei
     * @return feeDistributor_ The FeeDistributor contract address
     * @return allowlistEnabled_ Whether allowlist is currently enabled
     * @return aioToken_ The AIO token contract address
     * @return aioRewardPool_ The AIO reward pool address
     */
    function getConfig()
        external
        view
        returns (
            uint256 feeWei_,
            address feeDistributor_,
            bool allowlistEnabled_,
            address aioToken_,
            address aioRewardPool_
        )
    {
        return (
            feeDistributor.feeWei(),
            address(feeDistributor),
            allowlistEnabled,
            address(aioToken),
            aioRewardPool
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
     * @notice Sets the AIO token contract address
     * @dev Only callable by owner or PARAM_SETTER_ROLE (if governance mode enabled)
     * @param aioToken_ Address of the AIO token contract
     */
    function setAIOToken(address aioToken_) external {
        _checkParamSetter();
        if (aioToken_ == address(0)) {
            revert("Interaction: aioToken cannot be zero address");
        }
        aioToken = IAIOERC20(aioToken_);
        emit AIOTokenUpdated(aioToken_);
    }

    /**
     * @notice Sets the AIO reward pool address
     * @dev Only callable by owner or PARAM_SETTER_ROLE (if governance mode enabled)
     * @param rewardPool_ Address of the reward pool (must have AIO tokens and approve Interaction contract)
     */
    function setAIORewardPool(address rewardPool_) external {
        _checkParamSetter();
        if (rewardPool_ == address(0)) {
            revert("Interaction: rewardPool cannot be zero address");
        }
        aioRewardPool = rewardPool_;
        emit AIORewardPoolUpdated(rewardPool_);
    }

    /**
     * @notice Sets the AIO reward amount for an action
     * @dev Only callable by owner or PARAM_SETTER_ROLE (if governance mode enabled)
     * @param actionHash Hash of the action string (keccak256(bytes(action)))
     * @param rewardAmount Reward amount in wei (0 to disable rewards for this action)
     */
    function setActionReward(bytes32 actionHash, uint256 rewardAmount) external {
        _checkParamSetter();
        actionReward[actionHash] = rewardAmount;
        emit ActionRewardUpdated(actionHash, rewardAmount);
    }

    /**
     * @notice Convenience function to set action reward by string
     * @dev Only callable by owner or PARAM_SETTER_ROLE (if governance mode enabled)
     * @param action The action string
     * @param rewardAmount Reward amount in wei (0 to disable rewards for this action)
     */
    function setActionRewardByString(string calldata action, uint256 rewardAmount) external {
        _checkParamSetter();
        bytes32 actionHash = keccak256(bytes(action));
        actionReward[actionHash] = rewardAmount;
        emit ActionRewardUpdated(actionHash, rewardAmount);
    }

    /**
     * @notice Checks if a user has claimed AIO for a specific interaction
     * @param user Address of the user
     * @param action Action string identifier
     * @param timestamp Block timestamp of the original interaction
     * @return claimed Whether the interaction has been claimed
     * @return rewardAmount The reward amount for this action (0 if not configured)
     */
    function getClaimStatus(address user, string calldata action, uint256 timestamp)
        external
        view
        returns (bool claimed, uint256 rewardAmount)
    {
        bytes32 actionHash = keccak256(bytes(action));
        claimed = claimedInteractions[user][actionHash][timestamp];
        rewardAmount = actionReward[actionHash];
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
     * @notice Enables governance mode with Safe multisig and parameter setter role
     * @dev Only callable once by owner or trustedBootstrapper. After enabling, owner renounces control to Safe multisig.
     * @param admin Safe multisig address (will receive DEFAULT_ADMIN_ROLE and ownership)
     * @param paramSetter Address that can set parameters (will receive PARAM_SETTER_ROLE)
     */
    function enableGovernanceMode(address admin, address paramSetter) external {
        // Allow owner or trusted bootstrapper to call
        if (msg.sender != owner() && msg.sender != trustedBootstrapper) {
            revert("Interaction: caller is not the owner or trusted bootstrapper");
        }
        
        // If called by bootstrapper, bootstrapper should verify caller is owner before calling
        if (governanceModeEnabled) {
            revert("Interaction: governance mode already enabled");
        }
        if (admin == address(0)) {
            revert("Interaction: admin cannot be zero address");
        }
        if (paramSetter == address(0)) {
            revert("Interaction: paramSetter cannot be zero address");
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
                revert("Interaction: caller does not have PARAM_SETTER_ROLE");
            }
        } else {
            if (msg.sender != owner()) {
                revert("Interaction: caller is not the owner");
            }
        }
    }
}

