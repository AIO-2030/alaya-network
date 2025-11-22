// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {AIOERC20} from "../src/AIOERC20.sol";

/**
 * @title MintScript
 * @notice Script for minting additional tokens after initial deployment
 * @dev Only the owner (Safe multisig) can mint tokens
 * 
 * Usage:
 *   forge script script/Mint.s.sol:MintScript --sig "mint(address,uint256)" <TOKEN_ADDRESS> <RECIPIENT_ADDRESS> <AMOUNT> --rpc-url <RPC_URL> --broadcast --private-key <PRIVATE_KEY>
 * 
 * Example (mint 10 million tokens with 8 decimals):
 *   forge script script/Mint.s.sol:MintScript --sig "mint(address,uint256)" 0x... 0x... 10000000 --rpc-url https://base-sepolia.g.alchemy.com/v2/... --broadcast --private-key $PRIVATE_KEY
 * 
 * Note: Amount should be specified without decimals (e.g., 10000000 for 10 million tokens)
 * The script will automatically multiply by 1e8 (8 decimals)
 */
contract MintScript is Script {
    /**
     * @notice Mints tokens to the specified address
     * @param tokenAddress Address of the AIOERC20 token contract
     * @param recipient Address to receive the minted tokens
     * @param amount Amount of tokens to mint (without decimals, will be multiplied by 1e8)
     */
    function mint(address tokenAddress, address recipient, uint256 amount) public {
        require(tokenAddress != address(0), "Token address cannot be zero");
        require(recipient != address(0), "Recipient address cannot be zero");
        require(amount > 0, "Amount must be greater than zero");

        AIOERC20 token = AIOERC20(tokenAddress);
        
        // Get owner address
        address owner = token.owner();
        require(owner != address(0), "Token contract has no owner");

        console.log("=== Mint Configuration ===");
        console.log("Token Address:", tokenAddress);
        console.log("Owner:", owner);
        console.log("Recipient:", recipient);
        console.log("Amount (without decimals):", amount);
        
        // Convert amount to token units (8 decimals)
        uint256 amountWithDecimals = amount * 1e8;
        console.log("Amount (with 8 decimals):", amountWithDecimals);
        
        // Check current supply
        uint256 currentTotalMinted = token.totalMinted();
        uint256 maxSupply = token.MAX_SUPPLY();
        uint256 remainingSupply = maxSupply - currentTotalMinted;
        
        console.log("Current Total Minted:", currentTotalMinted);
        console.log("Max Supply:", maxSupply);
        console.log("Remaining Supply:", remainingSupply);
        
        require(amountWithDecimals <= remainingSupply, "Mint amount exceeds remaining supply");

        // Security check: Verify owner is set and log warning
        console.log("\n=== Security Check ===");
        console.log("Token Owner:", owner);
        if (owner == address(0)) {
            revert("MintScript: Token owner is zero address - contract may not be properly deployed");
        }
        console.log("WARNING: Only the owner can mint tokens.");
        console.log("WARNING: In production, ensure you are using the Safe multisig owner's private key.");
        console.log("WARNING: If owner is Safe multisig, use Safe interface to execute mint transaction.");
        console.log("=====================");
        
        vm.startBroadcast();

        // Mint tokens (must be called by owner)
        // Note: The contract's onlyOwner modifier will enforce this at the contract level
        // If the caller is not the owner, the transaction will revert with "Ownable: caller is not the owner"
        console.log("\nMinting tokens...");
        console.log("Note: Transaction will fail if caller is not the owner");
        token.mint(recipient, amountWithDecimals);
        
        console.log("\n=== Mint Successful ===");
        console.log("New Total Minted:", token.totalMinted());
        console.log("Recipient Balance:", token.balanceOf(recipient));
        console.log("Remaining Supply:", maxSupply - token.totalMinted());

        vm.stopBroadcast();
    }

    /**
     * @notice Mints tokens using environment variables
     * @dev Reads TOKEN_ADDRESS, RECIPIENT_ADDRESS, and MINT_AMOUNT from environment
     * 
     * Usage:
     *   TOKEN_ADDRESS=0x... RECIPIENT_ADDRESS=0x... MINT_AMOUNT=10000000 forge script script/Mint.s.sol:MintScript --sig "mintFromEnv()" --rpc-url <RPC_URL> --broadcast --private-key <PRIVATE_KEY>
     */
    function mintFromEnv() public {
        address tokenAddress = vm.envAddress("TOKEN_ADDRESS");
        address recipient = vm.envAddress("RECIPIENT_ADDRESS");
        uint256 amount = vm.envUint("MINT_AMOUNT");
        
        mint(tokenAddress, recipient, amount);
    }

    /**
     * @notice Checks token information without minting
     * @param tokenAddress Address of the AIOERC20 token contract
     */
    function checkTokenInfo(address tokenAddress) public view {
        require(tokenAddress != address(0), "Token address cannot be zero");
        
        AIOERC20 token = AIOERC20(tokenAddress);
        
        console.log("=== Token Information ===");
        console.log("Token Address:", tokenAddress);
        console.log("Name:", token.name());
        console.log("Symbol:", token.symbol());
        console.log("Decimals:", token.decimals());
        console.log("Owner:", token.owner());
        console.log("Max Supply:", token.MAX_SUPPLY());
        console.log("Total Minted:", token.totalMinted());
        console.log("Total Supply:", token.totalSupply());
        console.log("Remaining Supply:", token.MAX_SUPPLY() - token.totalMinted());
        console.log("=========================");
    }
}

