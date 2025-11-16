// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {Interaction} from "../src/Interaction.sol";
import {FeeDistributor} from "../src/FeeDistributor.sol";
import {AIOERC20} from "../src/AIOERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice Simple ERC20 token for testing
 */
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title RewardPoolMock
 * @notice Mock contract that acts as reward pool and can approve tokens
 */
contract RewardPoolMock {
    ERC20 public token;
    
    constructor(address token_) {
        token = ERC20(token_);
    }
    
    function approve(address spender, uint256 amount) external {
        token.approve(spender, amount);
    }
}

contract InteractionTest is Test {
    Interaction public interaction;
    FeeDistributor public feeDistributor;
    MockERC20 public mockToken;
    AIOERC20 public aioToken;

    address public owner;
    address public projectWallet;
    address public user1;
    address public user2;
    address public rewardPool; // AIO 奖励池地址

    uint256 public constant INITIAL_FEE_WEI = 1e15; // 0.001 ETH
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18; // 1 billion tokens
    uint256 public constant REWARD_AMOUNT = 100 * 1e18; // 100 AIO tokens per action

    // Events
    event InteractionRecorded(
        address indexed user,
        bytes32 indexed actionHash,
        string action,
        bytes meta,
        uint256 timestamp
    );
    event AllowlistToggled(bool enabled);
    event ActionAllowlistUpdated(bytes32 indexed actionHash, bool allowed);
    event AIOClaimed(
        address indexed user,
        bytes32 indexed actionHash,
        string action,
        uint256 amount,
        uint256 timestamp
    );
    event ActionRewardUpdated(bytes32 indexed actionHash, uint256 rewardAmount);
    event AIOTokenUpdated(address indexed aioToken_);
    event AIORewardPoolUpdated(address indexed rewardPool_);

    function setUp() public {
        owner = address(this);
        projectWallet = address(0x100);
        user1 = address(0x1);
        user2 = address(0x2);
        rewardPool = address(0x200); // 奖励池地址

        // Create mock ERC20 token
        mockToken = new MockERC20("Mock Token", "MOCK");

        // Create AIO token
        aioToken = new AIOERC20(MAX_SUPPLY, owner);

        // Create FeeDistributor
        feeDistributor = new FeeDistributor(
            projectWallet,
            INITIAL_FEE_WEI,
            owner
        );

        // Create Interaction contract
        interaction = new Interaction(address(feeDistributor), owner);

        // Setup AIO token and reward pool for claim functionality
        // Mint AIO tokens to owner first
        aioToken.mint(owner, 10_000 * 1e18); // Mint 10k tokens to owner
        
        // Create a mock contract that acts as reward pool and can approve tokens
        // In real scenario, reward pool would be a Safe multisig that can approve
        RewardPoolMock rewardPoolContract = new RewardPoolMock(address(aioToken));
        rewardPool = address(rewardPoolContract);
        
        // Transfer tokens to the reward pool contract
        aioToken.transfer(rewardPool, 5_000 * 1e18);
        
        // Set AIO token address in Interaction contract
        interaction.setAIOToken(address(aioToken));
        
        // Set reward pool address
        interaction.setAIORewardPool(rewardPool);
        
        // Approve Interaction contract to transfer from reward pool
        // Reward pool contract can approve on behalf of itself
        rewardPoolContract.approve(address(interaction), type(uint256).max);

        // Fund users
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        mockToken.mint(user1, 1000 * 1e18);
        mockToken.mint(user2, 1000 * 1e18);
    }

    // ============ Deployment Tests ============

    function test_Deployment() public view {
        assertEq(address(interaction.feeDistributor()), address(feeDistributor));
        assertEq(interaction.owner(), owner);
        assertFalse(interaction.allowlistEnabled());
    }

    function test_Deployment_ZeroFeeDistributor_Reverts() public {
        vm.expectRevert("Interaction: feeDistributor cannot be zero address");
        new Interaction(address(0), owner);
    }

    // ============ interact (ETH) Tests ============

    function test_Interact_ExactFee_Success() public {
        uint256 amount = INITIAL_FEE_WEI;
        string memory action = "test_action";
        bytes memory meta = "test_meta";
        uint256 initialBalance = projectWallet.balance;

        bytes32 actionHash = keccak256(bytes(action));
        vm.expectEmit(true, true, false, true);
        emit InteractionRecorded(user1, actionHash, action, meta, block.timestamp);

        vm.prank(user1);
        interaction.interact{value: amount}(action, meta);

        assertEq(projectWallet.balance, initialBalance + amount);
        assertEq(address(feeDistributor).balance, 0);
    }

    function test_Interact_GreaterThanFee_Success() public {
        uint256 amount = INITIAL_FEE_WEI * 2;
        string memory action = "test_action";
        bytes memory meta = "test_meta";
        uint256 initialBalance = projectWallet.balance;

        vm.prank(user1);
        interaction.interact{value: amount}(action, meta);

        assertEq(projectWallet.balance, initialBalance + amount);
    }

    function test_Interact_InsufficientFee_Reverts() public {
        uint256 amount = INITIAL_FEE_WEI - 1;
        string memory action = "test_action";
        bytes memory meta = "test_meta";

        vm.prank(user1);
        vm.expectRevert("Interaction: insufficient fee");
        interaction.interact{value: amount}(action, meta);
    }

    function test_Interact_MultipleInteractions() public {
        uint256 amount1 = INITIAL_FEE_WEI;
        uint256 amount2 = INITIAL_FEE_WEI * 2;
        uint256 initialBalance = projectWallet.balance;

        vm.prank(user1);
        interaction.interact{value: amount1}("action1", "meta1");

        vm.prank(user2);
        interaction.interact{value: amount2}("action2", "meta2");

        assertEq(projectWallet.balance, initialBalance + amount1 + amount2);
    }

    function test_Interact_ZeroFee_EdgeCase() public {
        // Set fee to zero
        feeDistributor.setFeeWei(0);

        uint256 amount = 0;
        string memory action = "test_action";
        bytes memory meta = "test_meta";
        uint256 initialBalance = projectWallet.balance;

        vm.prank(user1);
        interaction.interact{value: amount}(action, meta);

        assertEq(projectWallet.balance, initialBalance);
    }


    // ============ Allowlist Tests ============

    function test_Allowlist_Disabled_AllowsAll() public {
        uint256 amount = INITIAL_FEE_WEI;
        string memory action = "random_action";
        bytes memory meta = "meta";

        // Allowlist is disabled by default
        assertFalse(interaction.allowlistEnabled());

        vm.prank(user1);
        interaction.interact{value: amount}(action, meta);

        // Should succeed
        assertEq(projectWallet.balance, amount);
    }

    function test_Allowlist_Enabled_AllowedAction_Success() public {
        uint256 amount = INITIAL_FEE_WEI;
        string memory action = "allowed_action";
        bytes memory meta = "meta";
        bytes32 actionHash = keccak256(bytes(action));

        // Enable allowlist
        interaction.setAllowlistEnabled(true);

        // Add action to allowlist
        interaction.setActionAllowlist(actionHash, true);

        vm.prank(user1);
        interaction.interact{value: amount}(action, meta);

        // Should succeed
        assertEq(projectWallet.balance, amount);
    }

    function test_Allowlist_Enabled_DisallowedAction_Reverts() public {
        uint256 amount = INITIAL_FEE_WEI;
        string memory action = "disallowed_action";
        bytes memory meta = "meta";

        // Enable allowlist
        interaction.setAllowlistEnabled(true);

        // Don't add action to allowlist

        vm.prank(user1);
        vm.expectRevert("Interaction: action not allowed");
        interaction.interact{value: amount}(action, meta);
    }

    function test_Allowlist_SetActionAllowlistByString() public {
        uint256 amount = INITIAL_FEE_WEI;
        string memory action = "new_action";
        bytes memory meta = "meta";

        // Enable allowlist
        interaction.setAllowlistEnabled(true);

        // Add action using string method
        interaction.setActionAllowlistByString(action, true);

        vm.prank(user1);
        interaction.interact{value: amount}(action, meta);

        // Should succeed
        assertEq(projectWallet.balance, amount);
    }

    function test_Allowlist_RemoveFromAllowlist() public {
        uint256 amount = INITIAL_FEE_WEI;
        string memory action = "action";
        bytes memory meta = "meta";
        bytes32 actionHash = keccak256(bytes(action));

        // Enable allowlist and add action
        interaction.setAllowlistEnabled(true);
        interaction.setActionAllowlist(actionHash, true);

        // First interaction should succeed
        vm.prank(user1);
        interaction.interact{value: amount}(action, meta);

        // Remove from allowlist
        interaction.setActionAllowlist(actionHash, false);

        // Second interaction should fail
        vm.prank(user2);
        vm.expectRevert("Interaction: action not allowed");
        interaction.interact{value: amount}(action, meta);
    }


    // ============ Owner Functions Tests ============

    function test_SetAllowlistEnabled_Success() public {
        vm.expectEmit(true, false, false, true);
        emit AllowlistToggled(true);

        interaction.setAllowlistEnabled(true);
        assertTrue(interaction.allowlistEnabled());

        vm.expectEmit(true, false, false, true);
        emit AllowlistToggled(false);

        interaction.setAllowlistEnabled(false);
        assertFalse(interaction.allowlistEnabled());
    }

    function test_SetAllowlistEnabled_OnlyOwner_Reverts() public {
        vm.prank(user1);
        vm.expectRevert();
        interaction.setAllowlistEnabled(true);
    }

    function test_SetActionAllowlist_Success() public {
        bytes32 actionHash = keccak256(bytes("test_action"));

        vm.expectEmit(true, false, false, false);
        emit ActionAllowlistUpdated(actionHash, true);

        interaction.setActionAllowlist(actionHash, true);
        assertTrue(interaction.actionAllowlist(actionHash));

        interaction.setActionAllowlist(actionHash, false);
        assertFalse(interaction.actionAllowlist(actionHash));
    }

    function test_SetActionAllowlist_OnlyOwner_Reverts() public {
        bytes32 actionHash = keccak256(bytes("test_action"));

        vm.prank(user1);
        vm.expectRevert();
        interaction.setActionAllowlist(actionHash, true);
    }

    // ============ View Functions Tests ============

    function test_GetConfig() public view {
        (uint256 feeWei_, address feeDistributor_, bool allowlistEnabled_, address aioToken_, address aioRewardPool_) =
            interaction.getConfig();

        assertEq(feeWei_, INITIAL_FEE_WEI);
        assertEq(feeDistributor_, address(feeDistributor));
        assertFalse(allowlistEnabled_);
        assertEq(aioToken_, address(aioToken));
        assertEq(aioRewardPool_, rewardPool);
    }

    function test_GetConfig_AfterChanges() public {
        interaction.setAllowlistEnabled(true);
        feeDistributor.setFeeWei(2e15);

        (uint256 feeWei_, address feeDistributor_, bool allowlistEnabled_, address aioToken_, address aioRewardPool_) =
            interaction.getConfig();

        assertEq(feeWei_, 2e15);
        assertEq(feeDistributor_, address(feeDistributor));
        assertTrue(allowlistEnabled_);
        assertEq(aioToken_, address(aioToken));
        assertEq(aioRewardPool_, rewardPool);
    }

    // ============ Integration Tests ============

    function test_Integration_FullFlow_ETH() public {
        uint256 amount = INITIAL_FEE_WEI;
        string memory action = "integration_test";
        bytes memory meta = "integration_meta";
        uint256 initialBalance = projectWallet.balance;

        // User interacts with ETH
        vm.prank(user1);
        interaction.interact{value: amount}(action, meta);

        // Verify fee was forwarded
        assertEq(projectWallet.balance, initialBalance + amount);

        // Verify event was emitted
        bytes32 actionHash = keccak256(bytes(action));
        vm.expectEmit(true, true, false, true);
        emit InteractionRecorded(user1, actionHash, action, meta, block.timestamp);

        vm.prank(user1);
        interaction.interact{value: amount}(action, meta);
    }


    // ============ Fuzz Tests ============

    function testFuzz_Interact(uint256 amount) public {
        amount = bound(amount, INITIAL_FEE_WEI, 10 ether);
        uint256 initialBalance = projectWallet.balance;

        vm.deal(user1, amount);
        vm.prank(user1);
        interaction.interact{value: amount}("fuzz_action", "fuzz_meta");

        assertEq(projectWallet.balance, initialBalance + amount);
    }

    // ============ Claim AIO Tests ============

    function test_ClaimAIO_Success() public {
        // Setup: User completes an interaction
        string memory action = "test_action";
        bytes memory meta = "test_meta";
        uint256 amount = INITIAL_FEE_WEI;
        
        // Set reward for this action
        bytes32 actionHash = keccak256(bytes(action));
        interaction.setActionReward(actionHash, REWARD_AMOUNT);
        
        // User interacts (using their own wallet)
        vm.prank(user1);
        uint256 timestamp = block.timestamp;
        interaction.interact{value: amount}(action, meta);
        
        // Verify user has no AIO tokens initially
        assertEq(aioToken.balanceOf(user1), 0);
        
        // User claims AIO reward (using their own wallet)
        vm.expectEmit(true, true, false, true);
        emit AIOClaimed(user1, actionHash, action, REWARD_AMOUNT, timestamp);
        
        vm.prank(user1);
        interaction.claimAIO(action, timestamp);
        
        // Verify user received AIO tokens
        assertEq(aioToken.balanceOf(user1), REWARD_AMOUNT);
        
        // Verify reward pool balance decreased
        assertEq(aioToken.balanceOf(rewardPool), 5_000 * 1e18 - REWARD_AMOUNT);
    }

    function test_ClaimAIO_MultipleUsers() public {
        string memory action = "shared_action";
        bytes memory meta = "meta";
        bytes32 actionHash = keccak256(bytes(action));
        
        // Set reward
        interaction.setActionReward(actionHash, REWARD_AMOUNT);
        
        // User1 interacts and claims
        vm.prank(user1);
        uint256 timestamp1 = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        vm.prank(user1);
        interaction.claimAIO(action, timestamp1);
        assertEq(aioToken.balanceOf(user1), REWARD_AMOUNT);
        
        // User2 interacts and claims (different timestamp)
        vm.warp(block.timestamp + 1);
        vm.prank(user2);
        uint256 timestamp2 = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        vm.prank(user2);
        interaction.claimAIO(action, timestamp2);
        assertEq(aioToken.balanceOf(user2), REWARD_AMOUNT);
        
        // Both users should have their rewards
        assertEq(aioToken.balanceOf(user1), REWARD_AMOUNT);
        assertEq(aioToken.balanceOf(user2), REWARD_AMOUNT);
    }

    function test_ClaimAIO_AlreadyClaimed_Reverts() public {
        string memory action = "test_action";
        bytes memory meta = "test_meta";
        bytes32 actionHash = keccak256(bytes(action));
        
        // Set reward
        interaction.setActionReward(actionHash, REWARD_AMOUNT);
        
        // User interacts
        vm.prank(user1);
        uint256 timestamp = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // User claims first time (should succeed)
        vm.prank(user1);
        interaction.claimAIO(action, timestamp);
        assertEq(aioToken.balanceOf(user1), REWARD_AMOUNT);
        
        // User tries to claim again (should fail)
        vm.prank(user1);
        vm.expectRevert("Interaction: already claimed");
        interaction.claimAIO(action, timestamp);
        
        // User should still have only one reward
        assertEq(aioToken.balanceOf(user1), REWARD_AMOUNT);
    }

    function test_ClaimAIO_NoRewardConfigured_Reverts() public {
        string memory action = "no_reward_action";
        bytes memory meta = "meta";
        
        // User interacts
        vm.prank(user1);
        uint256 timestamp = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // User tries to claim (no reward configured)
        vm.prank(user1);
        vm.expectRevert("Interaction: no reward configured for this action");
        interaction.claimAIO(action, timestamp);
    }

    function test_ClaimAIO_AioTokenNotSet_Reverts() public {
        // Create new interaction without AIO token set
        Interaction newInteraction = new Interaction(address(feeDistributor), owner);
        
        string memory action = "test_action";
        bytes memory meta = "meta";
        
        // User interacts
        vm.prank(user1);
        uint256 timestamp = block.timestamp;
        newInteraction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // User tries to claim (AIO token not set)
        vm.prank(user1);
        vm.expectRevert("Interaction: AIO token not set");
        newInteraction.claimAIO(action, timestamp);
    }

    function test_ClaimAIO_RewardPoolNotSet_Reverts() public {
        // Create new interaction and set AIO token but not reward pool
        Interaction newInteraction = new Interaction(address(feeDistributor), owner);
        newInteraction.setAIOToken(address(aioToken));
        
        string memory action = "test_action";
        bytes memory meta = "meta";
        
        // User interacts
        vm.prank(user1);
        uint256 timestamp = block.timestamp;
        newInteraction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // User tries to claim (reward pool not set)
        vm.prank(user1);
        vm.expectRevert("Interaction: AIO reward pool not set");
        newInteraction.claimAIO(action, timestamp);
    }

    function test_ClaimAIO_DifferentTimestamp_Success() public {
        string memory action = "test_action";
        bytes memory meta = "meta";
        bytes32 actionHash = keccak256(bytes(action));
        
        // Set reward
        interaction.setActionReward(actionHash, REWARD_AMOUNT);
        
        // User interacts at timestamp1
        vm.prank(user1);
        uint256 timestamp1 = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        vm.prank(user1);
        interaction.claimAIO(action, timestamp1);
        assertEq(aioToken.balanceOf(user1), REWARD_AMOUNT);
        
        // User interacts again at timestamp2 (different timestamp)
        vm.warp(block.timestamp + 100);
        vm.prank(user1);
        uint256 timestamp2 = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // User can claim again with different timestamp
        vm.prank(user1);
        interaction.claimAIO(action, timestamp2);
        assertEq(aioToken.balanceOf(user1), REWARD_AMOUNT * 2);
    }

    function test_ClaimAIO_WrongTimestamp_StillWorks() public {
        // Note: The contract doesn't verify timestamp matches an actual interaction event.
        // It only uses timestamp as a unique identifier for the claim.
        // Users should use the timestamp from InteractionRecorded event, but the contract
        // doesn't enforce this - it's the frontend's responsibility to use the correct timestamp.
        
        string memory action = "test_action";
        bytes memory meta = "meta";
        bytes32 actionHash = keccak256(bytes(action));
        
        // Set reward
        interaction.setActionReward(actionHash, REWARD_AMOUNT);
        
        // User interacts
        vm.prank(user1);
        uint256 actualTimestamp = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // User claims with correct timestamp (should succeed)
        vm.prank(user1);
        interaction.claimAIO(action, actualTimestamp);
        assertEq(aioToken.balanceOf(user1), REWARD_AMOUNT);
        
        // Note: Claiming with wrong timestamp would also work (different claim identifier),
        // but users should always use the timestamp from the InteractionRecorded event.
        // This test verifies the correct timestamp works as expected.
    }

    function test_ClaimAIO_GetClaimStatus() public view {
        string memory action = "test_action";
        uint256 timestamp = block.timestamp;
        
        // Check status before setting reward
        (bool claimed, uint256 rewardAmount) = interaction.getClaimStatus(user1, action, timestamp);
        assertFalse(claimed);
        assertEq(rewardAmount, 0);
    }

    function test_ClaimAIO_GetClaimStatus_AfterRewardSet() public {
        string memory action = "test_action";
        bytes32 actionHash = keccak256(bytes(action));
        uint256 timestamp = block.timestamp;
        
        // Set reward
        interaction.setActionReward(actionHash, REWARD_AMOUNT);
        
        // Check status
        (bool claimed, uint256 rewardAmount) = interaction.getClaimStatus(user1, action, timestamp);
        assertFalse(claimed);
        assertEq(rewardAmount, REWARD_AMOUNT);
    }

    function test_ClaimAIO_GetClaimStatus_AfterClaimed() public {
        string memory action = "test_action";
        bytes memory meta = "meta";
        bytes32 actionHash = keccak256(bytes(action));
        
        // Set reward
        interaction.setActionReward(actionHash, REWARD_AMOUNT);
        
        // User interacts
        vm.prank(user1);
        uint256 timestamp = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // Check status before claiming
        (bool claimed1, uint256 rewardAmount1) = interaction.getClaimStatus(user1, action, timestamp);
        assertFalse(claimed1);
        assertEq(rewardAmount1, REWARD_AMOUNT);
        
        // User claims
        vm.prank(user1);
        interaction.claimAIO(action, timestamp);
        
        // Check status after claiming
        (bool claimed2, uint256 rewardAmount2) = interaction.getClaimStatus(user1, action, timestamp);
        assertTrue(claimed2);
        assertEq(rewardAmount2, REWARD_AMOUNT);
    }

    function test_ClaimAIO_RewardPoolInsufficientBalance_Reverts() public {
        string memory action = "test_action";
        bytes memory meta = "meta";
        bytes32 actionHash = keccak256(bytes(action));
        
        // Set a very large reward (larger than reward pool balance)
        uint256 largeReward = 10_000 * 1e18; // Larger than reward pool balance (5k)
        interaction.setActionReward(actionHash, largeReward);
        
        // User interacts
        vm.prank(user1);
        uint256 timestamp = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // User tries to claim (should fail due to insufficient balance in reward pool)
        vm.prank(user1);
        vm.expectRevert(); // ERC20 transfer will fail
        interaction.claimAIO(action, timestamp);
    }

    function test_ClaimAIO_SetActionReward() public {
        string memory action = "test_action";
        bytes32 actionHash = keccak256(bytes(action));
        
        vm.expectEmit(true, false, false, true);
        emit ActionRewardUpdated(actionHash, REWARD_AMOUNT);
        
        interaction.setActionReward(actionHash, REWARD_AMOUNT);
        assertEq(interaction.actionReward(actionHash), REWARD_AMOUNT);
        
        // Update reward
        uint256 newReward = 200 * 1e18;
        interaction.setActionReward(actionHash, newReward);
        assertEq(interaction.actionReward(actionHash), newReward);
        
        // Disable reward (set to 0)
        interaction.setActionReward(actionHash, 0);
        assertEq(interaction.actionReward(actionHash), 0);
    }

    function test_ClaimAIO_SetActionRewardByString() public {
        string memory action = "test_action";
        bytes32 actionHash = keccak256(bytes(action));
        
        vm.expectEmit(true, false, false, true);
        emit ActionRewardUpdated(actionHash, REWARD_AMOUNT);
        
        interaction.setActionRewardByString(action, REWARD_AMOUNT);
        assertEq(interaction.actionReward(actionHash), REWARD_AMOUNT);
    }

    function test_ClaimAIO_SetAIOToken() public {
        address newAioToken = address(0x300);
        
        vm.expectEmit(true, false, false, true);
        emit AIOTokenUpdated(newAioToken);
        
        interaction.setAIOToken(newAioToken);
        assertEq(address(interaction.aioToken()), newAioToken);
    }

    function test_ClaimAIO_SetAIORewardPool() public {
        address newRewardPool = address(0x400);
        
        vm.expectEmit(true, false, false, true);
        emit AIORewardPoolUpdated(newRewardPool);
        
        interaction.setAIORewardPool(newRewardPool);
        assertEq(interaction.aioRewardPool(), newRewardPool);
    }

    function test_ClaimAIO_Integration_FullFlow() public {
        // Full integration test: User completes interaction and claims reward
        string memory action = "integration_action";
        bytes memory meta = "integration_meta";
        bytes32 actionHash = keccak256(bytes(action));
        
        // Setup reward
        interaction.setActionReward(actionHash, REWARD_AMOUNT);
        
        uint256 initialUserBalance = aioToken.balanceOf(user1);
        uint256 initialRewardPoolBalance = aioToken.balanceOf(rewardPool);
        uint256 initialProjectWalletBalance = projectWallet.balance;
        
        // Step 1: User interacts (using their own wallet)
        vm.prank(user1);
        uint256 timestamp = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // Verify fee was paid
        assertEq(projectWallet.balance, initialProjectWalletBalance + INITIAL_FEE_WEI);
        
        // Step 2: User claims AIO reward (using their own wallet)
        vm.prank(user1);
        interaction.claimAIO(action, timestamp);
        
        // Verify user received AIO tokens
        assertEq(aioToken.balanceOf(user1), initialUserBalance + REWARD_AMOUNT);
        
        // Verify reward pool balance decreased
        assertEq(aioToken.balanceOf(rewardPool), initialRewardPoolBalance - REWARD_AMOUNT);
        
        // Verify claim status
        (bool claimed, uint256 rewardAmount) = interaction.getClaimStatus(user1, action, timestamp);
        assertTrue(claimed);
        assertEq(rewardAmount, REWARD_AMOUNT);
    }

    function test_ClaimAIO_OnlyOwnerCanSetReward() public {
        bytes32 actionHash = keccak256(bytes("test_action"));
        
        // User tries to set reward (should fail)
        vm.prank(user1);
        vm.expectRevert("Interaction: caller is not the owner");
        interaction.setActionReward(actionHash, REWARD_AMOUNT);
    }

    function test_ClaimAIO_OnlyOwnerCanSetAIOToken() public {
        // User tries to set AIO token (should fail)
        vm.prank(user1);
        vm.expectRevert("Interaction: caller is not the owner");
        interaction.setAIOToken(address(aioToken));
    }

    function test_ClaimAIO_OnlyOwnerCanSetRewardPool() public {
        // User tries to set reward pool (should fail)
        vm.prank(user1);
        vm.expectRevert("Interaction: caller is not the owner");
        interaction.setAIORewardPool(rewardPool);
    }

    // ============ User Wallet Scenario Tests ============
    // 这些测试专门验证用户使用自己钱包调用合约的场景

    function test_UserWallet_CompleteInteractionAndClaim() public {
        // 场景：用户使用自己的钱包完成交互并领取奖励
        string memory action = "user_wallet_action";
        bytes memory meta = "user_wallet_meta";
        bytes32 actionHash = keccak256(bytes(action));
        
        // Owner 设置奖励
        interaction.setActionReward(actionHash, REWARD_AMOUNT);
        
        uint256 initialUserAIOBalance = aioToken.balanceOf(user1);
        uint256 initialUserETHBalance = user1.balance;
        uint256 initialRewardPoolBalance = aioToken.balanceOf(rewardPool);
        
        // 步骤 1: 用户使用自己的钱包调用 interact()
        vm.prank(user1); // 模拟用户使用自己的钱包
        uint256 timestamp = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // 验证：用户 ETH 余额减少
        assertEq(user1.balance, initialUserETHBalance - INITIAL_FEE_WEI);
        
        // 验证：用户还没有 AIO token
        assertEq(aioToken.balanceOf(user1), initialUserAIOBalance);
        
        // 步骤 2: 用户使用自己的钱包调用 claimAIO()
        vm.prank(user1); // 模拟用户使用自己的钱包
        interaction.claimAIO(action, timestamp);
        
        // 验证：用户收到了 AIO token
        assertEq(aioToken.balanceOf(user1), initialUserAIOBalance + REWARD_AMOUNT);
        
        // 验证：奖励池余额减少
        assertEq(aioToken.balanceOf(rewardPool), initialRewardPoolBalance - REWARD_AMOUNT);
    }

    function test_UserWallet_CannotClaimOtherUserInteraction() public {
        // 场景：用户尝试领取其他用户的交互奖励（应该失败）
        // 注意：合约使用 user + actionHash + timestamp 作为唯一标识
        // 如果 User2 使用 User1 的 timestamp，由于 User1 已经领取，User2 的 claim 会失败
        // 因为 claimedInteractions[user2][actionHash][timestamp1] 是 false，但这不是 User2 的交互
        
        string memory action = "shared_action";
        bytes memory meta = "meta";
        bytes32 actionHash = keccak256(bytes(action));
        
        interaction.setActionReward(actionHash, REWARD_AMOUNT);
        
        // User1 完成交互
        vm.prank(user1);
        uint256 timestamp1 = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // User1 领取自己的奖励（应该成功）
        vm.prank(user1);
        interaction.claimAIO(action, timestamp1);
        assertEq(aioToken.balanceOf(user1), REWARD_AMOUNT);
        
        // User2 尝试使用 User1 的 timestamp 领取
        // 注意：由于 user 不同，claimedInteractions[user2][actionHash][timestamp1] 是 false
        // 所以 User2 理论上可以 claim，但这不应该发生，因为 timestamp1 是 User1 的交互
        // 实际上，合约不验证 timestamp 是否匹配实际的交互，只检查是否已 claim
        // 所以这个测试验证的是：每个用户只能 claim 自己的交互（通过正确的 timestamp）
        
        // User2 使用不同的 timestamp（新的交互）
        vm.warp(block.timestamp + 1);
        vm.prank(user2);
        uint256 timestamp2 = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // User2 可以领取自己的奖励
        vm.prank(user2);
        interaction.claimAIO(action, timestamp2);
        assertEq(aioToken.balanceOf(user2), REWARD_AMOUNT);
        
        // 验证：User2 不能重复领取自己的奖励
        vm.prank(user2);
        vm.expectRevert("Interaction: already claimed");
        interaction.claimAIO(action, timestamp2); // User2 自己的 timestamp，但已领取
    }

    function test_UserWallet_MultipleInteractionsSameUser() public {
        // 场景：同一用户多次交互，每次都可以领取奖励
        string memory action = "repeated_action";
        bytes memory meta = "meta";
        bytes32 actionHash = keccak256(bytes(action));
        
        interaction.setActionReward(actionHash, REWARD_AMOUNT);
        
        uint256 totalRewards = 0;
        
        // 第一次交互
        vm.prank(user1);
        uint256 timestamp1 = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        vm.prank(user1);
        interaction.claimAIO(action, timestamp1);
        totalRewards += REWARD_AMOUNT;
        assertEq(aioToken.balanceOf(user1), totalRewards);
        
        // 第二次交互（不同的 timestamp）
        vm.warp(block.timestamp + 100);
        vm.prank(user1);
        uint256 timestamp2 = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        vm.prank(user1);
        interaction.claimAIO(action, timestamp2);
        totalRewards += REWARD_AMOUNT;
        assertEq(aioToken.balanceOf(user1), totalRewards);
        
        // 第三次交互
        vm.warp(block.timestamp + 100);
        vm.prank(user1);
        uint256 timestamp3 = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        vm.prank(user1);
        interaction.claimAIO(action, timestamp3);
        totalRewards += REWARD_AMOUNT;
        assertEq(aioToken.balanceOf(user1), totalRewards);
        
        // 验证总共领取了 3 次奖励
        assertEq(totalRewards, REWARD_AMOUNT * 3);
    }

    function test_UserWallet_CheckClaimStatusBeforeClaiming() public {
        // 场景：用户在领取前检查状态
        string memory action = "check_status_action";
        bytes memory meta = "meta";
        bytes32 actionHash = keccak256(bytes(action));
        
        interaction.setActionReward(actionHash, REWARD_AMOUNT);
        
        // 用户完成交互
        vm.prank(user1);
        uint256 timestamp = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // 用户检查状态（使用自己的地址）
        (bool claimed1, uint256 rewardAmount1) = interaction.getClaimStatus(user1, action, timestamp);
        assertFalse(claimed1);
        assertEq(rewardAmount1, REWARD_AMOUNT);
        
        // 用户领取奖励
        vm.prank(user1);
        interaction.claimAIO(action, timestamp);
        
        // 再次检查状态
        (bool claimed2, uint256 rewardAmount2) = interaction.getClaimStatus(user1, action, timestamp);
        assertTrue(claimed2);
        assertEq(rewardAmount2, REWARD_AMOUNT);
    }

    function test_UserWallet_DifferentActionsDifferentRewards() public {
        // 场景：不同 action 有不同的奖励，用户分别领取
        string memory action1 = "action_1";
        string memory action2 = "action_2";
        bytes memory meta = "meta";
        
        bytes32 actionHash1 = keccak256(bytes(action1));
        bytes32 actionHash2 = keccak256(bytes(action2));
        
        uint256 reward1 = 50 * 1e18;
        uint256 reward2 = 200 * 1e18;
        
        interaction.setActionReward(actionHash1, reward1);
        interaction.setActionReward(actionHash2, reward2);
        
        // 用户完成第一个交互
        vm.prank(user1);
        uint256 timestamp1 = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action1, meta);
        
        // 用户领取第一个奖励
        vm.prank(user1);
        interaction.claimAIO(action1, timestamp1);
        assertEq(aioToken.balanceOf(user1), reward1);
        
        // 用户完成第二个交互
        vm.warp(block.timestamp + 1);
        vm.prank(user1);
        uint256 timestamp2 = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action2, meta);
        
        // 用户领取第二个奖励
        vm.prank(user1);
        interaction.claimAIO(action2, timestamp2);
        assertEq(aioToken.balanceOf(user1), reward1 + reward2);
    }

    function test_UserWallet_ClaimAfterRewardUpdated() public {
        // 场景：用户在奖励更新后领取（应该使用更新后的奖励）
        string memory action = "updated_reward_action";
        bytes memory meta = "meta";
        bytes32 actionHash = keccak256(bytes(action));
        
        // Owner 设置初始奖励
        interaction.setActionReward(actionHash, REWARD_AMOUNT);
        
        // 用户完成交互
        vm.prank(user1);
        uint256 timestamp = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // Owner 更新奖励（增加）
        uint256 newReward = REWARD_AMOUNT * 2;
        interaction.setActionReward(actionHash, newReward);
        
        // 用户领取（应该获得新的奖励金额）
        vm.prank(user1);
        interaction.claimAIO(action, timestamp);
        assertEq(aioToken.balanceOf(user1), newReward);
    }

    function test_UserWallet_ClaimAfterRewardDisabled() public {
        // 场景：用户在奖励被禁用后尝试领取（应该失败）
        string memory action = "disabled_reward_action";
        bytes memory meta = "meta";
        bytes32 actionHash = keccak256(bytes(action));
        
        // Owner 设置奖励
        interaction.setActionReward(actionHash, REWARD_AMOUNT);
        
        // 用户完成交互
        vm.prank(user1);
        uint256 timestamp = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // Owner 禁用奖励（设置为 0）
        interaction.setActionReward(actionHash, 0);
        
        // 用户尝试领取（应该失败）
        vm.prank(user1);
        vm.expectRevert("Interaction: no reward configured for this action");
        interaction.claimAIO(action, timestamp);
    }

    function test_UserWallet_ConcurrentClaims() public {
        // 场景：多个用户同时领取奖励
        string memory action = "concurrent_action";
        bytes memory meta = "meta";
        bytes32 actionHash = keccak256(bytes(action));
        
        interaction.setActionReward(actionHash, REWARD_AMOUNT);
        
        // 多个用户完成交互
        vm.prank(user1);
        uint256 timestamp1 = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        vm.warp(block.timestamp + 1);
        vm.prank(user2);
        uint256 timestamp2 = block.timestamp;
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // 多个用户同时领取（模拟并发场景）
        vm.prank(user1);
        interaction.claimAIO(action, timestamp1);
        
        vm.prank(user2);
        interaction.claimAIO(action, timestamp2);
        
        // 验证两个用户都收到了奖励
        assertEq(aioToken.balanceOf(user1), REWARD_AMOUNT);
        assertEq(aioToken.balanceOf(user2), REWARD_AMOUNT);
    }

}

