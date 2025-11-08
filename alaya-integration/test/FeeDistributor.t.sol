// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {FeeDistributor} from "../src/FeeDistributor.sol";

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

    address public owner;
    address public projectWallet;
    address public user1;
    address public user2;

    uint256 public constant INITIAL_FEE_WEI = 1e15; // 0.001 ETH

    // Events
    event FeeCollected(address indexed payer, uint256 amount);
    event Forwarded(address indexed to, uint256 amount);
    event ProjectWalletUpdated(address indexed newWallet);
    event FeeWeiUpdated(uint256 newFeeWei);

    function setUp() public {
        owner = address(this);
        projectWallet = address(0x100);
        user1 = address(0x1);
        user2 = address(0x2);

        feeDistributor = new FeeDistributor(
            projectWallet,
            INITIAL_FEE_WEI,
            owner
        );

        // Fund users
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    // ============ Deployment Tests ============

    function test_Deployment() public view {
        assertEq(feeDistributor.projectWallet(), projectWallet);
        assertEq(feeDistributor.feeWei(), INITIAL_FEE_WEI);
        assertEq(feeDistributor.owner(), owner);
    }

    function test_Deployment_ZeroProjectWallet_Reverts() public {
        vm.expectRevert("FeeDistributor: projectWallet cannot be zero address");
        new FeeDistributor(address(0), INITIAL_FEE_WEI, owner);
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

    function test_CollectEth_UpdateProjectWallet() public {
        address newWallet = address(0x200);
        feeDistributor.setProjectWallet(newWallet);

        uint256 amount = INITIAL_FEE_WEI;
        uint256 initialBalance = newWallet.balance;

        vm.prank(user1);
        feeDistributor.collectEth{value: amount}();

        assertEq(newWallet.balance, initialBalance + amount);
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
}
