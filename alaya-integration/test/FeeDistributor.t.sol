// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {FeeDistributor} from "../src/FeeDistributor.sol";
import {AIOERC20} from "../src/AIOERC20.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title MockERC20
 * @notice Simple ERC20 token for testing (used as USDT mock)
 */
contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

/**
 * @title ReentrancyAttacker
 * @notice Malicious contract that attempts reentrancy attack
 */
contract ReentrancyAttacker {
    FeeDistributor public feeDistributor;
    bool public attacking;

    constructor(address feeDistributor_) {
        feeDistributor = FeeDistributor(payable(feeDistributor_));
    }

    function attack() external payable {
        attacking = true;
        feeDistributor.collectEth{value: msg.value}();
        attacking = false;
    }

    receive() external payable {
        if (attacking && address(feeDistributor).balance > 0) {
            // Attempt reentrancy - should fail
            feeDistributor.collectEth{value: 0}();
        }
    }
}

contract FeeDistributorTest is Test {
    FeeDistributor public feeDistributor;
    MockERC20 public usdtToken;
    AIOERC20 public aioToken;

    address public owner;
    address public projectWallet;
    address public user1;
    address public user2;

    uint256 public constant INITIAL_FEE_WEI = 1e15; // 0.001 ETH
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 1e18; // 1 billion tokens

    // Events
    event FeeCollected(address indexed payer, uint256 amount);
    event Forwarded(address indexed to, uint256 amount);
    event ProjectWalletUpdated(address indexed newWallet);
    event FeeWeiUpdated(uint256 newFeeWei);
    event UsdtTokenUpdated(address indexed newUsdtToken);
    event AioTokenUpdated(address indexed newAioToken);

    function setUp() public {
        owner = address(this);
        projectWallet = address(0x100);
        user1 = address(0x1);
        user2 = address(0x2);

        // Create mock USDT token
        usdtToken = new MockERC20("Tether USD", "USDT");
        
        // Create AIO token
        aioToken = new AIOERC20(MAX_SUPPLY, owner);

        feeDistributor = new FeeDistributor(
            projectWallet,
            INITIAL_FEE_WEI,
            address(usdtToken),
            address(aioToken),
            owner
        );

        // Fund users
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        usdtToken.mint(user1, 1000 * 1e18);
        usdtToken.mint(user2, 1000 * 1e18);
        aioToken.mint(user1, 1000 * 1e18);
        aioToken.mint(user2, 1000 * 1e18);
    }

    // ============ Deployment Tests ============

    function test_Deployment() public view {
        assertEq(feeDistributor.projectWallet(), projectWallet);
        assertEq(feeDistributor.feeWei(), INITIAL_FEE_WEI);
        assertEq(feeDistributor.owner(), owner);
        assertEq(feeDistributor.usdtToken(), address(usdtToken));
        assertEq(feeDistributor.aioToken(), address(aioToken));
    }

    function test_Deployment_ZeroProjectWallet_Reverts() public {
        vm.expectRevert("FeeDistributor: projectWallet cannot be zero address");
        new FeeDistributor(address(0), INITIAL_FEE_WEI, address(usdtToken), address(aioToken), owner);
    }

    function test_Deployment_ZeroUsdtToken_Reverts() public {
        vm.expectRevert("FeeDistributor: usdtToken cannot be zero address");
        new FeeDistributor(projectWallet, INITIAL_FEE_WEI, address(0), address(aioToken), owner);
    }

    function test_Deployment_ZeroAioToken_Reverts() public {
        vm.expectRevert("FeeDistributor: aioToken cannot be zero address");
        new FeeDistributor(projectWallet, INITIAL_FEE_WEI, address(usdtToken), address(0), owner);
    }

    // ============ collectEth Tests ============

    function test_CollectEth_ExactFee_Success() public {
        uint256 amount = INITIAL_FEE_WEI;
        uint256 initialBalance = projectWallet.balance;

        vm.expectEmit(true, false, false, true);
        emit FeeCollected(user1, amount);

        vm.expectEmit(true, true, false, true);
        emit Forwarded(projectWallet, amount);

        vm.prank(user1);
        feeDistributor.collectEth{value: amount}();

        assertEq(projectWallet.balance, initialBalance + amount);
        assertEq(address(feeDistributor).balance, 0);
    }

    function test_CollectEth_GreaterThanFee_Success() public {
        uint256 amount = INITIAL_FEE_WEI * 2;
        uint256 initialBalance = projectWallet.balance;

        vm.expectEmit(true, false, false, true);
        emit FeeCollected(user1, amount);

        vm.expectEmit(true, true, false, true);
        emit Forwarded(projectWallet, amount);

        vm.prank(user1);
        feeDistributor.collectEth{value: amount}();

        assertEq(projectWallet.balance, initialBalance + amount);
        assertEq(address(feeDistributor).balance, 0);
    }

    function test_CollectEth_InsufficientFee_Reverts() public {
        uint256 amount = INITIAL_FEE_WEI - 1;

        vm.prank(user1);
        vm.expectRevert("FeeDistributor: insufficient fee");
        feeDistributor.collectEth{value: amount}();
    }

    function test_CollectEth_MultipleTimes() public {
        uint256 amount1 = INITIAL_FEE_WEI;
        uint256 amount2 = INITIAL_FEE_WEI * 2;
        uint256 initialBalance = projectWallet.balance;

        vm.prank(user1);
        feeDistributor.collectEth{value: amount1}();

        vm.prank(user2);
        feeDistributor.collectEth{value: amount2}();

        assertEq(projectWallet.balance, initialBalance + amount1 + amount2);
        assertEq(address(feeDistributor).balance, 0);
    }

    // ============ collectUsdt Tests ============

    function test_CollectUsdt_Success() public {
        uint256 amount = 100 * 1e18;
        uint256 initialBalance = usdtToken.balanceOf(projectWallet);

        // User approves
        vm.prank(user1);
        usdtToken.approve(address(feeDistributor), amount);

        vm.expectEmit(true, false, false, true);
        emit FeeCollected(user1, amount);

        vm.expectEmit(true, true, false, true);
        emit Forwarded(projectWallet, amount);

        vm.prank(user1);
        feeDistributor.collectUsdt(amount);

        assertEq(usdtToken.balanceOf(projectWallet), initialBalance + amount);
        assertEq(usdtToken.balanceOf(address(feeDistributor)), 0);
        assertEq(usdtToken.balanceOf(user1), 1000 * 1e18 - amount);
    }

    function test_CollectUsdt_ZeroAmount_Reverts() public {
        vm.prank(user1);
        vm.expectRevert("FeeDistributor: amount cannot be zero");
        feeDistributor.collectUsdt(0);
    }

    function test_CollectUsdt_InsufficientAllowance_Reverts() public {
        uint256 amount = 100 * 1e18;
        uint256 approvedAmount = amount - 1;

        vm.prank(user1);
        usdtToken.approve(address(feeDistributor), approvedAmount);

        vm.prank(user1);
        vm.expectRevert();
        feeDistributor.collectUsdt(amount);
    }

    function test_CollectUsdt_MultipleTimes() public {
        uint256 amount1 = 50 * 1e18;
        uint256 amount2 = 100 * 1e18;
        uint256 initialBalance = usdtToken.balanceOf(projectWallet);

        vm.startPrank(user1);
        usdtToken.approve(address(feeDistributor), amount1);
        feeDistributor.collectUsdt(amount1);
        vm.stopPrank();

        vm.startPrank(user2);
        usdtToken.approve(address(feeDistributor), amount2);
        feeDistributor.collectUsdt(amount2);
        vm.stopPrank();

        assertEq(usdtToken.balanceOf(projectWallet), initialBalance + amount1 + amount2);
        assertEq(usdtToken.balanceOf(address(feeDistributor)), 0);
    }

    // ============ collectAio Tests ============

    function test_CollectAio_Success() public {
        uint256 amount = 100 * 1e18;
        uint256 initialBalance = aioToken.balanceOf(projectWallet);

        // User approves
        vm.prank(user1);
        aioToken.approve(address(feeDistributor), amount);

        vm.expectEmit(true, false, false, true);
        emit FeeCollected(user1, amount);

        vm.expectEmit(true, true, false, true);
        emit Forwarded(projectWallet, amount);

        vm.prank(user1);
        feeDistributor.collectAio(amount);

        assertEq(aioToken.balanceOf(projectWallet), initialBalance + amount);
        assertEq(aioToken.balanceOf(address(feeDistributor)), 0);
        assertEq(aioToken.balanceOf(user1), 1000 * 1e18 - amount);
    }

    function test_CollectAio_ZeroAmount_Reverts() public {
        vm.prank(user1);
        vm.expectRevert("FeeDistributor: amount cannot be zero");
        feeDistributor.collectAio(0);
    }

    function test_CollectAio_InsufficientAllowance_Reverts() public {
        uint256 amount = 100 * 1e18;
        uint256 approvedAmount = amount - 1;

        vm.prank(user1);
        aioToken.approve(address(feeDistributor), approvedAmount);

        vm.prank(user1);
        vm.expectRevert();
        feeDistributor.collectAio(amount);
    }

    function test_CollectAio_MultipleTimes() public {
        uint256 amount1 = 50 * 1e18;
        uint256 amount2 = 100 * 1e18;
        uint256 initialBalance = aioToken.balanceOf(projectWallet);

        vm.startPrank(user1);
        aioToken.approve(address(feeDistributor), amount1);
        feeDistributor.collectAio(amount1);
        vm.stopPrank();

        vm.startPrank(user2);
        aioToken.approve(address(feeDistributor), amount2);
        feeDistributor.collectAio(amount2);
        vm.stopPrank();

        assertEq(aioToken.balanceOf(projectWallet), initialBalance + amount1 + amount2);
        assertEq(aioToken.balanceOf(address(feeDistributor)), 0);
    }

    // ============ Admin Functions Tests ============

    function test_SetProjectWallet_Success() public {
        address newWallet = address(0x200);

        vm.expectEmit(true, false, false, false);
        emit ProjectWalletUpdated(newWallet);

        feeDistributor.setProjectWallet(newWallet);

        assertEq(feeDistributor.projectWallet(), newWallet);
    }

    function test_SetProjectWallet_ZeroAddress_Reverts() public {
        vm.expectRevert("FeeDistributor: newWallet cannot be zero address");
        feeDistributor.setProjectWallet(address(0));
    }

    function test_SetProjectWallet_OnlyOwner_Reverts() public {
        vm.prank(user1);
        vm.expectRevert();
        feeDistributor.setProjectWallet(address(0x200));
    }

    function test_SetFeeWei_Success() public {
        uint256 newFee = 2e15;

        vm.expectEmit(true, false, false, true);
        emit FeeWeiUpdated(newFee);

        feeDistributor.setFeeWei(newFee);

        assertEq(feeDistributor.feeWei(), newFee);
    }

    function test_SetFeeWei_OnlyOwner_Reverts() public {
        vm.prank(user1);
        vm.expectRevert();
        feeDistributor.setFeeWei(2e15);
    }

    function test_SetUsdtToken_Success() public {
        MockERC20 newUsdtToken = new MockERC20("New USDT", "USDT");
        address newTokenAddress = address(newUsdtToken);

        vm.expectEmit(true, false, false, false);
        emit UsdtTokenUpdated(newTokenAddress);

        feeDistributor.setUsdtToken(newTokenAddress);

        assertEq(feeDistributor.usdtToken(), newTokenAddress);
    }

    function test_SetUsdtToken_ZeroAddress_Reverts() public {
        vm.expectRevert("FeeDistributor: newUsdtToken cannot be zero address");
        feeDistributor.setUsdtToken(address(0));
    }

    function test_SetUsdtToken_OnlyOwner_Reverts() public {
        vm.prank(user1);
        vm.expectRevert();
        feeDistributor.setUsdtToken(address(0x200));
    }

    function test_SetAioToken_Success() public {
        AIOERC20 newAioToken = new AIOERC20(MAX_SUPPLY, owner);
        address newTokenAddress = address(newAioToken);

        vm.expectEmit(true, false, false, false);
        emit AioTokenUpdated(newTokenAddress);

        feeDistributor.setAioToken(newTokenAddress);

        assertEq(feeDistributor.aioToken(), newTokenAddress);
    }

    function test_SetAioToken_ZeroAddress_Reverts() public {
        vm.expectRevert("FeeDistributor: newAioToken cannot be zero address");
        feeDistributor.setAioToken(address(0));
    }

    function test_SetAioToken_OnlyOwner_Reverts() public {
        vm.prank(user1);
        vm.expectRevert();
        feeDistributor.setAioToken(address(0x200));
    }

    // ============ Reentrancy Tests ============

    function test_Reentrancy_CollectEth_Safe() public {
        ReentrancyAttacker attacker = new ReentrancyAttacker(address(feeDistributor));

        uint256 amount = INITIAL_FEE_WEI;
        vm.deal(address(attacker), amount);

        // Should not revert due to reentrancy guard
        attacker.attack{value: amount}();

        // Project wallet should receive the fee
        assertEq(projectWallet.balance, amount);
    }

    function test_Reentrancy_CollectUsdt_Safe() public {
        // Create a malicious token that tries to reenter
        MaliciousERC20 maliciousToken = new MaliciousERC20(address(feeDistributor));
        maliciousToken.mint(user1, 1000 * 1e18);

        // Update USDT token to malicious token
        feeDistributor.setUsdtToken(address(maliciousToken));

        vm.prank(user1);
        maliciousToken.approve(address(feeDistributor), 100 * 1e18);

        // Should not revert due to reentrancy guard
        vm.prank(user1);
        feeDistributor.collectUsdt(100 * 1e18);
    }

    function test_Reentrancy_CollectAio_Safe() public {
        // Create a malicious token that tries to reenter
        MaliciousERC20 maliciousToken = new MaliciousERC20(address(feeDistributor));
        maliciousToken.mint(user1, 1000 * 1e18);

        // Update AIO token to malicious token
        feeDistributor.setAioToken(address(maliciousToken));

        vm.prank(user1);
        maliciousToken.approve(address(feeDistributor), 100 * 1e18);

        // Should not revert due to reentrancy guard
        vm.prank(user1);
        feeDistributor.collectAio(100 * 1e18);
    }

    // ============ Edge Cases ============

    function test_CollectEth_UpdateFeeThenCollect() public {
        // Change fee
        feeDistributor.setFeeWei(2e15);

        uint256 amount = 2e15;
        uint256 initialBalance = projectWallet.balance;

        vm.prank(user1);
        feeDistributor.collectEth{value: amount}();

        assertEq(projectWallet.balance, initialBalance + amount);
    }

    function test_CollectUsdt_UpdateProjectWallet() public {
        address newWallet = address(0x200);
        feeDistributor.setProjectWallet(newWallet);

        uint256 amount = 100 * 1e18;
        vm.prank(user1);
        usdtToken.approve(address(feeDistributor), amount);

        vm.prank(user1);
        feeDistributor.collectUsdt(amount);

        assertEq(usdtToken.balanceOf(newWallet), amount);
    }

    function test_CollectAio_UpdateProjectWallet() public {
        address newWallet = address(0x200);
        feeDistributor.setProjectWallet(newWallet);

        uint256 amount = 100 * 1e18;
        vm.prank(user1);
        aioToken.approve(address(feeDistributor), amount);

        vm.prank(user1);
        feeDistributor.collectAio(amount);

        assertEq(aioToken.balanceOf(newWallet), amount);
    }

    function test_CollectUsdt_UpdateUsdtToken() public {
        MockERC20 newUsdtToken = new MockERC20("New USDT", "USDT");
        newUsdtToken.mint(user1, 500 * 1e18);

        feeDistributor.setUsdtToken(address(newUsdtToken));

        uint256 amount = 100 * 1e18;
        vm.prank(user1);
        newUsdtToken.approve(address(feeDistributor), amount);

        vm.prank(user1);
        feeDistributor.collectUsdt(amount);

        assertEq(newUsdtToken.balanceOf(projectWallet), amount);
    }

    function test_CollectAio_UpdateAioToken() public {
        AIOERC20 newAioToken = new AIOERC20(MAX_SUPPLY, owner);
        newAioToken.mint(user1, 500 * 1e18);

        feeDistributor.setAioToken(address(newAioToken));

        uint256 amount = 100 * 1e18;
        vm.prank(user1);
        newAioToken.approve(address(feeDistributor), amount);

        vm.prank(user1);
        feeDistributor.collectAio(amount);

        assertEq(newAioToken.balanceOf(projectWallet), amount);
    }

    // ============ Fuzz Tests ============

    function testFuzz_CollectEth(uint256 amount) public {
        amount = bound(amount, INITIAL_FEE_WEI, 100 ether);
        uint256 initialBalance = projectWallet.balance;

        vm.deal(user1, amount);
        vm.prank(user1);
        feeDistributor.collectEth{value: amount}();

        assertEq(projectWallet.balance, initialBalance + amount);
        assertEq(address(feeDistributor).balance, 0);
    }

    function testFuzz_CollectUsdt(uint256 amount) public {
        amount = bound(amount, 1, 1000 * 1e18);
        uint256 initialBalance = usdtToken.balanceOf(projectWallet);
        usdtToken.mint(user1, amount);

        vm.prank(user1);
        usdtToken.approve(address(feeDistributor), amount);

        vm.prank(user1);
        feeDistributor.collectUsdt(amount);

        assertEq(usdtToken.balanceOf(projectWallet), initialBalance + amount);
        assertEq(usdtToken.balanceOf(address(feeDistributor)), 0);
    }

    function testFuzz_CollectAio(uint256 amount) public {
        amount = bound(amount, 1, 1000 * 1e18);
        uint256 initialBalance = aioToken.balanceOf(projectWallet);
        aioToken.mint(user1, amount);

        vm.prank(user1);
        aioToken.approve(address(feeDistributor), amount);

        vm.prank(user1);
        feeDistributor.collectAio(amount);

        assertEq(aioToken.balanceOf(projectWallet), initialBalance + amount);
        assertEq(aioToken.balanceOf(address(feeDistributor)), 0);
    }
}

/**
 * @title MaliciousERC20
 * @notice ERC20 token that attempts reentrancy attack on transfer
 */
contract MaliciousERC20 is ERC20 {
    FeeDistributor public feeDistributor;
    bool public reentering;

    constructor(address feeDistributor_) ERC20("MaliciousToken", "MAL") {
        feeDistributor = FeeDistributor(payable(feeDistributor_));
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function transfer(address to, uint256 value) public override returns (bool) {
        if (!reentering && to == address(feeDistributor) && balanceOf(msg.sender) > 0) {
            reentering = true;
            // Attempt to call collectUsdt/collectAio again - should fail due to reentrancy guard
            try feeDistributor.collectUsdt(1) {} catch {}
            reentering = false;
        }
        return super.transfer(to, value);
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        if (!reentering && to == address(feeDistributor) && balanceOf(from) > 0) {
            reentering = true;
            // Attempt to call collectUsdt/collectAio again - should fail due to reentrancy guard
            try feeDistributor.collectUsdt(1) {} catch {}
            reentering = false;
        }
        return super.transferFrom(from, to, value);
    }
}