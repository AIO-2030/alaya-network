// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title AIOERC20
 * @notice AIO2030 (AIO) - A utility/incentive token for verifiable interactions on Base Proof layer
 * @dev Production-ready ERC20 token with:
 *      - Fixed maximum supply
 *      - Owner-controlled minting
 *      - Burn functionality
 *      - EIP-2612 permit support
 */
contract AIOERC20 is ERC20, ERC20Permit, Ownable {
    /// @notice Maximum supply of tokens that can ever exist
    uint256 public immutable MAX_SUPPLY;

    /// @notice Total amount of tokens minted (may be less than totalSupply if tokens are burned)
    uint256 public totalMinted;

    /// @notice Emitted when tokens are minted
    /// @param to Address that received the minted tokens
    /// @param amount Amount of tokens minted
    event Minted(address indexed to, uint256 amount);

    /// @notice Emitted when tokens are burned
    /// @param from Address from which tokens were burned
    /// @param amount Amount of tokens burned
    event Burned(address indexed from, uint256 amount);

    /**
     * @notice Deploys AIOERC20 token contract
     * @param maxSupply_ Maximum supply of tokens that can ever be minted
     * @param owner_ Address that will own the contract (typically a Safe multisig)
     */
    constructor(uint256 maxSupply_, address owner_) ERC20("AIO2030", "AIO") ERC20Permit("AIO2030") Ownable(owner_) {
        if (maxSupply_ == 0) {
            revert("AIOERC20: maxSupply cannot be zero");
        }
        MAX_SUPPLY = maxSupply_;
    }

    /**
     * @notice Mints tokens to the specified address
     * @dev Only callable by the owner. Reverts if minting would exceed MAX_SUPPLY
     * @param to Address to receive the minted tokens
     * @param amount Amount of tokens to mint
     */
    function mint(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) {
            revert("AIOERC20: cannot mint to zero address");
        }
        if (amount == 0) {
            revert("AIOERC20: amount cannot be zero");
        }
        
        uint256 newTotalMinted = totalMinted + amount;
        if (newTotalMinted > MAX_SUPPLY) {
            revert("AIOERC20: mint would exceed MAX_SUPPLY");
        }

        totalMinted = newTotalMinted;
        _mint(to, amount);
        emit Minted(to, amount);
    }

    /**
     * @notice Burns tokens from the caller's balance
     * @param amount Amount of tokens to burn
     */
    function burn(uint256 amount) external {
        if (amount == 0) {
            revert("AIOERC20: amount cannot be zero");
        }
        _burn(msg.sender, amount);
        emit Burned(msg.sender, amount);
    }

    /**
     * @notice Burns tokens from a specified address (requires allowance)
     * @param from Address from which to burn tokens
     * @param amount Amount of tokens to burn
     */
    function burnFrom(address from, uint256 amount) external {
        if (from == address(0)) {
            revert("AIOERC20: cannot burn from zero address");
        }
        if (amount == 0) {
            revert("AIOERC20: amount cannot be zero");
        }
        _spendAllowance(from, msg.sender, amount);
        _burn(from, amount);
        emit Burned(from, amount);
    }

    /**
     * @notice Transfers ownership of the contract to a new owner
     * @dev Only callable by the current owner
     * @param newOwner Address of the new owner
     */
    function transferOwnership(address newOwner) public override onlyOwner {
        super.transferOwnership(newOwner);
    }
}
