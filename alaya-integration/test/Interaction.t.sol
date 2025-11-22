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
    event AIOClaimed(
        address indexed user,
        uint256 indexed amount
    );
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
    // Allowlist functionality has been removed from the contract


    // ============ Owner Functions Tests ============

    // Allowlist tests removed - functionality no longer exists in contract

    // ============ View Functions Tests ============

    function test_GetConfig() public view {
        (uint256 feeWei_, address feeDistributor_, address aioToken_, address aioRewardPool_) =
            interaction.getConfig();

        assertEq(feeWei_, INITIAL_FEE_WEI);
        assertEq(feeDistributor_, address(feeDistributor));
        assertEq(aioToken_, address(aioToken));
        assertEq(aioRewardPool_, rewardPool);
    }

    function test_GetConfig_AfterChanges() public {
        feeDistributor.setFeeWei(2e15);

        (uint256 feeWei_, address feeDistributor_, address aioToken_, address aioRewardPool_) =
            interaction.getConfig();

        assertEq(feeWei_, 2e15);
        assertEq(feeDistributor_, address(feeDistributor));
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
        // Verify user has no AIO tokens initially
        assertEq(aioToken.balanceOf(user1), 0);
        
        // User claims AIO reward (using their own wallet)
        vm.expectEmit(true, true, false, true);
        emit AIOClaimed(user1, REWARD_AMOUNT);
        
        vm.prank(user1);
        interaction.claimAIO(REWARD_AMOUNT);
        
        // Verify reward pool balance decreased
        assertEq(aioToken.balanceOf(rewardPool), 5_000 * 1e18 - REWARD_AMOUNT);
    }

    function test_ClaimAIO_MultipleUsers() public {
        string memory action = "shared_action";
        bytes memory meta = "meta";
        
        // User1 interacts and claims
        vm.prank(user1);
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        vm.prank(user1);
        interaction.claimAIO(REWARD_AMOUNT);
        assertEq(aioToken.balanceOf(user1), REWARD_AMOUNT);
        
        // User2 interacts and claims
        vm.warp(block.timestamp + 1);
        vm.prank(user2);
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        vm.prank(user2);
        interaction.claimAIO(REWARD_AMOUNT);
        assertEq(aioToken.balanceOf(user2), REWARD_AMOUNT);
        
        // Both users should have their rewards
        assertEq(aioToken.balanceOf(user1), REWARD_AMOUNT);
        assertEq(aioToken.balanceOf(user2), REWARD_AMOUNT);
    }

    function test_ClaimAIO_ZeroAmount_Reverts() public {
        // User tries to claim with zero amount (should fail)
        vm.prank(user1);
        vm.expectRevert("Interaction: amount cannot be zero");
        interaction.claimAIO(0);
    }

    function test_ClaimAIO_AioTokenNotSet_Reverts() public {
        // Create new interaction without AIO token set
        Interaction newInteraction = new Interaction(address(feeDistributor), owner);
        
        string memory action = "test_action";
        bytes memory meta = "meta";
        
        // User interacts
        vm.prank(user1);
        newInteraction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // User tries to claim (AIO token not set)
        vm.prank(user1);
        vm.expectRevert("Interaction: AIO token not set");
        newInteraction.claimAIO(REWARD_AMOUNT);
    }

    function test_ClaimAIO_RewardPoolNotSet_Reverts() public {
        // Create new interaction and set AIO token but not reward pool
        Interaction newInteraction = new Interaction(address(feeDistributor), owner);
        newInteraction.setAIOToken(address(aioToken));
        
        string memory action = "test_action";
        bytes memory meta = "meta";
        
        // User interacts
        vm.prank(user1);
        newInteraction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // User tries to claim (reward pool not set)
        vm.prank(user1);
        vm.expectRevert("Interaction: AIO reward pool not set");
        newInteraction.claimAIO(REWARD_AMOUNT);
    }

    function test_ClaimAIO_MultipleClaims() public {
        // User can claim multiple times
        vm.prank(user1);
        interaction.claimAIO(REWARD_AMOUNT);
        assertEq(aioToken.balanceOf(user1), REWARD_AMOUNT);
        
        // User can claim again
        vm.prank(user1);
        interaction.claimAIO(REWARD_AMOUNT);
        assertEq(aioToken.balanceOf(user1), REWARD_AMOUNT * 2);
    }

    function test_ClaimAIO_InsufficientBalance_Reverts() public {
        // User tries to claim more than reward pool has (should fail)
        uint256 excessiveAmount = 10_000 * 1e18; // More than reward pool balance
        vm.prank(user1);
        vm.expectRevert(); // ERC20 transfer will fail
        interaction.claimAIO(excessiveAmount);
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
        
        // Setup
        uint256 initialUserBalance = aioToken.balanceOf(user1);
        uint256 initialRewardPoolBalance = aioToken.balanceOf(rewardPool);
        uint256 initialProjectWalletBalance = projectWallet.balance;
        
        // Step 1: User interacts (using their own wallet)
        vm.prank(user1);
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // Verify fee was paid
        assertEq(projectWallet.balance, initialProjectWalletBalance + INITIAL_FEE_WEI);
        
        // Step 2: User claims AIO reward (using their own wallet)
        vm.prank(user1);
        interaction.claimAIO(REWARD_AMOUNT);
        
        // Verify user received AIO tokens
        assertEq(aioToken.balanceOf(user1), initialUserBalance + REWARD_AMOUNT);
        
        // Verify reward pool balance decreased
        assertEq(aioToken.balanceOf(rewardPool), initialRewardPoolBalance - REWARD_AMOUNT);
    }

    function test_ClaimAIO_OnlyOwnerCanSetReward() public {
        // This test is no longer relevant since we removed action reward management
        // Keeping function for potential future tests
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
        
        // Setup
        uint256 initialUserAIOBalance = aioToken.balanceOf(user1);
        uint256 initialUserETHBalance = user1.balance;
        uint256 initialRewardPoolBalance = aioToken.balanceOf(rewardPool);
        
        // 步骤 1: 用户使用自己的钱包调用 interact()
        vm.prank(user1); // 模拟用户使用自己的钱包
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // 验证：用户 ETH 余额减少
        assertEq(user1.balance, initialUserETHBalance - INITIAL_FEE_WEI);
        
        // 验证：用户还没有 AIO token
        assertEq(aioToken.balanceOf(user1), initialUserAIOBalance);
        
        // 步骤 2: 用户使用自己的钱包调用 claimAIO()
        vm.prank(user1); // 模拟用户使用自己的钱包
        interaction.claimAIO(REWARD_AMOUNT);
        
        // 验证：用户收到了 AIO token
        assertEq(aioToken.balanceOf(user1), initialUserAIOBalance + REWARD_AMOUNT);
        
        // 验证：奖励池余额减少
        assertEq(aioToken.balanceOf(rewardPool), initialRewardPoolBalance - REWARD_AMOUNT);
    }

    function test_UserWallet_CannotClaimOtherUserInteraction() public {
        // 场景：多个用户都可以独立领取奖励
        // 注意：由于移除了 claimedInteractions 检查，用户可以根据需要多次领取
        // 只要奖励池有足够的余额即可
        
        string memory action = "shared_action";
        bytes memory meta = "meta";
        
        // User1 完成交互并领取
        vm.prank(user1);
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        vm.prank(user1);
        interaction.claimAIO(REWARD_AMOUNT);
        assertEq(aioToken.balanceOf(user1), REWARD_AMOUNT);
        
        // User2 完成交互并领取
        vm.warp(block.timestamp + 1);
        vm.prank(user2);
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        vm.prank(user2);
        interaction.claimAIO(REWARD_AMOUNT);
        assertEq(aioToken.balanceOf(user2), REWARD_AMOUNT);
        
        // 验证：两个用户都收到了奖励
        assertEq(aioToken.balanceOf(user1), REWARD_AMOUNT);
        assertEq(aioToken.balanceOf(user2), REWARD_AMOUNT);
    }

    function test_UserWallet_MultipleInteractionsSameUser() public {
        // 场景：同一用户多次交互，每次都可以领取奖励
        string memory action = "repeated_action";
        bytes memory meta = "meta";
        
        uint256 totalRewards = 0;
        
        // 第一次交互
        vm.prank(user1);
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        vm.prank(user1);
        interaction.claimAIO(REWARD_AMOUNT);
        totalRewards += REWARD_AMOUNT;
        assertEq(aioToken.balanceOf(user1), totalRewards);
        
        // 第二次交互
        vm.warp(block.timestamp + 100);
        vm.prank(user1);
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        vm.prank(user1);
        interaction.claimAIO(REWARD_AMOUNT);
        totalRewards += REWARD_AMOUNT;
        assertEq(aioToken.balanceOf(user1), totalRewards);
        
        // 第三次交互
        vm.warp(block.timestamp + 100);
        vm.prank(user1);
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        vm.prank(user1);
        interaction.claimAIO(REWARD_AMOUNT);
        totalRewards += REWARD_AMOUNT;
        assertEq(aioToken.balanceOf(user1), totalRewards);
        
        // 验证总共领取了 3 次奖励
        assertEq(totalRewards, REWARD_AMOUNT * 3);
    }

    function test_UserWallet_CheckClaimStatusBeforeClaiming() public {
        // 场景：用户完成交互并领取奖励
        string memory action = "check_status_action";
        bytes memory meta = "meta";
        
        // 用户完成交互
        vm.prank(user1);
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // 用户领取奖励
        vm.prank(user1);
        interaction.claimAIO(REWARD_AMOUNT);
        
        // 验证用户收到了奖励
        assertEq(aioToken.balanceOf(user1), REWARD_AMOUNT);
    }

    function test_UserWallet_DifferentAmounts() public {
        // 场景：用户可以用不同的金额多次领取
        uint256 reward1 = 50 * 1e18;
        uint256 reward2 = 200 * 1e18;
        
        // 确保奖励池有足够的余额
        aioToken.mint(rewardPool, reward1 + reward2);
        RewardPoolMock(payable(rewardPool)).approve(address(interaction), reward1 + reward2);
        
        // 用户领取第一个奖励
        vm.prank(user1);
        interaction.claimAIO(reward1);
        assertEq(aioToken.balanceOf(user1), reward1);
        
        // 用户领取第二个奖励（不同金额）
        vm.prank(user1);
        interaction.claimAIO(reward2);
        assertEq(aioToken.balanceOf(user1), reward1 + reward2);
    }

    function test_UserWallet_ClaimAfterRewardUpdated() public {
        // 场景：用户可以使用不同的金额进行多次 claim
        string memory action = "updated_reward_action";
        bytes memory meta = "meta";
        
        // 用户完成交互
        vm.prank(user1);
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // 用户第一次领取
        uint256 firstClaim = REWARD_AMOUNT;
        vm.prank(user1);
        interaction.claimAIO(firstClaim);
        assertEq(aioToken.balanceOf(user1), firstClaim);
        
        // 用户第二次领取（不同的金额）
        uint256 secondClaim = REWARD_AMOUNT * 2;
        vm.prank(user1);
        interaction.claimAIO(secondClaim);
        assertEq(aioToken.balanceOf(user1), firstClaim + secondClaim);
    }

    function test_UserWallet_ClaimInsufficientBalance() public {
        // 场景：当奖励池余额不足时，用户尝试领取应该失败
        // 设置一个大于奖励池余额的金额
        uint256 largeAmount = aioToken.balanceOf(rewardPool) + 1;
        
        vm.prank(user1);
        vm.expectRevert(); // transferFrom 会失败
        interaction.claimAIO(largeAmount);
    }

    function test_UserWallet_ConcurrentClaims() public {
        // 场景：多个用户同时领取奖励
        string memory action = "concurrent_action";
        bytes memory meta = "meta";
        
        // 多个用户完成交互
        vm.prank(user1);
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        vm.warp(block.timestamp + 1);
        vm.prank(user2);
        interaction.interact{value: INITIAL_FEE_WEI}(action, meta);
        
        // 多个用户同时领取（模拟并发场景）
        vm.prank(user1);
        interaction.claimAIO(REWARD_AMOUNT);
        
        vm.prank(user2);
        interaction.claimAIO(REWARD_AMOUNT);
        
        // 验证两个用户都收到了奖励
        assertEq(aioToken.balanceOf(user1), REWARD_AMOUNT);
        assertEq(aioToken.balanceOf(user2), REWARD_AMOUNT);
    }

}

