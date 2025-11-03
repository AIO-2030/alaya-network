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

contract InteractionTest is Test {
    Interaction public interaction;
    FeeDistributor public feeDistributor;
    MockERC20 public mockToken;
    AIOERC20 public aioToken;

    address public owner;
    address public projectWallet;
    address public user1;
    address public user2;

    uint256 public constant INITIAL_FEE_WEI = 1e15; // 0.001 ETH
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18; // 1 billion tokens

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

    function setUp() public {
        owner = address(this);
        projectWallet = address(0x100);
        user1 = address(0x1);
        user2 = address(0x2);

        // Create mock ERC20 token
        mockToken = new MockERC20("Mock Token", "MOCK");

        // Create AIO token
        aioToken = new AIOERC20(MAX_SUPPLY, owner);

        // Create FeeDistributor
        feeDistributor = new FeeDistributor(
            projectWallet,
            INITIAL_FEE_WEI,
            address(mockToken), // usdtToken
            address(aioToken), // aioToken
            owner
        );

        // Create Interaction contract
        interaction = new Interaction(address(feeDistributor), owner);

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

    // ============ interact20 (ERC20) Tests ============

    function test_Interact20_Success() public {
        uint256 amount = 100 * 1e18;
        string memory action = "test_action";
        bytes memory meta = "test_meta";
        uint256 initialBalance = mockToken.balanceOf(projectWallet);

        // User approves
        vm.startPrank(user1);
        mockToken.approve(address(interaction), amount);

        bytes32 actionHash = keccak256(bytes(action));
        vm.expectEmit(true, true, false, true);
        emit InteractionRecorded(user1, actionHash, action, meta, block.timestamp);

        interaction.interact20(address(mockToken), amount, action, meta);
        vm.stopPrank();

        assertEq(mockToken.balanceOf(projectWallet), initialBalance + amount);
        assertEq(mockToken.balanceOf(address(feeDistributor)), 0);
        assertEq(mockToken.balanceOf(user1), 1000 * 1e18 - amount);
    }

    function test_Interact20_ZeroToken_Reverts() public {
        uint256 amount = 100 * 1e18;
        string memory action = "test_action";
        bytes memory meta = "test_meta";

        vm.prank(user1);
        vm.expectRevert("Interaction: token cannot be zero address");
        interaction.interact20(address(0), amount, action, meta);
    }

    function test_Interact20_ZeroAmount_Reverts() public {
        string memory action = "test_action";
        bytes memory meta = "test_meta";

        vm.prank(user1);
        vm.expectRevert("Interaction: amount cannot be zero");
        interaction.interact20(address(mockToken), 0, action, meta);
    }

    function test_Interact20_InsufficientAllowance_Reverts() public {
        uint256 amount = 100 * 1e18;
        uint256 approvedAmount = amount - 1;
        string memory action = "test_action";
        bytes memory meta = "test_meta";

        vm.prank(user1);
        mockToken.approve(address(interaction), approvedAmount);

        vm.prank(user1);
        vm.expectRevert();
        interaction.interact20(address(mockToken), amount, action, meta);
    }

    function test_Interact20_MultipleInteractions() public {
        uint256 amount1 = 50 * 1e18;
        uint256 amount2 = 100 * 1e18;
        uint256 initialBalance = mockToken.balanceOf(projectWallet);

        vm.startPrank(user1);
        mockToken.approve(address(interaction), amount1);
        interaction.interact20(address(mockToken), amount1, "action1", "meta1");
        vm.stopPrank();

        vm.startPrank(user2);
        mockToken.approve(address(interaction), amount2);
        interaction.interact20(address(mockToken), amount2, "action2", "meta2");
        vm.stopPrank();

        assertEq(mockToken.balanceOf(projectWallet), initialBalance + amount1 + amount2);
        assertEq(mockToken.balanceOf(user1), 1000 * 1e18 - amount1);
        assertEq(mockToken.balanceOf(user2), 1000 * 1e18 - amount2);
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

    function test_Allowlist_WorksForInteract20() public {
        uint256 amount = 100 * 1e18;
        string memory action = "disallowed_action";
        bytes memory meta = "meta";

        // Enable allowlist
        interaction.setAllowlistEnabled(true);

        vm.prank(user1);
        mockToken.approve(address(interaction), amount);

        vm.prank(user1);
        vm.expectRevert("Interaction: action not allowed");
        interaction.interact20(address(mockToken), amount, action, meta);
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
        (uint256 feeWei_, address feeDistributor_, bool allowlistEnabled_) =
            interaction.getConfig();

        assertEq(feeWei_, INITIAL_FEE_WEI);
        assertEq(feeDistributor_, address(feeDistributor));
        assertFalse(allowlistEnabled_);
    }

    function test_GetConfig_AfterChanges() public {
        interaction.setAllowlistEnabled(true);
        feeDistributor.setFeeWei(2e15);

        (uint256 feeWei_, address feeDistributor_, bool allowlistEnabled_) =
            interaction.getConfig();

        assertEq(feeWei_, 2e15);
        assertEq(feeDistributor_, address(feeDistributor));
        assertTrue(allowlistEnabled_);
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

    function test_Integration_FullFlow_ERC20() public {
        uint256 amount = 100 * 1e18;
        string memory action = "integration_test_erc20";
        bytes memory meta = "integration_meta_erc20";
        uint256 initialBalance = mockToken.balanceOf(projectWallet);
        uint256 user1InitialBalance = mockToken.balanceOf(user1);

        // User approves and interacts
        vm.startPrank(user1);
        mockToken.approve(address(interaction), amount);
        interaction.interact20(address(mockToken), amount, action, meta);
        vm.stopPrank();

        // Verify tokens were forwarded
        assertEq(mockToken.balanceOf(projectWallet), initialBalance + amount);
        assertEq(mockToken.balanceOf(user1), user1InitialBalance - amount);
        assertEq(mockToken.balanceOf(address(feeDistributor)), 0);
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

    function testFuzz_Interact20(uint256 amount) public {
        amount = bound(amount, 1, 1000 * 1e18);
        uint256 initialBalance = mockToken.balanceOf(projectWallet);
        uint256 user1InitialBalance = mockToken.balanceOf(user1);
        
        // Mint additional tokens if needed
        if (user1InitialBalance < amount) {
            mockToken.mint(user1, amount - user1InitialBalance);
        }

        vm.startPrank(user1);
        mockToken.approve(address(interaction), amount);
        interaction.interact20(address(mockToken), amount, "fuzz_action", "fuzz_meta");
        vm.stopPrank();

        assertEq(mockToken.balanceOf(projectWallet), initialBalance + amount);
        assertEq(mockToken.balanceOf(address(feeDistributor)), 0);
    }
}

