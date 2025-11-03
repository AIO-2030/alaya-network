// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {AIOERC20} from "../src/AIOERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";

contract AIOERC20Test is Test {
    AIOERC20 public token;
    address public owner;
    address public user1;
    address public user2;
    address public safe;
    
    uint256 public constant MAX_SUPPLY = 1_000_000_000 * 10**18; // 1 billion tokens

    event Minted(address indexed to, uint256 amount);
    event Burned(address indexed from, uint256 amount);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        safe = address(0x3); // Simulated Safe address
        
        token = new AIOERC20(MAX_SUPPLY, owner);
    }

    // ============ Deployment Tests ============

    function test_Deployment() public view {
        assertEq(token.name(), "AIO2030");
        assertEq(token.symbol(), "AIO");
        assertEq(token.decimals(), 18);
        assertEq(token.MAX_SUPPLY(), MAX_SUPPLY);
        assertEq(token.totalSupply(), 0);
        assertEq(token.totalMinted(), 0);
        assertEq(token.owner(), owner);
    }

    function test_Deployment_ZeroMaxSupply_Reverts() public {
        vm.expectRevert("AIOERC20: maxSupply cannot be zero");
        new AIOERC20(0, owner);
    }

    // ============ Mint Tests ============

    function test_Mint_Success() public {
        uint256 amount = 100 * 10**18;
        
        vm.expectEmit(true, false, false, true);
        emit Minted(user1, amount);
        
        token.mint(user1, amount);
        
        assertEq(token.balanceOf(user1), amount);
        assertEq(token.totalSupply(), amount);
        assertEq(token.totalMinted(), amount);
    }

    function test_Mint_ExceedMaxSupply_Reverts() public {
        token.mint(user1, MAX_SUPPLY);
        
        vm.expectRevert("AIOERC20: mint would exceed MAX_SUPPLY");
        token.mint(user2, 1);
    }

    function test_Mint_ToZeroAddress_Reverts() public {
        vm.expectRevert("AIOERC20: cannot mint to zero address");
        token.mint(address(0), 100 * 10**18);
    }

    function test_Mint_ZeroAmount_Reverts() public {
        vm.expectRevert("AIOERC20: amount cannot be zero");
        token.mint(user1, 0);
    }

    function test_Mint_OnlyOwner_Reverts() public {
        vm.prank(user1);
        vm.expectRevert();
        token.mint(user2, 100 * 10**18);
    }

    function test_Mint_MultipleTimes() public {
        uint256 amount1 = 100 * 10**18;
        uint256 amount2 = 200 * 10**18;
        
        token.mint(user1, amount1);
        token.mint(user2, amount2);
        
        assertEq(token.balanceOf(user1), amount1);
        assertEq(token.balanceOf(user2), amount2);
        assertEq(token.totalSupply(), amount1 + amount2);
        assertEq(token.totalMinted(), amount1 + amount2);
    }

    function test_Mint_AtMaxSupply() public {
        token.mint(user1, MAX_SUPPLY);
        
        assertEq(token.totalSupply(), MAX_SUPPLY);
        assertEq(token.totalMinted(), MAX_SUPPLY);
        assertEq(token.balanceOf(user1), MAX_SUPPLY);
    }

    // ============ Burn Tests ============

    function test_Burn_Success() public {
        uint256 mintAmount = 1000 * 10**18;
        uint256 burnAmount = 300 * 10**18;
        
        token.mint(user1, mintAmount);
        
        vm.prank(user1);
        vm.expectEmit(true, false, false, true);
        emit Burned(user1, burnAmount);
        
        token.burn(burnAmount);
        
        assertEq(token.balanceOf(user1), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
        assertEq(token.totalMinted(), mintAmount); // totalMinted should remain unchanged
    }

    function test_Burn_ZeroAmount_Reverts() public {
        token.mint(user1, 100 * 10**18);
        
        vm.prank(user1);
        vm.expectRevert("AIOERC20: amount cannot be zero");
        token.burn(0);
    }

    function test_Burn_InsufficientBalance_Reverts() public {
        token.mint(user1, 100 * 10**18);
        
        vm.prank(user1);
        vm.expectRevert();
        token.burn(200 * 10**18);
    }

    function test_BurnFrom_Success() public {
        uint256 mintAmount = 1000 * 10**18;
        uint256 burnAmount = 300 * 10**18;
        
        token.mint(user1, mintAmount);
        
        vm.prank(user1);
        token.approve(user2, burnAmount);
        
        vm.prank(user2);
        vm.expectEmit(true, false, false, true);
        emit Burned(user1, burnAmount);
        
        token.burnFrom(user1, burnAmount);
        
        assertEq(token.balanceOf(user1), mintAmount - burnAmount);
        assertEq(token.totalSupply(), mintAmount - burnAmount);
        assertEq(token.allowance(user1, user2), 0);
    }

    function test_BurnFrom_ZeroAddress_Reverts() public {
        vm.expectRevert("AIOERC20: cannot burn from zero address");
        token.burnFrom(address(0), 100 * 10**18);
    }

    function test_BurnFrom_ZeroAmount_Reverts() public {
        token.mint(user1, 100 * 10**18);
        
        vm.expectRevert("AIOERC20: amount cannot be zero");
        token.burnFrom(user1, 0);
    }

    function test_BurnFrom_InsufficientAllowance_Reverts() public {
        token.mint(user1, 1000 * 10**18);
        
        vm.prank(user1);
        token.approve(user2, 100 * 10**18);
        
        vm.prank(user2);
        vm.expectRevert();
        token.burnFrom(user1, 200 * 10**18);
    }

    function test_BurnAndMint_SupplyTracking() public {
        uint256 mintAmount = 1000 * 10**18;
        uint256 burnAmount = 300 * 10**18;
        
        token.mint(user1, mintAmount);
        assertEq(token.totalMinted(), mintAmount);
        
        vm.prank(user1);
        token.burn(burnAmount);
        assertEq(token.totalMinted(), mintAmount); // Should remain the same
        
        token.mint(user2, 200 * 10**18);
        assertEq(token.totalMinted(), mintAmount + 200 * 10**18);
        assertEq(token.totalSupply(), mintAmount - burnAmount + 200 * 10**18);
    }

    // ============ Permit Tests (EIP-2612) ============

    function test_Permit_Success() public {
        uint256 privateKey = 0x123;
        address signer = vm.addr(privateKey);
        
        uint256 amount = 100 * 10**18;
        token.mint(signer, amount);
        
        uint256 nonce = token.nonces(signer);
        uint256 deadline = block.timestamp + 1 hours;
        
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                signer,
                user1,
                amount,
                nonce,
                deadline
            )
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        
        token.permit(signer, user1, amount, deadline, v, r, s);
        
        assertEq(token.allowance(signer, user1), amount);
        assertEq(token.nonces(signer), nonce + 1);
    }

    function test_Permit_ExpiredDeadline_Reverts() public {
        uint256 privateKey = 0x123;
        address signer = vm.addr(privateKey);
        
        uint256 amount = 100 * 10**18;
        token.mint(signer, amount);
        
        uint256 nonce = token.nonces(signer);
        uint256 deadline = block.timestamp - 1; // Expired
        
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                signer,
                user1,
                amount,
                nonce,
                deadline
            )
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, digest);
        
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("ERC2612ExpiredSignature(uint256)")),
                deadline
            )
        );
        token.permit(signer, user1, amount, deadline, v, r, s);
    }

    function test_Permit_InvalidSignature_Reverts() public {
        uint256 privateKey = 0x123;
        address signer = vm.addr(privateKey);
        
        uint256 amount = 100 * 10**18;
        token.mint(signer, amount);
        
        uint256 nonce = token.nonces(signer);
        uint256 deadline = block.timestamp + 1 hours;
        
        bytes32 domainSeparator = token.DOMAIN_SEPARATOR();
        
        bytes32 structHash = keccak256(
            abi.encode(
                keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                signer,
                user1,
                amount,
                nonce,
                deadline
            )
        );
        
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                domainSeparator,
                structHash
            )
        );
        
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(0x456, digest); // Different private key
        
        address wrongSigner = vm.addr(0x456);
        vm.expectRevert(
            abi.encodeWithSelector(
                bytes4(keccak256("ERC2612InvalidSigner(address,address)")),
                wrongSigner,
                signer
            )
        );
        token.permit(signer, user1, amount, deadline, v, r, s);
    }

    // ============ Ownership Tests ============

    function test_TransferOwnership_Success() public {
        vm.expectEmit(true, true, false, false);
        emit OwnershipTransferred(owner, safe);
        
        token.transferOwnership(safe);
        
        assertEq(token.owner(), safe);
    }

    function test_TransferOwnership_OnlyOwner_Reverts() public {
        vm.prank(user1);
        vm.expectRevert();
        token.transferOwnership(safe);
    }

    function test_TransferOwnership_NewOwnerCanMint() public {
        token.transferOwnership(safe);
        
        vm.prank(safe);
        token.mint(user1, 100 * 10**18);
        
        assertEq(token.balanceOf(user1), 100 * 10**18);
    }

    function test_TransferOwnership_OldOwnerCannotMint() public {
        token.transferOwnership(safe);
        
        vm.expectRevert();
        token.mint(user1, 100 * 10**18);
    }

    // ============ Edge Cases ============

    function test_Mint_ThenBurn_ThenMintAgain() public {
        uint256 amount1 = 500 * 10**18;
        uint256 amount2 = 300 * 10**18;
        uint256 amount3 = 200 * 10**18;
        
        // Mint initial amount
        token.mint(user1, amount1);
        assertEq(token.totalMinted(), amount1);
        
        // Burn some
        vm.prank(user1);
        token.burn(amount2);
        assertEq(token.totalMinted(), amount1); // Unchanged
        assertEq(token.totalSupply(), amount1 - amount2);
        
        // Mint again (should work, totalMinted increases)
        token.mint(user2, amount3);
        assertEq(token.totalMinted(), amount1 + amount3);
        assertEq(token.totalSupply(), amount1 - amount2 + amount3);
        
        // Can mint more until we hit MAX_SUPPLY
        uint256 remaining = MAX_SUPPLY - token.totalMinted();
        token.mint(user2, remaining);
        assertEq(token.totalMinted(), MAX_SUPPLY);
    }

    function test_Fuzz_Mint(uint256 amount) public {
        amount = bound(amount, 1, MAX_SUPPLY);
        
        uint256 currentMinted = token.totalMinted();
        uint256 maxCanMint = MAX_SUPPLY - currentMinted;
        
        if (amount > maxCanMint) {
            vm.expectRevert("AIOERC20: mint would exceed MAX_SUPPLY");
            token.mint(user1, amount);
        } else {
            token.mint(user1, amount);
            assertEq(token.balanceOf(user1), amount);
            assertEq(token.totalMinted(), amount);
        }
    }
}
